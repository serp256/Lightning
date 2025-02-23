#include "engine_android.h"
#include "lightning_android.h"
#include "mobile_res.h"

#include <pthread.h>
#include <fcntl.h>
#include <errno.h>

jclass lightning_cls;

void lightning_uncaught_exception(const char* exn, int bc, char** bv) {
    __android_log_write(ANDROID_LOG_FATAL,"LIGHTNING", exn);
    int i;

    PRINT_DEBUG("1 tid %d", gettid());
    jobjectArray jbc = (*ML_ENV)->NewObjectArray(ML_ENV,bc, engine_find_class("java/lang/String"),NULL);
    PRINT_DEBUG("2");

    for (i = 0; i < bc; i++) {
        if (bv[i]) {
            __android_log_write(ANDROID_LOG_FATAL,"LIGHTNING",bv[i]);
            jstring jbve = (*ML_ENV)->NewStringUTF(ML_ENV,bv[i]);
            (*ML_ENV)->SetObjectArrayElement(ML_ENV,jbc,i,jbve);
            (*ML_ENV)->DeleteLocalRef(ML_ENV,jbve);
        };
    };

    PRINT_DEBUG("3");

    // Need to send email with this error and backtrace
    jstring jexn = (*ML_ENV)->NewStringUTF(ML_ENV,exn);
    PRINT_DEBUG("4");
    jmethodID mlUncExn = (*ML_ENV)->GetStaticMethodID(ML_ENV, lightning_cls, "uncaughtException","(Ljava/lang/String;[Ljava/lang/String;)V");
    PRINT_DEBUG("5");
    (*ML_ENV)->CallStaticVoidMethod(ML_ENV, lightning_cls, mlUncExn, jexn, jbc);
    PRINT_DEBUG("6");
    (*ML_ENV)->DeleteLocalRef(ML_ENV,jbc);
    PRINT_DEBUG("7");
}

void lightning_init() {
    lightning_cls = engine_find_class("ru/redspell/lightning/Lightning");
    jmethodID mid = (*ML_ENV)->GetStaticMethodID(ML_ENV, lightning_cls, "init", "()V");
    (*ML_ENV)->CallStaticVoidMethod(ML_ENV, lightning_cls, mid);
}

char *lightning_get_locale() {
	static char *retval = NULL;

    if (!retval) {
        jmethodID mid = (*ML_ENV)->GetStaticMethodID(ML_ENV, lightning_cls, "locale", "()Ljava/lang/String;");
        jstring jlocale = (*ML_ENV)->CallStaticObjectMethod(ML_ENV, lightning_cls, mid);
        const char* clocale = (*ML_ENV)->GetStringUTFChars(ML_ENV, jlocale, NULL);
        retval = malloc(strlen(clocale) + 1);
        strcpy(retval, clocale);

        (*ML_ENV)->ReleaseStringUTFChars(ML_ENV, jlocale, clocale);
        (*ML_ENV)->DeleteLocalRef(ML_ENV, jlocale);
    }

    return retval;
}

JNIEXPORT jobject JNICALL Java_ru_redspell_lightning_Lightning_activity(JNIEnv *env, jclass this) {
    return JAVA_ACTIVITY;
}

JNIEXPORT void JNICALL Java_ru_redspell_lightning_Lightning_disableTouches(JNIEnv *env, jclass this) {
    engine.touches_disabled = 1;
}

JNIEXPORT void JNICALL Java_ru_redspell_lightning_Lightning_enableTouches(JNIEnv *env, jclass this) {
    engine.touches_disabled = 0;
}

void lightning_set_referer(const char *ctype, jstring jnid) {
    CAMLparam0();
    CAMLlocal2(vtype,vnid);

    vtype = caml_copy_string(ctype);
    JSTRING_TO_VAL(jnid, vnid);
    set_referrer_ml(vtype, vnid);

    CAMLreturn0;
}

void lightning_convert_intent(void *data) {
    jobject intent = (jobject)data;
    static jclass intent_cls = NULL;
    static jclass bundle_cls = NULL;
    static jmethodID getextras_mid;
    static jmethodID getstring_mid;

    if (!intent_cls) {
        intent_cls = engine_find_class("android/content/Intent");
        bundle_cls = engine_find_class("android/os/Bundle");
        getextras_mid = (*ML_ENV)->GetMethodID(ML_ENV, intent_cls, "getExtras", "()Landroid/os/Bundle;");
        getstring_mid = (*ML_ENV)->GetMethodID(ML_ENV, bundle_cls, "getString", "(Ljava/lang/String;)Ljava/lang/String;");
    }

    jobject extras = (*ML_ENV)->CallObjectMethod(ML_ENV, intent, getextras_mid);
    if (extras) {
        jstring key = (*ML_ENV)->NewStringUTF(ML_ENV, "localNotification");
        jstring nid = (*ML_ENV)->CallObjectMethod(ML_ENV, extras, getstring_mid, key);

        if (nid) {
            lightning_set_referer("local", nid);
            (*ML_ENV)->DeleteLocalRef(ML_ENV, key);
            (*ML_ENV)->DeleteLocalRef(ML_ENV, nid);
        } else {
            (*ML_ENV)->DeleteLocalRef(ML_ENV, key);
            key = (*ML_ENV)->NewStringUTF(ML_ENV, "remoteNotification");
            nid = (*ML_ENV)->CallObjectMethod(ML_ENV, extras, getstring_mid, key);

            if (nid) {
                lightning_set_referer("remote", nid);
                (*ML_ENV)->DeleteLocalRef(ML_ENV, nid);
            }

            (*ML_ENV)->DeleteLocalRef(ML_ENV, key);
        }

        (*ML_ENV)->DeleteLocalRef(ML_ENV, extras);
    }
}

JNIEXPORT void JNICALL Java_ru_redspell_lightning_Lightning_convertIntent(JNIEnv *env, jclass this, jobject intent) {
    RUN_ON_ML_THREAD(&lightning_convert_intent, (void*)(*env)->NewGlobalRef(env, intent));
}

void lightning_on_backpressed(void *data) {
    if (engine.stage) {
        static value back_handler = 0;
        if (!back_handler) back_handler = caml_hash_variant("dispatchBackPressedEv");
        value res = caml_callback2(caml_get_public_method(engine.stage->stage, back_handler), engine.stage->stage, Val_unit);

        if (Bool_val(res)) exit(0);
    }
}

JNIEXPORT void JNICALL Java_ru_redspell_lightning_Lightning_onBackPressed(JNIEnv *env, jclass this) {
    RUN_ON_ML_THREAD(&lightning_on_backpressed, NULL);
}

int getResourceFd(const char *path, resource *res) {
    static char* main_exp = NULL;
    static char* patch_exp = NULL;

    if (!main_exp) {
        jclass cls = engine_find_class("ru/redspell/lightning/expansions/Expansions");
        jmethodID mid;
        jstring jexp;
        const char *cexp;

#define GET_EXP_PATH(exp, method) mid = (*ML_ENV)->GetStaticMethodID(ML_ENV, cls, #method, "()Ljava/lang/String;"); \
    jexp = (*ML_ENV)->CallStaticObjectMethod(ML_ENV, cls, mid); \
    cexp = (*ML_ENV)->GetStringUTFChars(ML_ENV, jexp, NULL); \
    exp = (char*)malloc(strlen(cexp) + 1); \
    strcpy(exp, cexp); \
    (*ML_ENV)->ReleaseStringUTFChars(ML_ENV, jexp, cexp); \
    (*ML_ENV)->DeleteLocalRef(ML_ENV, jexp);

        GET_EXP_PATH(main_exp, mainExp);
        GET_EXP_PATH(patch_exp, patchExp);
#undef GET_EXP_PATH
    }

    PRINT_DEBUG("getResourceFd %s", path);
    offset_size_pair_t* os_pair;

    if (!get_offset_size_pair(path, &os_pair)) {
        int fd;

#define GET_FD(path) if (!path) { \
        PRINT_DEBUG("path '%s' is NULL", #path); \
        return 0; \
    } \
    fd = open(path, O_RDONLY); \
    if (fd < 0) { \
        PRINT_DEBUG("failed to open path '%s' due to '%s'", path, strerror(errno)); \
        return 0; \
    }

        if (os_pair->location == 0) {
            GET_FD(engine.apk_path);
        } else if (os_pair->location == 1) {
            GET_FD(patch_exp)
        } else if (os_pair->location == 2) {
            GET_FD(main_exp)
        } else {
            char* extra_res_fname = get_extra_res_fname(os_pair->location);
            if (!extra_res_fname) return 0;
            GET_FD(extra_res_fname);
        }

#undef GET_FD

        lseek(fd, os_pair->offset, SEEK_SET);
        res->fd = fd;
        res->offset = os_pair->offset;
        res->length = os_pair->size;

        return 1;
    }

    return 0;
}

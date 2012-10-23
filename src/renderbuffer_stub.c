#include <stdio.h>
#include <math.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <kazmath/GL/matrix.h>
#include "render_stub.h"
#include "renderbuffer_stub.h"

static int fbs_cnt = 0;
static GLuint *fbfs = NULL;

static GLuint inline get_framebuffer() {
	GLuint fbid = 0;
	int i = 0;
	while ((i < fbs_cnt) && (fbfs[i] == 0)) {i++;};
	if (i < fbs_cnt) {
		fbid = fbfs[i];
		fbfs[i] = 0;
	} else glGenFramebuffers(1,&fbid);
	PRINT_DEBUG("get framebuffer: %d",fbid);
	return fbid;
}

static void inline back_framebuffer(GLuint fbid) {
	int i = 0;
	while (i < fbs_cnt && fbfs[i] != 0) {i++;};
	if (i < fbs_cnt) fbfs[i] = fbid;
	else {
		fbfs = realloc(fbfs,sizeof(GLuint)*(fbs_cnt + 1));
		fbfs[fbs_cnt] = fbid;
		++fbs_cnt;
	}
	PRINT_DEBUG("back framebuffer: %d",fbid);
}

static int tx_cnt = 0;
static GLuint *txs = NULL;


static GLuint inline get_texture_id() {
	GLuint tid = 0;
	int i = 0;
	while ((i < tx_cnt) && (txs[i] == 0)) {i++;};
	if (i < tx_cnt) {
		tid = txs[i];
		txs[i] = 0;
		glBindTexture(GL_TEXTURE_2D, tid);
	} else {
		glGenTextures(1,&tid);
		glBindTexture(GL_TEXTURE_2D, tid);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	};
	PRINT_DEBUG("get texture: %d",tid);
	return tid;
}

static void inline back_texture_id(GLuint tid) {
	int i = 0;
	while (i < tx_cnt && txs[i] != 0) {i++;};
	if (i < tx_cnt) {
		txs[i] = tid;
	} else {
		txs = realloc(txs,sizeof(GLuint)*(tx_cnt + 1));
		txs[tx_cnt] = tid;
		++tx_cnt;
	}
	PRINT_DEBUG("back texture: %d",tid);
}

static unsigned int total_tex_mem = 0;
static unsigned int total_tex_count = 0;
extern uintnat caml_dependent_size;

#ifdef TEXTURE_LOAD
#define LOGMEM(op,tid,size) DEBUGMSG("RENDER TEXTURE MEMORY [%s] <%d:%d> -> %d  %u:%u",op,tid,size,total_tex_count,total_tex_mem,caml_dependent_size);
#else
#define LOGMEM(op,tid,size)
#endif

void ml_render_texture_id_delete(value textureID) {
	GLuint tid = TEXTURE_ID(textureID);
	if (tid) {
		back_texture_id(tid);
		resetTextureIfBounded(tid);
		checkGLErrors("delete texture");
		struct tex *t = TEX(textureID);
		t->tid = 0;
		total_tex_mem -= t->mem;
		--total_tex_count;
		LOGMEM("delete",tid,t->mem);
		caml_free_dependent_memory(t->mem);
	};
}

static void textureID_finalize(value textureID) {
	GLuint tid = TEXTURE_ID(textureID);
	if (tid) {
		PRINT_DEBUG("finalize render texture");
		back_texture_id(tid);
		resetTextureIfBounded(tid);
		checkGLErrors("finalize texture");
		struct tex *t = TEX(textureID);
		total_tex_mem -= t->mem;
		--total_tex_count;
		caml_free_dependent_memory(t->mem);
		LOGMEM("finalize",tid,t->mem);
	};
}

static int textureID_compare(value texid1,value texid2) {
	GLuint t1 = TEXTURE_ID(texid1);
	GLuint t2 = TEXTURE_ID(texid2);
	if (t1 == t2) return 0;
	else {
		if (t1 < t2) return -1;
		return 1;
	}
}

struct custom_operations rendertextureID_ops = {
  "pointer to render texture id",
  textureID_finalize,
  textureID_compare,
  custom_hash_default,
  custom_serialize_default,
  custom_deserialize_default
};

#define MAX_RENDER_TEXTURES 100


value caml_gc_major(value v);

#define Store_rendertextureID(mltex,texID,dataLen) \
	if (++total_tex_count >= MAX_RENDER_TEXTURES) caml_gc_major(0); \
	caml_alloc_dependent_memory(dataLen); \
	mltex = caml_alloc_custom(&rendertextureID_ops, sizeof(struct tex), dataLen, MAX_GC_MEM); \
	{struct tex *_tex = TEX(mltex); _tex->tid = texID; _tex->mem = dataLen;  total_tex_mem += dataLen;LOGMEM("new",texID,dataLen)}

void get_framebuffer_state(framebuffer_state *s) {
	glGetIntegerv(GL_FRAMEBUFFER_BINDING,&s->framebuffer);
	glGetIntegerv(GL_VIEWPORT,s->viewport);
	checkGLErrors("get framebuffer state");
}

static void inline renderbuffer_activate(renderbuffer_t *rb) {
	glViewport(rb->vp.x,rb->vp.y,rb->vp.w,rb->vp.h);
	kmGLMatrixMode(KM_GL_PROJECTION);
	kmGLPushMatrix();
	kmGLLoadIdentity();
	kmMat4 orthoMatrix;
	kmMat4OrthographicProjection(&orthoMatrix, 0, (GLfloat)rb->vp.w, 0, (GLfloat)rb->vp.h, -1024, 1024 );
	kmGLMultMatrix( &orthoMatrix );
	kmGLMatrixMode(KM_GL_MODELVIEW);
	kmGLPushMatrix();
	kmGLLoadIdentity();
	enableSeparateBlend();
}


void set_framebuffer_state(framebuffer_state *s) {
	glBindFramebuffer(GL_FRAMEBUFFER,s->framebuffer);
	glViewport(s->viewport[0], s->viewport[1], s->viewport[2], s->viewport[3]);
}

static void inline renderbuffer_deactivate() {
	kmGLMatrixMode(KM_GL_PROJECTION);
	kmGLPopMatrix();
	kmGLMatrixMode(KM_GL_MODELVIEW);
	kmGLPopMatrix();
	disableSeparateBlend();
}


static int FRAMEBUFFER_BIND_COUNTER = 0;

// сделать рендер буфер
int create_renderbuffer(double width,double height, renderbuffer_t *r,GLenum filter) {
  GLuint rtid;
	GLuint iw = ceil(width);
	GLuint ih = ceil(height);
	//GLuint legalWidth = nextPowerOfTwo(iw);
	//GLuint legalHeight = nextPowerOfTwo(ih);
	GLuint legalWidth = nextPOT(iw);
	GLuint legalHeight = nextPOT(ih);
	TEXTURE_SIZE_FIX(legalWidth,legalHeight);
	rtid = get_texture_id();
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, legalWidth, legalHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glBindTexture(GL_TEXTURE_2D,0);
	checkGLErrors("create render texture %d [%d:%d]",rtid,legalWidth,legalHeight);
  GLuint fbid;
  //glGenFramebuffers(1, &fbid);
	fbid = get_framebuffer();
  glBindFramebuffer(GL_FRAMEBUFFER, fbid);
	checkGLErrors("bind framebuffer %d",fbid);
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rtid,0);
	FRAMEBUFFER_BIND_COUNTER++;
	checkGLErrors("framebuffertexture2d %d -> %d",fbid,rtid);
  r->fbid = fbid;
  r->tid = rtid;
	r->vp = (viewport){(GLuint)((legalWidth - width)/2),(GLuint)((legalHeight - height)/2),(GLuint)width,(GLuint)height};
	r->clp = (clipping){(double)r->vp.x / legalWidth,(double)r->vp.y / legalHeight,(width / legalWidth),(height / legalHeight)};
  r->width = width;
  r->height = height;
	r->realWidth = legalWidth;
	r->realHeight = legalHeight;
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) return 1;
	return 0;
}

int clone_renderbuffer(renderbuffer_t *sr, renderbuffer_t *dr,GLenum filter) {
	GLuint rtid;
  glGenTextures(1, &rtid);
  glBindTexture(GL_TEXTURE_2D, rtid);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sr->realWidth, sr->realHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	//checkGLErrors("create renderbuffer texture %d [%d:%d]",rtid,legalWidth,legalHeight);
  glBindTexture(GL_TEXTURE_2D,0);
  GLuint fbid;
  glGenFramebuffers(1, &fbid);
  glBindFramebuffer(GL_FRAMEBUFFER, fbid);
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rtid,0);
	FRAMEBUFFER_BIND_COUNTER++;
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) return 1;
	dr->fbid = fbid;
	dr->tid = rtid;
	dr->vp = sr->vp;
	dr->clp = sr->clp;
	dr->width = sr->width;
	dr->height = sr->height;
	dr->realWidth = sr->realWidth;
	dr->realHeight = sr->realHeight;
	return 0;
}

void delete_renderbuffer(renderbuffer_t *rb) {
	glDeleteTextures(1,&rb->tid);
	//glDeleteFramebuffers(1,&rb->fbid);
	back_framebuffer(rb->fbid);
}


/*
static void inline gl_clear(value ocolor,value oalpha) {
	color3F clr;
	if (ocolor == Val_none) clr = (color3F){0.,0.,0.};
	else {
		int c = Int_val(Field(ocolor,0));
		clr = COLOR3F_FROM_INT(c);
	};
	GLfloat alpha = oalpha == Val_none ? 0. : Double_val(Field(oalpha,0));
	glClearColor(clr.r,clr.g,clr.b,alpha);
	glClear(GL_COLOR_BUFFER_BIT);
}
*/


value ml_renderbuffer_draw(value filter, value ocolor, value oalpha, value mlwidth, value mlheight, value mlfun) {
	CAMLparam0();
	CAMLlocal2(renderInfo,clp);
	GLenum fltr;
	switch (Int_val(filter)) {
		case 0: 
			fltr = GL_NEAREST;
			break;
		case 1:
			fltr = GL_LINEAR;
			break;
		default: break;
	};
	framebuffer_state fstate;
	get_framebuffer_state(&fstate);
	renderbuffer_t rb; 
	if (create_renderbuffer(Double_val(mlwidth),Double_val(mlheight),&rb,fltr)) {
		char emsg[255];
		sprintf(emsg,"renderbuffer_draw. create framebuffer '%d', texture: '%d' [%d:%d], status: %X, counter: %d",rb.fbid,rb.tid,rb.realWidth,rb.realHeight,glCheckFramebufferStatus(GL_FRAMEBUFFER),FRAMEBUFFER_BIND_COUNTER);
		set_framebuffer_state(&fstate);
		caml_failwith(emsg);
	};
	lgResetBoundTextures();
	checkGLErrors("renderbuffer create");

	renderbuffer_activate(&rb);

	PRINT_DEBUG("start ocaml drawing function for %d:%d",rb.fbid,rb.tid);

	color3F clr;
	if (ocolor == Val_none) clr = (color3F){0.,0.,0.};
	else {
		int c = Int_val(Field(ocolor,0));
		clr = COLOR3F_FROM_INT(c);
	};
	GLfloat alpha = oalpha == Val_none ? 0. : Double_val(Field(oalpha,0));
	glClearColor(clr.r,clr.g,clr.b,alpha);
	glClear(GL_COLOR_BUFFER_BIT);

	caml_callback(mlfun,(value)&rb);

	PRINT_DEBUG("end ocaml drawing function for %d:%d",rb.fbid,rb.tid);

  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,0,0);
	renderbuffer_deactivate();

	set_framebuffer_state(&fstate);
	//glDeleteFramebuffers(1,&rb.fbid);
	back_framebuffer(rb.fbid);

	// и нужно вернуть текстуру
	int s = rb.realWidth * rb.realHeight * 4;
	renderInfo = caml_alloc_tuple(5);
	value mlTextureID; 
	Store_rendertextureID(mlTextureID,rb.tid,s);
	Store_field(renderInfo,0,mlTextureID);
	Store_field(renderInfo,1,caml_copy_double(rb.width));
	Store_field(renderInfo,2,caml_copy_double(rb.height));
	value clip = 0;
	if (!IS_CLIPPING(rb.clp)) {
		clp = caml_alloc(4 * Double_wosize,Double_array_tag);
		Store_double_field(clp,0,rb.clp.x);
		Store_double_field(clp,1,rb.clp.y);
		Store_double_field(clp,2,rb.clp.width);
		Store_double_field(clp,3,rb.clp.height);
		clip = caml_alloc_small(1,0);
		Field(clip,0) = clp;
	} else clip = Val_unit;
	Store_field(renderInfo,3,clip);
	value kind = caml_alloc_small(1,0);
	Field(kind,0) = Val_true;
	Store_field(renderInfo,4,kind);
	checkGLErrors("finish render to texture");
	CAMLreturn(renderInfo);
}


value ml_renderbuffer_draw_byte(value * argv, int n) {
	return (ml_renderbuffer_draw(argv[0],argv[1],argv[2],argv[3],argv[4],argv[5]));
}

value ml_renderbuffer_draw_to_texture(value mlclear, value owidth, value oheight, value renderInfo, value mlfun) {
	CAMLparam4(renderInfo,owidth,oheight,mlfun);
	CAMLlocal1(clp);

	double cwidth = Double_val(Field(renderInfo,1));
	double cheight = Double_val(Field(renderInfo,2));


	int resized = 0;
	double width = cwidth;
	//fprintf(stderr,"try resize %d:%d from [%f:%f] to [%f:%f]\n",rb->fbid,rb->tid,rb->width,rb->height,width,height);
	if (owidth != Val_none) {
		width = Double_val(Field(owidth,0));
		resized = (width != cwidth);
	};
	double height = cheight;
	if (oheight != Val_none) {
		height = Double_val(Field(oheight,0));
		resized |= (height != cheight);
	};
	PRINT_DEBUG("draw to texture: [%f:%f] -> [%f:%f]",cwidth,cheight,width,height);

	GLuint legalWidth = nextPOT(ceil(width));
	GLuint legalHeight = nextPOT(ceil(height));
	TEXTURE_SIZE_FIX(legalWidth,legalHeight);
	renderbuffer_t rb;
	rb.tid = TEXTURE_ID(Field(renderInfo,0));
  rb.width = width;
  rb.height = height;
	rb.realWidth = legalWidth;
	rb.realHeight = legalHeight;
	if (resized) {
		Store_field(renderInfo,1,caml_copy_double(width));
		Store_field(renderInfo,2,caml_copy_double(height));
		value clip;
		if (legalWidth == width && legalHeight == height) {
			rb.clp = (clipping){0.,0.,1.,1.};
			clip = Val_unit;
		} else {
			rb.clp = (clipping) {
				(double)(double)(legalWidth - width) / (2 * legalWidth),
				(double)(legalHeight - height) / (2 * legalHeight),
				(width / legalWidth),
				(height / legalHeight)
			};
			clp = caml_alloc(4 * Double_wosize,Double_array_tag);
			Store_double_field(clp,0,rb.clp.x);
			Store_double_field(clp,1,rb.clp.y);
			Store_double_field(clp,2,rb.clp.width);
			Store_double_field(clp,3,rb.clp.height);
			clip = caml_alloc_tuple(1);
			Store_field(clip,0,clp);
		}
		Store_field(renderInfo,3,clip);
		if (legalWidth != nextPOT(ceil(cwidth)) || legalHeight != nextPOT(ceil(cheight))) {

			lgGLBindTexture(rb.tid,1);
			glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,legalWidth,legalHeight,0,GL_RGBA,GL_UNSIGNED_BYTE,NULL);
			//rb->realWidth = legalWidth;
			//rb->realHeight = legalHeight;

			/*TEX(Field(renderInfo,0))->tid = 0;
			total_tex_mem -= TEX(Field(renderInfo,0))->mem;
			caml_free_dependent_memory(TEX(Field(renderInfo,0))->mem);*/
			//ml_texture_id_delete(Field(renderInfo,0));
			int s = legalWidth*legalHeight*4;
			update_texture_id_size(Field(renderInfo,0),s);
			//value mlTextureID = texture_id_alloc(rb.tid,s);
			//Store_textureID(mlTextureID,rb->tid,"renderbuffer resized",s);
			//Store_field(renderInfo,0,mlTextureID); // ??
			checkGLErrors("renderbuffer resize");
		};
	} else {
		// Достать clp из ocaml 
		clp = Field(renderInfo,3);
		if (clp == Val_none) 
			rb.clp = (clipping) {0.,0.,1.,1.};
		else 
			rb.clp = (clipping) {Double_field(clp,0),Double_field(clp,1),Double_field(clp,2),Double_field(clp,3)};
	};
	rb.vp = (viewport){(GLuint)((legalWidth - width)/2),(GLuint)((legalHeight - height)/2),(GLuint)width,(GLuint)height};

	framebuffer_state fstate;
	get_framebuffer_state(&fstate);

	//Теперь делаем фрэймбуффер
  //glGenFramebuffers(1, &rb.fbid);
	rb.fbid = get_framebuffer();
  glBindFramebuffer(GL_FRAMEBUFFER, rb.fbid);
	PRINT_DEBUG("FRAMEBUFFER BINDED");
	checkGLErrors("draw to texture bind framebuffer");
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rb.tid,0);
	FRAMEBUFFER_BIND_COUNTER++;
  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		char emsg[255];
		sprintf(emsg,"draw to texture framebuffer '%d', texture: '%d' [%d:%d], status: %X, counter: %d",rb.fbid,rb.tid,legalWidth,legalHeight,glCheckFramebufferStatus(GL_FRAMEBUFFER),FRAMEBUFFER_BIND_COUNTER);
		set_framebuffer_state(&fstate);
    caml_failwith(emsg);
  };

	// clear 

	renderbuffer_activate(&rb);

	if (mlclear != Val_none) {
		value ca = Field(mlclear,0);
		int c = Int_val(Field(ca,0));
		color3F clr = COLOR3F_FROM_INT(c);
		GLfloat alpha = Double_val(Field(ca,1));
		glClearColor(clr.r,clr.g,clr.b,alpha);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	caml_callback(mlfun,(value)&rb);

	glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,0,0);// Detach the texture

	set_framebuffer_state(&fstate);
	renderbuffer_deactivate();
	//glDeleteFramebuffers(1,&rb.fbid);
	back_framebuffer(rb.fbid);

	checkGLErrors("finish render to texture");
	CAMLreturn(Val_bool(resized));
}

/*
value ml_renderbuffer_draw_to_texture_byte(value *argv, int n) {
	return (ml_renderbuffer_draw_to_texture(argv[0],argv[1],argv[2],argv[3],argv[4]));
}*/




#define CNT_TEST_TEXTURES 200
void ml_test_c_fun (value f) {
	GLuint textures[CNT_TEST_TEXTURES];
	glGenTextures(CNT_TEST_TEXTURES, textures);
	int i;
	GLuint rtid;
	GLenum filter = GL_NEAREST;
	GLuint legalWidth = 128, legalHeight =128;
	for (i = 0; i < CNT_TEST_TEXTURES; i++) {
		rtid = textures[i];
		glBindTexture(GL_TEXTURE_2D, rtid);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, legalWidth, legalHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	};
	glBindTexture(GL_TEXTURE_2D,0);
	checkGLErrors("after create textures");
	GLuint fbid = get_framebuffer();

	framebuffer_state fstate;
	get_framebuffer_state(&fstate);

	PRINT_DEBUG("DEPTH ENABLED: %d",glIsEnabled(GL_STENCIL_TEST));
	// what about renderbuffer
	int j;
	for (i = 0; i < CNT_TEST_TEXTURES; i++) {
		rtid = textures[i];
		PRINT_DEBUG("TRY BIND WITH %d",i);
		glBindFramebuffer(GL_FRAMEBUFFER, fbid);
		glBindTexture(GL_TEXTURE_2D,rtid);
		glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rtid,0);
		GLint status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if (status != GL_FRAMEBUFFER_COMPLETE) {
			char msg[255];
			sprintf(msg,
					"failed to bind framebuffer and texture: %d:%d - %d %X",
					fbid,rtid,i,status
			);
			caml_failwith(msg);
		};
		glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0,0);
		//glDeleteTextures(1,&rtid);
	}

	set_framebuffer_state(&fstate);

	back_framebuffer(fbid);
}

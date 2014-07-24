
#ifndef __TEXTURE_COMMON_H__
#define __TEXTURE_COMMON_H__

#ifdef ANDROID
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#else 
#ifdef IOS
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <sys/types.h>
#else
#define GL_GLEXT_PROTOTYPES
#ifdef OSlinux
#include <GL/gl.h>
#else
#include <OpenGL/gl.h>
#include <sys/types.h>
#endif
#endif
#endif

#include <caml/mlvalues.h>
#include <zlib.h>
#include "light_common.h"



#if defined(IOS) || defined(ANDROID)
#define TEXTURE_SIZE_FIX(legalWidth,legalHeight) \
		if (legalWidth <= 8) { \
			if (legalWidth > legalHeight) legalHeight = legalWidth; \
			else \
				if (legalHeight > legalWidth * 2) legalWidth = legalHeight/2; \
				if (legalWidth > 16) legalWidth = 16; \
		} else { \
			if (legalHeight <= 8) legalHeight = 16 < legalWidth ? 16 : legalWidth; \
		};
#else
#define TEXTURE_SIZE_FIX(legalWidth,legalHeight)
#endif

int nextPowerOfTwo(int number);
unsigned long nextPOT(unsigned long x);
// next divisible by eight
unsigned long nextDBE(unsigned long x);

struct tex {
	GLuint tid;
#ifdef TEXTURE_LOAD
	char path[255];
#endif
	int mem;
	GLuint fbid; //this fiedls used only with render textures
};

#define TEXTURE_ID(v) ((struct tex*)Data_custom_val(v))->tid
#define TEX(v) ((struct tex*)Data_custom_val(v))

value ml_texture_id_zero();

//extern GLuint boundTextureID;
void setPMAGLBlend ();
void enableSeparateBlend ();
void disableSeparateBlend ();
void setNotPMAGLBlend ();
void lgGLBindTexture(GLuint textureID, int pma);
void lgGLBindTextures(GLuint textureID, GLuint textureID1, int newPMA);
void lgResetBoundTextures();
void resetTextureIfBounded(GLuint tid);
//value texture_id_alloc(GLuint textureID, unsigned int dataLen);
void texture_id_update(value mlTextureID,GLuint textureID);
void ml_texture_id_delete(value mlTextureID);
void update_texture_id_size(value mlTextureID,unsigned int dataLen);

typedef enum 
{
	LTextureFormatRGBA,
	LTextureFormatRGB,
	LTextureFormatAlpha,
	LTextureFormatPvrtcRGB2,
	LTextureFormatPvrtcRGBA2,
	LTextureFormatPvrtcRGB4,
	LTextureFormatPvrtcRGBA4,
	LTextureFormat565,
	LTextureFormat5551,
	LTextureFormat4444,
	LTextureFormatDXT1,
	LTextureFormatDXT5,
	LTextureFormatATCRGB,
	LTextureFormatATCRGBAE,
	LTextureFormatATCRGBAI,
	LTextureFormatETC1,
	LTextureLuminance,
	LTextureLuminanceAlpha,	
	LTextureFormatPallete,
	LTextureFormatETC1WithAlpha,
	LTextureFormatETC2RGB,
	LTextureFormatETC2RGBA,
	LTextureFormatPvrtc2RGBA2,
	LTextureFormatPvrtc2RGBA4
} LTextureFormat;

typedef struct {
#ifdef TEXTURE_LOAD
	char path[255];
#endif
	int format;
	unsigned int width;
	double realWidth;
	unsigned int height;
	double realHeight;
	int numMipmaps;
	int generateMipmaps;
	int premultipliedAlpha;
	float scale;
	unsigned int dataLen;
	unsigned char* imgData;
} textureInfo;


textureInfo* loadEtcAlphaTex(textureInfo* tInfo, char* _fname, char* suffix, int use_pvr);


int loadPlxPtr(gzFile fptr,textureInfo *tInfo);
int loadPlxFile(const char *path,textureInfo *tInfo);
int loadAlphaPtr(gzFile fptr,textureInfo *tInfo, int with_lum);
int loadAlphaFile(const char *path,textureInfo *tInfo, int with_lum);

value createGLTexture(value oldTextureID, textureInfo *tInfo,value filter);



#define OPTION_INT(v) v == 1 ? 0 : Long_val(Field(v,0))

#define ML_TEXTURE_INFO(mlTex,textureID,tInfo) \
	mlTex = caml_alloc_tuple(8);\
	if ((tInfo->format & 0xFFFF) != LTextureFormatPallete) {\
		Field(mlTex,0) = Val_int(tInfo->format);\
	} \
	else { Store_field(mlTex,0,caml_alloc(1,0)); Field(Field(mlTex,0),0) = Val_int(tInfo->format >> 16);} \
	Field(mlTex,1) = Val_long((unsigned int)tInfo->realWidth);\
	Field(mlTex,2) = Val_long(tInfo->width);\
	Field(mlTex,3) = Val_long((unsigned int)tInfo->realHeight);\
	Field(mlTex,4) = Val_long(tInfo->height);\
	Field(mlTex,5) = Val_int(tInfo->premultipliedAlpha);\
	Field(mlTex,6) = Val_long(tInfo->dataLen); \
	Field(mlTex,7) = textureID;





/*
typedef struct {
	GLfloat x;
	GLfloat y;
	GLfloat width;
	GLfloat height;
} clipping;

typedef struct {
	GLsizei x;
	GLsizei y;
	GLsizei w;
	GLsizei h;
} viewport;

#define IS_CLIPPING(clp) (clp.x == 0. && clp.y == 0. && clp.width == 1. && clp.height == 1.)

typedef struct {
  GLuint fbid;
	GLuint tid;
	double width;
	double height;
	GLuint realWidth;
	GLuint realHeight;
	viewport vp;
	clipping clp;
} renderbuffer_t; */


//#define RENDERBUFFER(v) ((renderbuffer_t*)Data_custom_val(v))



#endif

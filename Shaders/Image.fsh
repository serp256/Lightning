#ifdef GL_ES
precision lowp float;
#endif

varying vec4 v_fragmentColor;

#ifdef GL_ES
varying highp vec2 v_texCoord;
#else
varying vec2 v_texCoord;
#endif
uniform sampler2D u_texture;
uniform float u_parentAlpha;

void main()
{
	vec4 color = v_fragmentColor * texture2D(u_texture, v_texCoord);
	gl_FragColor = color * u_parentAlpha; 
}

#pragma language glsl3

//camera uniforms
extern highp mat4 transformProj;   //projective transformation
extern highp mat4 transform;       //model transformation
extern highp vec3 viewPos;         //camera position

//varyings
varying highp vec3 vertexPos;      //vertex position for pixel shader
varying float depth;               //depth

//shader settings
extern bool average_alpha;
extern bool useAlphaDither;
extern float pass;

//setting specific defines
#import globalDefines

//shader specific defines
#import shaderDefines

#ifdef PIXEL

//reflection engine
#import reflections

//light function
#import lightFunction

//uniforms required by the lighting
#import lightingSystemInit

//material
extern float ior;

void effect() {
#import mainPixelPre
	
	//dither alpha
	if (useAlphaDither) {
		alpha = step(fract(love_PixelCoord.x * 0.37 + love_PixelCoord.y * 73.73 + depth * 3.73), alpha);
	} else if (alpha < 0.99 && pass < 0.0 || alpha >= 0.99 && pass > 0.0) {
		discard;
	}
	
	//hidden
	if (alpha <= 0.0) {
		discard;
	}
	
	//alpha disabled
	if (pass == 0.0) {
		alpha = 1.0;
	}
	
#import mainPixel
	
	//forward lighting
	//requires col
	#import lightingSystem
	
	//returns color
	//requires alpha, col and normal
	if (average_alpha) {
		love_Canvases[0] = vec4(col * alpha, 1.0);
		love_Canvases[1] = vec4(1.0, alpha, ior, 1.0);
		#ifdef REFRACTION_ENABLED
			love_Canvases[2] = vec4(normal, 1.0);
		#endif
	} else {
		love_Canvases[0] = vec4(col, alpha);
		love_Canvases[1] = vec4(depth, 1.0, 1.0, 1.0);
	}
}
#endif


#ifdef VERTEX

#import animations

vec4 position(mat4 transform_projection, vec4 vertex_position) {
	highp vec4 pos = transform * animations(vertex_position);
	vertexPos = pos.xyz;
	
#import mainVertex
	
	//projection transform for the vertex
	highp vec4 vPos = transformProj * pos;
	
	//extract and pass depth
	depth = vPos.z;
	
	return vPos;
}
#endif
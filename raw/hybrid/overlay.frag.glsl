#version 450

#ifdef GL_ES
precision mediump float;
#endif

#define _NoShadows

#include "../compiled.glsl"

#ifdef _BaseTex
	uniform sampler2D sbase;
#endif
#ifndef _NoShadows
    uniform sampler2D shadowMap;
#endif
uniform float shirr[27];
#ifdef _Rad
	uniform sampler2D senvmapRadiance;
	uniform sampler2D senvmapBrdf;
	uniform int envmapNumMipmaps;
#endif
#ifdef _NorTex
	uniform sampler2D snormal;
#endif
#ifdef _OccTex
	uniform sampler2D socclusion;
#else
	uniform float occlusion;
#endif
#ifdef _RoughTex
uniform sampler2D srough;
#else
	uniform float roughness;
#endif
#ifdef _MetTex
	uniform sampler2D smetal;
#else
	uniform float metalness;
#endif
#ifdef _HeightTex
	uniform sampler2D sheight;
	uniform float heightStrength;
#endif

uniform float envmapStrength;
uniform bool receiveShadow;
uniform vec3 lightDir;
uniform vec3 lightColor;
uniform float lightStrength;

in vec3 position;
#ifdef _Tex
	in vec2 texCoord;
#endif
in vec4 lPos;
in vec4 matColor;
in vec3 eyeDir;
#ifdef _NorTex
	in mat3 TBN;
#else
	in vec3 normal;
#endif
out vec4 outColor;

#ifndef _NoShadows
float texture2DCompare(vec2 uv, float compare) {
    float depth = texture(shadowMap, uv).r * 2.0 - 1.0;
    return step(compare, depth);
}
float texture2DShadowLerp(vec2 size, vec2 uv, float compare) {
    vec2 texelSize = vec2(1.0) / size;
    vec2 f = fract(uv * size + 0.5);
    vec2 centroidUV = floor(uv * size + 0.5) / size;

    float lb = texture2DCompare(centroidUV + texelSize * vec2(0.0, 0.0), compare);
    float lt = texture2DCompare(centroidUV + texelSize * vec2(0.0, 1.0), compare);
    float rb = texture2DCompare(centroidUV + texelSize * vec2(1.0, 0.0), compare);
    float rt = texture2DCompare(centroidUV + texelSize * vec2(1.0, 1.0), compare);
    float a = mix(lb, lt, f.y);
    float b = mix(rb, rt, f.y);
    float c = mix(a, b, f.x);
    return c;
}
float PCF(vec2 uv, float compare) {
    float result = 0.0;
    // for (int x = -1; x <= 1; x++){
        // for(int y = -1; y <= 1; y++){
            // vec2 off = vec2(x, y) / shadowmapSize;
            // result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			
			vec2 off = vec2(-1, -1) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(-1, 0) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(-1, 1) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(0, -1) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(0, 0) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(0, 1) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(1, -1) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(1, 0) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
			off = vec2(1, 1) / shadowmapSize;
            result += texture2DShadowLerp(shadowmapSize, uv + off, compare);
        // }
    // }
    return result / 9.0;
}
float shadowTest(vec4 lPos) {
	vec4 lPosH = lPos / lPos.w;
	lPosH.x = (lPosH.x + 1.0) / 2.0;
    lPosH.y = (lPosH.y + 1.0) / 2.0;
    
	return PCF(lPosH.xy, lPosH.z - shadowsBias);
}
#endif

vec3 shIrradiance(vec3 nor, float scale) {
    const float c1 = 0.429043;
    const float c2 = 0.511664;
    const float c3 = 0.743125;
    const float c4 = 0.886227;
    const float c5 = 0.247708;
    vec3 cl00, cl1m1, cl10, cl11, cl2m2, cl2m1, cl20, cl21, cl22;
	cl00 = vec3(shirr[0], shirr[1], shirr[2]);
	cl1m1 = vec3(shirr[3], shirr[4], shirr[5]);
	cl10 = vec3(shirr[6], shirr[7], shirr[8]);
	cl11 = vec3(shirr[9], shirr[10], shirr[11]);
	cl2m2 = vec3(shirr[12], shirr[13], shirr[14]);
	cl2m1 = vec3(shirr[15], shirr[16], shirr[17]);
	cl20 = vec3(shirr[18], shirr[19], shirr[20]);
	cl21 = vec3(shirr[21], shirr[22], shirr[23]);
	cl22 = vec3(shirr[24], shirr[25], shirr[26]);
    return (
        c1 * cl22 * (nor.y * nor.y - (-nor.z) * (-nor.z)) +
		c3 * cl20 * nor.x * nor.x +
		c4 * cl00 -
		c5 * cl20 +
		2.0 * c1 * cl2m2 * nor.y * (-nor.z) +
		2.0 * c1 * cl21  * nor.y * nor.x +
		2.0 * c1 * cl2m1 * (-nor.z) * nor.x +
		2.0 * c2 * cl11  * nor.y +
		2.0 * c2 * cl1m1 * (-nor.z) +
		2.0 * c2 * cl10  * nor.x
    ) * scale;
}

vec2 envMapEquirect(vec3 normal) {
	float phi = acos(normal.z);
	float theta = atan(-normal.y, normal.x) + PI;
	return vec2(theta / PI2, phi / PI);
}

vec2 LightingFuncGGX_FV(float dotLH, float roughness) {
	float alpha = roughness*roughness;

	// F
	float F_a, F_b;
	float dotLH5 = pow(1.0 - dotLH, 5.0);
	F_a = 1.0;
	F_b = dotLH5;

	// V
	float vis;
	float k = alpha / 2.0;
	float k2 = k * k;
	float invK2 = 1.0 - k2;
	//vis = rcp(dotLH * dotLH * invK2 + k2);
	vis = inversesqrt(dotLH * dotLH * invK2 + k2);

	return vec2(F_a * vis, F_b * vis);
}

float LightingFuncGGX_D(float dotNH, float roughness) {
	float alpha = roughness * roughness;
	float alphaSqr = alpha * alpha;
	float pi = 3.14159;
	float denom = dotNH * dotNH * (alphaSqr - 1.0) + 1.0;

	float D = alphaSqr / (pi * denom * denom);
	return D;
}

// John Hable - Optimizing GGX Shaders
// http://www.filmicworlds.com/2014/04/21/optimizing-ggx-shaders-with-dotlh/
float LightingFuncGGX_OPT3(float dotNL, float dotLH, float dotNH, float roughness, float F0) {
	// vec3 H = normalize(V + L);
	// float dotNL = clamp(dot(N, L), 0.0, 1.0);
	// float dotLH = clamp(dot(L, H), 0.0, 1.0);
	// float dotNH = clamp(dot(N, H), 0.0, 1.0);

	float D = LightingFuncGGX_D(dotNH, roughness);
	vec2 FV_helper = LightingFuncGGX_FV(dotLH, roughness);
	float FV = F0 * FV_helper.x + (1.0 - F0) * FV_helper.y;
	float specular = dotNL * D * FV;

	return specular;
}

vec3 f_schlick(vec3 f0, float vh) {
	return f0 + (1.0-f0)*exp2((-5.55473 * vh - 6.98316)*vh);
}

float v_smithschlick(float nl, float nv, float a) {
	return 1.0 / ( (nl*(1.0-a)+a) * (nv*(1.0-a)+a) );
}

float d_ggx(float nh, float a) {
	float a2 = a*a;
	float denom = pow(nh*nh * (a2-1.0) + 1.0, 2.0);
	return a2 * (1.0 / 3.1415926535) / denom;
}

vec3 specularBRDF(vec3 f0, float roughness, float nl, float nh, float nv, float vh, float lh) {
	float a = roughness * roughness;
	return d_ggx(nh, a) * clamp(v_smithschlick(nl, nv, a), 0.0, 1.0) * f_schlick(f0, vh) / 4.0;
	//return vec3(LightingFuncGGX_OPT3(nl, lh, nh, roughness, f0[0]));
}

vec3 lambert(vec3 albedo, float nl) {
	return albedo * max(0.0, nl);
}

vec3 diffuseBRDF(vec3 albedo, float roughness, float nv, float nl, float vh, float lv) {
	return lambert(albedo, nl);
}

vec3 surfaceAlbedo(vec3 baseColor, float metalness) {
	return mix(baseColor, vec3(0.0), metalness);
}

vec3 surfaceF0(vec3 baseColor, float metalness) {
	return mix(vec3(0.04), baseColor, metalness);
}

#ifdef _Rad
float getMipLevelFromRoughness(float roughness) {
	// First mipmap level = roughness 0, last = roughness = 1
	return roughness * envmapNumMipmaps;
}
#endif

void main() {
	
#ifdef _NorTex
	vec3 n = (texture(snormal, texCoord).rgb * 2.0 - 1.0);
	n = normalize(TBN * normalize(n));
#else
	vec3 n = normalize(normal);
#endif

	vec3 l = normalize(lightDir);
	float dotNL = max(dot(n, l), 0.0);
	
	float visibility = 1.0;
#ifndef _NoShadows
	if (receiveShadow) {
		if (lPos.w > 0.0) {
			visibility = shadowTest(lPos);
		}
	}
#endif

	vec3 baseColor = matColor.rgb;
#ifdef _BaseTex
	vec4 texel = texture(sbase, texCoord);
#ifdef _AlphaTest
	if (texel.a < 0.4)
		discard;
#endif
	texel.rgb = pow(texel.rgb, vec3(2.2));
	baseColor *= texel.rgb;
#endif

	vec3 v = normalize(eyeDir);
	vec3 h = normalize(v + l);

	float dotNV = max(dot(n, v), 0.0);
	float dotNH = max(dot(n, h), 0.0);
	float dotVH = max(dot(v, h), 0.0);
	float dotLV = max(dot(l, v), 0.0);
	float dotLH = max(dot(l, h), 0.0);

#ifdef _MetTex
	float metalness = texture(smetal, texCoord).r;
#endif
	vec3 albedo = surfaceAlbedo(baseColor, metalness);
	vec3 f0 = surfaceF0(baseColor, metalness);

#ifdef _RoughTex
	float roughness = texture(srough, texCoord).r;
#endif

	// Direct
	vec3 direct = diffuseBRDF(albedo, roughness, dotNV, dotNL, dotVH, dotLV) + specularBRDF(f0, roughness, dotNL, dotNH, dotNV, dotVH, dotLH);	
	direct = direct * lightColor * lightStrength;
	
	// Indirect
	vec3 indirectDiffuse = shIrradiance(n, 2.2) / PI;	
#ifdef _EnvLDR
	indirectDiffuse = pow(indirectDiffuse, vec3(2.2));
#endif
	indirectDiffuse *= albedo;
	vec3 indirect = indirectDiffuse;
	
#ifdef _Rad
	vec3 reflectionWorld = reflect(-v, n); 
	float lod = getMipLevelFromRoughness(roughness);// + 1.0;
	vec3 prefilteredColor = textureLod(senvmapRadiance, envMapEquirect(reflectionWorld), lod).rgb;
	#ifdef _EnvLDR
		prefilteredColor = pow(prefilteredColor, vec3(2.2));
	#endif
	vec2 envBRDF = texture(senvmapBrdf, vec2(roughness, 1.0 - dotNV)).xy;
	vec3 indirectSpecular = prefilteredColor * (f0 * envBRDF.x + envBRDF.y);
	indirect += indirectSpecular;
#endif
	indirect = indirect * lightColor * lightStrength * envmapStrength;
	outColor = vec4(vec3(direct * visibility + indirect), 1.0);
	
#ifdef _OccTex
	vec3 occ = texture(socclusion, texCoord).rgb;
	outColor.rgb *= occ;
#else
	outColor.rgb *= occlusion; 
#endif

#ifdef _LDR
    outColor.rgb = vec3(pow(outColor.rgb, vec3(1.0 / 2.2)));
// #else
    // outColor = vec4(outColor.rgb, outColor.a);
#endif
}

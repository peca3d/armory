// Exclusive to bloom for now
#version 450

#ifdef GL_ES
precision mediump float;
#endif

#include "../compiled.glsl"

uniform sampler2D tex;
uniform vec2 dir;
uniform vec2 screenSize;

in vec2 texCoord;
out vec4 outColor;

// const float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
// const float weight[8] = float[] (0.197448, 0.174697, 0.120999, 0.065602, 0.02784, 0.009246, 0.002403, 0.000489);
const float weight[10] = float[] (0.132572, 0.125472, 0.106373, 0.08078, 0.05495, 0.033482, 0.018275, 0.008934, 0.003912, 0.001535);

//const float bloomStrength = 0.4;

void main() {
	vec2 step = dir / screenSize;// * 3.0;
	
	vec3 result = texture(tex, texCoord).rgb * weight[0];
	result += texture(tex, texCoord + step * 1.5).rgb * weight[1] * bloomStrength;
	result += texture(tex, texCoord - step * 1.5).rgb * weight[1] * bloomStrength;
	result += texture(tex, texCoord + step * 2.5).rgb * weight[2] * bloomStrength;
	result += texture(tex, texCoord - step * 2.5).rgb * weight[2] * bloomStrength;
	result += texture(tex, texCoord + step * 3.5).rgb * weight[3] * bloomStrength;
	result += texture(tex, texCoord - step * 3.5).rgb * weight[3] * bloomStrength;
	result += texture(tex, texCoord + step * 4.5).rgb * weight[4] * bloomStrength;
	result += texture(tex, texCoord - step * 4.5).rgb * weight[4] * bloomStrength;
	result += texture(tex, texCoord + step * 5.5).rgb * weight[5] * bloomStrength;
	result += texture(tex, texCoord - step * 5.5).rgb * weight[5] * bloomStrength;
	result += texture(tex, texCoord + step * 6.5).rgb * weight[6] * bloomStrength;
	result += texture(tex, texCoord - step * 6.5).rgb * weight[6] * bloomStrength;
	result += texture(tex, texCoord + step * 7.5).rgb * weight[7] * bloomStrength;
	result += texture(tex, texCoord - step * 7.5).rgb * weight[7] * bloomStrength;
	
	outColor.rgb = vec3(result);
}

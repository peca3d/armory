#version 450

#ifdef GL_ES
precision highp float;
#endif

in vec2 pos;

uniform vec3 ray00;
uniform vec3 ray01;
uniform vec3 ray10;
uniform vec3 ray11;

out vec3 initialRay;
out vec2 texCoord;

const vec2 madd = vec2(0.5, 0.5);

void main() {
  // Scale vertex attribute to [0-1] range
  texCoord = pos.xy * madd + madd;
  initialRay = mix(mix(ray00, ray01, texCoord.y), mix(ray10, ray11, texCoord.y), texCoord.x);
  gl_Position = vec4(pos.xy, 0.0, 1.0);
}

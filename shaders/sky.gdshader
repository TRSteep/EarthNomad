shader_type sky;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7)))*43758.5453); }
void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 cell = floor(d*650.0);
	float seed = hash(cell);
	float point = pow(max(0.0, 1.0-length(fract(d*650.0)-0.5)*2.0), 6.0);
	float stars = step(0.986,seed)*point;
	float band = exp(-pow(dot(d, normalize(vec3(0.2,0.85,0.5)))*8.0,2.0));
	float dust = 0.5+0.5*sin(d.x*25.0+sin(d.z*19.0)*2.0);
	COLOR = vec3(0.0015,0.0025,0.006) + vec3(0.012,0.017,0.028)*band*dust + mix(vec3(0.55,0.72,1.0),vec3(1.0,0.85,0.65),seed)*stars*1.6;
}

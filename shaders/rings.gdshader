shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
varying vec3 local_pos;
varying vec3 local_sun;
void vertex() {
	local_pos = VERTEX;
	local_sun = (inverse(MODEL_MATRIX) * vec4(sun_direction, 0.0)).xyz;
}
void fragment() {
	float r = length(local_pos.xz);
	float band = 0.65 + 0.16*sin(r*190.0) + 0.10*sin(r*421.0);
	float cassini = 1.0 - smoothstep(1.91, 1.94, r) * (1.0 - smoothstep(1.99, 2.02, r));
	vec3 ray = normalize(local_sun);
	float closest = length(local_pos - ray * max(dot(-local_pos,ray),0.0)*(-1.0));
	float shadow = mix(0.08, 1.0, smoothstep(0.96, 1.04, closest));
	ALBEDO = mix(vec3(0.31,0.27,0.22),vec3(0.77,0.69,0.54),band) * shadow;
	ALPHA = band * cassini * 0.9;
}

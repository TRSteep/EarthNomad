shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.14, 0.45, 1.0);
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform bool corona = false;
varying vec3 n;
varying vec3 pos;
void vertex() {
	n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float facing = max(dot(normalize(n), normalize(CAMERA_POSITION_WORLD-pos)), 0.0);
	float rim = pow(1.0-facing, 3.0);
	float day = smoothstep(-0.25, 0.5, dot(normalize(n), normalize(sun_direction)));
	ALBEDO = tint;
	ALPHA = rim * day * 0.32;
	if (corona) { ALPHA = pow(facing, 3.0) * 0.12; }
}

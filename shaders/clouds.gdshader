shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic;
uniform vec3 sun_direction = vec3(1.0,0.0,0.0);
varying vec3 n;
void vertex() { n = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
	float density = texture(cloud_map, UV).r;
	float day = max(dot(normalize(n),normalize(sun_direction)),0.0);
	ALBEDO = vec3(0.95,0.97,1.0) * (0.015+day*1.1);
	ALPHA = smoothstep(0.05,0.9,density)*0.94;
}

shader_type spatial;
render_mode unshaded;
#include "res://shaders/ring_profile.gdshaderinc"
uniform sampler2D surface_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D night_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform bool earth = false;
uniform bool star = false;
uniform float phase = 0.0;
uniform int ring_kind = 0;
uniform mat4 world_to_ring;
uniform vec3 body_tint : source_color = vec3(1.0);
uniform vec3 parent_center = vec3(0.0);
uniform float parent_radius = 0.0;
uniform bool haze = false;
varying vec3 world_normal;
varying vec3 world_position;
void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 tex = texture(surface_map, UV).rgb*body_tint;
	if(haze) { tex=mix(tex,vec3(0.64,0.43,0.19),0.93); }
	float cosine = dot(normalize(world_normal), normalize(sun_direction));
	float daylight = max(cosine, 0.0);
	vec3 color = tex * (0.012 + daylight * 1.15);
	if(ring_kind>0) {
		vec3 rp=(world_to_ring*vec4(world_position,1.0)).xyz;
		vec3 ray=normalize((world_to_ring*vec4(sun_direction,0.0)).xyz);
		if(abs(ray.y)>0.0001) {
			float t=-rp.y/ray.y;
			vec3 hit=rp+ray*t;
			float r=length(hit.xz);
			float tau=ring_profile(ring_kind,r,atan(hit.z,hit.x),max(fwidth(r),0.00003)).a;
			if(t>0.0) { color*=0.04+0.96*exp(-tau/max(abs(ray.y),0.04)); }
		}
	}
	if(parent_radius>0.0) {
		vec3 to_parent=parent_center-world_position;
		vec3 ray=normalize(sun_direction);
		float along=dot(to_parent,ray);
		float miss=length(to_parent-ray*along);
		float shadow=smoothstep(parent_radius*0.97,parent_radius*1.03,miss);
		if(along>0.0) { color*=0.025+0.975*shadow; }
	}
	if (earth) {
		float cloud_shadow = texture(cloud_map, UV + vec2(0.0015, 0.0)).r;
		color *= 1.0 - cloud_shadow * daylight * 0.23;
		color += texture(night_map, UV).rgb * (1.0-smoothstep(-0.18,0.04,cosine)) * 1.15;
		vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
		float rim = pow(1.0 - max(dot(normalize(world_normal), view_dir), 0.0), 3.5);
		color += vec3(0.08, 0.32, 0.65) * rim * smoothstep(-0.15, 0.4, cosine) * 0.6;
		float ocean = smoothstep(0.02, 0.15, tex.b - tex.r);
		vec3 half_dir = normalize(normalize(sun_direction) + view_dir);
		color += vec3(0.8, 0.88, 1.0) * ocean * pow(max(dot(normalize(world_normal), half_dir), 0.0), 180.0) * daylight * 0.35;
	}
	if (star) {
		float pulse = 1.0 + 0.025 * sin(UV.y * 180.0 + phase);
		color = tex * vec3(1.4, 1.12, 0.85) * pulse;
	}
	ALBEDO = color;
}

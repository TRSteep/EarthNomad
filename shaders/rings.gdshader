shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
#include "res://shaders/ring_profile.gdshaderinc"
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform int ring_kind = 1;
varying vec3 local_pos;
varying vec3 local_sun;
varying vec3 local_view;
void vertex() {
	local_pos = VERTEX;
	local_sun = (inverse(MODEL_MATRIX) * vec4(sun_direction, 0.0)).xyz;
	local_view = (inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz-VERTEX;
}
void fragment() {
	float r = length(local_pos.xz);
	vec4 profile=ring_profile(ring_kind,r,atan(local_pos.z,local_pos.x),max(fwidth(r),0.00003));
	vec3 ray = normalize(local_sun);
	float along=dot(-local_pos,ray);
	float closest=length(local_pos+ray*max(along,0.0));
	float shadow=along>0.0 ? smoothstep(0.98,1.02,closest) : 1.0;
	float incidence=max(abs(ray.y),0.04);
	float view_incidence=max(abs(normalize(local_view).y),0.04);
	float opacity=1.0-exp(-profile.a/view_incidence);
	float phase=pow(max(dot(normalize(local_view),-ray),0.0),8.0);
	ALBEDO=profile.rgb*(0.12+0.88*sqrt(incidence))*(0.025+shadow*0.975)*(1.0+0.28*phase);
	ALPHA=opacity;
}

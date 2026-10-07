shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform float stripe_meters = 3.2;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world_pos.xz * uv_scale;
	vec3 col = texture(albedo_tex, uv).rgb;
	float ao = texture(ao_tex, uv).r;
	col *= mix(1.0, ao, 0.45);
	float stripe = sin(world_pos.z * 6.2831853 / stripe_meters);
	float band = smoothstep(-0.15, 0.15, stripe);
	col *= mix(vec3(0.78, 0.88, 0.76), vec3(1.05, 1.12, 1.0), band);
	ALBEDO = col;
	ROUGHNESS = clamp(texture(rough_tex, uv).r, 0.55, 1.0);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(normal_tex, uv).rgb, 0.65);
}

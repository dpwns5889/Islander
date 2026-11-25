shader_type spatial;
// 3단계 빛: 그림자(주변광만) / 중간 / 밝음 (기획서 7.2)
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0); // 단색, 모델이면 텍스처에 곱한다(피해 표시)
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable; // 모델의 팔레트 텍스처 (없으면 흰색)
uniform float cut_mid : hint_range(0.0, 1.0) = 0.3; // 이 밝기부터 중간 단계
uniform float cut_high : hint_range(0.0, 1.0) = 0.7; // 이 밝기부터 가장 밝은 단계
uniform float mid_level : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float q = d >= cut_high ? 1.0 : (d >= cut_mid ? mid_level : 0.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * q / PI;
}

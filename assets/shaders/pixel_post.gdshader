shader_type spatial;
// 도트 화면 후처리: 깊이가 크게 바뀌는 곳(물체 바깥)만 어둡게 칠한다 (기획서 7.2)
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled, blend_mix;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float depth_threshold = 0.12; // 이웃보다 이만큼 멀면 외곽선
uniform float dark_amount : hint_range(0.0, 1.0) = 0.6;

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(v.xyz / v.w).z;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	float dc = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float edge = 0.0;
	for (int i = 0; i < 4; i++) {
		if (dc - linear_depth(SCREEN_UV + offs[i], INV_PROJECTION_MATRIX) > depth_threshold) {
			edge = 1.0; // 이웃이 더 가까움: 이 픽셀이 물체 바깥
		}
	}
	// 화면을 읽지 않고 반투명 덮개로 칠한다: 화면 복사는 반투명 물체(격자·영역선·미리보기)를 빼고 찍혀서 그것들이 지워진다
	ALBEDO = vec3(0.0);
	ALPHA = edge * dark_amount;
}

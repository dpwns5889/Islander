shader_type spatial;
// 도트 화면 후처리: 깊이가 크게 바뀌는 곳은 어둡게(바깥 외곽선), 면이 꺾이는 곳은 밝게 (기획서 7.2)
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled, blend_mix;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float depth_threshold = 0.12; // 이웃보다 이만큼 멀면 외곽선
uniform float normal_threshold = 0.85; // 이웃과 법선 내적이 이보다 작으면 모서리
uniform float dark_amount : hint_range(0.0, 1.0) = 0.6;
uniform float light_amount : hint_range(0.0, 1.0) = 0.22;

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
	vec3 nc = texture(normal_tex, SCREEN_UV).xyz * 2.0 - 1.0;
	float edge_dark = 0.0;
	float edge_light = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i];
		float dn = linear_depth(uv, INV_PROJECTION_MATRIX);
		if (dc - dn > depth_threshold) {
			edge_dark = 1.0; // 이웃이 더 가까움: 이 픽셀이 물체 바깥
		} else if (abs(dc - dn) < depth_threshold) {
			vec3 nn = texture(normal_tex, uv).xyz * 2.0 - 1.0;
			if (dot(normalize(nc), normalize(nn)) < normal_threshold) {
				edge_light = 1.0;
			}
		}
	}
	// 화면을 읽지 않고 반투명 덮개로 칠한다: 화면 복사는 반투명 물체(격자·영역선·미리보기)를 빼고 찍혀서 그것들이 지워진다
	if (edge_dark > 0.5) {
		ALBEDO = vec3(0.0);
		ALPHA = dark_amount;
	} else if (edge_light > 0.5) {
		ALBEDO = vec3(1.0);
		ALPHA = light_amount;
	} else {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	}
}

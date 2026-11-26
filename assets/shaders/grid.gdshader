shader_type spatial;
// 필드 격자: 확대·회전과 상관없이 항상 같은 픽셀 굵기의 선을 그린다 (기획서 7.2)
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never;

uniform vec2 origin; // 필드 왼쪽 위 모서리의 월드 xz
uniform float strength : hint_range(0.0, 1.0) = 0.5;

varying vec2 cell; // 칸 단위 좌표 (정수인 곳이 칸 경계)

void vertex() {
	cell = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz - origin;
}

void fragment() {
	// 도트 화면(세로 362)은 1도트, 도트를 끈 원래 해상도(1082 이상)는 2픽셀 이상
	float width = max(1.0, floor(VIEWPORT_SIZE.y / 500.0));
	// 한 픽셀이 차지하는 칸 길이. 비스듬한 선이 두 겹이 되지 않게 합이 아니라 큰 쪽을 쓴다
	vec2 w = max(abs(dFdx(cell)), abs(dFdy(cell))) * width;
	// 판정 구간은 픽셀 간격과 정확히 같아야 한다: 좁으면 줄이 빠지고 넓으면 두 겹이 된다 (tests/grid_render.gd).
	// 픽셀 중심이 칸 경계에 정확히 걸리는 배율에서 오차에 흔들리지 않게 구간 시작만 조금 비킨다
	vec2 line = step(fract(cell + w * 0.013), w);
	ALBEDO = vec3(1.0);
	ALPHA = strength * max(line.x, line.y);
}

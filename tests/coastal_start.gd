extends RefCounted
## 흐름 점검용 첫 도시 자리: 시작 영역 3x3에 평원이 넉넉하고 열린 바다도 있어 항구·교역소·병영을 모두 지을 수 있는 칸


static func pick(f: Field) -> Vector2i:
	var best: Vector2i = f.start_cells().keys()[0]
	var best_score: int = -1
	for c: Vector2i in f.start_cells():
		var plains: int = 0
		var sea: int = 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if f.cells.get(n, -1) == Piece.PLAINS:
					plains += 1
				elif not f.cells.has(n) and f.is_open_sea(n):
					sea += 1
		if sea >= 1 and plains >= 3 and plains * 10 + sea > best_score:
			best_score = plains * 10 + sea
			best = c
	return best

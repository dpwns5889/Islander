extends SceneTree
## R1 로직 점검: 96x96 군도 생성, 시작 자리, 도시 세우기, 도시 수 배율 godot --headless --script tests/r1_check.gd


func _initialize() -> void:
	var fails: int = 0
	var f: Field = Field.new()
	root.add_child(f)
	f.generate_map(12345)
	var inner: Rect2i = f.bounds.grow(-Balance.MAP_EDGE_SEA)
	var edge_land: int = 0
	var kinds: Dictionary = {}
	for c: Vector2i in f.cells:
		if not inner.has_point(c):
			edge_land += 1
		kinds[f.cells[c]] = int(kinds.get(f.cells[c], 0)) + 1
	fails += _check(f.bounds.size == Vector2i(96, 96), "맵은 96x96")
	fails += _check(edge_land == 0, "가장자리 %d칸은 바다" % Balance.MAP_EDGE_SEA)
	var ratio: float = f.cells.size() / float(inner.get_area())
	fails += _check(ratio > 0.25 and ratio < 0.4, "땅 비율 약 35%% (%.2f)" % ratio)
	fails += _check(kinds.has(Piece.PLAINS) and kinds.has(Piece.SAND) and kinds.has(Piece.FOREST) and kinds.has(Piece.MOUNTAIN), "평원·모래·숲·산이 모두 있다 %s" % kinds)
	var shore_ok: bool = true
	for c: Vector2i in f.cells:
		if f.sea_neighbor(c).x != -999 and f.cells[c] != Piece.SAND:
			shore_ok = false
	fails += _check(shore_ok, "바다와 닿은 땅은 모래")
	var small: int = 0
	for comp: Array in f._components(func(c: Vector2i) -> bool: return f.cells.has(c)):
		if comp.size() < Balance.MAP_MIN_ISLAND:
			small += 1
	fails += _check(small == 0, "%d칸보다 작은 섬이 없다" % Balance.MAP_MIN_ISLAND)
	var islands: int = f._components(func(c: Vector2i) -> bool: return f.cells.has(c)).size()
	fails += _check(islands >= 3, "섬이 여러 개 (%d개)" % islands)
	# 같은 시드는 같은 맵, 다른 시드는 다른 맵
	var g: Field = Field.new()
	root.add_child(g)
	g.generate_map(12345)
	fails += _check(g.cells == f.cells, "같은 시드는 같은 맵")
	g.generate_map(999)
	fails += _check(g.cells != f.cells, "다른 시드는 다른 맵")
	# 시작 자리
	var starts: Dictionary = f.start_cells()
	fails += _check(not starts.is_empty(), "첫 도시 자리가 있다 (%d칸)" % starts.size())
	var sand: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in f.cells:
		if f.cells[c] == Piece.SAND:
			sand = c
			break
	fails += _check(not f.can_start(sand) and not f.can_start(Vector2i(0, 0)), "모래·바다에는 세울 수 없다")
	var start: Vector2i = starts.keys()[0]
	fails += _check(f.can_start(start), "평원 시작 자리는 세울 수 있다")
	f.found_city(start)
	fails += _check(f.hqs.has(start) and f.hq_level[start] == 1 and f.territory_of[start].size() == 9, "도시를 세우면 레벨 1, 영역 3x3")
	fails += _check(not f.can_start(starts.keys()[-1]), "첫 도시를 세운 뒤에는 시작 자리를 다시 고를 수 없다")
	# 도시 수 배율, 도시 자동 공격 없음
	fails += _check(is_equal_approx(Balance.enemy_mult(1), 1.0) and is_equal_approx(Balance.enemy_mult(3), 1.3), "적 배율 = 1 + 0.15 × (도시 수 − 1)")
	fails += _check(not f.sea_blocked(), "넓은 바다라 바닷길이 열려 있다")
	print("R1 로직 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

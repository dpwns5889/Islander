extends SceneTree
## M21 점검: 바닷길이 막히면 해적이 가까운 땅에 내려 바다를 느리게 건넌다 (기획서 6장)
## godot --headless --script tests/m21_check.gd


func _initialize() -> void:
	var fails: int = 0
	var f: Field = _field(true)
	fails += _check(absf(f.speed_mult_at(f.cell_to_world(Vector2i(-1, 7)), true) - Balance.SEA_CROSS_SPEED) < 0.001, "건너는 해적은 바다에서 느리다")
	fails += _check(f.speed_mult_at(f.cell_to_world(Vector2i(-1, 7)), false) == 1.0, "배·일반 유닛은 느리지 않다")
	fails += _check(f.path(f.nav(false), Vector2i(4, 7), Vector2i(12, 5)).is_empty(), "땅길은 막혀 있다")
	fails += _check(not f.path(f.nav_cross(), Vector2i(4, 7), Vector2i(12, 5)).is_empty(), "건너는 길찾기는 바다를 지난다")
	var open: Dictionary = _sim(false)
	var blocked: Dictionary = _sim(true)
	print("열린 바다: 건너는 해적 %s, 끝남 %s / 막힌 바다: 건너는 해적 %s, 바다 위 %s, 끝남 %s, 집 %d채" % [open["crossing"], open["done"], blocked["crossing"], blocked["in_sea"], blocked["done"], blocked["houses"]])
	fails += _check(not open["crossing"], "바닷길이 열려 있으면 바다를 건너지 않는다")
	fails += _check(blocked["crossing"], "바닷길이 막히면 해적이 건너는 모드가 된다")
	fails += _check(blocked["in_sea"], "건너는 해적이 바다 칸에 들어선다")
	fails += _check(blocked["done"], "전투가 끝난다")
	print("M21 점검 실패 %d건" % fails)
	quit(fails)


## 왼쪽 섬 A(본부)와 오른쪽 섬 B(집 3채). ring이면 바깥에 땅 고리를 둘러 바닷길을 막는다
func _field(ring: bool) -> Field:
	var f: Field = Field.new()
	var a: Piece = Piece.new()
	for y in 5:
		for x in 5:
			a.cells.append(Vector2i(x, y))
			a.terrain.append(Piece.PLAINS)
	a.hq_index = 12
	f.place(a, Vector2i(2, 5))
	var b: Piece = Piece.new()
	for y in 5:
		for x in 3:
			b.cells.append(Vector2i(x, y))
			b.terrain.append(Piece.PLAINS)
	f.place(b, Vector2i(12, 5))
	for y in 3:
		f.build(Balance.HOUSE, Vector2i(12, 5 + y))
	if ring:
		var r: Rect2i = f.bounds.grow(3)
		for x in range(r.position.x, r.end.x):
			f._outer[Vector2i(x, r.position.y)] = Piece.SAND
			f._outer[Vector2i(x, r.end.y - 1)] = Piece.SAND
		for y in range(r.position.y, r.end.y):
			f._outer[Vector2i(r.position.x, y)] = Piece.SAND
			f._outer[Vector2i(r.end.x - 1, y)] = Piece.SAND
	return f


func _sim(ring: bool) -> Dictionary:
	var f: Field = _field(ring)
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var b: Battle = Battle.new()
	b.setup(f, gs, 3)
	b.rng.seed = 5
	var crossing: bool = false
	var in_sea: bool = false
	for _i in 6000:
		b.tick(0.1)
		for p in b.pirates:
			if p.crossing:
				crossing = true
				if f.terrain_at(f.world_to_cell(p.position)) == Field.SEA:
					in_sea = true
		if b.done:
			break
	var houses: int = 0
	for c in f.buildings:
		if f.buildings[c] == Balance.HOUSE:
			houses += 1
	return {"crossing": crossing, "in_sea": in_sea, "done": b.done, "houses": houses}


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

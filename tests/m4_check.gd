extends SceneTree
## M4 점검: godot --headless --script tests/m4_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 길찾기와 섬
	var f2: Field = _two_islands(true)
	var land: AStarGrid2D = f2.nav(false)
	var sea: AStarGrid2D = f2.nav(true)
	var isl: Dictionary = f2.island_map()
	fails += _check(isl[Vector2i(4, 7)] != isl[Vector2i(12, 5)], "섬이 두 개로 나뉜다")
	fails += _check(not f2.path(land, Vector2i(4, 7), Vector2i(6, 7)).is_empty(), "같은 섬은 걸어서 간다")
	fails += _check(f2.path(land, Vector2i(4, 7), Vector2i(12, 5)).is_empty(), "바다 건너는 걸어서 못 간다")
	fails += _check(not f2.path(sea, Vector2i(-1, 7), Vector2i(7, 7)).is_empty(), "바다 길")
	# 항구가 있으면 병사가 보트로 건너가고, 없으면 못 건넌다
	var with_port: Dictionary = _sim(true)
	var no_port: Dictionary = _sim(false)
	print("항구 있음: 건넘 %s, 승리 %s, 집 %d채 / 항구 없음: 건넘 %s, 승리 %s, 집 %d채" % [with_port["crossed"], with_port["victory"], with_port["houses"], no_port["crossed"], no_port["victory"], no_port["houses"]])
	fails += _check(with_port["crossed"], "항구가 있으면 병사가 건너간다")
	fails += _check(not no_port["crossed"], "항구가 없으면 건너가지 못한다")
	print("M4 점검 실패 %d건" % fails)
	quit(fails)


## 왼쪽 섬 A(본부, 5x5 평원)와 오른쪽 섬 B(집 3채, 오른쪽 한 줄은 모래). 사이는 바다
func _two_islands(with_port: bool) -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
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
			b.terrain.append(Piece.SAND if x == 2 else Piece.PLAINS)
	f.place(b, Vector2i(12, 5))
	for y in 3:
		f.build(Balance.HOUSE, Vector2i(12, 5 + y))
	if with_port:
		f.build(Balance.PORT, Vector2i(6, 7))
	return f


func _sim(with_port: bool) -> Dictionary:
	var f: Field = _two_islands(with_port)
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var b: Battle = Battle.new()
	b.setup(f, gs, 1)
	b.rng.seed = 3
	var island_b: int = b.islands[Vector2i(12, 5)]
	var crossed: bool = false
	var result: Array = []
	b.finished.connect(func(v: bool) -> void: result.append(v))
	for _i in 3000:
		b.tick(0.1)
		for s in b.soldiers:
			if s.island == island_b:
				crossed = true
		if b.done:
			break
	var houses: int = 0
	for c in f.buildings:
		if f.buildings[c] == Balance.HOUSE:
			houses += 1
	return {"crossed": crossed, "victory": result.size() > 0 and result[0], "houses": houses}


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

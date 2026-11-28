extends SceneTree
## R5 로직 점검: 목표 도시(시드·웨이브로 정해짐), 목표 도시에서 가장 가까운 가장자리 출발, 안개 밝히기(주변 4칸, 한 번 밝히면 계속),
## 유적지(평원 12곳, 첫 도시 영역 밖, 안개 속이면 숨김, 그 칸엔 못 짓는다, 한 번만 가져간다)
## godot --headless --script tests/r5_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 목표 도시: 같은 시드·웨이브면 같고, 도시 수 안의 번호다
	var seen: Dictionary = {}
	for w in range(1, 31):
		var t: int = Balance.wave_target(w, 777, 3)
		fails += _check(t >= 0 and t < 3 and t == Balance.wave_target(w, 777, 3), "목표 도시 번호는 0~2이고 다시 불러도 같다 (웨이브 %d: %d)" % [w, t])
		seen[t] = true
	fails += _check(seen.size() == 3, "30웨이브 동안 세 도시가 모두 목표가 된다 (%d)" % seen.size())
	fails += _check(Balance.wave_target(5, 1, 1) == 0, "도시가 하나면 항상 그 도시")
	# 안개
	var f: Field = _island()
	var hq: Vector2i = f.hq
	f.enable_fog()
	fails += _check(not f.is_explored(hq), "안개를 켜면 아직 밝힌 칸이 없다")
	fails += _check(f.reveal(hq, Balance.VISION_RANGE) and f.is_explored(hq + Vector2i(4, 0)) and f.is_explored(hq + Vector2i(2, 3)), "주변 4칸을 밝힌다")
	fails += _check(not f.is_explored(hq + Vector2i(5, 0)) and not f.is_explored(hq + Vector2i(3, 3)), "4칸 밖(거리 5, 대각 3·3)은 그대로")
	fails += _check(not f.reveal(hq, Balance.VISION_RANGE), "이미 밝힌 곳을 다시 밝혀도 바뀌는 것이 없다")
	f.reveal_cells(f.territory_of[hq])
	fails += _check(f.is_explored(hq + Vector2i(1, 1)), "도시 영역을 밝힌다")
	# 유적지
	var g: Field = _island()
	g.enable_fog()
	g.reveal(g.hq, 2.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	g.place_ruins(rng, g.territory_of[g.hq])
	fails += _check(g.ruins.size() == Balance.RUIN_COUNT, "유적지 12곳 (%d)" % g.ruins.size())
	var ok_place: bool = true
	var hidden: bool = true
	for c: Vector2i in g.ruins:
		ok_place = ok_place and g.cells.get(c, -1) == Piece.PLAINS and not g.territory_of[g.hq].has(c)
		if not g.is_explored(c):
			hidden = hidden and not (g.ruins[c] as Node3D).visible
	fails += _check(ok_place, "유적지는 첫 도시 영역 밖의 평원")
	fails += _check(hidden, "밝히지 않은 곳의 유적지는 보이지 않는다")
	var r: Vector2i = g.ruins.keys()[0]
	g.reveal(r, 0.0)
	fails += _check((g.ruins[r] as Node3D).visible, "밝히면 유적지가 보인다")
	g.reveal_cells({r + Vector2i(1, 0): true})
	fails += _check(not g.can_build(Balance.HOUSE, r) or not g.in_territory(r), "유적지 칸에는 짓지 못한다")
	g.territory_enabled = false
	fails += _check(not g.can_build(Balance.HOUSE, r), "영역 제한이 없어도 유적지 칸에는 짓지 못한다")
	fails += _check(g.take_ruin(r) and not g.ruins.has(r) and not g.take_ruin(r), "유적지는 한 번만 가져간다")
	# 해적선 출발: 목표 도시에서 가장 가까운 가장자리
	var h: Field = _island()
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var b: Battle = Battle.new()
	root.add_child(b)
	b.setup(h, gs)
	b.launch_wave(1)
	fails += _check(b.target_city == h.hq, "도시가 하나면 그 도시가 목표")
	fails += _check(b._edge_near(Vector2i(2, 6)) == Vector2i(h.bounds.position.x, 6), "(2, 6)에서 가장 가까운 가장자리는 왼쪽 (%s)" % b._edge_near(Vector2i(2, 6)))
	fails += _check(b._edge_near(Vector2i(20, 3)) == Vector2i(h.bounds.end.x - 1, 3), "(20, 3)은 오른쪽 가장자리")
	fails += _check(b._edge_near(Vector2i(10, 20)) == Vector2i(10, h.bounds.end.y - 1), "(10, 20)은 아래 가장자리")
	b.tick(0.1)
	fails += _check(not b.ships.is_empty() and h.world_to_cell(b.ships[0].position) == Vector2i(h.bounds.position.x, 6), "첫 해적선이 목표 도시 쪽 가장자리에서 나온다 (%s)" % (h.world_to_cell(b.ships[0].position) if not b.ships.is_empty() else Vector2i(-1, -1)))
	print("R5 점검 실패 %d건" % fails)
	quit(fails)


## 가로 14칸 × 세로 5칸 평원 섬(0..13, 4..8), 첫 도시는 (2, 6). 유적지 12곳이 들어갈 만큼 평원이 넉넉하다
func _island() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
	var pc: Piece = Piece.new()
	for y in 5:
		for x in 14:
			pc.cells.append(Vector2i(x, y))
			pc.terrain.append(Piece.PLAINS)
	pc.hq_index = 2 * 14 + 2
	f.place(pc, Vector2i(0, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

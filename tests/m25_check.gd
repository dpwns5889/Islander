extends SceneTree
## M25 점검: 상륙한 섬의 건물을 다 부수면 해적이 사라지지 않고 다른 섬으로 바다를 건너 간다 (기획서 6장)
## godot --headless --script tests/m25_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 왼쪽 섬 A(본부), 오른쪽 섬 B(집 1채), 사이는 바다
	var f: Field = Field.new()
	var a: Piece = Piece.new()
	for y in 5:
		for x in 5:
			a.cells.append(Vector2i(x, y))
			a.terrain.append(Piece.PLAINS)
	a.hq_index = 12
	f.place(a, Vector2i(2, 5))
	var b: Piece = Piece.new()
	for y in 3:
		for x in 3:
			b.cells.append(Vector2i(x, y))
			b.terrain.append(Piece.PLAINS)
	f.place(b, Vector2i(12, 5))
	f.build(Balance.HOUSE, Vector2i(12, 5))
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var bt: Battle = Battle.new()
	bt.setup(f, gs, 3)
	for s in bt.ships:
		s.hp = 0.0
	bt._prune(bt.ships)
	bt._ships_left = 0 # 해적선은 이미 다 내렸다
	var p: Unit = bt._add_unit(Balance.U_PIRATE, f.cell_to_world(Vector2i(13, 6)), 1.0)
	p.island = bt.islands.get(Vector2i(13, 6), -1)
	f.damage(Vector2i(12, 5), 9999.0) # 섬 B의 집이 부서진다
	for _i in 20:
		bt.tick(0.1)
	fails += _check(is_instance_valid(p) and p.hp > 0.0 and p.crossing, "섬 B가 비어도 본부 섬이 남아 있으면 해적이 건너는 모드가 된다")
	fails += _check(not bt.done, "본부가 멀쩡하면 전투가 끝나지 않는다")
	print("M25 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

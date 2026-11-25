extends SceneTree
## 본부 약한 공격 점검: godot --headless --script tests/m23_check.gd


func _initialize() -> void:
	var fails: int = 0
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 9:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 2 * 9 + 1
	f.place(p, Vector2i(4, 4))
	var b: Battle = Battle.new()
	b.setup(f, load("res://assets/scripts/game_state.gd").new(), 1)
	b._ships_left = 1
	b._ship_timer = 9999.0
	var hpos: Vector3 = f.cell_to_world(f.hq)
	var near: Unit = b._add_unit(Balance.U_SHIELD, hpos + Vector3(Balance.HQ_RANGE - 0.3, 0.0, 0.0), 1.0)
	near.speed = 0.0
	var far: Unit = b._add_unit(Balance.U_SHIELD, hpos + Vector3(Balance.HQ_RANGE + 1.0, 0.0, 0.0), 1.0)
	far.speed = 0.0
	var hn: float = near.hp
	var hf: float = far.hp
	b._towers_turn(0.0)
	fails += _check(absf(near.hp - (hn - Balance.HQ_ATK)) < 0.001 and far.hp == hf, "본부가 사거리 안의 적만 공격력 %.0f으로 쏜다" % Balance.HQ_ATK)
	b._towers_turn(0.5)
	fails += _check(absf(near.hp - (hn - Balance.HQ_ATK)) < 0.001, "1초가 지나기 전에는 다시 쏘지 않는다")
	b._towers_turn(0.6)
	fails += _check(absf(near.hp - (hn - 2.0 * Balance.HQ_ATK)) < 0.001, "1초 뒤에 다시 쏜다")
	# 병영도 본부 영역 밖에는 못 짓는다 (기획서 5.3)
	f.territory_enabled = true
	f.territory.clear()
	var far_c: Vector2i = Vector2i(11, 6)
	fails += _check(not f.can_build(Balance.BARRACKS, far_c) and not f.can_build(Balance.HOUSE, far_c), "영역 밖: 병영도 못 짓는다")
	# 낚시터 식량은 거리 제한 없이 이어진 바다 전체를 센다 (기획서 5.1)
	var lf: Field = Field.new()
	var lp: Piece = Piece.new()
	for y in 14:
		for x in 14:
			lp.cells.append(Vector2i(x, y))
			lp.terrain.append(Piece.SEA if (x >= 2 and x <= 11 and y == 7) else Piece.PLAINS)
	lf.place(lp, Vector2i(3, 3))
	var water: int = lf.fishing_cells(Vector2i(2 + 3, 7 + 3))
	fails += _check(water > 8, "긴 물길 낚시터는 4칸 너머까지 센다 (%d칸)" % water)
	print("본부 공격 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

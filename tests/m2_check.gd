extends SceneTree
## M2 로직 점검: godot --headless --script tests/m2_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 3x3 평원 한 덩어리, 가운데는 바다와 맞닿지 않는다
	var p: Piece = Piece.new()
	for y in 3:
		for x in 3:
			p.cells.append(Vector2i(x, y))
	for _c in p.cells:
		p.terrain.append(Piece.PLAINS)
	var f: Field = preload("res://tests/small_field.gd").make()
	f.place(p, Vector2i(5, 5))
	fails += _check(f.can_build(Balance.HOUSE, Vector2i(6, 6)), "평원에 집")
	fails += _check(f.can_build(Balance.BARRACKS, Vector2i(6, 6)), "평원에 병영")
	fails += _check(not f.can_build(Balance.PORT, Vector2i(6, 6)), "바다와 안 닿으면 항구 불가")
	fails += _check(f.can_build(Balance.PORT, Vector2i(5, 6)), "바다와 닿으면 항구 가능")
	fails += _check(not f.can_build(Balance.HOUSE, Vector2i(0, 0)), "바다에 건설 불가")
	f.build(Balance.HOUSE, Vector2i(6, 6))
	fails += _check(not f.can_build(Balance.HOUSE, Vector2i(6, 6)), "이미 건물이 있으면 불가")
	fails += _check(f.income() == Vector2i(10, 9), "집 1채 + 평원 9칸 = 골드 10, 식량 9")
	# 모래 위: 집·항구만, 집은 골드 15
	var s: Piece = Piece.new()
	s.cells.assign([Vector2i(0, 0), Vector2i(1, 0)])
	s.terrain.assign([Piece.SAND, Piece.SAND])
	f.place(s, Vector2i(12, 5))
	fails += _check(not f.can_build(Balance.BARRACKS, Vector2i(12, 5)), "모래에 병영 불가")
	fails += _check(not f.can_build(Balance.MARKET, Vector2i(12, 5)), "모래에 시장 불가")
	f.build(Balance.HOUSE, Vector2i(12, 5))
	fails += _check(f.income() == Vector2i(25, 9), "모래 집 +15")
	# 자원
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	fails += _check(gs.gold == Balance.START_GOLD, "시작 골드")
	fails += _check(gs.spend(30) and gs.gold == Balance.START_GOLD - 30, "골드 소모")
	fails += _check(not gs.spend(999) and gs.gold == Balance.START_GOLD - 30, "모자라면 소모 불가")
	print("M2 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

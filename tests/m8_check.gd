extends SceneTree
## M8 점검: godot --headless --script tests/m8_check.gd


func _initialize() -> void:
	var fails: int = 0
	var t: Array[int] = Balance.HQ_LEVEL_FOOD
	fails += _check(t == [20, 50, 100, 180, 300, 450, 650, 900, 1200], "레벨 2~10 기준: 20/50/100/180/300/450/650/900/1200")
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	fails += _check(gs.hq_level == 1 and gs.research_points == 0, "시작: 본부 레벨 1, 연구포인트 0")
	gs.add(0, 19)
	fails += _check(gs.check_level() == 0 and gs.research_points == 0, "식량 19: 변화 없음")
	gs.add(0, 1)
	fails += _check(gs.check_level() == 1 and gs.hq_level == 2 and gs.research_points == 0, "식량 20: 레벨 2, 연구포인트는 안 오른다")
	gs.add(0, 130) # 누적 150 → 레벨 4(100)까지
	fails += _check(gs.check_level() == 2 and gs.hq_level == 4 and gs.research_points == 0, "누적 150: 레벨 4")
	gs.spend(0, 100) # 식량을 써도 누적과 레벨은 그대로
	fails += _check(gs.food_total == 150 and gs.hq_level == 4, "식량을 써도 누적은 줄지 않는다")
	gs.add(0, 5000)
	fails += _check(gs.check_level() == 6 and gs.hq_level == 10 and gs.research_points == 0, "최고 레벨 10")
	fails += _check(gs.next_level_food() == -1, "최고 레벨에서는 다음 기준 없음")
	fails += _check(gs.check_level() == 0 and gs.research_points == 0, "최고 레벨 이후에는 더 오르지 않는다")
	# 연구수치: 기준(10)마다 연구포인트 +1, 남는 수치는 이월
	gs.reset()
	fails += _check(gs.add_research_progress(7) == 0 and gs.research_progress == 7, "연구수치 7: 연구포인트 없음")
	fails += _check(gs.add_research_progress(6) == 1 and gs.research_progress == 3 and gs.research_points == 1, "누적 13: 연구포인트 1, 3 이월")
	fails += _check(gs.add_research_progress(27) == 3 and gs.research_progress == 0 and gs.research_points == 4, "누적 30: 연구포인트 +3")
	var rf: Field = Field.new()
	var rp: Piece = Piece.new()
	for i in 4:
		rp.cells.append(Vector2i(i, 0))
		rp.terrain.append(Piece.PLAINS)
	rf.place(rp, Vector2i(2, 2))
	rf.build(Balance.LIBRARY, Vector2i(2, 2))
	rf.build(Balance.LAB, Vector2i(3, 2))
	fails += _check(rf.research_income() == 9, "도서관 Lv1(3) + 연구소 Lv1(6) = 9")
	rf.upgrade(Vector2i(3, 2))
	fails += _check(rf.research_income() == 11, "연구소 Lv2(8) → 11")
	# 시장: 4방향으로 붙은 집의 정산 골드 +25%
	rf.build(Balance.HOUSE, Vector2i(4, 2))
	var g0: int = rf.income().x
	rf.build(Balance.MARKET, Vector2i(5, 2))
	var g1: int = rf.income().x
	fails += _check(g0 == 10 and g1 == 12, "집 10골드 → 시장 옆 12골드 (%d → %d)" % [g0, g1])
	gs.reset()
	fails += _check(gs.hq_level == 1 and gs.research_points == 0 and gs.food_total == 0, "재시작하면 초기화")
	print("M8 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

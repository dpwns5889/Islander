extends SceneTree
## 병영 병력 계획 점검(병사 생산은 무료): godot --headless --script tests/m14_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 병영 1개(레벨 1): 병사 3명
	var f: Field = _island()
	f.build(Balance.BARRACKS, Vector2i(6, 6))
	var plan: Array = Battle.barracks_plan(f)
	fails += _check(plan.size() == 3 and plan[0]["kind"] == Balance.U_GUARD and plan[0]["cell"] == Vector2i(6, 6), "병영 레벨 1: 경비병 3명")
	# 레벨이 오르면 인원은 그대로 3명이고 병종이 검사, 기사로 바뀐다
	f.upgrade(Vector2i(6, 6))
	fails += _check(Battle.barracks_plan(f).size() == 3 and Battle.barracks_plan(f)[0]["kind"] == Balance.U_SPEAR, "병영 레벨 2: 창병 3명")
	f.upgrade(Vector2i(6, 6))
	var plan3: Array = Battle.barracks_plan(f)
	fails += _check(plan3.size() == 3 and plan3[0]["kind"] == Balance.U_PIKE and plan3[0]["lv"] == 3, "병영 레벨 3: 파이크병 3명")
	# 병영이 없으면 계획도 없다
	fails += _check(Battle.barracks_plan(_island()).is_empty(), "병영이 없으면 0")
	# 병영이 둘이면 합쳐서
	var f2: Field = _island()
	f2.build(Balance.BARRACKS, Vector2i(6, 6))
	f2.build(Balance.SHOOTING_RANGE, Vector2i(7, 6))
	var kinds: Dictionary = {}
	for e: Dictionary in Battle.barracks_plan(f2):
		kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
	fails += _check(kinds == {Balance.U_GUARD: 3, Balance.U_ARCHER: 2}, "병영 + 사격장: 경비병 3 + 궁수 2")
	# 실제 전투 시작: 골드·식량이 0이어도 병영 병사가 나오고, 자원은 그대로
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = 0
	gs.food = 0
	var b: Battle = Battle.new()
	b.setup(f2, gs, 1)
	fails += _check(b.soldiers.size() == Balance.HQ_GUARDS + 5, "자원이 없어도 병사 %d명 (수비병 %d + 병영 3 + 사격장 2)" % [b.soldiers.size(), Balance.HQ_GUARDS])
	fails += _check(gs.gold == 0 and gs.food == 0, "병사 생산에 자원이 들지 않는다")
	# 매 웨이브마다 똑같이 나온다
	var b2: Battle = Battle.new()
	b2.setup(f2, gs, 2)
	fails += _check(b2.soldiers.size() == b.soldiers.size(), "다음 웨이브에도 같은 수가 나온다")
	print("병영 병력 점검 실패 %d건" % fails)
	quit(fails)


func _island() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

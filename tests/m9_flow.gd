extends SceneTree
## M9 화면 흐름 점검: godot --headless --script tests/m9_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	gs.gold = 1000
	# 항구는 연구 전에는 못 짓는다
	main.set_build(Balance.PORT)
	var built: bool = false
	for c in main.field.cells:
		built = built or main.try_build(c)
	fails += _check(not built and not main.field.buildings.values().has(Balance.PORT), "항해술 없이는 항구 건설 불가")
	gs.research_points = 10
	fails += _check(not main.research("ship"), "선행 연구 없이 조선술 불가")
	fails += _check(main.research("sail") and gs.research_points == 9, "항해술 연구")
	main.set_build(Balance.PORT)
	for c in main.field.cells:
		if main.try_build(c):
			built = true
			break
	fails += _check(built and main.field.buildings.values().has(Balance.PORT), "연구 뒤에는 항구를 지을 수 있다")
	# 병영 병종 선택: 궁수는 궁술 뒤에
	main.set_build(Balance.BARRACKS)
	var barracks: Vector2i = Vector2i(-1, -1)
	for c in main.field.cells:
		if main.try_build(c):
			barracks = c
			break
	main.set_build(0)
	fails += _check(main.select_building(barracks) and main.unit_row.visible, "병영을 고르면 병종 버튼이 보인다")
	fails += _check(not main.select_unit(Balance.U_ARCHER), "궁술 전에는 궁수를 못 고른다")
	fails += _check(main.research("archery") and main.select_unit(Balance.U_ARCHER) and main.field.barracks_unit[barracks] == Balance.U_ARCHER, "궁술 뒤에는 궁수를 고른다")
	fails += _check(main.select_unit(Balance.U_SOLDIER) and main.field.barracks_unit[barracks] == Balance.U_SOLDIER, "검병으로 되돌릴 수 있다")
	# 금융: 건설 비용 할인
	fails += _check(main.research("trade") and main.research("commerce") and main.research("finance"), "교역·상업·금융 연구")
	main.set_build(Balance.HOUSE)
	fails += _check(main._cost_of(Balance.HOUSE) == 17, "금융: 집 20 → 17골드")
	main.set_build(0)
	main._toggle_research()
	fails += _check(main.research_panel.visible, "연구 패널이 열린다")
	main._toggle_research()
	fails += _check(not main.research_panel.visible, "연구 패널이 닫힌다")
	# 전투를 돌리면 연구 효과(단련, 상업)가 적용된 채로 끝난다
	main.research("archery") # 이미 했으므로 무시되어야 한다
	main.start_wave()
	for _i in 3000:
		if main.battle == null:
			break
		main.battle.tick(0.1)
	fails += _check(main.battle == null and gs.wave == 2, "연구를 한 상태로 웨이브 승리")
	print("M9 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

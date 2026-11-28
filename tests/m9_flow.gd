extends SceneTree
const Instant = preload("res://tests/instant.gd") ## 건설·강화 공사를 바로 끝낸다
## M9 화면 흐름 점검: godot --headless --script tests/m9_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	gs.gold = 1000
	# 항구는 연구 없이 처음부터 짓는다
	main.set_build(Balance.PORT)
	var built: bool = false
	for c in main.field.cells:
		if Instant.build(main, c):
			built = true
			break
	fails += _check(built and main.field.buildings.values().has(Balance.PORT), "항구는 연구 없이 지을 수 있다")
	gs.research_points = 40
	fails += _check(not main.research("mining") and main.research("toolmaking") and main.research("mining") and gs.research_points == 38, "도구 → 채광 연구")
	# 철기 제작 전에는 병영 레벨 3 강화를 못 한다
	main.set_build(Balance.BARRACKS)
	var barracks: Vector2i = Vector2i(-1, -1)
	for c in main.field.cells:
		if Instant.build(main, c):
			barracks = c
			break
	main.set_build(0)
	gs.gold = 1000
	fails += _check(main.select_building(barracks) and Instant.upgrade(main), "병영 레벨 2 강화")
	fails += _check(not Instant.upgrade(main), "철기 제작 전에는 레벨 3 강화 불가")
	fails += _check(main.research("ironwork") and Instant.upgrade(main) and main.field.levels[barracks] == 3, "철기 제작 뒤에는 레벨 3 강화")
	# 공학: 레벨업 비용 할인, 건설비는 그대로
	fails += _check(main.research("tools") and main.research("waterwheel") and main.research("engineering"), "농기구·물레방아·공학 연구")
	fails += _check(main._cost_of(Balance.HOUSE) == 20 and gs.upgrade_discounted(20) == 16, "공학: 건설 20, 레벨업 20 → 16골드")
	fails += _check(main.research("math") and main.research("currency") and main.research("commerce"), "수학·화폐·상업 연구")
	main.set_build(0)
	main._toggle_research()
	fails += _check(main.research_panel.visible, "연구 패널이 열린다")
	main.select_tech("tools")
	fails += _check(main.selected_tech == "tools" and Balance.TECHS["tools"]["desc"] in main.tech_detail.text and Balance.TECHS["tools"]["desc"] not in main.research_buttons["tools"].text, "연구를 고르면 상세 창에 효과, 트리 버튼에는 효과 없음")
	main._toggle_research()
	fails += _check(not main.research_panel.visible, "연구 패널이 닫힌다")
	# 전투를 돌리면 연구 효과(단련, 상업)가 적용된 채로 끝난다
	main.research("archery") # 이미 했으므로 무시되어야 한다
	main.call_wave()
	for _i in 6000: # 넓은 맵이라 먼 곳에 내린 해적까지 잡는 데 오래 걸릴 수 있다
		if main.battle.enemies_left() == 0 or main.over: # 실시간이라 웨이브를 다 막아도 전투는 이어진다 (기획서 2장)
			break
		main.battle.tick(0.1)
	fails += _check(main.battle.enemies_left() == 0 and gs.wave == 2, "연구를 한 상태로 웨이브 승리")
	print("M9 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

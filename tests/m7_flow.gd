extends SceneTree
## M7 화면 흐름 점검: godot --headless --script tests/m7_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	fails += _check(gs.gold == 50, "시작 골드 50")
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	var cell: Vector2i = Vector2i(-1, -1)
	main.set_build(Balance.HOUSE)
	for c in main.field.cells:
		if main.try_build(c):
			cell = c
			break
	main.set_build(0)
	fails += _check(gs.gold == 30, "집 20골드 (남은 골드 %d)" % gs.gold)
	fails += _check(main.select_building(cell) and main.upgrade_panel.visible, "건물을 고르면 레벨업 패널이 열린다")
	fails += _check(main.upgrade_selected() and main.field.levels[cell] == 2 and gs.gold == 10, "레벨 2: 20골드")
	fails += _check(not main.upgrade_selected() and main.field.levels[cell] == 2, "골드가 모자라면 레벨업 불가")
	gs.gold = 100
	fails += _check(main.upgrade_selected() and main.field.levels[cell] == 3 and gs.gold == 70, "레벨 3: 30골드")
	fails += _check(not main.upgrade_selected(), "최고 레벨에서는 더 못 올린다")
	fails += _check(not main.select_building(Vector2i(-50, -50)) and not main.upgrade_panel.visible, "빈 곳을 누르면 선택 해제")
	# 전투를 돌리고 나서도 레벨이 유지된다
	main.start_wave()
	for _i in 3000:
		if main.battle == null:
			break
		main.battle.tick(0.1)
	fails += _check(main.field.buildings.has(cell) and main.field.levels[cell] == 3, "웨이브 뒤에도 집 레벨 3")
	print("M7 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

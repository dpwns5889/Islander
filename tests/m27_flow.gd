extends SceneTree
const Instant = preload("res://tests/instant.gd") ## 건설·강화 공사를 바로 끝낸다
## M27 화면 흐름 점검: 건물 진화 UI godot --headless --script tests/m27_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	gs.gold = 1000
	var cell: Vector2i = Vector2i(-1, -1)
	main.set_build(Balance.HOUSE)
	for c in main.field.cells:
		if Instant.build(main, c):
			cell = c
			break
	main.set_build(0)
	main.select_building(cell)
	Instant.upgrade(main)
	Instant.upgrade(main) # 레벨 3
	fails += _check(main.field.levels[cell] == 3 and main.upgrade_button.text.begins_with("진화: 저택 28G") and main.upgrade_button.disabled, "레벨 3 집: 진화 버튼은 연구 전에 비활성")
	fails += _check("화폐" in main.upgrade_button.tooltip_text, "툴팁에 필요 연구(화폐)")
	fails += _check(not Instant.upgrade(main) and main.field.buildings[cell] == Balance.HOUSE, "연구 전에는 진화 안 됨")
	gs.researched["currency"] = true
	main._refresh_hud()
	fails += _check(not main.upgrade_button.disabled and main.build_buttons[Balance.HOUSE].visible and not main.build_buttons.has(Balance.MANSION), "화폐 뒤: 진화 가능, 건설 목록에는 집만 있고 저택은 없다")
	var before: int = gs.gold
	fails += _check(Instant.upgrade(main) and main.field.buildings[cell] == Balance.MANSION and main.field.levels[cell] == 1 and gs.gold == before - 28, "저택으로 진화: 28골드, 레벨 1")
	fails += _check(main.upgrade_button.text.begins_with("레벨 2로 강화"), "진화 뒤에는 다시 레벨업 버튼")
	fails += _check(main._unlocked(Balance.HOUSE), "진화 뒤에도 집은 계속 지을 수 있다")
	print("M27 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

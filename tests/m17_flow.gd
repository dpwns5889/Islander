extends SceneTree
## 방어탑·적 예고 화면 흐름 점검: godot --headless --script tests/m17_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0
	gs.gold = 1000
	# 군사·해상 카테고리에 방어탑이 있다
	fails += _check(main.dropdown_lists[1].get_child_count() == 3 and main.build_buttons.has(Balance.TOWER), "군사·해상 목록: 병영·항구·방어탑")
	main._toggle_category(1)
	var wall: Vector2i = Vector2i(-1, -1) # 방어탑을 지을 땅 칸
	for c in main.field.cells:
		if not main.field.hqs.has(c) and not main.field.buildings.has(c):
			wall = c
			break
	# 방어탑은 연구(궁술) 전에는 못 짓는다
	main.set_build(Balance.TOWER)
	fails += _check(not main._build_ok(wall) and main.build_buttons[Balance.TOWER].disabled, "궁술 전에는 방어탑 잠김")
	gs.research_points = 5
	fails += _check(main.research("archery"), "궁술 연구")
	main._refresh_hud()
	fails += _check(not main.build_buttons[Balance.TOWER].disabled, "궁술 뒤에는 방어탑 해금")
	main.set_build(Balance.TOWER)
	fails += _check(main.try_build(wall) and main.field.buildings[wall] == Balance.TOWER and gs.gold == 960, "방어탑 40골드, 빈 땅에 바로 설치")
	main.select_building(wall)
	fails += _check(main.upgrade_selected() and main.field.levels[wall] == 2 and "공격 6" in main.upgrade_effect.text, "방어탑 레벨 2: " + main.upgrade_effect.text)
	# 적 예고: 종류별 인원과 새 적 안내
	gs.wave = 5
	main._refresh_hud()
	fails += _check("석궁수 1명 · 해적 3명" in main.wave_info.text and "새 적: 석궁수 (체력 18 · 공격 3 · 사거리 3.5칸)" in main.wave_info.text, "5웨이브 예고: " + main.wave_info.text)
	gs.wave = 6
	main._refresh_hud()
	fails += _check("새 적" not in main.wave_info.text, "6웨이브에는 새 적 안내가 없다")
	gs.wave = 10
	main._refresh_hud()
	fails += _check("선장 1명" in main.wave_info.text and "새 적: 선장" in main.wave_info.text, "10웨이브 예고(보스): " + main.wave_info.text)
	gs.wave = 12
	main._refresh_hud()
	fails += _check("방패병 1명 · 도끼병 3명 · 석궁수 2명 · 해적 5명" in main.wave_info.text and "새 적: 방패병" in main.wave_info.text, "12웨이브 예고: " + main.wave_info.text)
	# 전투에서 방어탑이 적을 공격하고 웨이브가 끝까지 돈다 (방어탑 포함)
	gs.wave = 3
	main.start_wave()
	for _i in 3000:
		if main.battle == null:
			break
		main.battle.tick(0.1)
	fails += _check(main.battle == null, "방어탑이 있는 필드에서 웨이브가 끝났다")
	print("방어탑 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

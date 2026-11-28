extends SceneTree
const Instant = preload("res://tests/instant.gd") ## 건설·강화 공사를 바로 끝낸다
## 방어탑·적 예고 화면 흐름 점검: godot --headless --script tests/m17_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	gs.gold = 1000
	# 군사·해상 카테고리에 방어탑이 있다
	fails += _check(main.dropdown_lists[1].get_child_count() == 3 and main.build_buttons.has(Balance.TOWER) and not main.build_buttons.has(Balance.SHOOTING_RANGE), "군사·해상 목록: 병영·항구·방어탑 (사격장 보류)")
	main._toggle_category(1)
	var wall: Vector2i = Vector2i(-1, -1) # 방어탑을 지을 땅 칸
	for c in main.field.cells:
		if main.field.in_territory(c) and not main.field.hqs.has(c) and not main.field.buildings.has(c):
			wall = c
			break
	# 방어탑은 연구(궁술) 전에는 못 짓는다
	main.set_build(Balance.TOWER)
	fails += _check(not main._build_ok(wall) and main.build_buttons[Balance.TOWER].disabled, "궁술 전에는 방어탑 잠김")
	gs.research_points = 5
	fails += _check(main.research("toolmaking") and main.research("archery"), "궁술 연구")
	main._refresh_hud()
	fails += _check(not main.build_buttons[Balance.TOWER].disabled, "궁술 뒤에는 방어탑 해금")
	main.set_build(Balance.TOWER)
	fails += _check(Instant.build(main, wall) and main.field.buildings[wall] == Balance.TOWER and gs.gold == 960, "방어탑 40골드, 빈 땅에 바로 설치")
	main.select_building(wall)
	fails += _check(Instant.upgrade(main) and main.field.levels[wall] == 2 and "공격 6" in main.upgrade_effect.text, "방어탑 레벨 2: " + main.upgrade_effect.text)
	# 적 예고: 종류별 인원과 새 적 안내
	gs.wave = 5
	main._refresh_hud()
	fails += _check("전투력 4" in main.wave_info.text and "석궁수" in main.wave_info.text and "새 적: 석궁수 (체력 18 · 공격 3 · 사거리 1.8칸)" in main.wave_info.text, "5웨이브 예고: " + main.wave_info.text)
	gs.wave = 6
	main._refresh_hud()
	fails += _check("새 적" not in main.wave_info.text, "6웨이브에는 새 적 안내가 없다")
	gs.wave = 10
	main._refresh_hud()
	fails += _check("선장 1명" in main.wave_info.text and "새 적: 선장" in main.wave_info.text, "10웨이브 예고(보스): " + main.wave_info.text)
	gs.wave = 12
	main._refresh_hud()
	fails += _check("방패병" in main.wave_info.text and "전투력 %d" % Balance.wave_budget(12) in main.wave_info.text and "새 적: 방패병" in main.wave_info.text, "12웨이브 예고: " + main.wave_info.text)
	# 전투에서 방어탑이 적을 공격하고 웨이브가 끝까지 돈다 (방어탑 포함)
	gs.wave = 3
	main.call_wave()
	for _i in 6000: # 넓은 맵이라 먼 곳에 내린 해적까지 잡는 데 오래 걸릴 수 있다
		if main.battle.enemies_left() == 0 or main.over: # 실시간이라 웨이브를 다 막아도 전투는 이어진다 (기획서 2장)
			break
		main.battle.tick(0.1)
	fails += _check(main.battle.enemies_left() == 0, "방어탑이 있는 필드에서 웨이브가 끝났다 (%s, 패배 %s)" % [main.battle.summary(), main.over])
	print("방어탑 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

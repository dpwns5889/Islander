extends SceneTree
## 보상 타일 강제·설치 모드 종료·병영 미리보기 화면 점검: godot --headless --script tests/m14_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	var first_ok: bool = main.tiles_required == 0 and main.pieces_left == 0 and not main.panel.visible
	main._begin_prep() # 첫 준비 단계는 보상이 없으므로 이후 준비 단계로 대신한다
	gs.gold = 500
	gs.researched["sail"] = true
	fails += _check(first_ok, "첫 준비 단계에는 보상 타일이 없다")
	var g0: int = gs.gold
	var ruin: Vector2i = Vector2i(99, 99) # 유적지 원정: 항구가 있어야 하고 준비 단계당 1회
	main.field.ruins[ruin] = true
	fails += _check(not main.explore(ruin) and gs.gold == g0, "항구가 없으면 원정 불가")
	main.field.buildings[Vector2i(98, 98)] = Balance.PORT
	var rp0: int = gs.research_points
	fails += _check(main.explore(ruin) and main.explored and (gs.gold > g0 - Balance.EXPLORE_COST or gs.research_points == rp0 + 1), "항구가 있으면 원정 성공")
	main.field.buildings.erase(Vector2i(98, 98))
	# 1. 이후 준비 단계도 타일을 먼저 놓아야 한다
	fails += _check(main.tiles_required == 1 and main._blocked(), "타일을 놓기 전에는 막혀 있다")
	main.set_build(Balance.HOUSE)
	fails += _check(main.build_id == 0, "건물 설치 모드가 열리지 않는다")
	fails += _check(main.build_buttons[Balance.HOUSE].disabled, "건물 버튼 비활성화")
	fails += _check(main.wave_button.disabled, "웨이브 시작 버튼 비활성화")
	main.start_wave()
	fails += _check(main.battle == null, "웨이브를 시작할 수 없다")
	fails += _check("전투 보상" in main.wave_info.text, "안내 문구: " + main.wave_info.text)
	# 막히는 것은 건설·강화·웨이브 시작이다. 연구·시장 구매는 가능하다
	gs.research_points = 1
	fails += _check(main.research("sail") or gs.has_tech("sail"), "연구는 가능하다")
	# 2. 타일을 놓으면 풀린다. 건물을 하나 지으면 설치 모드가 끝난다
	main.pick(0)
	var placed: bool = false
	for y in range(0, 14):
		for x in range(0, 20):
			if not placed and main.place_current(Vector2i(x, y)):
				placed = true
	fails += _check(placed and main.tiles_required == 0 and not main._blocked(), "타일을 놓으면 풀린다")
	main._refresh_hud()
	fails += _check(not main.wave_button.disabled and not main.build_buttons[Balance.HOUSE].disabled, "버튼이 다시 켜진다")
	main.set_build(Balance.HOUSE)
	fails += _check(main.build_id == Balance.HOUSE, "건물 설치 모드 진입")
	var first: Vector2i = Vector2i(-1, -1)
	for c in main.field.cells:
		if main.field.can_build(Balance.HOUSE, c):
			first = c
			break
	fails += _check(main.try_build(first) and main.build_id == 0, "건물을 하나 지으면 설치 모드가 끝난다")
	fails += _check(not main.try_build(first), "모드가 끝났으니 같은 자리에 또 지어지지 않는다")
	# 3. 강화도 타일을 놓은 뒤에만
	main.select_building(first)
	fails += _check(main.upgrade_selected() and main.field.levels[first] == 2, "타일을 놓은 뒤에는 강화 가능")
	# 4. 병영 미리보기: 병사 생산은 무료라 골드와 상관없이 병력이 그대로 보인다
	gs.gold = 100
	main.set_build(Balance.BARRACKS)
	var barracks: Vector2i = Vector2i(-1, -1)
	for c in main.field.cells:
		if main.field.can_build(Balance.BARRACKS, c):
			barracks = c
			break
	main.try_build(barracks) # 병영 30골드
	gs.gold = 0
	main._refresh_hud()
	fails += _check("병영 병력 3명 (경비병 3)" in main.wave_info.text and "모자라" not in main.wave_info.text, "골드가 0이어도 병력 표시: " + main.wave_info.text)
	gs.gold = 40
	gs.food = 7
	main.tiles_required = 0
	main.start_wave()
	fails += _check(main.battle != null and main.battle.soldiers.size() == Balance.HQ_GUARDS + 3 and gs.gold == 40 and gs.food == 7, "전투 시작: 병영 병사 3명, 골드·식량은 그대로 (%d명)" % main.battle.soldiers.size())
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	main.battle.tick(0.1)
	# 5. 전투에서 이기면 다시 타일 강제
	fails += _check(main.battle == null and main.tiles_required == 1 and main._blocked(), "전투 보상: 다시 타일을 놓아야 한다")
	main.start_wave()
	fails += _check(main.battle == null, "보상 타일을 놓기 전에는 다음 웨이브를 시작할 수 없다")
	# 6. 어느 선택지도 들어갈 자리가 없으면 무료로 확장해 자리를 만든다
	var f: Field = main.field
	for y in range(f.bounds.position.y, f.bounds.end.y):
		for x in range(f.bounds.position.x, f.bounds.end.x):
			if not f.cells.has(Vector2i(x, y)):
				var one: Piece = Piece.new()
				one.cells.assign([Vector2i(0, 0)])
				one.terrain.assign([Piece.PLAINS])
				f.place(one, Vector2i(x, y))
	main.tiles_required = 0
	main.start_wave()
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	var full_size: Vector2i = f.bounds.size
	main.battle.tick(0.1)
	var any_fit: bool = false
	for p in main.choices:
		any_fit = any_fit or f.has_room(p)
	fails += _check(f.bounds.size != full_size and any_fit, "자리가 없으면 선택지가 들어갈 때까지 무료 확장 (%s → %s)" % [str(full_size), str(f.bounds.size)])
	# 2라운드마다 4방으로 확장: 3·5웨이브 준비 단계에 넓어지고 4웨이브에는 그대로
	var sz: Vector2i = main.field.bounds.size
	gs.wave = 3
	main._begin_prep()
	fails += _check(main.field.bounds.size == sz + Vector2i(2, 2), "3웨이브 준비 단계에 사방으로 넓어진다 (%s → %s)" % [str(sz), str(main.field.bounds.size)])
	gs.wave = 4
	main._begin_prep()
	fails += _check(main.field.bounds.size == sz + Vector2i(2, 2), "4웨이브에는 넓어지지 않는다")
	print("보상 타일 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

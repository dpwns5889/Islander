extends SceneTree
## 화면 캡처: godot --script tests/screenshot.gd -- <png 경로> [전투 대기 초] [prep]
## menu: 건설 메뉴 목록, npc: 교역 NPC 거래 창. reward를 붙이면 보상 타일을 놓기 전 상태를 캡처한다. hq를 붙이면 10웨이브를 이긴 직후(본부 조각)를 캡처한다. prep을 붙이면 전투를 시작하지 않고 준비 단계(시장·확장 포함)를 캡처한다. 뒤에 research를 더 붙이면 연구 패널도 연다


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.place_current(Vector2i(5, 7))
	if args.size() > 2 and args[2] == "defense": # 방어탑과 12웨이브 구성으로 전투
		main.tiles_required = 0
		var gs2: Node = root.get_node("GameState")
		gs2.gold = 1000
		gs2.researched["archery"] = true
		gs2.wave = 12
		var made: int = 0
		for c in main.field.cells:
			main.set_build(Balance.TOWER if made == 0 else Balance.HOUSE)
			if main.try_build(c):
				made += 1
				if made >= 4:
					break
		main.start_wave()
		await create_timer(float(args[1])).timeout
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	if args.size() > 2 and args[2] == "sea": # 11웨이브부터 나오는 바다 섞인 타일 (카드와 놓은 모습)
		main.tiles_required = 0
		root.get_node("GameState").wave = 11
		var found: int = -1
		for _t in 100:
			main._roll_choices()
			for i in main.choices.size():
				if main.choices[i].has_sea():
					found = i
					break
			if found >= 0:
				break
		main.pick(found)
		var placed: bool = false
		for y in range(2, 12):
			for x in range(10, 18):
				if not placed and main.place_current(Vector2i(x, y)):
					placed = true
		main._roll_choices()
		await create_timer(float(args[1])).timeout
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	if args.size() > 2 and (args[2] == "menu" or args[2] == "npc"): # 건설 메뉴 드롭다운 / 교역 NPC 거래 창
		main.tiles_required = 0
		var gs1: Node = root.get_node("GameState")
		gs1.gold = 300
		gs1.researched["math"] = true
		gs1.researched["commerce"] = true
		if args[2] == "npc":
			main.set_build(Balance.TRADING_POST)
			for c in main.field.cells:
				if main.try_build(c):
					break
			main.set_build(Balance.FISHERY)
			for y in range(main.field.bounds.position.y, main.field.bounds.end.y):
				for x in range(main.field.bounds.position.x, main.field.bounds.end.x):
					if main.try_build(Vector2i(x, y)):
						break
				if main.field.buildings.values().has(Balance.FISHERY):
					break
			gs1.wave = 3
			main.spawn_npc(main.field.trading_post())
			main._toggle_trade()
		else:
			main._toggle_category(0)
		await create_timer(float(args[1])).timeout
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	if args.size() > 2 and args[2] == "reward": # 타일을 놓기 전(강제 상태)을 그대로 캡처한다
		var gs0: Node = root.get_node("GameState")
		gs0.gold = 20
		main.set_build(Balance.BARRACKS)
		await create_timer(float(args[1])).timeout
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	main.tiles_required = 0 # 화면 확인용: 보상 타일 강제를 건너뛴다
	if args.size() > 2 and args[2] == "hq": # 10웨이브를 이긴 직후(본부 조각이 손에 들려 있는 상태)
		root.get_node("GameState").wave = 10
		main.start_wave()
		main.battle._ships_left = 0
		main.battle._pirates_left = 0
		main.battle.tick(0.1)
		await create_timer(float(args[1])).timeout
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	main.pick(0)
	main.place_current(Vector2i(15, 7))
	var f: Field = main.field
	var isl: Dictionary = f.island_map()
	var hq_island: int = isl[f.hq]
	root.get_node("GameState").gold = 1000
	for t in ["math", "archery"]:
		root.get_node("GameState").researched[t] = true
	root.get_node("GameState").research_points = 3
	main.set_build(Balance.PORT)
	for c in isl:
		if isl[c] == hq_island and main.try_build(c):
			break
	main.set_build(Balance.MARKET)
	for c in isl:
		if isl[c] == hq_island and main.try_build(c):
			break
	main.set_build(0)
	main.field.expand_all()
	if args.size() > 2 and args[2] == "prep":
		for id in [Balance.HOUSE, Balance.FARM, Balance.BARRACKS, Balance.SHOOTING_RANGE]:
			main.set_build(id)
			for c in isl:
				if isl[c] == hq_island and main.try_build(c):
					break
		main.set_build(0)
		var shown: Vector2i = main.field.buildings.keys()[main.field.buildings.size() - 1]
		main.field.upgrade(shown)
		main.select_building(shown)
		for c in main.field.buildings:
			if main.field.buildings[c] == Balance.BARRACKS:
				main.select_building(c)
		if args.size() > 3 and args[3] == "research":
			root.get_node("GameState").research_points = 2
			main._toggle_research()
			main.select_tech("astronomy")
	else:
		main.start_wave()
		for c in isl:
			if isl[c] != hq_island:
				main.command_move(c)
				break
	await create_timer(float(args[1]) if args.size() > 1 else 6.0).timeout
	root.get_texture().get_image().save_png(args[0])
	quit()

extends SceneTree
## 화면 캡처: godot --script tests/screenshot.gd -- <png 경로> [대기 초] [모드]
## 모드 start: 개척자·경비병으로 막 시작한 화면(첫 도시 전), menu: 건설 메뉴 목록, npc: 교역 NPC 거래 창, defense: 방어탑과 12웨이브 전투,
## prep: 준비 단계(건물·패널), 뒤에 research를 더 붙이면 연구 패널도 연다. city: 도시 2개·개척자 선택·개척자 생산.
## 모드가 없으면 첫 도시를 세우고 전투를 캡처한다


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var wait: float = float(args[1]) if args.size() > 1 else 6.0
	var mode: String = args[2] if args.size() > 2 else ""
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 캡처 중 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var f: Field = main.field
	var gs: Node = root.get_node("GameState")
	if mode == "start":
		await create_timer(wait).timeout
		root.get_texture().get_image().save_png(args[0])
		quit()
		return
	var start: Vector2i = preload("res://tests/coastal_start.gd").pick(f) # 평원과 바다가 함께 있는 자리
	main.found_start(start)
	gs.gold = 1000
	if mode == "defense": # 방어탑과 12웨이브 구성으로 전투
		gs.researched["archery"] = true
		gs.wave = 12
		_build(main, [Balance.TOWER, Balance.HOUSE, Balance.HOUSE, Balance.HOUSE])
		main.call_wave()
	elif mode == "menu":
		gs.researched["math"] = true
		main._toggle_category(0)
	elif mode == "npc":
		gs.researched["commerce"] = true
		gs.researched["fishing"] = true
		_build(main, [Balance.TRADING_POST])
		if f.trading_post().x >= 0:
			main.spawn_npc(f.trading_post())
			main._toggle_trade()
	elif mode == "city": # 도시 2개(도시 목록), 개척자를 고른 상태, 첫 도시 패널의 개척자 생산
		gs.food = 1000
		var b: Battle = main.battle
		for c: Vector2i in f.cells:
			if f.hqs.size() < 2 and b.islands.get(c, -2) == b.islands.get(f.hq, -1) and f.found_block(c) == "" and maxi(absi(c.x - f.hq.x), absi(c.y - f.hq.y)) >= 6:
				f.found_city(c)
		var settler: Unit = b._spawn_unit(Balance.U_SETTLER, f.hq)
		main.select_settler(settler)
		main.select_building(f.hq)
		main.toggle_settler()
	elif mode == "prep":
		for t in ["math", "archery"]:
			gs.researched[t] = true
		gs.research_points = 2
		_build(main, [Balance.HOUSE, Balance.FARM, Balance.BARRACKS, Balance.PORT])
		for c in f.buildings:
			if f.buildings[c] == Balance.BARRACKS:
				f.upgrade(c)
				main.select_building(c)
		if args.size() > 3 and args[3] == "research":
			main._toggle_research()
			main.select_tech("astronomy")
	else:
		_build(main, [Balance.BARRACKS, Balance.HOUSE])
		main.call_wave()
	await create_timer(wait).timeout
	root.get_texture().get_image().save_png(args[0])
	quit()


## 첫 도시 영역 안에 건물을 차례로 짓는다
func _build(main: Node, ids: Array) -> void:
	var f: Field = main.field
	for id: int in ids:
		main.set_build(id)
		for c: Vector2i in f.territory_of[f.hq]:
			if main.try_build(c):
				break
	main.set_build(0)

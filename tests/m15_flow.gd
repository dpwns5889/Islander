extends SceneTree
## 교역 NPC·건설 메뉴 화면 흐름 점검: godot --headless --script tests/m15_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	gs.gold = 1000
	gs.researched["math"] = true
	gs.researched["commerce"] = true
	# 1. 건설 메뉴: 카테고리를 누르면 목록이 열리고, 건물을 고르면 닫힌다
	fails += _check(main.category_buttons.size() == 4 and not main.dropdown_panel.visible, "카테고리 버튼 4개, 목록은 닫혀 있다")
	main._toggle_category(2) # 상업
	fails += _check(main.open_category == 2 and main.dropdown_panel.visible and main.dropdown_lists[2].visible and not main.dropdown_lists[0].visible, "상업 목록이 열린다")
	fails += _check("교역소" in main.build_buttons[Balance.TRADING_POST].text and "시장" in main.build_buttons[Balance.MARKET].text, "목록에 시장·교역소")
	main._toggle_category(2)
	fails += _check(main.open_category == -1 and not main.dropdown_panel.visible, "다시 누르면 닫힌다")
	main._toggle_category(0)
	main._toggle_category(1)
	fails += _check(main.open_category == 1 and not main.dropdown_lists[0].visible, "다른 카테고리로 바꿀 수 있다")
	main._toggle_category(2)
	main._on_build_button(Balance.TRADING_POST)
	fails += _check(main.build_id == Balance.TRADING_POST and main.open_category == -1 and not main.dropdown_panel.visible, "건물을 고르면 설치 모드, 목록은 닫힌다")
	var post: Vector2i = Vector2i(-1, -1)
	var bb: Rect2i = main.field.bounds # 교역소는 물 위에 짓는다
	for y in range(bb.position.y, bb.end.y):
		for x in range(bb.position.x, bb.end.x):
			if post.x < 0 and main.try_build(Vector2i(x, y)):
				post = Vector2i(x, y)
	fails += _check(post.x >= 0 and main.field.trading_post() == post and main.build_id == 0, "교역소 설치, 설치 모드 종료")
	main.set_build(Balance.TRADING_POST)
	fails += _check(not main._build_ok(Vector2i(post.x + 1, post.y)), "교역소는 두 번째를 지을 수 없다")
	main.set_build(0)
	# 2. 교역소를 지은 다음 라운드에 첫 방문, 이후 3라운드마다 (1웨이브에 지었으니 2, 5, 8웨이브)
	fails += _check(not main.npc_present and not main.trade_button.visible and main.npc_next_wave == 2, "처음에는 NPC가 없고 2웨이브에 올 예정")
	_win(main) # 1웨이브 → 2웨이브 준비
	fails += _check(gs.wave == 2 and main.npc_present and main.trade_button.visible and main.npc_node != null, "2웨이브(설치 다음 라운드): NPC 방문, 버튼 표시")
	fails += _check(main.trade_offers.size() == 3, "교역소 레벨 1: 거래 3개")
	fails += _check(main.npc_next_wave == 5, "다음 방문은 3라운드 뒤인 5웨이브")
	fails += _check(main._blocked(), "보상 타일을 놓기 전이어도")
	# 3. 거래 창을 닫아도 버튼으로 다시 열 수 있다
	main._toggle_trade()
	fails += _check(main.trade_panel.visible, "거래 창이 열린다")
	main._toggle_trade()
	fails += _check(not main.trade_panel.visible and main.trade_button.visible and main.npc_present, "닫아도 버튼과 NPC는 남는다")
	main._toggle_trade()
	fails += _check(main.trade_panel.visible, "다시 열 수 있다")
	# 4. 거래: 제안된 것마다 한 번씩만
	for offer: Dictionary in main.trade_offers.duplicate():
		var id: String = offer["id"]
		gs.gold = 1000
		gs.food = 100
		var g0: int = gs.gold
		var f0: int = gs.food
		var rp0: int = gs.research_points
		var pieces0: int = main.pieces_left
		fails += _check(main.do_trade(id), "거래 성공: " + id)
		fails += _check(not main.do_trade(id), "같은 거래는 한 번뿐: " + id)
		if id == "gold_rp":
			fails += _check(gs.gold == g0 - 60 and gs.research_points == rp0 + 1, "골드 60 → 연구포인트 1")
		elif id == "gold_piece":
			fails += _check(gs.gold == g0 - 40 and main.pieces_left == pieces0 + 1, "골드 40 → 조각 +1")
		elif id == "gold_guards":
			fails += _check(gs.gold == g0 - 30 and gs.extra_guards == 2, "골드 30 → 수비병 +2")
			gs.extra_guards = 0
	# 5. 웨이브를 시작하면 NPC가 떠난다
	main.tiles_required = 0
	main.start_wave()
	fails += _check(main.battle != null and not main.npc_present and not main.trade_button.visible and not main.trade_panel.visible and main.npc_node == null, "전투가 시작되면 NPC가 떠난다")
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	main.battle.tick(0.1)
	fails += _check(gs.wave == 3 and not main.npc_present, "3웨이브: NPC 없음")
	# 6. 교역소 레벨 2도 거래 3개, 5웨이브에 다시 방문
	main.tiles_required = 0
	gs.gold = 1000
	main.select_building(post)
	fails += _check(main.upgrade_selected() and main.field.levels[post] == 2, "교역소 레벨 2")
	_win(main) # 3 → 4
	fails += _check(gs.wave == 4 and not main.npc_present, "4웨이브: NPC 없음")
	_win(main) # 4 → 5
	fails += _check(gs.wave == 5 and main.npc_present and main.trade_offers.size() == 3 and main.npc_next_wave == 8, "5웨이브: NPC 다시 방문, 거래 3개, 다음은 8웨이브")
	# 7. 교역소가 없으면 방문하지 않는다
	main.field.damage(post, 9999.0)
	fails += _check(main.field.trading_post() == Vector2i(-1, -1), "교역소 파괴")
	_win(main) # 5 → 6
	_win(main) # 6 → 7
	_win(main) # 7 → 8
	fails += _check(gs.wave == 8 and not main.npc_present and main.npc_next_wave == -1, "교역소가 없으면 8웨이브에도 NPC가 오지 않는다")
	print("교역 NPC 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _win(main: Node) -> void:
	main.tiles_required = 0
	main.start_wave()
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	main.battle.tick(0.1)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

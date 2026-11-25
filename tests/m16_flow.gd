extends SceneTree
## 교역소 바다 닫힘 처리·바다 타일 후보 화면 점검: godot --headless --script tests/m16_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0
	gs.gold = 1000
	gs.researched["math"] = true
	gs.researched["commerce"] = true
	# 교역소를 열린 바다 옆에 짓는다
	main.set_build(Balance.TRADING_POST)
	var post: Vector2i = Vector2i(-1, -1)
	var bb: Rect2i = main.field.bounds # 교역소는 물 위에 짓는다
	for y in range(bb.position.y, bb.end.y):
		for x in range(bb.position.x, bb.end.x):
			if post.x < 0 and main.try_build(Vector2i(x, y)):
				post = Vector2i(x, y)
	fails += _check(post.x >= 0 and main.npc_next_wave == 2, "교역소 설치, 2웨이브에 방문 예정")
	# 미리보기 경고: 교역소의 열린 이웃 바다를 전부 막는 타일은 경고
	var open_neighbors: Array[Vector2i] = []
	for d in Field.DIRS:
		if main.field.terrain_at(post + d) == Field.SEA:
			open_neighbors.append(post + d)
	var plug: Piece = Piece.new()
	for n in open_neighbors:
		plug.cells.append(n - open_neighbors[0])
		plug.terrain.append(Piece.PLAINS)
	main.current = plug
	main._update_warn(open_neighbors[0], main.field.can_place(plug, open_neighbors[0]))
	fails += _check(main._warn, "교역소 바다를 막는 타일 위치에서 경고가 켜진다")
	main._refresh_hud()
	fails += _check("교역소가 바다와 끊겨" in main.status.text, "경고 문구: " + main.status.text)
	main._update_warn(Vector2i(17, 12), true)
	fails += _check(not main._warn, "다른 위치에서는 경고가 꺼진다")
	main.current = null
	main._rebuild_ghost()
	# 실제로 막으면 2웨이브에 NPC가 오지 못한다
	main.field.place(plug, open_neighbors[0])
	fails += _check(not main.field.is_post_open(post), "바다가 닫혔다")
	main.select_building(post)
	main._refresh_hud()
	fails += _check("물가가 막혀" in main.upgrade_effect.text, "교역소 패널 경고: " + main.upgrade_effect.text)
	main.tiles_required = 0
	main.start_wave()
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	main.battle.tick(0.1)
	fails += _check(gs.wave == 2 and not main.npc_present and not main.trade_button.visible, "닫힌 교역소에는 NPC가 오지 못한다")
	fails += _check("오지 못했습니다" in main._note, "안내 문구: " + main._note)
	fails += _check(main.npc_next_wave == 5, "일정은 3라운드 뒤(5웨이브)로 넘어간다")
	fails += _check(main.field.trading_post() == post, "교역소는 그대로 남는다")
	# 바다 칸 타일로 막힌 땅을 깎아 되돌리면 NPC가 다시 온다
	var carve: Piece = Piece.new()
	carve.cells.assign([Vector2i(0, 0)])
	carve.terrain.assign([Piece.SEA])
	main.current = carve
	main.pieces_left = 1
	main._update_warn(open_neighbors[0], main.field.can_place(carve, open_neighbors[0]))
	fails += _check(main._carve_n == 1 and not main._warn, "깎는 칸은 땅 1칸이 물로 바뀐다고 안내, 교역소는 경고 없음")
	main._refresh_hud()
	fails += _check("땅 1칸이 물로 바뀝니다" in main.status.text, "안내 문구: " + main.status.text)
	fails += _check(main.place_current(open_neighbors[0]), "바다 칸을 땅 위에 놓을 수 있다")
	fails += _check(main.field.is_post_open(post), "교역소가 다시 열린 바다와 맞닿는다")
	for _i in 3: # 2 → 5웨이브
		main.tiles_required = 0
		main.start_wave()
		main.battle._ships_left = 0
		main.battle._pirates_left = 0
		main.battle.tick(0.1)
	fails += _check(gs.wave == 5 and main.npc_present, "다시 열린 교역소에는 5웨이브에 NPC가 온다")
	# 10라운드 이후에만 바다 섞인 타일이 후보에 나온다
	var saw_early: bool = false
	gs.wave = 10
	for _i in 80:
		main._roll_choices()
		for c in main.choices:
			saw_early = saw_early or c.has_sea()
	fails += _check(not saw_early, "10웨이브 준비 단계까지는 바다 섞인 타일이 없다")
	var saw_late: bool = false
	gs.wave = 11
	for _i in 80:
		main._roll_choices()
		for c in main.choices:
			saw_late = saw_late or c.has_sea()
	fails += _check(saw_late, "11웨이브부터는 바다 섞인 타일이 후보에 나온다")
	print("교역소 닫힘 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

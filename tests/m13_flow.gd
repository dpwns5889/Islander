extends SceneTree
## M10 화면 흐름 점검: godot --headless --script tests/m13_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	fails += _check(not main.pending_hq and not main.hq_card.visible, "처음에는 본부 조각이 없다")
	# 9웨이브를 이겨도 본부 조각은 없다
	gs.wave = 9
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	main.start_wave()
	main.battle._ships_left = 0 # 적 없이 바로 승리
	main.battle._pirates_left = 0
	main.battle.tick(0.1)
	fails += _check(main.battle == null and gs.wave == 10 and not main.pending_hq, "9웨이브 뒤에는 본부 조각이 없다")
	# 10웨이브(보스)를 이기면 본부 조각이 나오고, 놓기 전에는 웨이브를 시작할 수 없다
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	main.start_wave()
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	main.battle.tick(0.1)
	fails += _check(main.battle == null and gs.wave == 11, "10웨이브 승리")
	fails += _check(main.pending_hq and main.hq_card.visible and main.placing_hq and main.current != null, "본부 조각이 나와 손에 들려 있다")
	fails += _check(main.wave_button.disabled, "본부 조각을 놓기 전에는 웨이브 시작 버튼이 비활성화")
	fails += _check("본부 조각을 먼저 놓으세요" in main.wave_info.text, "예고 줄 안내: " + main.wave_info.text)
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	main.start_wave()
	fails += _check(main.battle == null, "버튼을 못 눌러도 코드로 시작할 수 없다")
	# 일반 조각을 고르고 다시 본부 조각으로 돌아올 수 있다. 회전해도 본부 조각이다
	main.pick(0)
	fails += _check(not main.placing_hq, "일반 조각을 고르면 본부 조각 상태가 풀린다")
	main.select_hq()
	main._rotate()
	fails += _check(main.placing_hq, "회전해도 본부 조각")
	# 본부 조각을 놓는다: 일반 조각 배치 횟수는 줄지 않는다
	var before_pieces: int = main.pieces_left
	var placed: bool = false
	for y in range(2, 12):
		for x in range(12, 18):
			if not placed and main.place_current(Vector2i(x, y)):
				placed = true
	fails += _check(placed and main.field.hqs.size() == 2 and not main.pending_hq, "본부 조각을 놓으면 본부가 2개")
	fails += _check(main.pieces_left == before_pieces, "일반 조각 배치 횟수는 그대로")
	main.tiles_required = 0
	main._refresh_hud()
	fails += _check(not main.wave_button.disabled and not main.hq_card.visible, "놓은 뒤에는 웨이브를 시작할 수 있다")
	# 자리가 없으면 무료로 확장한다
	var f: Field = main.field
	for y in range(f.bounds.position.y, f.bounds.end.y):
		for x in range(f.bounds.position.x, f.bounds.end.x):
			if not f.cells.has(Vector2i(x, y)):
				var one: Piece = Piece.new()
				one.cells.assign([Vector2i(0, 0)])
				one.terrain.assign([Piece.PLAINS])
				f.place(one, Vector2i(x, y))
	var size_before: Vector2i = f.bounds.size
	gs.wave = 20
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	main.start_wave()
	main.battle._ships_left = 0
	main.battle._pirates_left = 0
	main.battle.tick(0.1)
	fails += _check(main.pending_hq and f.bounds.size != size_before and f.has_room(main.hq_piece), "꽉 찬 필드는 자리가 생길 때까지 확장된다 (%s → %s)" % [str(size_before), str(f.bounds.size)])
	print("M10 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

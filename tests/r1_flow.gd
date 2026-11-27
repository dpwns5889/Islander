extends SceneTree
## R1 화면 흐름 점검: 시작 위치 고르기 → 첫 도시, 카메라(좌클릭 드래그 회전·짧은 클릭·휠·가장자리), 경비병 2명·도시 공격 없음
## godot --headless --script tests/r1_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false
	root.add_child(main)
	await process_frame
	var f: Field = main.field
	fails += _check(not main.started and f.hqs.is_empty() and f.cells.size() > 1000, "시작 전: 도시 없음, 맵이 생성됨 (땅 %d칸)" % f.cells.size())
	fails += _check(main.top_panel.visible and not main.res_bar.visible and not main.build_panel.visible and not main.wave_button.visible, "시작 전: 안내만 보이고 자원·건설·웨이브 시작은 숨김")
	fails += _check(main.status.text.contains("첫 도시"), "시작 안내 문구")
	var bad: Vector2i = Vector2i(0, 0)
	fails += _check(not main.found_start(bad) and not main.started, "바다에는 세울 수 없다")
	var start: Vector2i = f.start_cells().keys()[0]
	fails += _check(main.found_start(start) and main.started and f.hqs.has(start), "평원을 고르면 첫 도시가 선다")
	fails += _check(main.res_bar.visible and main.build_panel.visible and main.wave_button.visible and not main.wave_button.disabled, "도시를 세우면 자원·건설·웨이브 시작이 보인다")
	fails += _check(not main.found_start(f.start_cells().keys()[-1]), "두 번째 시작 자리는 고를 수 없다")
	fails += _check(main._pan.distance_to(f.cell_to_world(start) - f.center_world()) < 0.01 and is_equal_approx(main._zoom, 1.0), "카메라가 첫 도시를 비춘다")
	# 카메라: 짧은 좌클릭은 회전하지 않고, 끌면 회전한다
	var yaw0: float = main._yaw
	_mouse(main, true, Vector2(300, 300))
	_motion(main, Vector2(302, 300), Vector2(2, 0))
	_mouse(main, false, Vector2(302, 300))
	fails += _check(is_equal_approx(main._yaw, yaw0), "짧은 좌클릭은 회전하지 않는다")
	_mouse(main, true, Vector2(300, 300))
	_motion(main, Vector2(340, 300), Vector2(40, 0))
	_motion(main, Vector2(380, 300), Vector2(40, 0))
	_mouse(main, false, Vector2(380, 300))
	fails += _check(not is_equal_approx(main._yaw, yaw0), "좌클릭 드래그는 회전한다 (%.1f → %.1f)" % [yaw0, main._yaw])
	for i in 30:
		main._wheel_zoom(1.0 / Balance.ZOOM_STEP)
	fails += _check(is_equal_approx(main._zoom, Balance.ZOOM_MAX), "휠 축소는 %.1f배까지" % Balance.ZOOM_MAX)
	var pan0: Vector3 = main._pan
	main._pan_camera(Vector2(-50, 0))
	fails += _check(main._pan != pan0, "카메라 이동")
	# 경비병 2명, 도시는 공격하지 않는다, 우클릭 이동
	var b: Battle = main.battle
	fails += _check(b != null and b.soldiers.size() == Balance.HQ_GUARDS, "첫 도시를 세우면 경비병 %d명" % Balance.HQ_GUARDS)
	var pirate: Unit = b._add_unit(Balance.U_PIRATE, f.cell_to_world(start) + Vector3(1.0, 0.0, 0.0), 1.0)
	var hp0: float = pirate.hp
	b._towers_turn(1.0)
	fails += _check(is_equal_approx(pirate.hp, hp0), "도시는 해적을 쏘지 않는다")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	var walk: Vector2i = start
	for c: Vector2i in f.territory_of[start]:
		if f.is_walkable(c) and c != start:
			walk = c
	fails += _check(main.command_move(walk) and b.soldiers[0].order == walk, "전투 중 이동 명령")
	print("R1 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _mouse(main: Node, pressed: bool, pos: Vector2) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	main._unhandled_input(e)


func _motion(main: Node, pos: Vector2, rel: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	main._unhandled_input(e)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

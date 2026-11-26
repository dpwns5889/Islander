extends SceneTree
## M30 화면 흐름 점검: 전투 중 카메라 확대·회전과 전투 뒤 복귀 godot --headless --script tests/m30_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var pv: PixelView = main.pixel
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0
	_wheel(main, MOUSE_BUTTON_WHEEL_UP)
	var prep_size: float = pv._size
	_drag(main, Vector2(100, 100), MOUSE_BUTTON_MASK_RIGHT)
	fails += _check(is_equal_approx(pv._yaw, 0.0) and is_equal_approx(pv._pitch, 90.0), "준비 단계에서는 돌지 않는다")
	main.start_wave()
	await create_timer(1.0).timeout
	var base_size: float = pv._size
	fails += _check(is_equal_approx(pv._pitch, Balance.COMBAT_PITCH) and is_equal_approx(pv._yaw, 0.0), "전투는 기본 시점에서 시작")
	_wheel(main, MOUSE_BUTTON_WHEEL_UP)
	fails += _check(is_equal_approx(pv._size, base_size * Balance.ZOOM_STEP), "전투 중 휠 확대")
	for _i in 40:
		_wheel(main, MOUSE_BUTTON_WHEEL_DOWN)
	fails += _check(is_equal_approx(pv._size, base_size * Balance.ZOOM_MAX), "축소 한계")
	_drag(main, Vector2(-100, 0), 0)
	fails += _check(is_equal_approx(pv._yaw, 0.0), "우클릭 없이 움직이면 돌지 않는다")
	_drag(main, Vector2(-100, 0), MOUSE_BUTTON_MASK_RIGHT)
	fails += _check(is_equal_approx(pv._yaw, 100.0 * Balance.CAM_ROTATE_SENS), "가로 드래그: 좌우 회전")
	_drag(main, Vector2(0, 1000), MOUSE_BUTTON_MASK_RIGHT)
	fails += _check(is_equal_approx(pv._pitch, Balance.CAM_PITCH_MAX), "기울기 위쪽 한계")
	_drag(main, Vector2(0, -1000), MOUSE_BUTTON_MASK_RIGHT)
	fails += _check(is_equal_approx(pv._pitch, Balance.CAM_PITCH_MIN), "기울기 아래쪽 한계")
	# 돌린 상태에서도 화면 가운데는 필드 중심을 가리킨다
	await process_frame
	var ray: Array[Vector3] = pv.ray(root.get_visible_rect().size / 2.0)
	var center: Vector3 = main.field.center_world()
	var hit: Vector3 = Plane(Vector3.UP, center.y).intersects_ray(ray[0], ray[1])
	fails += _check(hit.distance_to(center) < 0.5, "회전해도 화면 중앙은 필드 중심 (오차 %.2f)" % hit.distance_to(center))
	for _i in 3000:
		if main.battle == null:
			break
		main.battle.tick(0.1)
	await create_timer(1.0).timeout
	fails += _check(main.battle == null and is_equal_approx(pv._pitch, 90.0) and is_equal_approx(pv._yaw, 0.0), "전투 뒤 90도, 회전 0")
	fails += _check(is_equal_approx(pv._size, prep_size), "전투 뒤 준비 단계 배율 복귀")
	main.tiles_required = 0
	main.start_wave()
	await create_timer(1.0).timeout
	fails += _check(is_equal_approx(pv._size, base_size) and is_equal_approx(pv._yaw, 0.0) and is_equal_approx(pv._pitch, Balance.COMBAT_PITCH), "다음 전투도 기본 시점")
	print("M30 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _wheel(main: Node, button: MouseButton) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	main._unhandled_input(e)


func _drag(main: Node, motion: Vector2, mask: int) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.relative = motion
	e.button_mask = mask
	main._unhandled_input(e)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

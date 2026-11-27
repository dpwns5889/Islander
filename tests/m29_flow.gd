extends SceneTree
## M29 화면 흐름 점검: P키 도트 화면 켜고 끄기 godot --headless --script tests/m29_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field)) # 배율 1에서 본다 (시작 화면은 3배라 도트 하나가 크다)
	var pv: PixelView = main.pixel
	fails += _check(pv.enabled and pv._sub.size.y == Balance.PIXEL_HEIGHT + 2, "시작은 도트 화면")
	_press(main, false)
	await process_frame
	fails += _check(not pv.enabled and not pv._post.visible and pv._sub.size.y == root.size.y + 2, "P: 원래 해상도, 외곽선 끔")
	var center: Vector2 = root.get_visible_rect().size / 2.0
	var off_ray: Vector3 = pv.ray(center)[0]
	_press(main, true)
	fails += _check(not pv.enabled, "키 반복 입력은 무시")
	_press(main, false)
	await process_frame
	fails += _check(pv.enabled and pv._post.visible and pv._sub.size.y == Balance.PIXEL_HEIGHT + 2, "P 다시: 도트 화면")
	fails += _check(off_ray.distance_to(pv.ray(center)[0]) < 0.2, "전환해도 마우스가 가리키는 곳은 같다")
	print("M29 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _press(main: Node, echo: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = KEY_P
	e.pressed = true
	e.echo = echo
	main._unhandled_input(e)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

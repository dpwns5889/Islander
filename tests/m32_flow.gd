extends SceneTree
## M32 화면 흐름 점검(건물 패널 위치): godot --headless --script tests/m32_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.place_current(Vector2i(7, 7))
	main.tiles_required = 0
	var f: Field = main.field
	var hq: Vector2i = f.hq
	main.select_building(hq)
	await process_frame
	await process_frame
	var panel: Control = main.upgrade_panel
	var at: Vector2 = main.pixel.unproject(f.cell_to_world(hq) + Vector3(0, Field.BLOCK_H, 0))
	var r: Rect2 = panel.get_global_rect()
	var view: Rect2 = root.get_visible_rect()
	fails += _check(panel.visible and r.end.y < at.y and absf(r.get_center().x - at.x) < 1.0, "패널은 건물 바로 위 가운데 (패널 %s, 건물 %s)" % [r, at])
	var ray: Array[Vector3] = main.pixel.ray(at)
	var hit: Variant = Plane(Vector3.UP, Field.BLOCK_H).intersects_ray(ray[0], ray[1])
	fails += _check(hit != null and f.world_to_cell(hit as Vector3) == hq, "화면 좌표를 되돌리면 같은 칸")
	for _i in 20: # 확대해서 건물을 화면 가장자리 밖으로 밀어도 패널은 화면 안
		main._wheel_zoom(Balance.ZOOM_STEP)
	await process_frame
	await process_frame
	fails += _check(view.encloses(panel.get_global_rect()), "확대해도 패널은 화면 안 (%s)" % panel.get_global_rect())
	print("M32 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

extends SceneTree
## 격자 렌더 점검: 모든 배율에서 줄이 빠지거나 두 겹이 되지 않는지 도트 화면 원본을 훑어 본다 (기획서 7.2)
## 실제 렌더가 필요해 창을 띄워 실행한다: godot --path . --script tests/grid_render.gd


func _initialize() -> void:
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.current = null
	main._rebuild_ghost()
	var bad: int = 0
	var checked: int = 0
	for grown in [0, 3]:
		for _i in grown:
			main.field.expand_all()
		for on in [true, false]:
			main.pixel.set_enabled(on)
			var z: float = 0.4
			while z <= 1.3001:
				main._zoom = z
				main._update_camera()
				for _f in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				var img: Image = main.pixel._sub.get_texture().get_image()
				var width: int = 1 if on else 2
				var cell_px: float = (img.get_height() - 2) / main.pixel._size
				for vertical in [true, false]:
					var err: String = _scan(main, img, vertical, width, cell_px)
					checked += 1
					if err != "":
						bad += 1
						if bad <= 12:
							print("grown=", grown, " dot=", on, " zoom=", snappedf(z, 0.001), " vertical=", vertical, " ", err)
				z += 0.0173 if on else 0.0719
	print("격자 점검: ", checked, "건 중 이상 ", bad, "건")
	quit(bad)


## 필드 안 바다를 가로지르는 한 줄에서 밝은 구간의 굵기와 간격을 본다
func _scan(main: Node, img: Image, vertical: bool, width: int, cell_px: float) -> String:
	var b: Rect2i = main.field.bounds
	var a: Vector3 = main.field.cell_to_world(b.position) - Vector3(0.5, -0.02, 0.5)
	# 확대하면 가장자리가 화면 밖이므로 필드 가운데 칸을 지나는 줄을 본다
	var from: Vector3 = a + (Vector3(0.0, 0.0, floorf(b.size.y / 2.0) + 0.37) if vertical else Vector3(floorf(b.size.x / 2.0) + 0.37, 0.0, 0.0))
	var to: Vector3 = from + (Vector3(b.size.x, 0, 0) if vertical else Vector3(0, 0, b.size.y))
	var p0: Vector2 = main.pixel.camera.unproject_position(from)
	var p1: Vector2 = main.pixel.camera.unproject_position(to)
	var runs: Array[Vector2i] = []
	var start: int = -1
	var lo: int = maxi(0, int(p0.x if vertical else p0.y) + 3)
	var hi: int = mini((img.get_width() if vertical else img.get_height()) - 1, int(p1.x if vertical else p1.y) - 3)
	var values: Array[float] = []
	for i in range(lo, hi):
		var c: Color = img.get_pixel(i, int(p0.y)) if vertical else img.get_pixel(int(p0.x), i)
		values.append(c.r)
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var sea: float = sorted[sorted.size() / 2]
	for i in values.size():
		var lit: bool = values[i] > sea + 0.08
		if lit and start < 0:
			start = i
		elif not lit and start >= 0:
			runs.append(Vector2i(start, i - start))
			start = -1
	for i in runs.size():
		if runs[i].y != width:
			return "굵기 %d (기대 %d)" % [runs[i].y, width]
		if i > 0 and absf(runs[i].x - runs[i - 1].x - cell_px) > 1.01:
			return "간격 %d (칸 %.2f픽셀)" % [runs[i].x - runs[i - 1].x, cell_px]
	var expected: int = int(values.size() / cell_px)
	return "" if runs.size() >= expected else "줄 수 %d < %d" % [runs.size(), expected]

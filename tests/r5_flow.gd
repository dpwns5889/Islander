extends SceneTree
## R5 화면 흐름 점검: 판이 시작될 때부터 안개와 유적지 12곳(시작 칸 4칸 밖) → 첫 도시를 세우면 도시 영역이 밝다,
## 유닛이 움직이면 주변 4칸을 밝히고 유적지를 밟으면 보상, 안개 속 해적선은 숨김, 예고의 목표 도시 방향, 미니맵(클릭하면 카메라)
## godot --headless --script tests/r5_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	var f: Field = main.field
	var s0: Vector2i = f.settler_start()
	fails += _check(f.fog_on and f.is_explored(s0) and not f.is_explored(Vector2i(0, 0)) and main.minimap_panel.visible, "판이 시작될 때부터 안개, 개척자 주변만 밝다")
	var far_ok: bool = f.ruins.size() == Balance.RUIN_COUNT
	for c: Vector2i in f.ruins:
		far_ok = far_ok and Vector2(c - s0).length() > Balance.VISION_RANGE
	fails += _check(far_ok, "유적지 12곳은 시작 칸에서 4칸 밖")
	var start: Vector2i = preload("res://tests/coastal_start.gd").pick(f)
	main.found_start(start)
	var b: Battle = main.battle
	fails += _check(f.fog_on and f.is_explored(start) and not f.is_explored(Vector2i(0, 0)), "첫 도시를 세우면 안개가 덮이고 도시 영역은 밝다")
	fails += _check(f.ruins.size() == Balance.RUIN_COUNT, "유적지 12곳 (%d)" % f.ruins.size())
	var hidden: bool = true
	for c: Vector2i in f.ruins:
		hidden = hidden and (f.ruins[c] as Node3D).visible == f.is_explored(c)
	fails += _check(hidden, "안개 속 유적지는 숨긴다")
	# 유닛 시야: 경비병 한 명을 먼 땅으로 옮기면 주변 4칸이 밝아진다
	var guard: Unit = b.squad_units(1)[0]
	var far: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in f.cells:
		if not f.is_explored(c) and not f.ruins.has(c):
			far = c
			break
	guard.position = f.cell_to_world(far)
	main.advance(0.25)
	fails += _check(f.is_explored(far) and f.is_explored(far + Vector2i(0, 4)) == f.bounds.has_point(far + Vector2i(0, 4)), "유닛 주변 4칸을 밝힌다")
	# 유적지 보상
	var ruin: Vector2i = f.ruins.keys()[0]
	var gold0: int = gs.gold
	var rp0: int = gs.research_points
	guard.position = f.cell_to_world(ruin)
	main.advance(0.1)
	var gain: int = gs.gold - gold0
	fails += _check(not f.ruins.has(ruin) and ((gain >= 60 and gain <= 100) or gs.research_points == rp0 + 1) and "유적지 발견" in main._note, "유적지를 밟으면 골드 60~100 또는 연구포인트 +1 (%s)" % main._note)
	# 예고: 목표 도시 방향
	main._refresh_hud()
	fails += _check("1번 도시 방향" in main.wave_info.text, "예고에 목표 도시 방향 (%s)" % main.wave_info.text)
	# 안개 속 해적선은 숨긴다
	main.call_wave()
	for _i in 30:
		b.tick(0.1)
	main._process(0.0)
	var ok_vis: bool = not b.ships.is_empty()
	for s: Unit in b.ships:
		ok_vis = ok_vis and s.visible == f.is_explored(f.world_to_cell(s.position))
	fails += _check(ok_vis, "해적선은 밝힌 곳에서만 보인다 (%d척)" % b.ships.size())
	var edge: Vector2i = b._edge_near(start)
	fails += _check(not b.ships.is_empty() and b.target_city == start, "해적선은 목표 도시(첫 도시) 쪽에서 나온다 (가장자리 %s)" % edge)
	# 미니맵
	main._refresh_hud()
	fails += _check(main.minimap_panel.visible and main.minimap.texture != null and main.minimap.texture.get_size() == Vector2(f.bounds.size), "미니맵이 보인다")
	var px: Color = main._mini_img.get_pixelv(start + Vector2i(1, 1) - f.bounds.position) # 도시 칸 자체는 경비병 점이 덮는다
	fails += _check(px.to_rgba32() == Color.WHITE.to_rgba32(), "미니맵에 도시가 흰색 3x3으로 찍힌다")
	fails += _check(main._mini_img.get_pixelv(Vector2i.ZERO).to_rgba32() == Balance.FOG_COLOR.to_rgba32(), "밝히지 않은 곳은 안개 색")
	main.focus_minimap(Vector2(0.5, 0.25))
	var want: Vector3 = f.cell_to_world(f.bounds.position + Vector2i(f.bounds.size.x / 2, f.bounds.size.y / 4)) - f.center_world()
	fails += _check(main._pan.distance_to(want) < 0.01, "미니맵을 누른 곳으로 카메라가 간다")
	print("R5 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

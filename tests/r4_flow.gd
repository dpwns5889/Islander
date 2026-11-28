extends SceneTree
## R4 화면 흐름 점검: 도시 패널의 개척자 생산 → 개척자 고르기(분대 선택과 둘 중 하나) → 우클릭 이동 → "도시 세우기",
## 조건이 안 맞으면 비활성과 이유, 도시 목록 버튼(누르면 카메라), 도시가 늘면 분대 상한
## godot --headless --script tests/r4_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	var f: Field = main.field
	main.found_start(preload("res://tests/coastal_start.gd").pick(f))
	var b: Battle = main.battle
	var hq: Vector2i = f.hq
	gs.gold = 1000
	gs.food = 1000
	# 도시 패널: 개척자 생산
	main.select_building(hq)
	main._refresh_hud()
	fails += _check(main.settler_button.visible and "개척자 생산 30G · 식량 30" in main.settler_button.text and not main.settler_button.disabled, "도시 패널: 개척자 생산 (%s)" % main.settler_button.text)
	fails += _check(main.toggle_settler() and gs.gold == 970 and b.settler_jobs.has(hq), "개척자 생산 시작")
	main._refresh_hud()
	fails += _check("생산 중" in main.settler_button.text and "개척자" in main.city_list.get_child(0).text, "생산 중 표시: 패널과 도시 목록")
	for _i in 305:
		b.tick(0.1)
	var s: Unit = b.settlers()[0] if not b.settlers().is_empty() else null
	fails += _check(s != null, "30초 뒤 개척자가 도시 옆에 나온다")
	if s == null:
		quit(fails + 1)
		return
	# 고르기: 개척자와 분대는 둘 중 하나
	main.select_squad(1)
	fails += _check(main._settler_at(f.world_to_cell(s.position)) == s, "개척자가 선 칸을 누르면 그 개척자")
	main.select_settler(s)
	main._refresh_hud()
	fails += _check(main.selected_settler == s and main.selected_squads.is_empty() and main.found_button.visible, "개척자를 고르면 분대 선택이 풀리고 '도시 세우기'가 보인다")
	fails += _check(main.found_button.disabled and "건물" in main.found_button.tooltip_text and not main.found_with_settler(), "도시 칸에서는 못 세운다: 비활성과 이유 (%s)" % main.found_button.tooltip_text)
	main.select_squad(1)
	fails += _check(main.selected_settler == null and main.selected_squads == [1], "숫자키로 분대를 고르면 개척자 선택이 풀린다")
	main.select_settler(s)
	# 4칸 이상 떨어진 같은 섬의 빈 평원으로 보낸다
	var dest: Vector2i = Vector2i(-1, -1)
	var best: int = 999
	for c: Vector2i in f.cells:
		if b.islands.get(c, -2) == b.islands.get(hq, -1) and f.found_block(c) == "" and f.is_walkable(c):
			var d: int = maxi(absi(c.x - hq.x), absi(c.y - hq.y))
			if d < best:
				best = d
				dest = c
	fails += _check(dest.x >= 0 and best == Balance.CITY_MIN_DIST, "정착할 수 있는 가장 가까운 칸은 4칸 거리 (%d)" % best)
	var guard_order: Vector2i = b.squad_units(1)[0].order
	fails += _check(main.command_move(dest) and s.order == dest and b.squad_units(1)[0].order == guard_order, "우클릭은 고른 개척자만 움직인다")
	for _i in 1200:
		b.tick(0.1)
		if s.home == dest:
			break
	main._refresh_hud()
	fails += _check(s.home == dest and not main.found_button.disabled, "도착하면 '도시 세우기'가 켜진다")
	var cap0: int = b.squad_cap()
	fails += _check(main.found_with_settler() and f.hqs.has(dest) and f.hqs.size() == 2 and b.settlers().is_empty(), "도시를 세우면 개척자가 사라지고 도시가 2개")
	main._refresh_hud()
	fails += _check(b.squad_cap() == cap0 + 1 and main.selected_settler == null and not main.found_button.visible, "분대 상한 +1 (%d)" % b.squad_cap())
	fails += _check(main.city_list.get_child_count() >= 2 and main.city_list.get_child(1).visible and main.city_list.get_child(1).text.begins_with("도시 2"), "도시 목록에 도시 2")
	main._pan = Vector3.ZERO
	(main.city_list.get_child(1) as Button).pressed.emit()
	var want: Vector3 = f.cell_to_world(dest) - f.center_world()
	fails += _check(main._pan.distance_to(want) < 0.01, "도시 목록을 누르면 카메라가 그 도시로")
	gs.gold = 1000
	gs.food = 1000
	main.select_building(hq)
	main._refresh_hud()
	fails += _check("45G · 식량 45" in main.settler_button.text, "도시 2개: 개척자 비용 45 (%s)" % main.settler_button.text)
	print("R4 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

extends SceneTree
## R3 화면 흐름 점검: 분대 줄, 숫자키·Shift·두 번 눌러 카메라, 고른 분대만 우클릭 이동(없으면 무시),
## 병영 패널의 분대 생산·대기열 취소, 상한 툴팁, 충원 버튼, 사격장 숨김, 경비병 거래 삭제
## godot --headless --script tests/r3_flow.gd


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
	gs.gold = 1000
	gs.food = 1000
	main._refresh_hud()
	fails += _check(main.squad_panel.visible and main.squad_buttons[0].visible and main.squad_buttons[0].text == "1 경비병 2/2" and not main.squad_buttons[1].visible, "분대 줄: 1번 경비병 2/2만 보인다 (%s)" % main.squad_buttons[0].text)
	fails += _check(not main.build_buttons.has(Balance.SHOOTING_RANGE), "사격장은 건설 목록에 없다")
	fails += _check(Balance.TRADES.size() == 1 and Balance.TRADES[0]["id"] == "gold_rp", "경비병 거래 삭제")
	# 고른 분대가 없으면 우클릭은 아무 일도 없다
	var walk: Vector2i = f.hq
	for c: Vector2i in f.territory_of[f.hq]:
		if f.is_walkable(c) and c != f.hq:
			walk = c
	fails += _check(main.selected_squads.is_empty() and not main.command_move(walk) and b.soldiers.all(func(u: Unit) -> bool: return u.order.x < 0), "고른 분대가 없으면 이동 명령 없음")
	# 숫자키 1로 고르고 우클릭 이동
	_key(main, KEY_1, false)
	fails += _check(main.selected_squads == [1] and main.squad_buttons[0].modulate != Color(0.75, 0.75, 0.75), "숫자키 1: 1번 분대를 고르고 밝게 표시")
	fails += _check(main.command_move(walk) and b.squad_units(1).all(func(u: Unit) -> bool: return u.order == walk), "고른 분대가 우클릭한 곳으로 간다")
	_key(main, KEY_5, false)
	fails += _check(main.selected_squads == [1], "없는 분대 번호는 무시")
	# 병영: 분대 생산 버튼과 대기열
	main.set_build(Balance.BARRACKS)
	var bar: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in f.territory_of[f.hq]:
		if bar.x < 0 and main.try_build(c):
			bar = c
	fails += _check(bar.x >= 0 and b.soldiers.size() == Balance.HQ_GUARDS, "병영을 지어도 병사가 공짜로 나오지 않는다")
	main.select_building(bar)
	main._refresh_hud()
	var melee: Button = main.squad_prod_buttons["melee"]
	var ranged: Button = main.squad_prod_buttons["ranged"]
	fails += _check(melee.visible and not melee.disabled and "경비병 3명" in melee.text and ranged.disabled and "궁술" in ranged.tooltip_text, "병영 패널: 근접 분대 가능, 원거리는 궁술 필요 (%s)" % melee.text)
	fails += _check(main.queue_selected("melee") and main.queue_buttons[0].visible and "30초" in main.queue_buttons[0].text, "근접 분대 생산: 대기열에 30초")
	main.queue_selected("melee")
	main._refresh_hud()
	fails += _check(melee.disabled and "상한 3" in melee.tooltip_text, "상한 3에 닿으면 버튼 비활성과 이유")
	var g0: int = gs.gold
	fails += _check(main.cancel_queued(1) and gs.gold == g0 + 30 and not main.queue_buttons[1].visible, "대기열을 누르면 취소·환불")
	for _i in 320:
		b.tick(0.1)
	main._refresh_hud()
	fails += _check(b.squads.has(2) and main.squad_buttons[1].visible and main.squad_buttons[1].text == "2 경비병 3/3", "생산이 끝나면 2번 분대가 분대 줄에 나온다")
	# Shift+숫자로 더하고, 두 번 누르면 카메라가 분대로 간다
	_key(main, KEY_2, true)
	fails += _check(main.selected_squads == [1, 2], "Shift+2: 2번 분대를 더한다")
	main._pan = Vector3(30, 0, 30)
	_key(main, KEY_2, false)
	_key(main, KEY_2, false)
	var at: Vector3 = b.squad_units(2)[0].position - f.center_world()
	fails += _check(main.selected_squads == [2] and Vector2(main._pan.x - at.x, main._pan.z - at.z).length() < 1.0, "숫자키를 두 번 빠르게 누르면 카메라가 그 분대로 간다")
	# 충원 버튼: 고른 분대에 빈 자리가 있고 병영 곁이면 보인다
	b.squad_units(2)[0].hp = 0.0
	b.tick(0.1)
	main._refresh_hud()
	fails += _check(main.reinforce_button.visible and main.reinforce_button.text == "충원 10G · 식량 5", "충원 버튼 (%s)" % main.reinforce_button.text)
	fails += _check(main.reinforce_selected() and b.squad_units(2).size() == 3, "충원하면 3/3")
	main._refresh_hud()
	fails += _check(not main.reinforce_button.visible, "정원이 차면 충원 버튼이 사라진다")
	print("R3 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _key(main: Node, code: Key, shift: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	main._unhandled_input(e)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

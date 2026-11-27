extends SceneTree
## 전투 개선 화면 흐름 점검: godot --headless --script tests/m10_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	fails += _check(not main.command_move(main.field.start_cells().keys()[0]), "도시를 세우기 전에는 이동 명령을 못 내린다")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	var land: Vector2i = main.field.hq
	fails += _check(not main.build_buttons.has(99), "집결지 버튼은 없다")
	fails += _check(main.speed_button.visible and main.battle.speed_scale == 1.0 and main.speed_button.text == "배속 x1", "도시를 세우면 배속 x1 버튼")
	main.cycle_speed()
	fails += _check(main.battle.speed_scale == 2.0 and main.speed_button.text == "배속 x2", "배속 x2")
	main.cycle_speed()
	fails += _check(main.battle.speed_scale == 4.0 and main.speed_button.text == "배속 x4", "배속 x4")
	main.cycle_speed()
	fails += _check(main.battle.speed_scale == 1.0, "다시 x1")
	fails += _check(not main.command_move(Vector2i(0, 0)), "바다 칸은 이동 목표가 될 수 없다")
	main.select_squad(1)
	fails += _check(main.command_move(land) and main.battle.soldiers[0].order == land, "분대를 고르고 땅을 클릭하면 그곳으로 이동")
	main.call_wave()
	for _i in 6000: # 넓은 맵이라 먼 곳에 내린 해적까지 잡는 데 오래 걸릴 수 있다
		if main.battle.enemies_left() == 0 or main.over:
			break
		main.battle.tick(0.1)
	main._refresh_hud()
	fails += _check(main.battle.enemies_left() == 0 and main.speed_button.visible, "웨이브를 막아도 전투와 배속 버튼은 이어진다 (실시간, 기획서 2장)")
	print("전투 개선 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

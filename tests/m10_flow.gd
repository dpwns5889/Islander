extends SceneTree
## 전투 개선 화면 흐름 점검: godot --headless --script tests/m10_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	var land: Vector2i = main.field.hq
	fails += _check(not main.command_move(land), "준비 단계에서는 이동 명령을 못 내린다")
	fails += _check(not main.build_buttons.has(99), "준비 단계의 집결지 버튼은 없다")
	fails += _check(not main.speed_button.visible, "배속 버튼은 전투 때만 보인다")
	main.start_wave()
	fails += _check(main.speed_button.visible and main.battle.speed_scale == 1.0 and main.speed_button.text == "배속 x1", "전투 시작: 배속 x1")
	main.cycle_speed()
	fails += _check(main.battle.speed_scale == 2.0 and main.speed_button.text == "배속 x2", "배속 x2")
	main.cycle_speed()
	fails += _check(main.battle.speed_scale == 4.0 and main.speed_button.text == "배속 x4", "배속 x4")
	main.cycle_speed()
	fails += _check(main.battle.speed_scale == 1.0, "다시 x1")
	fails += _check(not main.command_move(Vector2i(0, 0)), "바다 칸은 이동 목표가 될 수 없다")
	fails += _check(main.command_move(land) and main.battle.soldiers[0].order == land, "전투 중 땅을 클릭하면 병사가 그곳으로 이동")
	for _i in 3000:
		if main.battle == null:
			break
		main.battle.tick(0.1)
	fails += _check(main.battle == null, "전투가 끝났다")
	fails += _check(not main.speed_button.visible, "전투가 끝나면 배속 버튼이 사라진다")
	print("전투 개선 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

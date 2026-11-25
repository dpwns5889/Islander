extends SceneTree
## M5 화면 흐름 점검: godot --headless --script tests/m5_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	main._begin_prep() # 첫 준비 단계는 보상 타일이 없어 일반 준비 단계로 대신한다
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	gs.gold = 1000
	gs.researched["math"] = true # 시장은 교역 연구가 있어야 짓는다
	# 전투를 빠르게 돌려 승리하면 정산·본부 레벨·연구포인트
	var hq0: Vector2i = main.field.hqs.keys()[0]
	main.field.hq_food[hq0] = 19 # 정산 식량(평원 칸 수)과 합쳐 기준(5)을 넘게 한다
	main.start_wave()
	for _i in 3000:
		if main.battle == null:
			break
		main.battle.tick(0.1)
	fails += _check(main.battle == null and gs.wave == 2, "웨이브 승리 후 2웨이브")
	fails += _check(main.field.hq_level[hq0] >= 2, "식량 누적으로 본부 레벨 상승 (누적 %d)" % main.field.hq_food[hq0])
	fails += _check(main.pieces_left == 1 and gs.research_points == 0, "본부 레벨업은 연구포인트를 주지 않는다 (놓을 조각 %d개, 연구포인트 %d)" % [main.pieces_left, gs.research_points])
	print("M5 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

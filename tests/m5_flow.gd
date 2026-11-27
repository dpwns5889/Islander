extends SceneTree
## M5 화면 흐름 점검: godot --headless --script tests/m5_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
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
	fails += _check(gs.research_points == 0, "도시 레벨업은 연구포인트를 주지 않는다 (연구포인트 %d)" % gs.research_points)
	print("M5 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

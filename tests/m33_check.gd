extends SceneTree
## 해적선 출현 시간 점검: godot --headless --script tests/m33_check.gd


func _initialize() -> void:
	var fails: int = 0
	for wave in [1, 12, 30, 60]: # 60웨이브(무한 모드)는 간격이 계산 한 번(0.1초)보다 짧다
		var f: Field = preload("res://tests/small_field.gd").make()
		var p: Piece = Piece.new()
		for y in 5:
			for x in 5:
				p.cells.append(Vector2i(x, y))
				p.terrain.append(Piece.PLAINS)
		p.hq_index = 12
		f.place(p, Vector2i(4, 4))
		var gs: Node = load("res://assets/scripts/game_state.gd").new()
		var b: Battle = Battle.new()
		b.setup(f, gs)
		b.launch_wave(wave)
		for _i in 20: # 전투 시간 2초
			b.tick(0.1)
		fails += _check(b._ships_left == 0 and b._pirates_left == 0, "웨이브 %d: 2초 안에 모두 출발 (남은 배 %d / %d, 남은 적 %d)" % [wave, b._ships_left, Balance.ship_count(wave), b._pirates_left])
	print("해적선 출현 시간 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

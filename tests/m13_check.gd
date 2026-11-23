extends SceneTree
## M10 추가 본부 점검: godot --headless --script tests/m13_check.gd


func _initialize() -> void:
	var fails: int = 0
	fails += _check(Balance.HQ_PIECE_WAVES == [10, 20], "본부 조각은 10·20웨이브 뒤")
	# 본부가 둘인 필드: 각각 체력 300, 모두 공격 목표
	var f: Field = _two_hq_field()
	fails += _check(f.hqs.size() == 2 and f.hq_hp == 600.0, "본부 2개, 체력 합 600")
	fails += _check(f.targets().has(Vector2i(6, 6)) and f.targets().has(Vector2i(16, 6)), "두 본부 모두 목표")
	fails += _check(not f.can_build(Balance.HOUSE, Vector2i(6, 6)), "본부 칸에는 건물을 못 짓는다")
	# 하나가 파괴돼도 나머지는 산다. 영구 손실, 빈 땅이 되고 복구되지 않는다
	fails += _check(not f.damage(Vector2i(6, 6), 100.0) and f.hqs[Vector2i(6, 6)] == 200.0, "피해만 입으면 파괴 아님")
	fails += _check(f.damage(Vector2i(6, 6), 500.0), "체력 0이면 파괴(true)")
	fails += _check(f.hqs.size() == 1 and f.hq_lost == 1 and f.hq == Vector2i(16, 6) and f.hq_hp == 300.0, "남은 본부 1개, 영구 손실 1")
	fails += _check(f.can_build(Balance.HOUSE, Vector2i(6, 6)), "파괴된 본부 칸은 빈 땅")
	f.damage(Vector2i(16, 6), 50.0)
	f.repair_all()
	fails += _check(f.hqs.size() == 1 and f.hq_hp == 300.0, "수리해도 파괴된 본부는 돌아오지 않는다")
	fails += _check(f.hq_status() == "본부 1/2 · 체력 300 · 영구 손실 1", "상태 문구: " + f.hq_status())
	# 보유 자원 30% 감소(내림)
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = 55
	gs.food = 20
	gs.lose_share(Balance.HQ_LOSS_RATE)
	fails += _check(gs.gold == 38 and gs.food == 14, "골드 55→38, 식량 20→14")
	# 전투: 본부마다 수비병 2명. 한 본부가 파괴되면 자원이 한 번 줄고 전투는 계속, 모두 파괴되면 패배
	var f2: Field = _two_hq_field()
	var gs2: Node = load("res://assets/scripts/game_state.gd").new()
	gs2.gold = 100
	gs2.food = 20
	var b: Battle = Battle.new()
	b.setup(f2, gs2, 1)
	b._ships_left = 1 # 웨이브가 끝나 버리지 않도록
	b._ship_timer = 9999.0
	fails += _check(b.soldiers.size() == 4, "본부 2개: 수비병 4명 (%d)" % b.soldiers.size())
	var result: Array = []
	b.finished.connect(func(v: bool) -> void: result.append(v))
	var killer: Unit = b._add_unit(Balance.U_PIRATE, f2.cell_to_world(Vector2i(16, 6)), 1000.0) # 한 방에 본부를 부순다
	killer.island = b.islands[Vector2i(16, 6)]
	for _i in 30:
		b.tick(0.1)
	fails += _check(f2.hqs.size() == 1 and f2.hq_lost == 1, "한 본부가 파괴됨")
	fails += _check(gs2.gold == 70 and gs2.food == 14, "파괴 순간 골드 100→70, 식량 20→14 (%d, %d)" % [gs2.gold, gs2.food])
	fails += _check(not b.done, "본부가 남아 있으면 전투는 계속된다")
	var killer2: Unit = b._add_unit(Balance.U_PIRATE, f2.cell_to_world(Vector2i(6, 6)), 1000.0)
	killer2.island = b.islands[Vector2i(6, 6)]
	for _i in 30:
		b.tick(0.1)
	fails += _check(b.done and result == [false], "모든 본부가 파괴되면 패배")
	# 놓을 자리 확인
	var big: Piece = Piece.start_piece(RandomNumberGenerator.new())
	fails += _check(big.hq_index >= 0, "본부 조각에는 본부 칸이 있다")
	var full: Field = Field.new()
	fails += _check(full.has_room(big), "빈 필드에는 자리가 있다")
	for y in Field.H:
		for x in Field.W:
			var one: Piece = Piece.new()
			one.cells.assign([Vector2i(0, 0)])
			one.terrain.assign([Piece.PLAINS])
			full.place(one, Vector2i(x, y))
	fails += _check(not full.has_room(big), "꽉 찬 필드에는 자리가 없다")
	full.expand(Vector2i.RIGHT, true)
	fails += _check(not full.has_room(big), "한 줄(1칸)만으로는 7칸 조각이 안 들어간다")
	full.expand(Vector2i.RIGHT, true)
	full.expand(Vector2i.RIGHT, true)
	fails += _check(full.has_room(big), "3줄 확장하면 들어간다")
	fails += _check(full.expansions == 3 and full.paid_expansions == 0, "무료 확장은 비용 계산에 쓰는 횟수를 늘리지 않는다")
	print("M10 점검 실패 %d건" % fails)
	quit(fails)


## 5x5 평원 섬 두 개, 본부는 각각 (6,6)과 (16,6)
func _two_hq_field() -> Field:
	var f: Field = Field.new()
	for ox in [4, 14]:
		var p: Piece = Piece.new()
		for y in 5:
			for x in 5:
				p.cells.append(Vector2i(x, y))
				p.terrain.append(Piece.PLAINS)
		p.hq_index = 12
		f.place(p, Vector2i(ox, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

extends SceneTree
## M5 점검: godot --headless --script tests/m5_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 확장 비용
	fails += _check(Balance.expand_cost(0) == 70 and Balance.expand_cost(1) == 105 and Balance.expand_cost(2) == 158, "확장 비용 70/105/158")
	# 확장: 한 줄씩, 최대 40x30
	var f: Field = Field.new()
	f.generate_outside(1)
	f.expand(Vector2i.LEFT)
	fails += _check(f.bounds == Rect2i(-1, 0, 21, 15) and f.expansions == 1, "왼쪽으로 한 줄")
	f.expand(Vector2i.UP)
	f.expand(Vector2i.RIGHT)
	f.expand(Vector2i.DOWN)
	fails += _check(f.bounds == Rect2i(-1, -1, 22, 17), "네 방향 확장")
	var piece: Piece = Piece.new()
	piece.cells.assign([Vector2i(0, 0), Vector2i(1, 0)])
	piece.terrain.assign([Piece.PLAINS, Piece.PLAINS])
	fails += _check(f.can_place(piece, Vector2i(-1, -1)), "넓힌 칸에 조각을 놓을 수 있다")
	fails += _check(not f.can_place(piece, Vector2i(-2, -1)), "넓힌 영역 밖은 불가")
	var ring: Rect2i = f.bounds.grow(2)
	var ring_ok: bool = true
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var c: Vector2i = Vector2i(x, y)
			if not f.bounds.has_point(c) and f.terrain_at(c) != Field.SEA:
				ring_ok = false
	fails += _check(ring_ok, "확장 뒤에도 필드 가까이는 바다")
	for _i in 30:
		if f.can_expand(Vector2i.RIGHT):
			f.expand(Vector2i.RIGHT)
		if f.can_expand(Vector2i.DOWN):
			f.expand(Vector2i.DOWN)
	fails += _check(f.bounds.size == Vector2i(Field.MAX_W, Field.MAX_H) and not f.can_expand(Vector2i.RIGHT) and not f.can_expand(Vector2i.UP), "최대 40x30")
	# 적 강도: 땅 칸 수와 확장 횟수가 늘면 강해진다
	fails += _check(Balance.enemy_mult(100, 3) > Balance.enemy_mult(100, 0) and Balance.enemy_mult(200, 0) > Balance.enemy_mult(100, 0), "넓힐수록 적이 강해진다")
	# 본부 레벨
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.add(0, 19)
	fails += _check(gs.check_level() == 0 and gs.hq_level == 1, "식량 19: 레벨 1")
	gs.add(0, 1)
	fails += _check(gs.check_level() == 1 and gs.hq_level == 2, "식량 20: 레벨 2")
	gs.add(0, 100)
	fails += _check(gs.check_level() == 2 and gs.hq_level == 4 and gs.next_level_food() == 180, "식량 120: 레벨 4, 다음은 180")
	gs.spend(0, 50)
	fails += _check(gs.food_total == 120, "식량을 써도 누적은 줄지 않는다")
	# 확장한 필드에서도 전투가 끝까지 돈다
	var g2: Node = load("res://assets/scripts/game_state.gd").new()
	var f2: Field = _island()
	f2.expand(Vector2i.LEFT)
	f2.expand(Vector2i.UP)
	var b: Battle = Battle.new()
	b.setup(f2, g2, 1)
	b.rng.seed = 4
	var done: Array = []
	b.finished.connect(func(v: bool) -> void: done.append(v))
	for _i in 3000:
		b.tick(0.1)
		if b.done:
			break
	fails += _check(done.size() == 1 and done[0], "확장한 필드에서 1웨이브 승리")
	print("M5 점검 실패 %d건" % fails)
	quit(fails)


func _island() -> Field:
	var f: Field = Field.new()
	f.generate_outside(2)
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

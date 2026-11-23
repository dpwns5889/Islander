extends SceneTree
## 바다 섞인 타일·교역소 물가 검사 점검: godot --headless --script tests/m16_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 1. 10라운드까지는 바다 칸이 없고, 이후에는 섞인 타일이 나온다 (땅 3칸 이상, 바다 1~2칸, 4~7칸)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var early_sea: int = 0
	var late_sea: int = 0
	var late_ok: bool = true
	for i in 500:
		rng.seed = i
		if Piece.random_piece(rng, false).has_sea():
			early_sea += 1
		rng.seed = i
		var p: Piece = Piece.random_piece(rng, true)
		if p.has_sea():
			late_sea += 1
			var seas: int = p.terrain.count(Piece.SEA)
			late_ok = late_ok and p.cells.size() - seas >= 3 and seas >= 1 and seas <= 2 and p.cells.size() >= 4 and p.cells.size() <= 7
	fails += _check(early_sea == 0, "10라운드까지는 바다 섞인 타일이 없다 (%d)" % early_sea)
	fails += _check(late_sea > 100 and late_sea < 300, "이후에는 약 %d%%가 바다 섞임 (%d/500)" % [int(Balance.SEA_TILE_CHANCE * 100), late_sea])
	fails += _check(late_ok, "바다 섞인 타일: 땅 3칸 이상, 바다 1~2칸, 4~7칸")
	fails += _check(Balance.SEA_TILE_WAVE == 10, "10라운드 이후")
	# 2. 바다 칸이 있는 타일을 놓으면 그 칸은 땅이 아니라 물 타일로 차지된다
	var f: Field = Field.new()
	var ring: Piece = Piece.new()
	for y in 3:
		for x in 3:
			ring.cells.append(Vector2i(x, y))
			ring.terrain.append(Piece.SEA if x == 1 and y == 1 else Piece.PLAINS)
	ring.hq_index = 0
	fails += _check(f.can_place(ring, Vector2i(5, 5)), "빈 필드에 놓을 수 있다")
	f.place(ring, Vector2i(5, 5))
	fails += _check(not f.cells.has(Vector2i(6, 6)) and f.water.has(Vector2i(6, 6)) and f.cells.size() == 8, "가운데는 땅이 아니라 물 타일 (땅 %d칸)" % f.cells.size())
	fails += _check(f.terrain_at(Vector2i(6, 6)) == Field.SEA, "물 타일은 바다다")
	var one: Piece = Piece.new()
	one.cells.assign([Vector2i(0, 0)])
	one.terrain.assign([Piece.PLAINS])
	fails += _check(not f.can_place(one, Vector2i(6, 6)), "물 타일 위에는 다른 조각을 놓을 수 없다")
	fails += _check(not f.is_open_sea(Vector2i(6, 6)), "땅으로 둘러싸인 물 타일은 닫힌 바다(호수)")
	fails += _check(f.can_build(Balance.FISHERY, Vector2i(6, 6)), "물 타일 위에는 낚시터를 지을 수 있다")
	# 3. 교역소가 바다와 끊기는지 미리 계산: 열린 이웃이 (3,5) 하나뿐인 교역소
	var g: Field = Field.new()
	var strip: Piece = Piece.new()
	for y in 3:
		for x in 2:
			strip.cells.append(Vector2i(x, y))
			strip.terrain.append(Piece.PLAINS)
	strip.hq_index = 0
	g.place(strip, Vector2i(4, 4)) # (4..5, 4..6)
	var post: Vector2i = Vector2i(4, 5)
	fails += _check(g.can_build(Balance.TRADING_POST, post), "열린 바다 옆에 교역소를 지을 수 있다")
	g.build(Balance.TRADING_POST, post)
	fails += _check(g.is_post_open(post), "처음에는 열려 있다")
	var plug: Piece = Piece.new()
	plug.cells.assign([Vector2i(0, 0)])
	plug.terrain.assign([Piece.PLAINS])
	fails += _check(g.can_place(plug, Vector2i(3, 5)) and not g.post_open_after(post, plug, Vector2i(3, 5)), "교역소 옆 바다를 막는 타일: 끊긴다고 계산")
	fails += _check(g.post_open_after(post, plug, Vector2i(12, 10)), "다른 곳에 놓으면 열려 있다")
	fails += _check(g.is_post_open(post) and not g.cells.has(Vector2i(3, 5)), "미리 계산은 필드를 바꾸지 않는다")
	var sea_plug: Piece = Piece.new()
	sea_plug.cells.assign([Vector2i(0, 0), Vector2i(0, 1)])
	sea_plug.terrain.assign([Piece.SEA, Piece.PLAINS])
	fails += _check(g.post_open_after(post, sea_plug, Vector2i(3, 5)), "바다 칸으로 놓으면 바다는 그대로라 안 끊긴다")
	g.place(plug, Vector2i(3, 5))
	fails += _check(not g.is_post_open(post), "실제로 놓으면 닫힌다")
	fails += _check(g.trading_post() == post, "건물은 그대로 남는다(복구·철거 없음)")
	print("바다 타일·물가 검사 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

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
			late_ok = late_ok and seas == p.cells.size() and seas >= 3 and seas <= 5
	fails += _check(early_sea == 0, "10라운드까지는 바다 섞인 타일이 없다 (%d)" % early_sea)
	fails += _check(late_sea > 100 and late_sea < 300, "이후에는 약 %d%%가 바다 섞임 (%d/500)" % [int(Balance.SEA_TILE_CHANCE * 100), late_sea])
	fails += _check(late_ok, "바다 타일: 전부 바다 칸, 3~5칸")
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
	for ex in [Vector2i(3, 4), Vector2i(3, 6)]: # (3,5)가 (2,5) 하나로만 바다와 이어지는 물 칸이 되게 한다
		var col: Piece = Piece.new()
		col.cells.assign([Vector2i(0, 0)])
		col.terrain.assign([Piece.PLAINS])
		g.place(col, ex)
	var post: Vector2i = Vector2i(3, 5)
	fails += _check(g.can_build(Balance.TRADING_POST, post), "열린 바다 옆에 교역소를 지을 수 있다")
	g.build(Balance.TRADING_POST, post)
	fails += _check(g.is_post_open(post), "처음에는 열려 있다")
	var plug: Piece = Piece.new()
	plug.cells.assign([Vector2i(0, 0)])
	plug.terrain.assign([Piece.PLAINS])
	fails += _check(g.can_place(plug, Vector2i(2, 5)) and not g.post_open_after(post, plug, Vector2i(2, 5)), "교역소 옆 바다를 막는 타일: 끊긴다고 계산")
	fails += _check(g.post_open_after(post, plug, Vector2i(12, 10)), "다른 곳에 놓으면 열려 있다")
	fails += _check(g.is_post_open(post) and not g.cells.has(Vector2i(2, 5)), "미리 계산은 필드를 바꾸지 않는다")
	var sea_plug: Piece = Piece.new()
	sea_plug.cells.assign([Vector2i(0, 0), Vector2i(0, 1)])
	sea_plug.terrain.assign([Piece.SEA, Piece.PLAINS])
	fails += _check(g.post_open_after(post, sea_plug, Vector2i(2, 5)), "바다 칸으로 놓으면 바다는 그대로라 안 끊긴다")
	g.place(plug, Vector2i(2, 5))
	fails += _check(not g.is_post_open(post), "실제로 놓으면 닫힌다")
	fails += _check(g.trading_post() == post, "건물은 그대로 남는다(복구·철거 없음)")
	# 4. 바다 칸은 기존 땅을 물로 깎아 닫힌 바다를 다시 열 수 있다
	var carve: Piece = Piece.new()
	carve.cells.assign([Vector2i(0, 0)])
	carve.terrain.assign([Piece.SEA])
	fails += _check(g.carve_count(carve, Vector2i(2, 5)) == 1 and g.carve_count(carve, Vector2i(12, 10)) == 0, "깎을 땅 칸 수 계산")
	fails += _check(g.can_place(carve, Vector2i(2, 5)), "바다 칸은 기존 땅 위에 놓을 수 있다")
	fails += _check(g.post_open_after(post, carve, Vector2i(2, 5)), "깎으면 열린다고 미리 계산 (지금은 닫혀 있어도)")
	fails += _check(not g.is_post_open(post) and g.cells.has(Vector2i(2, 5)), "미리 계산은 필드를 바꾸지 않는다")
	var nodes_before: int = g.get_child_count()
	g.place(carve, Vector2i(2, 5))
	fails += _check(not g.cells.has(Vector2i(2, 5)) and g.water.has(Vector2i(2, 5)), "땅이 물 타일로 바뀐다")
	fails += _check(g.is_post_open(post), "교역소가 다시 열린 바다와 맞닿는다 (되돌림)")
	fails += _check(g.can_place(plug, Vector2i(2, 5)) == false, "물 타일이 된 칸에는 다시 땅을 못 놓는다")
	# 5. 깎을 수 없는 곳: 건물, 본부, 이미 있는 물 타일. 땅 칸은 여전히 빈 칸에만
	fails += _check(g.can_build(Balance.HOUSE, Vector2i(5, 6)), "깎기 전에는 땅에 집을 지을 수 있다")
	g.build(Balance.HOUSE, Vector2i(5, 6))
	fails += _check(not g.can_place(carve, Vector2i(5, 6)), "건물이 있는 칸은 깎을 수 없다")
	fails += _check(not g.can_place(carve, Vector2i(4, 4)), "본부 칸은 깎을 수 없다")
	fails += _check(not g.can_place(carve, Vector2i(2, 5)), "이미 물 타일인 칸에는 못 놓는다")
	fails += _check(not g.can_place(plug, Vector2i(5, 5)), "땅 칸 조각은 기존 땅 위에 못 놓는다")
	# 6. 깎인 땅은 블록도 사라진다 (이전 블록 노드가 남지 않는다)
	var g2: Field = Field.new()
	g2.place(strip, Vector2i(4, 4))
	var before_nodes: int = g2.get_child_count()
	g2.place(carve, Vector2i(5, 5))
	var land_blocks: int = 0
	for ch in g2.get_children():
		if ch is MeshInstance3D and not ch.is_queued_for_deletion() and ch.mesh == g2.block_mesh:
			land_blocks += 1
	fails += _check(land_blocks == 5 and g2.cells.size() == 5, "땅 6칸 중 1칸이 깎여 블록 5개 (%d)" % land_blocks)
	print("바다 타일·물가 검사 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

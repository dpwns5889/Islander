extends SceneTree
## M3 전투 점검: godot --headless --script tests/m3_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 건물 피해·파괴·수리
	var f: Field = _island(false)
	f.build(Balance.HOUSE, Vector2i(5, 5))
	f.damage(Vector2i(5, 5), 20.0)
	fails += _check(f.hp[Vector2i(5, 5)] == 30.0, "건물 피해")
	f.damage(Vector2i(5, 5), 100.0)
	fails += _check(not f.buildings.has(Vector2i(5, 5)), "체력 0이면 파괴")
	fails += _check(f.can_build(Balance.HOUSE, Vector2i(5, 5)), "파괴된 칸은 재건 가능")
	f.build(Balance.HOUSE, Vector2i(5, 5))
	f.damage(Vector2i(5, 5), 20.0)
	f.damage(f.hq, 100.0)
	f.repair_all()
	fails += _check(f.hp[Vector2i(5, 5)] == 50.0 and f.hq_hp == Balance.HQ_HP, "수리")
	# 평원 해안에도 상륙한다: 해적이 들어와 본부나 건물을 때린다
	var r1: Dictionary = _sim(_island(false), 0, 0, 0, 12)
	fails += _check(not r1["victory"], "평원만 있는 섬도 공격받는다")
	# 모래 해안 + 병영·식량 없음 → 후반 웨이브에서는 본부 수비병만으로 못 막는다
	var r2: Dictionary = _sim(_island(true), 0, 0, 0, 12)
	fails += _check(not r2["victory"], "방어가 약하면 후반 웨이브에서 패배")
	# 아군 2 vs 해적 3 → 아군이 이긴다
	# 시작 배치(흩어짐)가 무작위라 한 번씩은 질 수 있다. 40번 중 80% 이상 이기면 "이길 정도"로 본다
	var wins: int = 0
	for seed_i in 40:
		var d: Dictionary = _duel(seed_i)
		wins += 1 if d["pirates"] == 0 and d["soldiers"] >= 1 else 0
	print("아군 2 vs 적 3 승률 %d/40" % wins)
	fails += _check(wins >= 32, "아군 2 vs 적 3: 40번 중 32번 이상 승리 (%d)" % wins)
	# 병영 + 식량 → 막는지 (밸런스 참고용 출력)
	# 시작 자원(골드 100 - 병영 60 = 40)으로 1웨이브를 막을 수 있어야 한다 (밸런스 확인)
	for food in [0, 20, 30, 50]:
		var r3: Dictionary = _sim(_island(true), 1, food, Balance.START_GOLD - Balance.BUILDINGS[Balance.BARRACKS]["cost"])
		print("병영 1개, 골드 40, 식량 %d → 승리 %s, 본부 체력 %d" % [food, r3["victory"], r3["hq"]])
	# 병영 없이 본부 병사만으로 시작 자원(골드 100, 식량 20)에 1웨이브를 이긴다
	var r4: Dictionary = _sim(_island(true), 0, Balance.START_FOOD, Balance.START_GOLD)
	fails += _check(r4["victory"], "본부 병사만으로 1웨이브 승리")
	print("본부만, 시작 자원 → 승리 %s, 본부 체력 %d" % [r4["victory"], r4["hq"]])
	# 시작 조각의 본부는 평원 칸
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_i in 300:
		rng.seed = seed_i
		var sp: Piece = Piece.start_piece(rng)
		fails += _check(sp.terrain[sp.hq_index] == Piece.PLAINS, "시작 조각: 본부는 평원")
	print("M3 점검 실패 %d건" % fails)
	quit(fails)


## 5x5 평원 섬 (+ 오른쪽에 모래 해안 한 줄)
func _island(with_sand: bool) -> Field:
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	if with_sand:
		var s: Piece = Piece.new()
		for y in 5:
			s.cells.append(Vector2i(0, y))
			s.terrain.append(Piece.SAND)
		f.place(s, Vector2i(9, 4))
	return f


func _sim(f: Field, barracks: int, food: int, gold: int = 1000, wave: int = 1) -> Dictionary:
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.food = food
	gs.gold = gold
	for i in barracks:
		f.build(Balance.BARRACKS, Vector2i(5 + i, 4))
	var b: Battle = Battle.new()
	b.rng.seed = 7
	b.setup(f, gs, wave)
	b.rng.seed = 7
	var result: Array = []
	b.finished.connect(func(v: bool) -> void: result.append(v))
	for _i in 3000:
		b.tick(0.1)
		if b.done:
			break
	return {"victory": result.size() > 0 and result[0], "hq": f.hq_hp}


## 본부 수비병 2명과 해적 3명을 본부 곁에서 싸우게 한다
func _duel(seed_i: int) -> Dictionary:
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = 0
	gs.food = 0
	var f: Field = _island(true)
	var b: Battle = Battle.new()
	b.setup(f, gs, 1)
	b.rng.seed = seed_i
	b._ships_left = 1 # 웨이브가 끝나 버리지 않도록 배 1척을 남겨 둔다
	b._ship_timer = 9999.0
	for i in 3:
		var p: Unit = b._add_unit(Balance.U_PIRATE, f.cell_to_world(f.hq) + Vector3(1.5 + 0.3 * i, 0.0, b.rng.randf_range(-0.5, 0.5)), 1.05)
		p.island = b.islands[f.hq]
	for _i in 600:
		b.tick(0.1)
		if b.pirates.is_empty() or b.soldiers.is_empty() or b.done:
			break
	var hp: float = 0.0
	for s in b.soldiers:
		hp += s.hp
	return {"pirates": b.pirates.size(), "soldiers": b.soldiers.size(), "hp": hp}


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

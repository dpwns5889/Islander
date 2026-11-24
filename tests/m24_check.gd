extends SceneTree
## 본부별 레벨·영역 점검: godot --headless --script tests/m24_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 1. 본부마다 따로 레벨, 자기 영역의 식량만 센다 (기획서 5.3)
	var f: Field = _land(15, 15)
	f.territory_enabled = true
	_hq(f, Vector2i(3, 3))
	_hq(f, Vector2i(11, 3))
	fails += _check(f.hq_level[Vector2i(3, 3)] == 1 and f.hq_level[Vector2i(11, 3)] == 1, "두 본부 모두 레벨 1에서 시작")
	fails += _check(f.income({}, Vector2i(3, 3)).y == 9 and f.income({}, Vector2i(11, 3)).y == 9, "본부별 식량은 자기 3x3 평원 9칸")
	f.hq_food[Vector2i(3, 3)] = 4
	var ups: Dictionary = f.settle_levels({}) # 정산: 각자 +9
	fails += _check(f.hq_level[Vector2i(3, 3)] == 3 and f.hq_level[Vector2i(11, 3)] == 2, "본부별로 따로 오른다 (13→레벨3, 9→레벨2)")
	fails += _check(f.territory_of[Vector2i(3, 3)].size() == 11 and f.territory_of[Vector2i(11, 3)].size() == 10, "오른 레벨만큼 영역 +1칸씩")
	fails += _check(ups.size() == 2, "정산이 오른 본부를 돌려 준다")
	# 2. 영역은 겹치지 않는다: 먼저 차지한 쪽이 갖는다
	var g: Field = _land(12, 8)
	g.territory_enabled = true
	_hq(g, Vector2i(3, 4))
	_hq(g, Vector2i(4, 4)) # 3x3이 겹친다
	var overlap: bool = false
	for c in g.territory_of[Vector2i(3, 4)]:
		overlap = overlap or g.territory_of[Vector2i(4, 4)].has(c)
	fails += _check(not overlap, "두 영역은 한 칸도 겹치지 않는다")
	fails += _check(g.territory_of[Vector2i(4, 4)].has(Vector2i(4, 4)) and g.territory_of[Vector2i(3, 4)].size() == 8, "본부 칸은 항상 자기 영역(기존 영역에서 가져옴)")
	g.grow_territory(Vector2i(3, 4), 30)
	overlap = false
	for c in g.territory_of[Vector2i(3, 4)]:
		overlap = overlap or g.territory_of[Vector2i(4, 4)].has(c)
	fails += _check(not overlap, "확장해도 남의 영역은 가져오지 않는다")
	# 3. 새 본부는 살아 있는 본부 최고 레벨의 절반에서 시작
	var h: Field = _land(15, 15)
	h.territory_enabled = true
	_hq(h, Vector2i(3, 3))
	h.hq_level[Vector2i(3, 3)] = 7
	_hq(h, Vector2i(11, 11))
	fails += _check(h.hq_level[Vector2i(11, 11)] == 3 and h.hq_food[Vector2i(11, 11)] == Balance.HQ_LEVEL_FOOD[1] and h.territory_of[Vector2i(11, 11)].size() == 11, "최고 7의 절반 3레벨: 영역 9+2칸, 식량은 기준값")
	h._nodes[Vector2i(11, 11)] = []
	h.damage(Vector2i(11, 11), 9999.0)
	fails += _check(not h.hq_level.has(Vector2i(11, 11)) and not h.hq_food.has(Vector2i(11, 11)), "파괴된 본부의 레벨·누적은 사라진다")
	# 4. 정사각형 우선: 확률 100%로 두면 3x3 → 3x4 → 4x4가 된다
	var sq: Field = _land(20, 20)
	sq.territory_enabled = true
	sq.claim_start(Vector2i(8, 8))
	sq._terr_rng.seed = 7
	var chance: float = Balance.TERRITORY_SQUARE_CHANCE
	fails += _check(chance > 0.0 and chance < 1.0, "정사각형 확률은 0과 1 사이 (%.2f)" % chance)
	var square_runs: int = 0
	for trial in 40:
		var t: Field = _land(20, 20)
		t.territory_enabled = true
		t.claim_start(Vector2i(8, 8))
		t.grow_territory(Vector2i(8, 8), 7, 1.0) # 3x3 + 7 = 16칸 → 정사각형 우선만 나오면 4x4
		var lo: Vector2i = Vector2i(99, 99)
		var hi: Vector2i = Vector2i(-99, -99)
		for c in t.territory_of[Vector2i(8, 8)]:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		if (hi.x - lo.x + 1) * (hi.y - lo.y + 1) == 16:
			square_runs += 1
	fails += _check(square_runs == 40, "정사각형 우선 100%%면 3x3에 7칸을 더해 항상 4x4 (%d/40)" % square_runs)
	var random_runs: int = 0
	for trial in 40:
		var r: Field = _land(20, 20)
		r.territory_enabled = true
		r.claim_start(Vector2i(8, 8))
		r.grow_territory(Vector2i(8, 8), 7, 0.0)
		var lo2: Vector2i = Vector2i(99, 99)
		var hi2: Vector2i = Vector2i(-99, -99)
		for c in r.territory_of[Vector2i(8, 8)]:
			lo2 = Vector2i(mini(lo2.x, c.x), mini(lo2.y, c.y))
			hi2 = Vector2i(maxi(hi2.x, c.x), maxi(hi2.y, c.y))
		if (hi2.x - lo2.x + 1) * (hi2.y - lo2.y + 1) == 16:
			random_runs += 1
	fails += _check(random_runs < 20, "무작위 100%면 4x4가 되는 일이 드물다 (%d/40)" % random_runs)
	print("본부별 레벨 점검 실패 %d건" % fails)
	quit(fails)


## w x h 평원 땅 (모든 칸이 필드 안). 본부는 claim_start로 따로 둔다
## 본부를 두고 영역을 받는다
func _hq(f: Field, c: Vector2i) -> void:
	f.hqs[c] = Balance.HQ_HP
	f.claim_start(c)


func _land(w: int, h: int) -> Field:
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for y in h:
		for x in w:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	f.place(p, Vector2i(0, 0))
	f.hqs.clear()
	f.territory_of.clear()
	f.territory.clear()
	f.hq_level.clear()
	f.hq_food.clear()
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

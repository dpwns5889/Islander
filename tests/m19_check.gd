extends SceneTree
## 본부 영역·낚시터 공격 점검: godot --headless --script tests/m19_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 1. 본부 영역: 시작은 3x3, 건설과 생산은 영역 안에서만
	var f: Field = _line(10)
	f.territory_enabled = true
	f.claim_start(Vector2i(4, 5))
	fails += _check(f.territory.size() == 9 and f.in_territory(Vector2i(5, 6)) and not f.in_territory(Vector2i(7, 5)), "시작 영역은 본부 주변 3x3")
	fails += _check(f.can_build(Balance.HOUSE, Vector2i(5, 5)) and not f.can_build(Balance.HOUSE, Vector2i(7, 5)), "건설은 영역 안에서만")
	f.build(Balance.HOUSE, Vector2i(5, 5))
	f.build(Balance.HOUSE, Vector2i(8, 5)) # 영역 밖에 지어진 집은 생산하지 않는다
	fails += _check(f.income().x == 10, "영역 밖 집은 골드를 못 낸다 (%d)" % f.income().x)
	# 2. 레벨업: 영역과 붙은 칸이 1개씩 늘고, 겹친 본부는 하나로 이어진다
	f.grow_territory(Vector2i(4, 5), 3)
	fails += _check(f.territory.size() == 12, "레벨마다 영역 +1칸 (3칸 → %d)" % f.territory.size())
	var connected: bool = true
	for c in f.territory:
		var near: bool = false
		for d in Field.DIRS:
			near = near or f.territory.has(c + d)
		connected = connected and near
	fails += _check(connected, "늘어난 칸은 영역과 이어져 있다")
	f.claim_start(Vector2i(6, 5)) # 두 번째 본부와 영역이 겹친다
	var edges_inside: int = f._terr_nodes.size()
	fails += _check(f.territory_of.size() == 2 and f.in_territory(Vector2i(5, 5)) and edges_inside > 0, "본부 둘의 영역 합집합")
	var perimeter: int = 0
	for c in f.territory:
		for d in Field.DIRS:
			if not f.territory.has(c + d):
				perimeter += 1
	fails += _check(f._terr_nodes.size() == perimeter, "경계선은 합집합의 바깥만 그린다 (겹친 안쪽에는 없다)")
	# 3. 본부가 파괴되면 그 영역이 사라진다
	f.hqs[Vector2i(6, 5)] = 1.0
	f._nodes[Vector2i(6, 5)] = []
	f.hqs[Vector2i(4, 5)] = 1.0
	f.damage(Vector2i(6, 5), 5.0)
	fails += _check(f.territory_of.size() == 1 and not f.in_territory(Vector2i(8, 6)), "파괴된 본부의 영역은 사라진다")
	# 4. 식량 정산: 평원 칸 +1은 영역 안만 (영역 3x3 안 평원 2칸)
	var pf: Field = _line(10)
	pf.territory_enabled = true
	pf.claim_start(Vector2i(4, 5))
	fails += _check(pf.income().y == 2, "평원 식량은 영역 안 2칸만 (%d)" % pf.income().y)
	# 5. 낚시터: 해적은 육지 쪽에서 낚시터를 공격한다
	var lf: Field = _line(6)
	var wcell: Vector2i = Vector2i(6, 6) # 땅(4..9, 5) 바로 아래 물
	lf.build(Balance.FISHERY, wcell)
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var b: Battle = Battle.new()
	b.setup(lf, gs, 1)
	b._ships_left = 1
	b._ship_timer = 9999.0
	for s in b.soldiers.duplicate():
		b.soldiers.erase(s)
		s.hp = 0.0
	b.islands = lf.island_map()
	var lone: Unit = b._add_unit(Balance.U_PIRATE, lf.cell_to_world(Vector2i(8, 5)), 1.0)
	lone.island = b.islands[Vector2i(8, 5)]
	lf.hqs.clear() # 낚시터만 목표로 남긴다
	var hp0: float = lf.hp[wcell]
	for _i in 200:
		b._pirate_turn(lone, 0.1)
	fails += _check(lf.hp[wcell] < hp0 or not lf.buildings.has(wcell), "해적이 육지 쪽에서 낚시터를 공격한다 (%.1f → %.1f)" % [hp0, lf.hp.get(wcell, 0.0)])
	print("본부 영역 점검 실패 %d건" % fails)
	quit(fails)


## 땅 한 줄 (4..4+n-1, 5), 모두 평원
func _line(n: int) -> Field:
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for i in n:
		p.cells.append(Vector2i(i, 0))
		p.terrain.append(Piece.PLAINS)
	f.place(p, Vector2i(4, 5))
	f.hqs.clear()
	f.territory_of.clear()
	f.territory.clear()
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

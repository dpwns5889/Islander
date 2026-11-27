extends SceneTree
## 숲·산 지형 점검: godot --headless --script tests/m18_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 2. 건설 조건: 숲은 집·도서관·방어탑, 산은 방어탑만
	var f: Field = _field()
	fails += _check(f.can_build(Balance.HOUSE, Vector2i(5, 5)) and f.can_build(Balance.LIBRARY, Vector2i(5, 5)) and f.can_build(Balance.TOWER, Vector2i(5, 5)), "숲: 집·도서관·방어탑")
	fails += _check(not f.can_build(Balance.FARM, Vector2i(5, 5)) and not f.can_build(Balance.BARRACKS, Vector2i(5, 5)) and not f.can_build(Balance.LAB, Vector2i(5, 5)), "숲: 밭·병영·연구소 불가")
	fails += _check(f.can_build(Balance.TOWER, Vector2i(6, 5)) and not f.can_build(Balance.HOUSE, Vector2i(6, 5)) and not f.can_build(Balance.PORT, Vector2i(6, 5)), "산: 방어탑만")
	fails += _check(f.can_build(Balance.FARM, Vector2i(7, 5)), "평원: 전부")
	# 3. 식량: 평원 칸만 (숲·산은 0)
	fails += _check(f.income().y == 3, "식량은 평원 칸 3개만 (%d)" % f.income().y)
	# 4. 산은 걸을 수 없다: 길찾기에서 막히고 섬이 갈라진다
	fails += _check(f.is_land(Vector2i(6, 5)) and not f.is_walkable(Vector2i(6, 5)) and f.is_walkable(Vector2i(5, 5)), "산은 땅이지만 걸을 수 없다")
	var isl: Dictionary = f.island_map()
	fails += _check(isl.has(Vector2i(5, 5)) and not isl.has(Vector2i(6, 5)) and isl[Vector2i(5, 5)] != isl[Vector2i(7, 5)], "산으로만 이어진 땅은 서로 다른 섬")
	fails += _check(f.path(f.nav(false), Vector2i(5, 5), Vector2i(7, 5)).is_empty(), "산을 지나는 길은 없다")
	# 5. 숲 위 이동속도 ×0.7
	fails += _check(absf(f.speed_mult_at(f.cell_to_world(Vector2i(5, 5))) - Balance.FOREST_SPEED) < 0.001 and f.speed_mult_at(f.cell_to_world(Vector2i(7, 5))) == 1.0, "숲 0.7배, 평원 1배")
	# 6. 산 위 방어탑: 근접 적은 못 건드리고 사거리 안의 원거리 적만 노린다
	f.build(Balance.TOWER, Vector2i(6, 5))
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var b: Battle = Battle.new()
	b.setup(f, gs)
	b.launch_wave(1)
	b._ships_left = 1
	b._ship_timer = 9999.0
	for s in b.soldiers.duplicate(): # 병사는 치워 둔다
		b.soldiers.erase(s)
		s.hp = 0.0
	var tpos: Vector3 = f.cell_to_world(Vector2i(6, 5))
	var melee: Unit = b._add_unit(Balance.U_PIRATE, tpos + Vector3(1.0, 0.0, 0.5), 1.0)
	var island_id: int = b.islands[Vector2i(7, 5)]
	melee.island = island_id
	melee.speed = 0.0
	var tower_hp: float = f.hp[Vector2i(6, 5)]
	for _i in 30:
		b._pirate_turn(melee, 0.1)
	fails += _check(f.hp[Vector2i(6, 5)] == tower_hp, "근접 적은 산 위 방어탑을 공격하지 못한다")
	var xbow: Unit = b._add_unit(Balance.U_CROSSBOW, tpos + Vector3(2.0, 0.0, 0.0), 1.0)
	xbow.island = island_id
	xbow.speed = 0.0
	xbow.cooldown = 0.0
	for _i in 10:
		b._pirate_turn(xbow, 0.1)
	fails += _check(f.hp[Vector2i(6, 5)] < tower_hp or not f.buildings.has(Vector2i(6, 5)), "원거리 적은 사거리 안의 산 위 방어탑을 공격한다")
	print("숲·산 점검 실패 %d건" % fails)
	quit(fails)


## 땅 한 줄(4..8, 5): 숲 (5) · 산 (6) · 평원 (7) 등 (4와 8은 평원)
func _field() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
	var terr: Array[int] = [Piece.PLAINS, Piece.FOREST, Piece.MOUNTAIN, Piece.PLAINS, Piece.PLAINS]
	var p: Piece = Piece.new()
	for i in 5:
		p.cells.append(Vector2i(i, 0))
		p.terrain.append(terr[i])
	p.hq_index = 0
	f.place(p, Vector2i(4, 5))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

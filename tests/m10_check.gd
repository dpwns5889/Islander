extends SceneTree
## 전투 개선(배속·겹침 방지·본부 일회 생산·전투 중 집결지) 점검: godot --headless --script tests/m10_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 1. 같은 자리에 12명을 세워도 서로 밀어내 겹치지 않고, 땅 밖으로 나가지 않는다
	var b: Battle = _battle(_island(5), 100, 20)
	for i in 12:
		b._add_unit(Balance.U_SOLDIER, b.field.cell_to_world(Vector2i(6, 6)), 1.0)
	for _i in 60:
		b.tick(0.1)
	var min_d: float = INF
	var on_land: bool = true
	for i in b.soldiers.size():
		on_land = on_land and b.field.is_land(b.field.world_to_cell(b.soldiers[i].position))
		for j in range(i + 1, b.soldiers.size()):
			var a: Vector3 = b.soldiers[i].position
			var c: Vector3 = b.soldiers[j].position
			min_d = minf(min_d, Vector2(a.x - c.x, a.z - c.z).length())
	fails += _check(min_d >= Balance.UNIT_GAP * 0.9, "유닛 사이 최소 거리 %.2f (기준 %.2f)" % [min_d, Balance.UNIT_GAP])
	fails += _check(on_land, "밀려나도 땅 위에 있다")
	# 2. 본부는 전투 시작에 수비병 2명만 만들고 계속 만들지 않는다 (자원도 쓰지 않는다)
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = 100
	gs.food = 20
	var b2: Battle = Battle.new()
	b2.setup(_island(5), gs, 1)
	b2._ships_left = 1
	b2._ship_timer = 9999.0
	fails += _check(b2.soldiers.size() == Balance.HQ_GUARDS, "시작: 수비병 %d명" % Balance.HQ_GUARDS)
	for _i in 600:
		b2.tick(0.1)
	fails += _check(b2.soldiers.size() == Balance.HQ_GUARDS and gs.gold == 100 and gs.food == 20, "60초가 지나도 병사가 늘지 않고 자원도 그대로")
	# 3. 배속: 4배면 0.25초에 1.0초가 흐른다
	var b3: Battle = _battle(_island(5), 100, 20)
	b3.speed_scale = 4.0
	b3._process(0.25)
	fails += _check(absf(b3.time - 1.0) < 0.001, "배속 x4: 0.25초 → 전투 시간 %.2f" % b3.time)
	# 4. 클릭 이동: 같은 섬의 적이 없으면 클릭한 곳 가까이 모이고, 도착하면 명령이 끝난다
	var f4: Field = _island(10)
	var b4: Battle = _battle(f4, 100, 20)
	b4.command_move(Vector2i(13, 6))
	fails += _check(b4.soldiers[0].order == Vector2i(13, 6), "모든 병사에게 이동 명령")
	for _i in 120:
		b4.tick(0.1)
	var far_away: int = 0
	for s in b4.soldiers:
		if Vector2(s.position.x - f4.cell_to_world(Vector2i(13, 6)).x, s.position.z - f4.cell_to_world(Vector2i(13, 6)).z).length() > 2.0:
			far_away += 1
	fails += _check(far_away == 0 and b4.soldiers.size() >= 2, "클릭한 곳으로 병사가 이동한다 (멀리 남은 병사 %d명)" % far_away)
	var arrived: bool = true
	for s in b4.soldiers:
		arrived = arrived and s.order.x == -1
	fails += _check(arrived, "도착하면 이동 명령이 끝난다 (깃발처럼 계속 남지 않는다)")
	b4.command_move(Vector2i(4, 4))
	b4.clear_orders()
	fails += _check(b4.soldiers[0].order == Vector2i(-1, -1), "이동 취소")
	# 5. 이동 중에도 가까운 적(3칸 안)은 상대한다
	var f5: Field = _island(10)
	var b5: Battle = _battle(f5, 100, 20)
	b5.command_move(Vector2i(13, 6))
	var near_pirate: Unit = b5._add_unit(Balance.U_PIRATE, b5.soldiers[0].position + Vector3(2.0, 0.0, 0.0), 1.0)
	near_pirate.island = b5.soldiers[0].island
	var hp0: float = near_pirate.hp
	for _i in 15:
		b5.tick(0.1)
	fails += _check(near_pirate.hp < hp0, "가까운 적은 이동 명령 중에도 공격한다")
	# 6. 다른 섬을 클릭하면 항구의 보트로 건너간다
	var f6: Field = _two_islands()
	var b6: Battle = _battle(f6, 100, 20)
	b6.command_move(Vector2i(13, 7))
	var island_b: int = b6.islands[Vector2i(12, 5)]
	var crossed: bool = false
	for _i in 400:
		b6.tick(0.1)
		for s in b6.soldiers:
			crossed = crossed or s.island == island_b
	fails += _check(crossed, "클릭한 곳이 다른 섬이면 보트로 건너간다")
	print("전투 개선 점검 실패 %d건" % fails)
	quit(fails)


func _battle(f: Field, gold: int, food: int) -> Battle:
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = gold
	gs.food = food
	var b: Battle = Battle.new()
	b.setup(f, gs, 1)
	b._ships_left = 1 # 웨이브가 끝나 버리지 않도록 배 1척을 남겨 둔다
	b._ship_timer = 9999.0
	return b


## 가로 w칸, 세로 5칸 평원 섬 (4,4)부터. 본부는 (5,6)
func _island(w: int) -> Field:
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for y in 5:
		for x in w:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 2 * w + 1
	f.place(p, Vector2i(4, 4))
	return f


## 왼쪽 섬 A(본부, 항구)와 오른쪽 섬 B. 사이는 바다
func _two_islands() -> Field:
	var f: Field = Field.new()
	var a: Piece = Piece.new()
	for y in 5:
		for x in 5:
			a.cells.append(Vector2i(x, y))
			a.terrain.append(Piece.PLAINS)
	a.hq_index = 12
	f.place(a, Vector2i(2, 5))
	var b: Piece = Piece.new()
	for y in 5:
		for x in 3:
			b.cells.append(Vector2i(x, y))
			b.terrain.append(Piece.PLAINS)
	f.place(b, Vector2i(12, 5))
	f.build(Balance.PORT, Vector2i(6, 7))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

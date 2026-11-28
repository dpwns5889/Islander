extends SceneTree
## R4 개척자 로직 점검: 비용 증가, 정착 조건(평원·모래, 건물 없음, 다른 도시와 4칸), 생산(30초, 도시마다 1명, 취소·도시 붕괴 환불),
## 개척자는 싸우지 않고 해적의 목표가 된다, 이동 명령, 도시가 늘면 분대 상한·적 배율·기본 수입이 오른다
## godot --headless --script tests/r4_check.gd


func _initialize() -> void:
	var fails: int = 0
	fails += _check(Balance.settler_cost(1) == Vector2i(30, 30) and Balance.settler_cost(2) == Vector2i(45, 45) and Balance.settler_cost(3) == Vector2i(60, 60), "개척자 비용: 30 → 45 → 60 (도시마다 +50%)")
	var f: Field = _island()
	var hq: Vector2i = f.hq
	fails += _check(hq == Vector2i(2, 6), "섬 왼쪽 끝의 첫 도시 (%s)" % hq)
	# 정착 조건
	fails += _check(f.found_block(Vector2i(-3, 6)) != "", "바다에는 세울 수 없다")
	fails += _check(f.found_block(hq + Vector2i(3, 0)) != "" and f.found_block(hq + Vector2i(3, 3)) != "", "다른 도시와 3칸(대각선 포함)이면 안 된다")
	fails += _check(f.found_block(hq + Vector2i(4, 0)) == "" and f.found_block(hq + Vector2i(4, -2)) == "", "4칸 떨어지면 된다")
	f.build(Balance.HOUSE, hq + Vector2i(5, 0))
	fails += _check("건물" in f.found_block(hq + Vector2i(5, 0)), "건물이 있는 칸에는 못 세운다")
	# 생산
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = 100
	gs.food = 100
	var b: Battle = Battle.new()
	b.setup(f, gs)
	fails += _check(b.queue_settler(hq) and gs.gold == 70 and gs.food == 70, "개척자 생산: 골드 30 · 식량 30")
	fails += _check(not b.queue_settler(hq), "도시마다 한 번에 1명")
	fails += _check(b.cancel_settler(hq) and gs.gold == 100 and gs.food == 100, "취소하면 전액 환불")
	b.queue_settler(hq)
	for _i in 295:
		b.tick(0.1)
	fails += _check(b.settlers().is_empty(), "30초 전에는 나오지 않는다")
	for _i in 10:
		b.tick(0.1)
	var s: Unit = null if b.settlers().is_empty() else b.settlers()[0]
	fails += _check(s != null and s.squad == 0 and s.hp == 20.0 and b.squads.size() == 1 and b.squad_count() == 1, "30초 뒤 개척자 (체력 20, 분대에 들지 않는다)")
	if s == null:
		print("개척자가 없어 나머지를 건너뛴다")
		quit(fails)
		return
	# 이동 명령: 도착하면 선다
	var dest: Vector2i = hq + Vector2i(6, 0)
	s.order = dest
	for _i in 80:
		b.tick(0.1)
	fails += _check(s.home == dest and s.order.x < 0 and s.position.distance_to(f.cell_to_world(dest) + Vector3(0, s.position.y, 0)) <= 0.61, "명령한 칸까지 걸어가고 그 칸이 집이 된다 (%s)" % s.home)
	var still: Vector3 = s.position
	for _i in 20:
		b.tick(0.1)
	fails += _check(s.position.distance_to(still) < 0.05, "명령이 없으면 그 자리에 선다")
	# 해적은 개척자를 노리고, 개척자는 반격하지 않는다 (경비병은 멀리)
	for g in b.squad_units(1):
		g.position = f.cell_to_world(hq)
		g.home = hq
	var p: Unit = b._add_unit(Balance.U_PIRATE, s.position + Vector3(0.5, 0.0, 0.0), 1.0)
	p.island = s.island
	var php: float = p.hp
	for _i in 15:
		b.tick(0.1)
	fails += _check(s.hp < 20.0 and is_equal_approx(p.hp, php), "해적이 개척자를 때리고, 개척자는 반격하지 않는다 (개척자 %.1f)" % s.hp)
	p.hp = 0.0
	b.tick(0.1)
	# 도시가 무너지면 생산 중인 개척자를 환불
	gs.gold = 100
	gs.food = 100
	b.queue_settler(hq)
	f.damage(hq, 9999.0)
	b.tick(0.1)
	fails += _check(not b.settler_jobs.has(hq) and gs.gold == 100 and gs.food == 100, "도시가 무너지면 개척자 비용 환불")
	# 도시가 늘면: 분대 상한 +1, 적 배율 +0.15, 기본 골드 +20
	var f2: Field = _island()
	var g1: int = f2.income().x
	f2.found_city(f2.hq + Vector2i(6, 0))
	var b2: Battle = Battle.new()
	b2.setup(f2, gs)
	fails += _check(b2.squad_cap() == 4 and is_equal_approx(Balance.enemy_mult(f2.hqs.size()), 1.15) and f2.income().x >= g1 + Balance.HQ_BASE_GOLD, "도시 2개: 분대 상한 4, 적 배율 1.15, 기본 골드 +20")
	fails += _check(f2.territory_of.size() == 2 and f2.territory_of[f2.hq + Vector2i(6, 0)].size() > 1, "새 도시도 영역을 받는다")
	print("R4 점검 실패 %d건" % fails)
	quit(fails)


## 가로 14칸 × 세로 5칸 평원 섬(0..13, 4..8), 첫 도시는 (2, 6)
func _island() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
	var pc: Piece = Piece.new()
	for y in 5:
		for x in 14:
			pc.cells.append(Vector2i(x, y))
			pc.terrain.append(Piece.PLAINS)
	pc.hq_index = 2 * 14 + 2
	f.place(pc, Vector2i(0, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

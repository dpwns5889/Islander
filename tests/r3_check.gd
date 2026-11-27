extends SceneTree
## R3 분대 로직 점검: 시작 분대, 번호(가장 작은 빈 번호), 상한, 병영 생산(비용·대기열 3칸·30초·병종·연구),
## 취소·병영 붕괴 환불, 충원(병영 2칸), 분대별 이동 명령, 파손 병영의 약한 병사
## godot --headless --script tests/r3_check.gd


func _initialize() -> void:
	var fails: int = 0
	fails += _check(Balance.squad_cap(1) == 3 and Balance.squad_cap(3) == 5 and Balance.squad_cap(20) == 9, "분대 수 상한: 3 + (도시 − 1), 최대 9")
	var f: Field = _island()
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.gold = 1000
	gs.food = 1000
	var b: Battle = Battle.new()
	b.setup(f, gs)
	fails += _check(b.squads.size() == 1 and b.squads[1]["kind"] == Balance.U_GUARD and b.squad_units(1).size() == Balance.HQ_GUARDS and b.squad_units(1)[0].home == f.hq, "시작 경비병 2명이 1번 분대, 집은 도시")
	var bar: Vector2i = Vector2i(7, 6)
	fails += _check(not b.queue_squad(bar, "melee"), "병영이 없으면 생산할 수 없다")
	f.build(Balance.BARRACKS, bar)
	# 생산: 비용, 연구
	fails += _check(b.queue_squad(bar, "melee") and gs.gold == 970 and gs.food == 985 and b.squad_count() == 2, "근접 분대: 골드 30 · 식량 15, 대기열도 상한에 센다")
	fails += _check(not b.queue_squad(bar, "ranged"), "궁술 전에는 원거리 분대 불가")
	gs.researched["archery"] = true
	fails += _check(b.queue_squad(bar, "ranged") and gs.gold == 940 and gs.food == 975, "원거리 분대: 골드 30 · 식량 10")
	fails += _check(not b.queue_squad(bar, "melee") and b.squad_count() == 3, "상한 3에 닿으면 생산 불가")
	# 취소는 전액 환불
	fails += _check(b.cancel_squad(bar, 1) and gs.gold == 970 and gs.food == 985 and b.queues[bar].size() == 1, "대기열 취소: 비용 환불")
	# 대기열 3칸 (상한을 늘려 확인)
	f.hqs[Vector2i(-50, -50)] = Balance.HQ_HP
	f.hqs[Vector2i(-51, -50)] = Balance.HQ_HP
	f.hqs[Vector2i(-52, -50)] = Balance.HQ_HP
	fails += _check(b.squad_cap() == 6 and b.queue_squad(bar, "melee") and b.queue_squad(bar, "melee") and not b.queue_squad(bar, "melee"), "병영 대기열은 3칸")
	b.cancel_squad(bar, 2)
	b.cancel_squad(bar, 1)
	for k in [Vector2i(-50, -50), Vector2i(-51, -50), Vector2i(-52, -50)]:
		f.hqs.erase(k)
	# 30초 뒤 맨 앞 분대가 병영에서 나온다
	for _i in 295:
		b.tick(0.1)
	fails += _check(not b.squads.has(2), "30초 전에는 나오지 않는다")
	for _i in 10:
		b.tick(0.1)
	fails += _check(b.squads.has(2) and b.squads[2]["kind"] == Balance.U_GUARD and b.squad_units(2).size() == 3 and b.squad_units(2)[0].home == bar and not b.queues.has(bar), "30초 뒤 2번 분대: 경비병 3명, 집은 병영")
	# 병종은 생산을 시작할 때의 병영 레벨
	f.upgrade(bar)
	b.queue_squad(bar, "melee")
	fails += _check(b.queues[bar][0]["kind"] == Balance.U_SPEAR, "병영 레벨 2: 창병 분대")
	b.cancel_squad(bar, 0)
	# 분대별 이동 명령
	var dest: Vector2i = Vector2i(5, 5)
	b.command_move(dest, [2])
	fails += _check(b.squad_units(2).all(func(u: Unit) -> bool: return u.order == dest) and b.squad_units(1).all(func(u: Unit) -> bool: return u.order.x < 0), "고른 분대만 이동 명령을 받는다")
	for u in b.squad_units(2):
		u.order = Vector2i(-1, -1)
	# 충원: 병영 2칸 안, 1명당 근접 골드 10 · 식량 5
	var lost: Unit = b.squad_units(2)[0]
	lost.hp = 0.0
	b.tick(0.1)
	var g0: int = gs.gold
	var f0: int = gs.food
	fails += _check(b.squad_units(2).size() == 2 and b.reinforce_site(2) == bar and b.reinforce_cost(2) == Vector2i(10, 5), "1명이 죽으면 병영 곁에서 충원 가능 (10G · 식량 5)")
	fails += _check(b.reinforce(2) and b.squad_units(2).size() == 3 and gs.gold == g0 - 10 and gs.food == f0 - 5 and b.squad_units(2)[2].home == bar, "충원하면 정원이 차고 집을 이어받는다")
	fails += _check(not b.reinforce(2), "정원이 차 있으면 충원하지 않는다")
	b.squad_units(2)[0].hp = 0.0
	b.tick(0.1)
	for u in b.squad_units(2):
		u.position = f.cell_to_world(bar + Vector2i(3, 0))
	fails += _check(b.reinforce_site(2) == Battle.NO_CELL, "병영에서 2칸보다 멀면 충원할 수 없다")
	# 분대원이 모두 죽으면 번호가 비고, 다음 분대가 가장 작은 번호를 받는다
	for u in b.squad_units(1):
		u.hp = 0.0
	b.tick(0.1)
	fails += _check(not b.squads.has(1) and b.squads.has(2), "1번 분대가 전멸하면 번호가 빈다")
	b.queue_squad(bar, "melee")
	for _i in 305:
		b.tick(0.1)
	fails += _check(b.squads.has(1) and b.squads[1]["kind"] == Balance.U_SPEAR, "새 분대는 비어 있는 가장 작은 번호(1)를 받는다")
	# 파손된 병영의 병사는 약하다
	for u in b.squad_units(1):
		u.hp = 0.0
	b.tick(0.1)
	f.damage(bar, f.max_hp(bar) * 0.7)
	b.queue_squad(bar, "melee")
	for _i in 305:
		b.tick(0.1)
	var worn: Unit = b.squad_units(1)[0]
	fails += _check(is_equal_approx(worn.hp, Balance.UNITS[Balance.U_SPEAR]["hp"] * 0.65), "병영 체력 30%%: 병사 체력 65%% (%.1f)" % worn.hp)
	# 병영이 무너지면 대기열을 모두 환불한다
	b.queue_squad(bar, "ranged")
	g0 = gs.gold
	f.damage(bar, 9999.0)
	b.tick(0.1)
	fails += _check(not b.queues.has(bar) and gs.gold == g0 + 30, "병영이 무너지면 대기열 환불")
	print("R3 점검 실패 %d건" % fails)
	quit(fails)


func _island() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
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

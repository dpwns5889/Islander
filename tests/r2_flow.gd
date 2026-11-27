extends SceneTree
## R2 화면 흐름 점검: 실시간 루프 — 10초 생산 틱, 3분 뒤 첫 웨이브와 2분 간격, 웨이브 부르기 보너스, 겹치는 웨이브,
## 일시정지·배속, 5초 수리와 적 근처 금지, 교역 NPC 시간 일정, 30웨이브 승리, 전투 중 건설
## godot --headless --script tests/r2_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	var f: Field = main.field
	fails += _check(main.battle == null and main.game_time == 0.0, "도시를 세우기 전에는 시간이 흐르지 않는다")
	main.advance(100.0)
	fails += _check(main.game_time == 0.0, "시작 전 advance는 무시")
	main.found_start(preload("res://tests/coastal_start.gd").pick(f))
	var b: Battle = main.battle
	fails += _check(b != null and is_equal_approx(main.wave_timer, Balance.WAVE_FIRST_DELAY), "첫 도시를 세우면 전투가 돌고 첫 웨이브까지 3분")
	# 생산 틱
	var g0: int = gs.gold
	var inc: Vector2i = f.income(gs.researched)
	main.advance(9.0)
	fails += _check(gs.gold == g0, "10초 전에는 생산이 없다")
	main.advance(1.5)
	fails += _check(gs.gold == g0 + inc.x and f.hq_food[f.hq] == inc.y, "10초마다 골드 +%d, 도시 식량 누적 +%d" % [inc.x, inc.y])
	# 전투 중에도 건설
	gs.gold = 1000
	main.set_build(Balance.BARRACKS)
	var built: bool = false
	for c: Vector2i in f.territory_of[f.hq]:
		if not built and main.try_build(c):
			built = true
	fails += _check(built and b.soldiers.size() == Balance.HQ_GUARDS + 3, "병영을 지으면 바로 정원 3명 (병사 %d)" % b.soldiers.size())
	# 첫 웨이브
	main.advance(Balance.WAVE_FIRST_DELAY - main.game_time + 0.1)
	fails += _check(gs.wave == 2 and b.enemies_left() > 0 and main.wave_timer > Balance.WAVE_INTERVAL - 1.0, "3분이 지나면 1웨이브가 오고 다음은 2분 뒤 (남은 적 %d)" % b.enemies_left())
	# 웨이브 부르기: 남은 시간 1초당 골드 0.5
	main.advance(20.0)
	var left: float = main.wave_timer
	g0 = gs.gold
	fails += _check(main.call_wave() and gs.gold == g0 + floori(left * Balance.CALL_WAVE_GOLD) and gs.wave == 3, "웨이브 부르기: 골드 +%d, 2웨이브가 바로 온다" % floori(left * Balance.CALL_WAVE_GOLD))
	fails += _check(is_equal_approx(main.wave_timer, Balance.WAVE_INTERVAL), "부르면 다음 타이머는 2분부터")
	# 일시정지
	main.toggle_pause()
	fails += _check(main.paused and b.speed_scale == 0.0 and main._speed() == 0.0, "일시정지면 시간이 멈춘다")
	var t0: float = main.game_time
	main._process(1.0)
	fails += _check(main.game_time == t0, "일시정지 중에는 게임 시간이 흐르지 않는다")
	main.set_build(Balance.HOUSE)
	built = false
	for c: Vector2i in f.territory_of[f.hq]:
		if not built and main.try_build(c):
			built = true
	fails += _check(built, "일시정지 중에도 건설할 수 있다")
	main.toggle_pause()
	main.cycle_speed()
	fails += _check(not main.paused and b.speed_scale == 2.0, "배속 x2")
	main.cycle_speed()
	main.cycle_speed()
	# 수리: 5초에 걸쳐 차고, 3칸 안에 적이 있으면 못 한다
	b.clear_enemies()
	var house: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in f.buildings:
		if f.buildings[c] == Balance.HOUSE:
			house = c
	f.damage(house, f.max_hp(house) * 0.8)
	var enemy: Unit = b._add_unit(Balance.U_PIRATE, f.cell_to_world(house), 1.0)
	fails += _check(not main.can_repair(house), "적이 3칸 안이면 수리할 수 없다")
	enemy.queue_free()
	b.pirates.erase(enemy)
	main.select_building(house)
	g0 = gs.gold
	var cost: int = f.repair_cost(house)
	fails += _check(main.repair_selected() and gs.gold == g0 - cost and f.hp_ratio(house) < 1.0, "수리 비용을 내면 바로 다 차지 않는다")
	fails += _check(not main.repair_selected(), "수리 중에는 다시 수리하지 않는다")
	main.advance(2.5)
	var mid: float = f.hp_ratio(house)
	main.advance(3.0)
	fails += _check(mid > 0.6 and mid < 1.0 and f.hp_ratio(house) >= 1.0 and not main.repairing.has(house), "5초에 걸쳐 체력이 찬다 (중간 %.2f)" % mid)
	# 교역 NPC: 지은 지 2분 뒤, 60초 머문다, 6분마다
	gs.researched["commerce"] = true
	main.set_build(Balance.TRADING_POST)
	var post: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in f.territory_of[f.hq]:
		if post.x < 0 and main.try_build(c):
			post = c
	fails += _check(post.x >= 0 and is_equal_approx(main.npc_next_time, main.game_time + Balance.TRADE_FIRST_DELAY), "교역소를 지으면 2분 뒤 방문 예정")
	main.advance(Balance.TRADE_FIRST_DELAY + 0.1)
	fails += _check(main.npc_present, "2분 뒤 NPC 방문")
	main.advance(Balance.TRADE_STAY)
	fails += _check(not main.npc_present, "60초 뒤 떠난다")
	b.clear_enemies()
	# 30웨이브 승리
	gs.wave = Balance.WIN_WAVE
	main.call_wave()
	fails += _check(main.last_wave_time >= 0.0 and not main.victory_shown, "30웨이브가 왔다")
	b.clear_enemies()
	main.advance(0.1)
	fails += _check(main.victory_shown, "30웨이브 뒤 적이 모두 사라지면 승리")
	print("R2 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

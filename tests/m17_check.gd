extends SceneTree
## 적 곡선·적 종류·성벽·방어탑 점검: godot --headless --script tests/m17_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 1. 예산 곡선: 기준점, 단조 증가(보스 라운드의 선장은 따로)
	var mono: bool = true
	for n in range(1, 41):
		mono = mono and Balance.wave_budget(n + 1) >= Balance.wave_budget(n)
	fails += _check(mono, "웨이브가 오를수록 총 전투력이 줄지 않는다")
	fails += _check(Balance.wave_budget(1) == 2 and Balance.wave_budget(10) == 12 and Balance.wave_budget(30) == 110, "예산 기준점 2/12/110")
	fails += _check(Balance.wave_budget(30) - Balance.wave_budget(20) > Balance.wave_budget(10) - Balance.wave_budget(1), "뒤로 갈수록 가파르다(곡선)")
	var same: bool = true
	for n in range(1, 41):
		same = same and Balance.enemy_composition(n, 7) == Balance.enemy_composition(n, 7) and Balance.wave_power(n, 7) == Balance.wave_budget(n) + Balance.CAPTAINS.get(n, 0) * 8
	fails += _check(same, "같은 시드·웨이브는 같은 구성, 총 전투력 = 예산(+선장)")
	var differs: bool = false
	for sd in range(1, 30):
		differs = differs or Balance.enemy_composition(15, sd) != Balance.enemy_composition(15, 0)
	fails += _check(differs, "시드가 다르면 구성이 달라진다")
	# 2. 구성: 합계, 선장은 보스 라운드만, 새 종류는 정해진 웨이브부터
	var comp_ok: bool = true
	for n in range(1, 41):
		var comp: Dictionary = Balance.enemy_composition(n, 3)
		var total: int = 0
		for k in comp:
			total += comp[k]
			if Balance.ENEMY_FIRST_WAVE.has(k) and n < Balance.ENEMY_FIRST_WAVE[k]:
				comp_ok = false
		comp_ok = comp_ok and total == Balance.pirate_count(n, 3)
	fails += _check(comp_ok, "모든 웨이브: 구성 합계 = 적 수, 새 종류는 첫 등장 웨이브부터")
	var caps: Array[int] = []
	for n in range(1, 41):
		caps.append(Balance.enemy_composition(n, 3).get(Balance.U_CAPTAIN, 0))
	fails += _check(caps[9] == 1 and caps[19] == 2 and caps[29] == 2, "선장: 10웨이브 1, 20웨이브 2, 30웨이브 2")
	var other_caps: int = 0
	for n in range(1, 41):
		if n != 10 and n != 20 and n != 30:
			other_caps += caps[n - 1]
	fails += _check(other_caps == 0, "보스 라운드가 아니면 선장이 없다")
	var c5: Dictionary = Balance.enemy_composition(5, 3)
	fails += _check(c5.get(Balance.U_CROSSBOW, 0) >= 1 and not c5.has(Balance.U_AXE), "5웨이브: 신규 석궁수가 1명 이상, 도끼병은 아직 없음")
	var c12: Dictionary = Balance.enemy_composition(12, 3)
	fails += _check(c12.get(Balance.U_SHIELD, 0) >= 1 and c12.get(Balance.U_AXE, 0) >= 1, "12웨이브: 방패병·도끼병 포함")
	fails += _check(Balance.new_enemy_kinds(5) == [Balance.U_CROSSBOW] and Balance.new_enemy_kinds(8) == [Balance.U_AXE] and Balance.new_enemy_kinds(10) == [Balance.U_CAPTAIN] and Balance.new_enemy_kinds(12) == [Balance.U_SHIELD] and Balance.new_enemy_kinds(6).is_empty(), "새 적 등장 웨이브")
	# 갈수록 강하다: 적 전체 체력 합
	var hp_sum: Callable = func(n: int) -> float:
		var t: float = 0.0
		var cmp: Dictionary = Balance.enemy_composition(n, 3)
		for k in cmp:
			t += float(Balance.UNITS[k]["hp"]) * cmp[k]
		return t
	fails += _check(hp_sum.call(4) < hp_sum.call(10) and hp_sum.call(10) < hp_sum.call(20) and hp_sum.call(20) < hp_sum.call(30), "적 전체 체력이 웨이브마다 늘어난다")
	var avg4: float = hp_sum.call(4) / Balance.pirate_count(4, 3)
	var avg30: float = hp_sum.call(30) / Balance.pirate_count(30, 3)
	fails += _check(avg30 > avg4 * 1.5, "한 명당 평균 체력도 크게 늘어난다 (%.0f → %.0f)" % [avg4, avg30])
	# 3. 능력치
	var stats: Dictionary = {Balance.U_CROSSBOW: [18.0, 3.0, 1.1, 1.8], Balance.U_AXE: [40.0, 4.0, 1.2, 0.7], Balance.U_SHIELD: [100.0, 2.0, 0.9, 0.7], Balance.U_CAPTAIN: [80.0, 5.0, 1.1, 0.7]}
	var stats_ok: bool = true
	for k in stats:
		var u: Dictionary = Balance.UNITS[k]
		stats_ok = stats_ok and u["hp"] == stats[k][0] and u["atk"] == stats[k][1] and u["speed"] == stats[k][2] and u["reach"] == stats[k][3]
	fails += _check(stats_ok, "적 능력치 표")
	# 4. 배: 강한 적이 먼저 타고, 합치면 구성과 같다
	var q: Array[int] = Balance.enemy_queue(12, 0)
	fails += _check(q[0] == Balance.U_SHIELD and q[q.size() - 1] == Balance.U_PIRATE, "대기열: 강한 적이 먼저")
	fails += _check(Balance.enemy_queue(10, 0)[0] == Balance.U_CAPTAIN, "보스 라운드는 선장이 먼저")
	var island: Field = _island(5, 5)
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.run_seed = 0
	var b: Battle = Battle.new()
	b.setup(island, gs, 12)
	b.rng.seed = 3
	var kinds: Dictionary = {}
	var first_ship_first: int = -1
	for _i in 600:
		b.tick(0.1)
		for s in b.ships:
			if first_ship_first == -1 and not s.crew_kinds.is_empty():
				first_ship_first = s.crew_kinds[0]
			for idx in s.crew_kinds.size():
				kinds["%d_%d" % [s.get_instance_id(), idx]] = s.crew_kinds[idx]
		if b.done or b._ships_left == 0 and b.ships.is_empty():
			break
	var counted: Dictionary = {}
	for key in kinds:
		counted[kinds[key]] = int(counted.get(kinds[key], 0)) + 1
	fails += _check(counted == Balance.enemy_composition(12, 0) and first_ship_first == Balance.U_SHIELD, "12웨이브 배에 실린 적 = 구성, 첫 배 맨 앞은 방패병 (%s)" % str(counted))
	# 석궁수는 3.5칸 거리에서 쏜다
	var cb: Battle = Battle.new()
	cb.setup(_island(5, 5), load("res://assets/scripts/game_state.gd").new(), 1)
	cb._ships_left = 1
	cb._ship_timer = 9999.0
	var xbow: Unit = cb._add_unit(Balance.U_CROSSBOW, cb.soldiers[0].position + Vector3(1.5, 0.0, 0.0), 1.0)
	xbow.island = cb.soldiers[0].island
	xbow.cooldown = 0.0
	var pos0: Vector3 = xbow.position
	fails += _check(cb._engage(xbow, cb.soldiers[0].position, 0.1) and xbow.position == pos0, "석궁수는 1.5칸 거리에서 움직이지 않고 쏜다")
	# 5. 일반 건물은 목표
	var f: Field = _island(9, 5)
	f.build(Balance.HOUSE, Vector2i(7, 6))
	fails += _check(f.targets().has(Vector2i(7, 6)), "일반 건물은 목표")
	# 8. 방어탑: 땅 위(평원·모래)에 바로 짓고 적의 목표가 된다
	var t: Field = _island(9, 5)
	fails += _check(t.can_build(Balance.TOWER, Vector2i(8, 6)) and not t.can_build(Balance.TOWER, Vector2i(0, 0)), "방어탑은 빈 땅 위에 짓는다")
	t.build(Balance.TOWER, Vector2i(8, 6))
	fails += _check(t.targets().has(Vector2i(8, 6)) and not t.can_build(Balance.TOWER, Vector2i(8, 6)), "방어탑은 목표가 되고 겹쳐 짓지 못한다")
	# 9. 방어탑 공격: 사거리 안의 적만 1초마다, 레벨별 공격력
	for lv in [1, 2, 3]:
		var tf: Field = _island(9, 5)
		tf.build(Balance.TOWER, Vector2i(8, 6))
		for _u in lv - 1:
			tf.upgrade(Vector2i(8, 6))
		var tb: Battle = Battle.new()
		tb.setup(tf, load("res://assets/scripts/game_state.gd").new(), 1)
		tb._ships_left = 1
		tb._ship_timer = 9999.0
		var tpos: Vector3 = tf.cell_to_world(Vector2i(8, 6))
		var near: Unit = tb._add_unit(Balance.U_SHIELD, tpos + Vector3(Balance.TOWER_RANGE_LV[lv - 1] - 0.3, 0.0, 0.0), 1.0)
		near.island = tb.islands[tf.hq]
		near.speed = 0.0 # 움직이지 않게 고정
		var far: Unit = tb._add_unit(Balance.U_SHIELD, tpos + Vector3(Balance.TOWER_RANGE_LV[lv - 1] + 1.0, 0.0, 0.0), 1.0)
		far.island = near.island
		far.speed = 0.0
		var hp_near: float = near.hp
		var hp_far: float = far.hp
		tb._towers_turn(0.0)
		fails += _check(absf(near.hp - (hp_near - Balance.TOWER_ATK_LV[lv - 1])) < 0.001 and far.hp == hp_far, "방어탑 레벨 %d: 사거리 안의 적에게 %.0f 피해, 밖은 무사" % [lv, Balance.TOWER_ATK_LV[lv - 1]])
		if lv == 1:
			fails += _check(tb._fx.size() == 1, "공격 선이 표시된다")
			tb._towers_turn(0.5)
			fails += _check(absf(near.hp - (hp_near - 4.0)) < 0.001, "1초가 지나기 전에는 다시 쏘지 않는다")
			tb._towers_turn(0.6)
			fails += _check(absf(near.hp - (hp_near - 8.0)) < 0.001, "1초 뒤에 다시 쏜다")
			fails += _check(tb._fx.size() <= 1, "선은 짧게 보였다 사라진다")
	# 10. 방어탑은 해적선을 공격하지 않는다
	var sf: Field = _island(9, 5)
	sf.build(Balance.TOWER, Vector2i(8, 6))
	var sb: Battle = Battle.new()
	sb.setup(sf, load("res://assets/scripts/game_state.gd").new(), 1)
	sb._ships_left = 1
	sb._ship_timer = 9999.0
	var ship: Unit = sb._add_unit(Balance.U_SHIP, sf.cell_to_world(Vector2i(8, 6)) + Vector3(1.0, 0.0, 0.0), 1.0)
	var ship_hp: float = ship.hp
	sb._towers_turn(0.0)
	fails += _check(ship.hp == ship_hp, "방어탑은 해적선을 공격하지 않는다")
	# 11. 바다 길이 완전히 막혀도 해적선은 상륙 지점 앞에서 나와 전투가 벌어진다 (전투 없이 끝나지 않는다)
	var bf: Field = _island(5, 5)
	var bb: Battle = Battle.new()
	bb.setup(bf, load("res://assets/scripts/game_state.gd").new(), 3)
	var blocked: AStarGrid2D = bf.nav(true)
	for y in blocked.region.size.y:
		for x in blocked.region.size.x:
			blocked.set_point_solid(Vector2i(x, y), true)
	bb.sea_nav = blocked
	var seen: bool = false
	for _i in 300:
		bb.tick(0.1)
		seen = seen or not bb.ships.is_empty() or not bb.pirates.is_empty()
		if bb.done:
			break
	fails += _check(seen, "길이 막혀도 해적이 나타난다")
	print("적·방어탑 점검 실패 %d건" % fails)
	quit(fails)


## 가로 w, 세로 h 평원 섬 (4,4)부터. 본부는 가운데 왼쪽
func _island(w: int, h: int) -> Field:
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for y in h:
		for x in w:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = (h / 2) * w + 1
	f.place(p, Vector2i(4, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

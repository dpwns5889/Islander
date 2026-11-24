extends SceneTree
## M9 점검: godot --headless --script tests/m9_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 테크트리 구조: 12개, 비용은 단계와 같고 선행은 같은 갈래의 앞 단계
	var n: int = 0
	for branch: Array in Balance.TECH_ORDER:
		for i in branch.size():
			n += 1
			fails += _check(Balance.tech_cost(branch[i]) == i + 1, "%s 비용 %d" % [branch[i], i + 1])
			fails += _check(Balance.tech_prereq(branch[i]) == (branch[i - 1] if i > 0 else ""), "%s 선행" % branch[i])
	fails += _check(n == 12 and Balance.TECHS.size() == 12, "연구 12개")
	# 연구: 포인트와 선행 조건
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.research_points = 1
	fails += _check(not gs.can_research("ship"), "선행(항해술) 없이는 조선술 불가")
	fails += _check(gs.research("sail") and gs.research_points == 0 and gs.has_tech("sail"), "항해술 연구: 포인트 1 소모")
	fails += _check(not gs.research("sail"), "같은 연구를 두 번 못 한다")
	gs.research_points = 1
	fails += _check(not gs.can_research("ship"), "포인트 부족 (조선술 2점)")
	gs.research_points = 2
	fails += _check(gs.research("ship") and gs.research_points == 0, "조선술 연구")
	fails += _check(gs.discounted(20) == 20, "금융 전 할인 없음")
	gs.researched["finance"] = true
	fails += _check(gs.discounted(20) == 17 and gs.discounted(50) == 43, "금융: 20→17, 50→43")
	gs.reset()
	fails += _check(gs.researched.is_empty(), "재시작하면 연구 초기화")
	# 수입 효과
	var f: Field = _island()
	f.build(Balance.HOUSE, Vector2i(5, 5))
	f.build(Balance.FARM, Vector2i(6, 5))
	var plains: int = f.cells.values().count(Piece.PLAINS)
	var hq_gold: int = Balance.HQ_BASE_GOLD * f.hqs.size() # 본부 기본 골드
	fails += _check(f.income() == Vector2i(10 + hq_gold, 5 + plains), "연구 없음: 골드 %d, 식량 %d" % [10 + hq_gold, 5 + plains])
	fails += _check(f.income({"commerce": true}).x == 12 + hq_gold, "상업: 집 골드 +20%")
	fails += _check(f.income({"tools": true}).y == floori(5 * 1.3 + plains), "농기구: 밭 +30%")
	fails += _check(f.income({"tools": true, "harvest": true}).y == floori(5 * 1.8 + plains), "농기구+대풍작: 밭 +80%")
	fails += _check(f.income({"irrigation": true}).y == floori(5 + plains * 1.5), "관개: 평원 칸 1.5")
	# 병종과 연구 효과 (전투)
	var gsb: Node = load("res://assets/scripts/game_state.gd").new()
	gsb.gold = 1000
	gsb.food = 1000
	var f2: Field = _island()
	f2.build(Balance.BARRACKS, Vector2i(6, 6))
	f2.barracks_unit[Vector2i(6, 6)] = Balance.U_ARCHER
	var b: Battle = Battle.new()
	b.setup(f2, gsb, 1)
	var archers: int = 0
	for s in b.soldiers:
		if s.kind == Balance.U_ARCHER:
			archers += 1
			fails += _check(s.reach == 4.0 and s.hp == 20.0 and s.atk == 3.0, "궁수 능력치")
	fails += _check(archers == Balance.BARRACKS_SOLDIERS_LV[0], "병영이 궁수를 %d명 만든다 (%d)" % [Balance.BARRACKS_SOLDIERS_LV[0], archers])
	fails += _check(gsb.gold == 1000 and gsb.food == 1000, "병사 생산은 골드·식량을 쓰지 않는다")
	# 궁수는 사거리 4칸에서 쏜다 (다가가지 않는다)
	var archer: Unit = b.soldiers[b.soldiers.size() - 1]
	var pirate: Unit = b._add_unit(Balance.U_PIRATE, archer.position + Vector3(3.5, 0.0, 0.0), 1.0)
	archer.cooldown = 0.0
	var before: Vector3 = archer.position
	fails += _check(b._engage(archer, pirate.position, 0.1) and archer.position == before, "궁수는 3.5칸 거리에서 움직이지 않고 공격 준비")
	var sword: Unit = b.soldiers[0]
	sword.cooldown = 0.0
	fails += _check(not b._engage(sword, pirate.position, 0.1), "검병은 3.5칸에서는 공격하지 못하고 다가간다")
	# 기병: 속도 2.5
	var f3: Field = _island()
	f3.build(Balance.BARRACKS, Vector2i(6, 6))
	f3.barracks_unit[Vector2i(6, 6)] = Balance.U_CAVALRY
	var b3: Battle = Battle.new()
	b3.setup(f3, gsb, 1)
	var cav: Unit = b3.soldiers[b3.soldiers.size() - 1]
	fails += _check(cav.kind == Balance.U_CAVALRY and cav.speed == 2.5 and cav.hp == 40.0 and cav.atk == 6.0, "기병 능력치")
	# 단련 +20%, 대풍작 식량 -1
	var gs4: Node = load("res://assets/scripts/game_state.gd").new()
	gs4.researched["drill"] = true
	gs4.researched["harvest"] = true
	var b4: Battle = Battle.new()
	b4.setup(_island(), gs4, 1)
	fails += _check(absf(b4.soldiers[0].hp - 36.0) < 0.01 and absf(b4.soldiers[0].atk - 6.0) < 0.01, "단련: 검병 체력 36, 공격 6")
	# 조선술(보트 2척, 속도 +30%), 대양 항해(탑승 +2명)
	var gs5: Node = load("res://assets/scripts/game_state.gd").new()
	gs5.researched["ship"] = true
	gs5.researched["ocean"] = true
	var f5: Field = _island()
	f5.build(Balance.PORT, Vector2i(4, 5))
	var b5: Battle = Battle.new()
	b5.setup(f5, gs5, 1)
	fails += _check(b5.boats.size() == 2, "조선술: 항구당 보트 2척")
	fails += _check(absf(b5.boats[0].speed - 2.5 * 1.3) < 0.001, "조선술: 속도 +30%")
	fails += _check(b5.boat_capacity(b5.boats[0]) == 6, "대양 항해: 탑승 4+2명")
	var b6: Battle = Battle.new()
	b6.setup(f5, load("res://assets/scripts/game_state.gd").new(), 1)
	fails += _check(b6.boats.size() == 1 and b6.boat_capacity(b6.boats[0]) == 4, "연구 없으면 보트 1척, 탑승 4명")
	# 부서진 병영은 복구되지 않고 병종 기록도 사라진다
	f2.build(Balance.BARRACKS, Vector2i(7, 7))
	f2.barracks_unit[Vector2i(7, 7)] = Balance.U_ARCHER
	f2.damage(Vector2i(7, 7), 9999.0)
	f2.repair_all()
	fails += _check(not f2.buildings.has(Vector2i(7, 7)) and not f2.barracks_unit.has(Vector2i(7, 7)), "부서진 병영은 복구되지 않는다")
	print("M9 점검 실패 %d건" % fails)
	quit(fails)


func _island() -> Field:
	var f: Field = Field.new()
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

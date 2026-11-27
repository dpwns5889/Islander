extends SceneTree
## M9 점검: godot --headless --script tests/m9_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 테크트리 구조: 13개, 비용은 열 번호(1~4점), 선행은 모두 존재하는 연구 (문명5식)
	fails += _check(Balance.TECHS.size() == 14, "연구 14개")
	var total: int = 0
	for id in Balance.TECHS:
		total += Balance.tech_cost(id)
		for pre: String in Balance.tech_prereqs(id):
			fails += _check(Balance.TECHS.has(pre) and Balance.TECHS[pre]["col"] < Balance.TECHS[id]["col"], "%s 선행 %s는 앞 열" % [id, pre])
	fails += _check(total == 14, "전부 연구하면 14점 (%d)" % total)
	fails += _check(Balance.tech_prereqs("math").is_empty() and Balance.tech_prereqs("furnace") == ["archery", "ironwork"], "선행이 둘인 연구")
	# 연구: 포인트와 선행 조건
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.research_points = 9
	fails += _check(not gs.can_research("tools"), "선행(도구) 없이는 농기구 불가")
	fails += _check(not gs.can_research("furnace"), "선행 없이는 용광로 불가")
	fails += _check(gs.research("toolmaking") and gs.research_points == 8, "도구 연구: 포인트 1 소모")
	fails += _check(gs.research("tools") and gs.research("waterwheel") and gs.research_points == 6 and gs.has_tech("waterwheel"), "농기구·물레방아 연구: 각 1점")
	fails += _check(not gs.can_research("commerce"), "상업은 화폐가 필요하다")
	fails += _check(not gs.research("waterwheel"), "같은 연구를 두 번 못 한다")
	gs.research_points = 0
	fails += _check(not gs.can_research("engineering"), "포인트 부족 (공학 1점)")
	gs.research_points = 1
	fails += _check(gs.research("engineering") and gs.research_points == 0, "공학 연구")
	gs.researched.erase("engineering")
	fails += _check(gs.upgrade_discounted(20) == 20, "공학 전 할인 없음")
	gs.researched["engineering"] = true
	fails += _check(gs.upgrade_discounted(20) == 16 and gs.upgrade_discounted(50) == 40, "공학: 레벨업 20→16, 50→40")
	gs.reset()
	fails += _check(gs.researched.is_empty(), "재시작하면 연구 초기화")
	# 수입 효과
	var f: Field = _island()
	f.build(Balance.HOUSE, Vector2i(5, 5))
	f.build(Balance.FARM, Vector2i(6, 5))
	var plains: int = f.cells.values().count(Piece.PLAINS)
	var hq_gold: int = Balance.HQ_BASE_GOLD * f.hqs.size() # 본부 기본 골드
	fails += _check(f.income() == Vector2i(10 + hq_gold, 5 + plains), "연구 없음: 골드 %d, 식량 %d" % [10 + hq_gold, 5 + plains])
	fails += _check(f.income({"math": true}).x == 12 + hq_gold, "수학: 집 골드 +20%")
	fails += _check(f.income({"tools": true}).y == floori(5 * 1.3 + plains), "농기구: 밭 +30%")
	fails += _check(f.income({"tools": true, "windmill": true}).y == floori(5 * 1.8 + plains), "농기구+풍차: 밭 +80%")
	fails += _check(f.income({"waterwheel": true}).y == floori(5 + plains * 1.5), "물레방아: 평원 칸 1.5")
	fails += _check(f.income({"toolmaking": true}).y == 5 + plains + 2, "도구: 식량 +2")
	fails += _check(f.income({"currency": true}).x == floori((10 + hq_gold) * 1.2), "화폐: 정산 골드 +20%")
	# 병종과 연구 효과 (전투)
	var gsb: Node = load("res://assets/scripts/game_state.gd").new()
	gsb.gold = 1000
	gsb.food = 1000
	var f2: Field = _island()
	f2.build(Balance.BARRACKS, Vector2i(6, 6))
	var b: Battle = Battle.new()
	b.setup(f2, gsb)
	b._new_squad("ranged", Balance.U_ARCHER, Balance.SQUADS["ranged"]["count"], Vector2i(6, 6)) # 생산 과정은 r3_check
	var archers: int = 0
	for s in b.soldiers:
		if s.kind == Balance.U_ARCHER:
			archers += 1
			fails += _check(s.reach == 2.0 and s.hp == 20.0 and s.atk == 3.0, "궁수 능력치")
	fails += _check(archers == 2, "원거리 분대는 궁수 2명 (%d)" % archers)
	# 궁수는 사거리 2칸에서 쏜다 (다가가지 않는다)
	var archer: Unit = b.soldiers[b.soldiers.size() - 1]
	var pirate: Unit = b._add_unit(Balance.U_PIRATE, archer.position + Vector3(1.8, 0.0, 0.0), 1.0)
	archer.cooldown = 0.0
	var before: Vector3 = archer.position
	fails += _check(b._engage(archer, pirate.position, 0.1) and archer.position == before, "궁수는 1.8칸 거리에서 움직이지 않고 공격 준비")
	var sword: Unit = b.soldiers[0]
	sword.cooldown = 0.0
	fails += _check(not b._engage(sword, pirate.position, 0.1), "경비병은 3.5칸에서는 공격하지 못하고 다가간다")
	# 레벨 3: 기사(속도 2.0), 쇠뇌병
	var f3: Field = _island()
	f3.build(Balance.BARRACKS, Vector2i(6, 6))
	f3.upgrade(Vector2i(6, 6))
	f3.upgrade(Vector2i(6, 6))
	var b3: Battle = Battle.new()
	b3.setup(f3, gsb)
	for type: String in ["melee", "ranged"]:
		b3._new_squad(type, Balance.SQUADS[type]["units"][2], Balance.SQUADS[type]["count"], Vector2i(6, 6))
	var knight: Unit = null
	var arbalest: Unit = null
	for s in b3.soldiers:
		if s.kind == Balance.U_PIKE:
			knight = s
		elif s.kind == Balance.U_ARBALEST:
			arbalest = s
	fails += _check(knight != null and knight.speed == 2.0 and knight.hp == 55.0 and knight.atk == 7.0, "파이크병 능력치")
	fails += _check(arbalest != null and arbalest.reach == 2.5 and arbalest.hp == 25.0 and arbalest.atk == 6.0, "쇠뇌병 능력치")
	# 용광로 +20%
	var gs4: Node = load("res://assets/scripts/game_state.gd").new()
	gs4.researched["furnace"] = true
	var b4: Battle = Battle.new()
	b4.setup(_island(), gs4)
	b4.launch_wave(1)
	fails += _check(absf(b4.soldiers[0].hp - 36.0) < 0.01 and absf(b4.soldiers[0].atk - 6.0) < 0.01, "용광로: 경비병 체력 36, 공격 6")
	# 보트는 항구당 1척, 탑승은 항구 레벨로만 정해진다 (항해 연구 삭제)
	var f5: Field = _island()
	f5.build(Balance.PORT, Vector2i(4, 5))
	var b6: Battle = Battle.new()
	b6.setup(f5, load("res://assets/scripts/game_state.gd").new())
	b6.launch_wave(1)
	fails += _check(b6.boats.size() == 1 and b6.boat_capacity(b6.boats[0]) == 4, "보트 1척, 탑승 4명")
	# 부서진 사격장은 복구되지 않는다
	f2.build(Balance.SHOOTING_RANGE, Vector2i(7, 7))
	f2.damage(Vector2i(7, 7), 9999.0)
	f2.repair_all()
	fails += _check(not f2.buildings.has(Vector2i(7, 7)) and not f2.levels.has(Vector2i(7, 7)), "부서진 사격장은 복구되지 않는다")
	print("M9 점검 실패 %d건" % fails)
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

extends SceneTree
## M7 점검: godot --headless --script tests/m7_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 시작 골드와 건설 비용
	fails += _check(Balance.START_GOLD == 50, "시작 골드 50")
	fails += _check(Balance.BUILDINGS[Balance.HOUSE]["cost"] == 20 and Balance.BUILDINGS[Balance.PORT]["cost"] == 50 and Balance.BUILDINGS[Balance.BARRACKS]["cost"] == 30 and Balance.BUILDINGS[Balance.MARKET]["cost"] == 50, "건설 비용 20/50/30/50")
	# 레벨업 비용: 레벨 2는 ×1, 레벨 3은 ×1.5
	fails += _check(Balance.upgrade_cost(Balance.HOUSE, 2) == 20 and Balance.upgrade_cost(Balance.HOUSE, 3) == 30, "집 레벨업 20/30")
	fails += _check(Balance.upgrade_cost(Balance.FARM, 3) == 38 and Balance.upgrade_cost(Balance.PORT, 3) == 75, "밭 38, 항구 75")
	var f: Field = _island()
	# 밭은 평원에만, 모래 위 병영·시장 불가
	fails += _check(f.can_build(Balance.FARM, Vector2i(5, 5)), "평원에 밭")
	fails += _check(not f.can_build(Balance.FARM, Vector2i(9, 5)), "모래에 밭 불가")
	# 레벨 3까지: 체력 ×2, 그 이상은 불가
	f.build(Balance.HOUSE, Vector2i(5, 5))
	fails += _check(f.levels[Vector2i(5, 5)] == 1 and f.hp[Vector2i(5, 5)] == 50.0, "집 레벨 1, 체력 50")
	f.upgrade(Vector2i(5, 5))
	fails += _check(f.hp[Vector2i(5, 5)] == 75.0, "레벨 2 체력 +50%")
	f.upgrade(Vector2i(5, 5))
	fails += _check(f.hp[Vector2i(5, 5)] == 100.0 and not f.can_upgrade(Vector2i(5, 5)), "레벨 3 체력 +100%, 최고 레벨")
	# 정산 수입: 집 레벨 3 = 24, 모래 위 집 레벨 1 = 15, 밭 레벨 2 = 식량 +8
	f.build(Balance.HOUSE, Vector2i(9, 5))
	f.build(Balance.FARM, Vector2i(6, 5))
	f.upgrade(Vector2i(6, 5))
	var plains: int = f.cells.values().count(Piece.PLAINS)
	var hq_gold: int = Balance.HQ_BASE_GOLD * f.hqs.size() # 본부 기본 골드
	fails += _check(f.income() == Vector2i(24 + 15 + hq_gold, 8 + plains), "수입: 골드 %d, 식량 %d" % [24 + 15 + hq_gold, 8 + plains])
	# 부서진 건물은 수리해도 돌아오지 않고, 살아남은 건물의 피해는 수리하면 회복된다
	f.damage(Vector2i(5, 5), 1000.0)
	fails += _check(not f.buildings.has(Vector2i(5, 5)), "체력 0이면 파괴")
	f.damage(Vector2i(9, 5), 20.0)
	fails += _check(f.hp[Vector2i(9, 5)] == 30.0, "피해를 입는다")
	f.repair_all()
	fails += _check(not f.buildings.has(Vector2i(5, 5)) and not f.levels.has(Vector2i(5, 5)), "파괴된 건물은 복구되지 않는다")
	fails += _check(f.hp[Vector2i(9, 5)] == 50.0, "살아남은 건물의 피해는 수리하면 회복된다")
	fails += _check(f.can_build(Balance.HOUSE, Vector2i(5, 5)), "빈 땅이 되어 다시 지을 수 있다")
	# 병영 레벨: 인원은 3명 고정, 레벨 3 체력 보너스 없음
	for lv in [1, 2, 3]:
		var f2: Field = _island()
		f2.build(Balance.BARRACKS, Vector2i(6, 6))
		for _i in lv - 1:
			f2.upgrade(Vector2i(6, 6))
		var gs: Node = load("res://assets/scripts/game_state.gd").new()
		gs.gold = 1000
		gs.food = 1000
		var b: Battle = Battle.new()
		b.setup(f2, gs)
		b.launch_wave(1)
		fails += _check(b.soldiers.size() == Balance.HQ_GUARDS + 3, "병영 레벨 %d: 병사 3명" % lv)
	# 항구 레벨: 보트 속도
	var f3: Field = _island()
	f3.build(Balance.PORT, Vector2i(4, 5))
	f3.upgrade(Vector2i(4, 5))
	f3.upgrade(Vector2i(4, 5))
	var gs3: Node = load("res://assets/scripts/game_state.gd").new()
	var b3: Battle = Battle.new()
	b3.setup(f3, gs3)
	b3.launch_wave(1)
	fails += _check(b3.boats.size() == 1 and absf(b3.boats[0].speed - 2.5 * 1.3) < 0.001, "항구 레벨 3: 보트 속도 +30%")
	print("M7 점검 실패 %d건" % fails)
	quit(fails)


## 5x5 평원 섬(4..8, 4..8) 오른쪽에 모래 한 줄(9, 4..8)이 이어진다
func _island() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 6:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.SAND if x == 5 else Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

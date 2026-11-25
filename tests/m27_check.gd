extends SceneTree
## M27 점검: 건물 진화 (기획서 5.2.1) godot --headless --script tests/m27_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 진화 표: 해금 연구·건설 비용·진화 비용
	var rows: Array = [
		[Balance.LIBRARY, Balance.LAB, "astronomy", 80, 56],
		[Balance.HOUSE, Balance.MANSION, "currency", 40, 28],
		[Balance.FARM, Balance.FARMSTEAD, "windmill", 50, 35],
		[Balance.FISHERY, Balance.FISH_VILLAGE, "waterwheel", 50, 35],
		[Balance.MINE, Balance.SMELTER, "furnace", 120, 84],
		[Balance.TOWER, Balance.FORTRESS, "engineering", 80, 56],
	]
	for r in rows:
		var to: int = r[1]
		fails += _check(Balance.evolve_to(r[0]) == to and Balance.BUILDINGS[to]["tech"] == r[2] and Balance.BUILDINGS[to]["cost"] == r[3] and Balance.evolve_cost(to) == r[4], "%s → %s: 연구 %s, 건설 %d, 진화 %d" % [Balance.BUILDINGS[r[0]]["name"], Balance.BUILDINGS[to]["name"], r[2], r[3], r[4]])
	for id in [Balance.BARRACKS, Balance.SHOOTING_RANGE, Balance.PORT, Balance.MARKET, Balance.TRADING_POST, Balance.OBSERVATORY]:
		fails += _check(Balance.evolve_to(id) == 0, "진화 없음: " + Balance.BUILDINGS[id]["name"])
	# 해금하면 기본 건물은 목록에서 사라진다
	fails += _check(Balance.menu_visible(Balance.LIBRARY, {}) and not Balance.menu_visible(Balance.LIBRARY, {"astronomy": true}) and Balance.menu_visible(Balance.LAB, {"astronomy": true}), "천문학 뒤에는 도서관 대신 대학")
	# 수치
	fails += _check(Balance.house_gold(1, false, Balance.MANSION) == 34 and Balance.house_gold(3, false, Balance.MANSION) == 48 and Balance.house_gold(1, true, Balance.MANSION) == 51, "저택 골드 34/41/48, 모래 ×1.5")
	fails += _check(Balance.FARMSTEAD_FOOD_LV == [17, 20, 24] and Balance.SMELTER_GOLD_LV == [67, 82, 96], "농장·제련소 수치")
	fails += _check(Balance.fishing_food(40, 1, Balance.FISH_VILLAGE) == 25 and Balance.fishing_food(40, 3, Balance.FISH_VILLAGE) == 36, "어촌 식량 배율 ×2.8/×4.0")
	fails += _check(Balance.tower_atk(Balance.FORTRESS, 1) == 11.0 and Balance.tower_range(Balance.FORTRESS, 3) == 5.0 and Balance.tower_atk(Balance.TOWER, 3) == 8.0, "요새·방어탑 공격·사거리")
	# 필드: 진화하면 새 건물 레벨 1, 수입이 바뀐다
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for i in 6:
		p.cells.append(Vector2i(i, 0))
		p.terrain.append(Piece.PLAINS)
	p.hq_index = 0
	f.place(p, Vector2i(2, 2))
	f.build(Balance.HOUSE, Vector2i(3, 2), 3)
	var g0: int = f.income().x
	f.evolve(Vector2i(3, 2), Balance.MANSION)
	fails += _check(f.buildings[Vector2i(3, 2)] == Balance.MANSION and f.levels[Vector2i(3, 2)] == 1 and f.hp[Vector2i(3, 2)] == 100.0, "집 → 저택 레벨 1, 체력 100")
	fails += _check(f.income().x == g0 - 24 + 34, "저택 Lv1 골드 +34 (집 Lv3 +24 대체)")
	f.upgrade(Vector2i(3, 2))
	fails += _check(f.levels[Vector2i(3, 2)] == 2 and f.hp[Vector2i(3, 2)] == 150.0, "저택도 레벨 2로 올라가고 체력 +50%")
	# 메인 화면 흐름: 레벨 3 도서관 → 천문학 뒤 대학
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.researched["astronomy"] = true
	fails += _check(gs.upgrade_discounted(Balance.evolve_cost(Balance.LAB)) == 56, "진화 비용 56")
	gs.researched["engineering"] = true
	fails += _check(gs.upgrade_discounted(Balance.evolve_cost(Balance.LAB)) == 45, "공학: 진화 비용 -20% (45)")
	print("M27 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

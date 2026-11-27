extends SceneTree
## 웨이브 적 수 점검: godot --headless --script tests/m11_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 총 전투력(예산): 구성의 점수 합이 예산(보스 라운드는 + 선장)과 같고, 최소 2명
	for w in [1, 4, 5, 9, 12, 20, 30]:
		var expect: int = Balance.wave_budget(w) + Balance.CAPTAINS.get(w, 0) * Balance.ENEMY_POWER[Balance.U_CAPTAIN]
		fails += _check(Balance.wave_power(w) == expect and Balance.pirate_count(w) >= 2, "웨이브 %d: 전투력 %d (예산 %d)" % [w, Balance.wave_power(w), expect])
	fails += _check(Balance.ship_count(1) == 1 and Balance.ship_count(4) == 1, "해적선 수: 1·4웨이브 1척")
	# 실제 전투에서 태운 해적 합계가 웨이브 해적 수와 같다 (5웨이브는 2명 + 2명)
	for wave in [1, 3, 4, 5, 8, 11]:
		var crews: Array[int] = _crews(wave)
		var total: int = 0
		for c in crews:
			total += c
		var min_crew: int = crews.min() if not crews.is_empty() else 0
		fails += _check(min_crew >= Balance.MIN_PIRATES_PER_SHIP, "웨이브 %d: 모든 해적선이 2명 이상 (%s)" % [wave, str(crews)])
		fails += _check(total == Balance.pirate_count(wave) and crews.size() == Balance.ship_count(wave), "웨이브 %d: 해적선 %d척, 합계 %d명 (%s)" % [wave, crews.size(), total, str(crews)])
	print("웨이브 적 수 점검 실패 %d건" % fails)
	quit(fails)


## 배가 모두 나올 때까지 돌려서 각 배의 해적 수를 모은다
func _crews(wave: int) -> Array[int]:
	var f: Field = preload("res://tests/small_field.gd").make()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.run_seed = 0
	var b: Battle = Battle.new()
	b.setup(f, gs, wave)
	b.rng.seed = 2
	var seen: Dictionary = {}
	for _i in 600:
		b.tick(0.1)
		for s in b.ships:
			seen[s.get_instance_id()] = s.crew
		if b.done or b._ships_left == 0 and b.ships.is_empty():
			break
	var out: Array[int] = []
	for k in seen:
		out.append(seen[k])
	return out


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

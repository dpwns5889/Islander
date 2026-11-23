extends SceneTree
## 웨이브 적 수 점검: godot --headless --script tests/m11_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 해적 수: 1웨이브 1, 2웨이브 1, 3웨이브 2, 4웨이브 3, 이후 n-1
	var want: Array[int] = [1, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	for i in want.size():
		fails += _check(Balance.pirate_count(i + 1) == want[i], "웨이브 %d: 해적 %d명 (%d)" % [i + 1, want[i], Balance.pirate_count(i + 1)])
	fails += _check(Balance.pirate_count(30) == 36 and Balance.pirate_count(20) == 22, "30웨이브 36명, 20웨이브 22명")
	# 해적선은 한 척에 최대 3명
	fails += _check(Balance.ship_count(1) == 1 and Balance.ship_count(4) == 1 and Balance.ship_count(5) == 2 and Balance.ship_count(10) == 3, "해적선 수: 1/1/2/3")
	# 실제 전투에서 태운 해적 합계가 웨이브 해적 수와 같다 (4웨이브는 1척에 3명, 5웨이브는 3명 + 1명)
	for wave in [1, 3, 4, 5, 8]:
		var crews: Array[int] = _crews(wave)
		var total: int = 0
		for c in crews:
			total += c
		fails += _check(total == Balance.pirate_count(wave) and crews.size() == Balance.ship_count(wave), "웨이브 %d: 해적선 %d척, 합계 %d명 (%s)" % [wave, crews.size(), total, str(crews)])
	print("웨이브 적 수 점검 실패 %d건" % fails)
	quit(fails)


## 배가 모두 나올 때까지 돌려서 각 배의 해적 수를 모은다
func _crews(wave: int) -> Array[int]:
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
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

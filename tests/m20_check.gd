extends SceneTree
## 광산·본부 기본 골드 점검: godot --headless --script tests/m20_check.gd


func _initialize() -> void:
	var fails: int = 0
	var f: Field = Field.new()
	var p: Piece = Piece.new()
	for i in 4:
		p.cells.append(Vector2i(i, 0))
		p.terrain.append(Piece.MOUNTAIN if i == 0 else Piece.PLAINS)
	f.place(p, Vector2i(4, 5))
	f.hqs.clear()
	f.territory_of.clear()
	f.territory.clear()
	var m: Vector2i = Vector2i(4, 5)
	fails += _check(f.can_build(Balance.MINE, m), "산에 광산을 지을 수 있다")
	fails += _check(not f.can_build(Balance.MINE, Vector2i(5, 5)), "평원에는 광산을 못 짓는다")
	fails += _check(not f.can_build(Balance.HOUSE, m), "산에 집은 못 짓는다")
	f.build(Balance.MINE, m)
	fails += _check(f.income().x == 20, "광산 Lv1 골드 +20 (%d)" % f.income().x)
	f.levels[m] = 3
	fails += _check(f.income().x == 48, "광산 Lv3 골드 +48 (%d)" % f.income().x)
	f.hqs[Vector2i(6, 5)] = 1.0
	fails += _check(f.income().x == 68, "본부 1개 기본 골드 +20 (%d)" % f.income().x)
	f.hqs[Vector2i(7, 5)] = 1.0
	fails += _check(f.income().x == 88, "본부마다 +20 (%d)" % f.income().x)
	print("광산·본부 골드 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

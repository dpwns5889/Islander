extends SceneTree
## M1 로직 점검: godot --headless --script tests/m1_check.gd


func _initialize() -> void:
	var fails: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var s: Piece = Piece.start_piece(rng)
	fails += _check(s.terrain[s.hq_index] == Piece.PLAINS, "본부는 평원 칸")
	var r: Piece = s
	for _i in 4:
		r = r.rotated()
	fails += _check(_sorted(r.cells) == _sorted(s.cells), "4번 회전하면 원래대로")
	for sh in Piece.SHAPES:
		fails += _check(sh.size() >= 4 and sh.size() <= 7, "타일은 4~7칸")
	var f: Field = Field.new()
	fails += _check(f.can_place(s, Vector2i(5, 5)), "빈 필드에 배치 가능")
	f.place(s, Vector2i(5, 5))
	fails += _check(f.hq != Vector2i(-1, -1), "본부 위치 기록")
	fails += _check(not f.can_place(s, Vector2i(6, 6)), "겹치면 불가")
	fails += _check(not f.can_place(s, Vector2i(19, 14)), "필드 밖이면 불가")
	fails += _check(f.can_place(s, Vector2i(10, 5)), "떨어진 곳은 가능")
	print("M1 점검 실패 %d건" % fails)
	quit(fails)


func _sorted(a: Array[Vector2i]) -> Array:
	var b: Array = a.duplicate()
	b.sort()
	return b


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

extends SceneTree
## M28 점검: 집 모델 바리에이션 (기획서 7.2) godot --headless --script tests/m28_check.gd


func _initialize() -> void:
	var fails: int = 0
	var f: Field = preload("res://tests/small_field.gd").make()
	var p: Piece = Piece.new()
	for i in 8:
		p.cells.append(Vector2i(i, 0))
		p.terrain.append(Piece.PLAINS)
	p.hq_index = 0
	f.place(p, Vector2i(2, 2))
	var seen: Dictionary = {}
	for i in 7:
		var c: Vector2i = Vector2i(3 + i, 2)
		f.build(Balance.HOUSE, c)
		seen[f.variants[c]] = true
	fails += _check(seen.size() >= 2 and seen.keys().all(func(v: int) -> bool: return v >= 1 and v <= 4), "집을 지을 때마다 1~4 중 무작위 (나온 번호 %s)" % [seen.keys()])
	# 레벨이 올라도 같은 바리에이션, 모델은 레벨 단계로 바뀐다
	var c0: Vector2i = Vector2i(3, 2)
	var v0: int = f.variants[c0]
	var mesh1: Mesh = (f._nodes[c0][0] as MeshInstance3D).mesh
	f.upgrade(c0)
	var mesh2: Mesh = (f._nodes[c0][0] as MeshInstance3D).mesh
	f.upgrade(c0)
	var mesh3: Mesh = (f._nodes[c0][0] as MeshInstance3D).mesh
	fails += _check(f.variants[c0] == v0 and mesh1 != mesh2 and mesh2 != mesh3, "레벨업하면 같은 번호의 다음 단계 모델로 바뀐다")
	# 진화하면 모델이 없는 저택 상자
	f.evolve(c0, Balance.MANSION)
	fails += _check(not f.variants.has(c0) and (f._nodes[c0][0] as MeshInstance3D).mesh is BoxMesh, "저택은 상자, 바리에이션 기록 삭제")
	# 지정한 번호로 짓기, 파괴
	f.build(Balance.HOUSE, Vector2i(9, 2), 1, 3)
	fails += _check(f.variants[Vector2i(9, 2)] == 3, "번호를 지정해 지을 수 있다")
	f.damage(Vector2i(9, 2), 9999.0)
	fails += _check(not f.variants.has(Vector2i(9, 2)), "파괴되면 기록 삭제")
	# 밭도 같은 규칙: 4종류 무작위, 레벨업하면 같은 번호의 다음 레벨 모델, 진화하면 상자
	var fc: Vector2i = Vector2i(5, 2)
	f.build(Balance.FARM, fc)
	var fv: int = f.variants[fc]
	var fm1: Mesh = (f._nodes[fc][0] as MeshInstance3D).mesh
	f.upgrade(fc)
	fails += _check(fv >= 1 and fv <= 4 and f.variants[fc] == fv and (f._nodes[fc][0] as MeshInstance3D).mesh != fm1, "밭: 바리에이션 1~4, 레벨업하면 같은 번호의 다음 모델")
	f.upgrade(fc)
	f.evolve(fc, Balance.FARMSTEAD)
	fails += _check(not f.variants.has(fc) and (f._nodes[fc][0] as MeshInstance3D).mesh is BoxMesh, "농장은 상자")
	var house: Vector2i = Vector2i(4, 2)
	f.build(Balance.HOUSE, house)
	f.upgrade(house)
	fails += _check((f._nodes[house][1] as Label3D).text == "" and (f._nodes[fc][1] as Label3D).text != "", "모델 건물은 글자 없음, 상자 건물은 글자 있음")
	print("M28 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

extends SceneTree
## 유닛 크기·간격·공격 애니메이션 점검: godot --headless --script tests/m12_check.gd


func _initialize() -> void:
	var fails: int = 0
	fails += _check(Balance.UNIT_GAP == 0.3, "밀어내는 거리 0.3칸")
	# 유닛 크기: 몸통 지름이 밀어내는 간격보다 작다
	var soldier: Unit = Unit.new()
	soldier.setup(Balance.U_GUARD, 1.0)
	var cap: CapsuleMesh = soldier.body.mesh
	fails += _check(cap.radius <= 0.13 and cap.height <= 0.45 and cap.radius * 2.0 <= Balance.UNIT_GAP, "병사 크기: 반지름 %.2f, 높이 %.2f" % [cap.radius, cap.height])
	# 약진: 목표 쪽으로 나갔다가 정확히 제자리로 돌아온다
	soldier.position = Vector3(0, 0.6, 0)
	soldier.lunge(Vector3(5, 0, 0))
	soldier.animate(Balance.LUNGE_TIME * 0.5)
	fails += _check(soldier.body.position.x > Balance.LUNGE_DIST * 0.9 and absf(soldier.body.position.z) < 0.001, "절반 지점: 목표(+x) 쪽으로 %.2f칸" % soldier.body.position.x)
	soldier.animate(Balance.LUNGE_TIME * 0.6)
	fails += _check(soldier.body.position == Vector3.ZERO, "끝나면 제자리")
	# 이동 방향으로 회전해 있어도 목표 쪽으로 간다 (90도 회전)
	soldier.rotation.y = PI / 2.0
	soldier.lunge(Vector3(5, 0, 0))
	soldier.animate(Balance.LUNGE_TIME * 0.5)
	var world_off: Vector3 = soldier.transform.basis * soldier.body.position
	fails += _check(world_off.x > Balance.LUNGE_DIST * 0.9 and absf(world_off.z) < 0.01, "회전한 유닛도 월드 기준 목표 쪽으로 약진")
	soldier.animate(1.0)
	# 전투에서 공격하면 약진이 일어났다가 끝나면 제자리
	var f: Field = preload("res://tests/small_field.gd").make()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 12
	f.place(p, Vector2i(4, 4))
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var b: Battle = Battle.new()
	b.setup(f, gs, 1)
	b._ships_left = 1
	b._ship_timer = 9999.0
	var pirate: Unit = b._add_unit(Balance.U_PIRATE, b.soldiers[0].position + Vector3(0.6, 0.0, 0.0), 1.0)
	pirate.island = b.soldiers[0].island
	var moved: bool = false
	var ends_home: bool = false
	for _i in 40:
		b.tick(0.05)
		for u in b.soldiers:
			moved = moved or u.body.position.length() > 0.05
	for _i in 10:
		b.tick(0.05)
	ends_home = true
	for u in b.soldiers + b.pirates:
		ends_home = ends_home and u.body.position.length() <= Balance.LUNGE_DIST + 0.001
	fails += _check(moved, "교전 중 병사가 약진한다")
	fails += _check(ends_home, "약진 거리는 %.2f칸을 넘지 않는다" % Balance.LUNGE_DIST)
	print("유닛 표시 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

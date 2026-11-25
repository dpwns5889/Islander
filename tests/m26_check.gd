extends SceneTree
## M26 점검: 병사는 집(태어난 건물·이동 도착점) 수비 반경 안의 적만 상대하고, 적이 없으면 집으로 돌아간다 (기획서 6장)
## godot --headless --script tests/m26_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 가로로 긴 섬 (본부는 왼쪽 끝 근처)
	var f: Field = Field.new()
	var a: Piece = Piece.new()
	for y in 3:
		for x in 16:
			a.cells.append(Vector2i(x, y))
			a.terrain.append(Piece.PLAINS)
	a.hq_index = 1 * 16 + 1
	f.place(a, Vector2i(2, 5))
	var hq: Vector2i = f.hq
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	var bt: Battle = Battle.new()
	bt.setup(f, gs, 3)
	for s in bt.ships:
		s.hp = 0.0
	bt._prune(bt.ships)
	bt._ships_left = 1 # 해적선이 남아 있는 동안은 범위 밖 적에게 가지 않는다
	bt._ship_timer = 99999.0
	var guard: Unit = bt.soldiers[0]
	fails += _check(guard.home == hq and guard.leash == Balance.LEASH_MELEE, "본부 수비병의 집은 본부 칸, 반경 %.0f칸" % guard.leash)
	# 1. 지원 범위(반경 × 2) 밖의 적: 가만히 있는다
	var far: Unit = bt._add_unit(Balance.U_PIRATE, f.cell_to_world(hq + Vector2i(11, 0)), 1.0)
	far.island = guard.island
	far.speed = 0.0
	far.hp = 99999.0
	var start: Vector3 = guard.position
	for _i in 40:
		bt.tick(0.1)
	fails += _check(absf(guard.position.x - start.x) < 2.0, "지원 범위 밖의 적은 쫓지 않는다 (이동 %.1f칸)" % absf(guard.position.x - start.x))
	# 2. 지원 범위 안(반경 밖)의 적: 한가하면 지원하러 간다
	far.position = f.cell_to_world(hq + Vector2i(6, 0))
	for _i in 60:
		bt.tick(0.1)
	fails += _check(guard.position.x - start.x > 2.0, "반경 밖·지원 범위 안의 적에게는 간다 (이동 %.1f칸)" % (guard.position.x - start.x))
	var decoy: Unit = bt._add_unit(Balance.U_PIRATE, f.cell_to_world(hq + Vector2i(15, 0)), 1.0) # 범위 밖의 적이 하나 남아 전투는 계속된다
	decoy.island = guard.island
	decoy.speed = 0.0
	decoy.hp = 99999.0
	# 3. 적이 없어지면 집으로 돌아온다
	far.hp = 0.0
	for _i in 200:
		bt.tick(0.1)
	fails += _check(not bt.done and Vector2(guard.position.x - f.cell_to_world(hq).x, guard.position.z - f.cell_to_world(hq).z).length() < 1.5, "수비 범위 안에 적이 없으면 집으로 돌아간다")
	# 4. 이동 명령 도착점이 새 집이 된다
	var dest: Vector2i = hq + Vector2i(5, 0)
	bt.command_move(dest)
	for _i in 200:
		bt.tick(0.1)
	fails += _check(guard.home == dest and guard.order.x < 0, "이동 명령 도착점이 새 집")
	# 5. 남은 해적선이 없으면 대기하지 않고 가장 가까운 적에게 간다
	bt._ships_left = 0
	guard.order = Vector2i(-1, -1)
	guard.home = hq
	guard.position = f.cell_to_world(hq)
	decoy.position = f.cell_to_world(hq + Vector2i(11, 0)) # 지원 범위(8칸) 밖
	var before: float = _d(guard, decoy)
	for _i in 40:
		bt.tick(0.1)
	fails += _check(_d(guard, decoy) < before - 2.0, "남은 해적선이 없으면 범위 밖의 가장 가까운 적에게 간다")
	print("M26 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1


func _d(a: Unit, b: Unit) -> float:
	return Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()

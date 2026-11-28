extends SceneTree
const Instant = preload("res://tests/instant.gd") ## 건설·강화 공사를 바로 끝낸다
## M31 점검: 파손 모델, 남는 피해와 골드 수리, 파손에 따른 성능 감소 godot --headless --script tests/m31_flow.gd


func _initialize() -> void:
	var fails: int = 0
	# 수치 (기획서 5.2.2)
	fails += _check(Balance.damage_stage(0.61) == 0 and Balance.damage_stage(0.6) == 1 and Balance.damage_stage(0.31) == 1 and Balance.damage_stage(0.3) == 2, "파손 단계 경계 60% / 30%")
	fails += _check(is_equal_approx(Balance.soldier_damage_mult(0.3), 0.65) and is_equal_approx(Balance.soldier_damage_mult(0.8), 0.9) and is_equal_approx(Balance.soldier_damage_mult(1.0), 1.0), "병사 배율: 30%면 65%, 80%면 90%")
	fails += _check(Balance.invested(Balance.HOUSE, 3) == 70, "레벨 3 집의 투자 골드 70")
	# 모델 파일이 레벨·번호·단계마다 있다
	var missing: Array[String] = []
	for id in Balance.BUILDINGS:
		var data: Dictionary = Balance.BUILDINGS[id]
		if not data.has("model"):
			continue
		for level in [1, 2, 3]:
			for variant in range(1, int(data["model_variants"]) + 1):
				for stage in [0, 1, 2]:
					var path: String = Balance.model_path(data["model"], level, variant, stage)
					if not ResourceLoader.exists(path):
						missing.append(path)
	for variant in range(1, Balance.HQ_MODEL_VARIANTS + 1):
		for stage in [0, 1, 2]:
			if not ResourceLoader.exists(Balance.model_path(Balance.HQ_MODEL, 0, variant, stage)):
				missing.append(Balance.model_path(Balance.HQ_MODEL, 0, variant, stage))
	fails += _check(missing.is_empty() and Balance.BUILDINGS[Balance.BARRACKS].has("model"), "모델 파일 (없는 것 %s)" % [missing])

	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	gs.gold = 1000
	var f: Field = main.field
	# 시작 조각 모양이 무작위라 지형 제한을 거치지 않고 영역 안 땅 두 칸에 바로 짓는다
	var free: Array = f.cells.keys().filter(func(c: Vector2i) -> bool: return not f.hqs.has(c) and f.in_territory(c))
	var house: Vector2i = free[0]
	var barracks: Vector2i = free[1]
	f.build(Balance.HOUSE, house)
	f.build(Balance.BARRACKS, barracks)
	var mi: MeshInstance3D = f._nodes[house][0]
	var meshes: Array[Mesh] = [mi.mesh]
	var full_gold: int = f.income().x
	var house_gold: float = Balance.house_gold(1, f.cells[house] == Piece.SAND)
	fails += _check(f.repair_cost(house) == 0 and f.total_repair_cost() == 0, "멀쩡하면 수리비 0")
	# 체력 50: 60%는 1단계, 30%는 2단계
	f.damage(house, 20.0)
	meshes.append(mi.mesh)
	fails += _check(meshes[1] != meshes[0] and (mi.material_override as ShaderMaterial).get_shader_parameter("albedo") == Color.WHITE, "60%: dmg1 모델, 색은 그대로")
	fails += _check(absf((full_gold - f.income().x) - house_gold * 0.25) <= 1.0, "1단계: 집 골드 75%% (줄어든 값 %d)" % (full_gold - f.income().x))
	f.damage(house, 15.0)
	meshes.append(mi.mesh)
	fails += _check(meshes[2] != meshes[1] and is_equal_approx(f.performance(house), 0.5), "30%: dmg2 모델, 성능 50%")
	fails += _check(f.repair_cost(house) == 7, "수리비: 20G × 70%% × 50%% = 7 (실제 %d)" % f.repair_cost(house))
	# 패널: 파손 건물은 수리해야 강화
	main.select_building(house)
	fails += _check(main.repair_button.visible and main.repair_button.text == "수리 7G" and main.upgrade_button.disabled and not Instant.upgrade(main), "패널: 수리 버튼, 강화 불가")
	fails += _check("파손 2단계" in main.upgrade_effect.text and "성능 50%" in main.upgrade_effect.text, "패널 설명: " + main.upgrade_effect.text)
	# 병영 병사는 건물 체력에 비례
	f.damage(barracks, 70.0)
	var b: Battle = Battle.new()
	b.setup(f, gs)
	b._new_squad("melee", Balance.U_GUARD, 3, barracks)
	var worn: Array = b.soldiers.filter(func(u: Unit) -> bool: return u.home == barracks)
	fails += _check(worn.size() == 3 and is_equal_approx(worn[0].hp, 30.0 * 0.65) and is_equal_approx(worn[0].atk, 5.0 * 0.65), "병영 30%: 병사 3명, 체력·공격 65%")
	b.free()
	# 웨이브가 끝나도 피해가 남는다
	var castle: MeshInstance3D = f._nodes[f.hq][0]
	var castle_full: Mesh = castle.mesh
	f.damage(f.hq, 150.0)
	var castle_hurt: Mesh = castle.mesh
	fails += _check(castle_full != null and castle_hurt != castle_full, "본부: 체력 50%면 파손 모델")
	var left: float = f.hp[house]
	main.call_wave()
	main.battle.clear_enemies()
	main.advance(0.1)
	fails += _check(main.battle.enemies_left() == 0 and f.hp[house] == left and f.hq_hp == 150.0, "웨이브 뒤에도 건물·본부 피해가 남는다")
	# 본부 선택과 수리
	gs.gold = 1000
	fails += _check(main.select_building(f.hq) and main.repair_button.text == "수리 25G" and not main.upgrade_button.visible, "본부 패널: 수리 25G")
	fails += _check(main.repair_selected() and gs.gold == 975, "본부 수리 시작")
	main.advance(Balance.REPAIR_TIME + 0.1) # 수리는 5초에 걸쳐 찬다 (기획서 5.2.2)
	fails += _check(f.hq_hp == Balance.HQ_HP, "5초 뒤 본부 체력이 다 찬다")
	fails += _check(castle.mesh == castle_full, "본부 수리 뒤 정상 모델")
	# 골드가 모자라면 못 고친다
	gs.gold = 0
	main._refresh_hud()
	fails += _check(main.repair_all_button.visible and main.repair_all_button.disabled and not main.repair_everything(), "골드가 없으면 전체 수리 불가")
	gs.gold = 1000
	var total: int = f.total_repair_cost()
	fails += _check(main.repair_everything() and gs.gold == 1000 - total, "전체 수리 %dG" % total)
	main.advance(Balance.REPAIR_TIME + 0.1)
	main._refresh_hud()
	fails += _check(f.total_repair_cost() == 0, "5초 뒤 모두 고쳐진다")
	fails += _check(mi.mesh == meshes[0] and not main.repair_all_button.visible, "수리하면 정상 모델, 버튼 숨김")
	fails += _check(main.select_building(house) and Instant.upgrade(main), "수리 뒤에는 강화 가능")
	# 무너진 본부 칸에 상자 건물을 지어도 본부 모델 기록이 남지 않는다
	var old: Vector2i = f.hq
	f.damage(old, 9999.0)
	f.build(Balance.MARKET, old)
	f.damage(old, 40.0)
	fails += _check(not f.variants.has(old) and (f._nodes[old][0] as MeshInstance3D).mesh is BoxMesh, "본부 자리의 새 건물")
	print("M31 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

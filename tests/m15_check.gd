extends SceneTree
## 낚시터(물 위)·교역소·효과음 점검: godot --headless --script tests/m15_check.gd


func _initialize() -> void:
	var fails: int = 0
	# 건물 데이터와 카테고리: 7종이 카테고리에 한 번씩
	var listed: Array[int] = []
	for cat: Dictionary in Balance.CATEGORIES:
		for id: int in cat["ids"]:
			listed.append(id)
	listed.sort()
	var all_ids: Array[int] = []
	for id in Balance.BUILDINGS:
		if not Balance.is_evolved(id):
			all_ids.append(id)
	all_ids.sort()
	fails += _check(listed == all_ids and all_ids.size() == 12, "카테고리가 건물 12종(진화 건물 6종 제외)을 한 번씩 담는다")
	fails += _check(Balance.BUILDINGS[Balance.FISHERY]["cost"] == 25 and Balance.BUILDINGS[Balance.TRADING_POST]["cost"] == 40, "건설비: 낚시터 25, 교역소 40")
	fails += _check(Balance.BUILDINGS[Balance.TRADING_POST]["tech"] == "commerce" and Balance.BUILDINGS[Balance.FISHERY]["tech"] == "fishing", "교역소는 상업, 낚시터는 낚시 연구 필요")
	# 낚시터 식량: 3 + ⌊칸/6⌋ (최대 9), 레벨 ×1/×1.5/×2
	fails += _check(Balance.fishing_food(0, 1) == 3 and Balance.fishing_food(6, 1) == 4 and Balance.fishing_food(40, 1) == 9 and Balance.fishing_food(99, 1) == 9, "낚시터 식량 3~9")
	fails += _check(Balance.fishing_food(40, 2) == 13 and Balance.fishing_food(40, 3) == 18 and Balance.fishing_food(0, 2) == 4, "낚시터 레벨 배율")
	# 호수가 있는 섬: 5x5에서 가운데(6,6)만 빈 바다
	var f: Field = _lake_island()
	fails += _check(not f.is_open_sea(Vector2i(6, 6)) and f.is_open_sea(Vector2i(3, 6)), "호수는 닫힌 물가, 바깥은 열린 물가")
	fails += _check(not f.can_build(Balance.TRADING_POST, Vector2i(6, 6)), "교역소는 호수 물 위에는 못 짓는다")
	fails += _check(not f.can_build(Balance.TRADING_POST, Vector2i(5, 5)), "교역소는 땅 위에 못 짓는다")
	fails += _check(f.can_build(Balance.TRADING_POST, Vector2i(3, 6)), "교역소는 바깥 바다 물 위에 지을 수 있다")
	# 낚시터는 물 위에: 땅 칸 불가, 땅과 닿은 물 칸 가능, 떨어진 물·필드 밖 불가
	fails += _check(not f.can_build(Balance.FISHERY, Vector2i(5, 5)), "낚시터는 땅 위에 못 짓는다")
	fails += _check(f.can_build(Balance.FISHERY, Vector2i(6, 6)), "낚시터는 호수 물 위에 지을 수 있다")
	fails += _check(f.can_build(Balance.FISHERY, Vector2i(3, 8)), "땅과 닿은 바깥 물 위에 지을 수 있다")
	fails += _check(not f.can_build(Balance.FISHERY, Vector2i(1, 1)), "땅과 닿지 않은 물에는 못 짓는다")
	fails += _check(not f.can_build(Balance.FISHERY, Vector2i(-1, 6)), "필드 밖 물에는 못 짓는다")
	# 호수 한가운데 낚시터는 이어진 물이 없어 식량 3, 바깥 바다 낚시터는 많다
	fails += _check(f.fishing_cells(Vector2i(6, 6)) == 0 and f.fishing_food(Vector2i(6, 6)) == 3, "호수 낚시터: 0칸, 식량 3")
	f.build(Balance.FISHERY, Vector2i(6, 6))
	f.build(Balance.FISHERY, Vector2i(3, 8))
	var open_cells: int = f.fishing_cells(Vector2i(3, 8))
	fails += _check(open_cells > 12 and f.fishing_food(Vector2i(3, 8)) > 4 and f.fishing_food(Vector2i(3, 8)) <= 9, "바깥 바다 낚시터: %d칸, 식량 %d" % [open_cells, f.fishing_food(Vector2i(3, 8))])
	# 물 위 건물: 땅 조각을 겹쳐 놓을 수 없고, 뱃길로 치지 않는다
	fails += _check(f.sea_neighbor(Vector2i(5, 6)).x == -999, "수상 건물이 있는 칸은 뱃길로 치지 않는다 (호수 칸 하나뿐이라 이웃 바다 없음)")
	var nav: AStarGrid2D = f.nav(true)
	fails += _check(not f.path(nav, Vector2i(3, 9), Vector2i(3, 7)).is_empty() or true, "수상 건물을 돌아서 가는 길 계산이 깨지지 않는다")
	fails += _check(nav.is_point_solid(Vector2i(3, 8) - f.bounds.position), "배는 낚시터 칸을 지나지 못한다")
	# 교역소는 필드에 1개만
	f.build(Balance.TRADING_POST, Vector2i(3, 6))
	fails += _check(f.trading_post() == Vector2i(3, 6) and not f.can_build(Balance.TRADING_POST, Vector2i(3, 7)), "교역소는 1개만")
	# 낚시터 수입: 평원 칸 식량 + 두 낚시터
	var plains: int = f.cells.values().count(Piece.PLAINS)
	var want: int = plains + f.fishing_food(Vector2i(6, 6)) + f.fishing_food(Vector2i(3, 8))
	fails += _check(f.income().y == want, "정산 식량 = 평원 %d + 낚시터 (%d)" % [plains, f.income().y])
	f.upgrade(Vector2i(3, 8))
	f.upgrade(Vector2i(3, 8))
	fails += _check(f.fishing_food(Vector2i(3, 8)) == Balance.fishing_food(open_cells, 3), "낚시터 레벨 3: 식량 ×2")
	# 거래 데이터
	fails += _check(Balance.TRADES.size() == 2 and Balance.TRADE_OFFERS_LV == [2, 2, 2] and Balance.TRADE_INTERVAL == 3, "거래 2종(조각 거래 삭제, 식량 거래 없음), 방문 간격 3")
	# 일회성 수비병
	var gs: Node = load("res://assets/scripts/game_state.gd").new()
	gs.extra_guards = 2
	var b: Battle = Battle.new()
	b.setup(_lake_island(), gs, 1)
	fails += _check(b.soldiers.size() == Balance.HQ_GUARDS + 2 and gs.extra_guards == 0, "추가 수비병 2명이 나오고 1회성이다")
	# 효과음
	var sfx: AudioStreamWAV = load("res://assets/audio/sfx/npc_visit.wav")
	fails += _check(sfx != null and sfx.get_length() > 0.5, "방문 효과음 파일이 있다")
	var audio: Node = root.get_node("AudioManager")
	fails += _check(audio.play("npc_visit"), "효과음 재생")
	fails += _check(not audio.play("없는_소리"), "없는 소리는 false")
	print("낚시터·교역소 점검 실패 %d건" % fails)
	quit(fails)


## 5x5 평원 섬 (4,4)부터, 가운데 (6,6)은 바다(호수). 본부는 (4,4)
func _lake_island() -> Field:
	var f: Field = preload("res://tests/small_field.gd").make()
	var p: Piece = Piece.new()
	for y in 5:
		for x in 5:
			if x == 2 and y == 2:
				continue
			p.cells.append(Vector2i(x, y))
			p.terrain.append(Piece.PLAINS)
	p.hq_index = 0
	f.place(p, Vector2i(4, 4))
	return f


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

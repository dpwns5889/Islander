extends SceneTree
## 승리 화면·최고 웨이브·메뉴·효과음 점검: godot --headless --script tests/m22_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var sm: Node = root.get_node("SaveManager")
	var old: int = sm.best_wave
	sm.best_wave = 0
	fails += _check(sm.record(5) and not sm.record(3) and sm.best_wave == 5, "최고 웨이브는 더 높을 때만 갱신")
	var menu: Node = load("res://assets/scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	fails += _check(menu.find_children("*", "Button", true, false).size() == 2, "메뉴: 시작·종료 버튼")
	menu.queue_free()
	for n in ["hit", "tower", "landing", "boss", "win", "lose"]:
		fails += _check(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % n), "효과음 " + n)
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	fails += _check(not main.field.sea_blocked(), "기본 필드는 바닷길이 열려 있다")
	gs.wave = Balance.WIN_WAVE - 1
	_win(main)
	fails += _check(_result_btns(main).is_empty(), "29웨이브를 막아도 승리 화면 없음")
	_win(main)
	var btns: Array[Button] = _result_btns(main)
	fails += _check(gs.wave == Balance.WIN_WAVE + 1 and sm.best_wave == Balance.WIN_WAVE and btns.size() == 2, "30웨이브를 막으면 승리 화면(계속하기·처음으로), 최고 웨이브 저장")
	if btns.size() == 2:
		btns[0].pressed.emit()
		await process_frame
		fails += _check(_result_btns(main).is_empty(), "계속하기로 승리 화면이 닫힘")
	sm.best_wave = old # 테스트가 실제 저장을 바꾸지 않게 되돌린다
	print("승리·메뉴 점검 실패 %d건" % fails)
	quit(fails)


func _result_btns(main: Node) -> Array[Button]:
	var out: Array[Button] = []
	for b in main.layer.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("계속하기") or (b as Button).text == "처음으로":
			out.append(b)
	return out


func _win(main: Node) -> void:
	main.call_wave()
	main.battle.clear_enemies() # 웨이브를 바로 막은 것으로 친다
	main.advance(0.1)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

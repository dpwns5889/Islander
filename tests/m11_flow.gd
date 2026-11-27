extends SceneTree
## 다음 웨이브 적 예고 화면 점검: godot --headless --script tests/m11_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	main.edge_pan = false # 마우스 위치로 카메라가 움직이지 않게
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.found_start(preload("res://tests/coastal_start.gd").pick(main.field))
	fails += _check(main.wave_info.visible and "웨이브 1 예고: 해적 2명 (전투력 2 · 해적선 1척)" in main.wave_info.text, "1웨이브 예고: " + main.wave_info.text)
	var before: String = main.wave_info.text
	main.field.hqs[Vector2i(-50, -50)] = Balance.HQ_HP # 도시가 늘면 해적의 세기(배율)가 예고에 반영된다
	main._refresh_hud()
	fails += _check(main.wave_info.text != before and "×1.15" in main.wave_info.text, "도시가 늘면 예고의 배율이 바뀐다: " + main.wave_info.text)
	main.field.hqs.erase(Vector2i(-50, -50))
	gs.wave = 4
	main._refresh_hud()
	fails += _check("웨이브 4 예고: 해적 3명 (전투력 3 · 해적선 1척)" in main.wave_info.text, "4웨이브 예고: " + main.wave_info.text)
	gs.wave = 5
	main._refresh_hud()
	fails += _check("전투력 4 · 해적선 2척" in main.wave_info.text and "석궁수" in main.wave_info.text, "5웨이브 예고: " + main.wave_info.text)
	gs.wave = 1
	main.call_wave()
	main._refresh_hud()
	fails += _check(main.wave_info.visible and "웨이브 2 예고" in main.wave_info.text, "웨이브가 오면 예고는 다음 웨이브로 바뀐다: " + main.wave_info.text)
	print("적 예고 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

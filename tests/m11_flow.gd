extends SceneTree
## 준비 단계 적 예고 화면 점검: godot --headless --script tests/m11_flow.gd


func _initialize() -> void:
	var fails: int = 0
	var main: Node = load("res://assets/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs: Node = root.get_node("GameState")
	main.place_current(Vector2i(9, 7))
	main.tiles_required = 0 # 보상 타일 강제 규칙은 m14에서 따로 점검한다
	fails += _check(main.wave_info.visible and "웨이브 1 예고: 해적 2명 (해적선 1척)" in main.wave_info.text, "1웨이브 예고: " + main.wave_info.text)
	var before: String = main.wave_info.text
	main.field.expand(Vector2i.RIGHT) # 확장하면 해적의 세기(배율)가 예고에 반영된다
	gs.gold = 1000
	main.field.expand(Vector2i.LEFT)
	main._refresh_hud()
	fails += _check(main.wave_info.text != before, "확장하면 예고의 배율이 바뀐다: " + main.wave_info.text)
	gs.wave = 4
	main._refresh_hud()
	fails += _check("웨이브 4 예고: 해적 3명 (해적선 1척)" in main.wave_info.text, "4웨이브 예고: " + main.wave_info.text)
	gs.wave = 5
	main._refresh_hud()
	fails += _check("석궁수 1명 · 해적 3명 (해적선 2척)" in main.wave_info.text, "5웨이브 예고: " + main.wave_info.text)
	gs.wave = 1
	main.start_wave()
	fails += _check(not main.wave_info.visible, "전투 중에는 예고를 숨긴다")
	print("적 예고 흐름 점검 실패 %d건" % fails)
	quit(fails)


func _check(ok: bool, msg: String) -> int:
	if not ok:
		print("실패: ", msg)
	return 0 if ok else 1

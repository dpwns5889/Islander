extends RefCounted
## 점검용: 건설·강화·진화를 하고 10초 공사를 바로 끝낸다. 공사 시간 자체는 tests/r2_flow.gd가 본다 (기획서 5.1.1)


static func build(main: Node, c: Vector2i) -> bool:
	var ok: bool = main.try_build(c)
	if ok:
		finish(main)
	return ok


static func upgrade(main: Node) -> bool:
	var ok: bool = main.upgrade_selected()
	if ok:
		finish(main)
	return ok


static func finish(main: Node) -> void:
	for d: Array in main.field.tick_jobs(Balance.BUILD_TIME):
		main._job_done(d[0], d[1])
	main._refresh_hud() # 공사가 끝난 뒤의 패널 글자·버튼

extends Node3D
## 시작 위치 고르기와 실시간 진행: 10초 생산 틱, 웨이브 타이머, 일시정지·배속, 건설·연구·수리 (기획서 2장, 3장, 5장)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var field: Field
var pixel: PixelView
var cursor: MeshInstance3D ## 건설·시작 위치 표시
var build_id: int = 0 ## 건설 모드의 건물 종류, 0이면 건설 모드 아님
var top_panel: PanelContainer
var res_bar: PanelContainer ## 최상단 고정 자원바 (기획서 7.2)
var build_panel: PanelContainer
var side_panel: PanelContainer
var city_list: VBoxContainer ## 왼쪽 도시 목록: 도시마다 버튼 한 줄, 누르면 카메라가 그 도시로 (기획서 5.3)
var build_buttons: Dictionary = {}
var selected_cell: Vector2i = Vector2i(-1, -1) ## 레벨업 패널에 보이는 건물
var upgrade_panel: PanelContainer
var upgrade_title: Label
var upgrade_effect: Label
var upgrade_button: Button
var repair_button: Button ## 고른 건물·본부 수리 (기획서 5.2.2)
var repair_all_button: Button
var research_panel: PanelContainer
var research_buttons: Dictionary = {} ## 연구 id → 버튼
var selected_tech: String = "" ## 연구 창에서 고른 연구 (오른쪽 상세 창에 표시) (기획서 5.4)
var tech_detail: RichTextLabel
var tech_do_button: Button
const TECH_W: float = 140.0 ## 트리 버튼 너비
const TECH_PITCH: float = 170.0 ## 열 간격
var tech_lines: Control ## 연구 선행 연결선을 그리는 판
var research_toggle: Button
var stats: Label
var status: Label
var wave_button: Button
var speed_button: Button
var category_buttons: Array[Button] = [] ## 건설 메뉴 카테고리 버튼
var dropdown_panel: PanelContainer ## 카테고리를 누르면 위로 펼쳐지는 목록
var dropdown_lists: Array[VBoxContainer] = []
var open_category: int = -1
var npc_next_time: float = -1.0 ## 교역 NPC가 다음에 올 게임 시간, 교역소가 없으면 -1 (기획서 5.6)
var npc_leave_time: float = 0.0 ## 와 있는 NPC가 떠날 게임 시간
var npc_present: bool = false ## 교역 NPC가 와 있는지 (기획서 5.6)
var npc_node: MeshInstance3D = null
var trade_offers: Array = []
var trade_sold: Dictionary = {} ## 이번 방문에서 이미 한 거래 id → true
var trade_button: Button
var trade_panel: PanelContainer
var trade_list: VBoxContainer
var trade_buttons: Dictionary = {}
var wave_panel: PanelContainer
var wave_info: Label ## 다음 웨이브 적 예고
var battle_speed_index: int = 0
var paused: bool = false ## 스페이스로 일시정지 (기획서 2장)
var pause_button: Button
var game_time: float = 0.0 ## 첫 도시를 세운 뒤 흐른 게임 시간(초). 배속을 따르고 일시정지 중에는 멈춘다
var wave_timer: float = 0.0 ## 다음 웨이브까지 남은 게임 시간(초)
var prod_timer: float = 0.0 ## 다음 생산 틱까지 남은 게임 시간(초)
var last_wave_time: float = -1.0 ## 마지막(30) 웨이브가 온 게임 시간 (승리 안전장치)
var victory_shown: bool = false
var over: bool = false ## 패배해 판이 끝났는지
var repairing: Dictionary = {} ## 수리 중인 건물·도시 칸 → true (5초에 걸쳐 찬다) (기획서 5.2.2)
var layer: CanvasLayer
var battle: Battle = null ## 첫 도시를 세우면 만들어져 판 내내 돈다
var selected_squads: Array[int] = [] ## 숫자키·분대 줄로 고른 분대 번호 (기획서 6장)
var squad_panel: PanelContainer ## 하단 가운데 분대 줄 (기획서 7.2)
var squad_buttons: Array[Button] = [] ## 1~9번 분대 아이콘
var reinforce_button: Button
var squad_prod_buttons: Dictionary = {} ## "melee"/"ranged" → 병영 패널의 분대 생산 버튼
var queue_buttons: Array[Button] = [] ## 병영 패널의 대기열(누르면 취소)
var selected_settler: Unit = null ## 좌클릭으로 고른 개척자. 분대 선택과 둘 중 하나만 (기획서 4장)
var found_button: Button ## 고른 개척자의 "도시 세우기"
var settler_button: Button ## 도시 패널의 개척자 생산·취소
var _tap_n: int = 0 ## 숫자키 두 번 누르기 판정
var minimap_panel: PanelContainer ## 오른쪽 아래 미니맵 (기획서 7.2)
var minimap: TextureRect
var _mini_img: Image
var _mini_terrain: Image ## 지형만 그린 미니맵 바탕 (지형은 판 중에 바뀌지 않는다)
var _explore_timer: float = 0.0
var _tap_time: float = -10.0
## 카메라는 쿼터뷰 하나다 (기획서 7.2)
var _zoom: float = Balance.ZOOM_START ## 휠 줌 배율(작을수록 확대)
var _pitch: float = Balance.COMBAT_PITCH ## 기울기(도)
var _yaw: float = Balance.COMBAT_YAW ## 좌우 회전(도)
var _pan: Vector3 = Vector3.ZERO ## 화면 중앙이 맵 중심에서 옮겨 간 거리
var _press: Vector2 = Vector2.ZERO ## 좌클릭을 누른 자리
var _pressing: bool = false
var _rotating: bool = false ## 좌클릭을 끌어 회전하는 중 (놓아도 클릭으로 치지 않는다)
var edge_pan: bool = true ## 화면 가장자리 카메라 이동. 테스트·캡처는 끈다
var _note: String = ""
var _hud_timer: float = 0.0
var _gmats: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED # 게임 중에는 마우스가 창 밖으로 나가지 않는다 (기획서 7.2)
	rng.randomize()
	GameState.reset()
	_build_world()
	field.generate_map(rng.randi())
	_build_ui()
	GameState.changed.connect(_refresh_hud)
	_begin()


func _build_world() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.15, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, -30, 0)
	add_child(sun)
	pixel = PixelView.new() # 3D를 낮은 해상도로 그려 도트처럼 보이게 한다 (기획서 7.2)
	add_child(pixel)
	field = Field.new()
	field.territory_enabled = true
	add_child(field)
	cursor = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(0.9, 0.1, 0.9)
	cursor.mesh = cm
	cursor.visible = false
	add_child(cursor)
	_update_camera()


func _build_ui() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	# 상단: 자원·웨이브·웨이브 시작, 그 아래 안내 문구
	var top: VBoxContainer = VBoxContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	# 골드·식량·연구포인트는 최상단 고정바로 분리 (기획서 7.2)
	stats = Label.new()
	res_bar = PanelContainer.new()
	res_bar.add_child(stats)
	res_bar.visible = false
	layer.add_child(res_bar)
	res_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	wave_button = Button.new()
	wave_button.pressed.connect(call_wave)
	row.add_child(wave_button)
	pause_button = Button.new()
	pause_button.pressed.connect(toggle_pause)
	row.add_child(pause_button)
	speed_button = Button.new()
	speed_button.pressed.connect(cycle_speed)
	speed_button.text = "배속 x1"
	row.add_child(speed_button)
	trade_button = Button.new()
	trade_button.text = "교역 NPC 방문!"
	trade_button.modulate = Color(1.0, 0.9, 0.4)
	trade_button.visible = false
	trade_button.pressed.connect(_toggle_trade)
	row.add_child(trade_button)
	top.add_child(row)
	status = Label.new()
	top.add_child(status)
	top_panel = PanelContainer.new()
	top_panel.add_child(top)
	layer.add_child(top_panel)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	top_panel.position.y = 44 # 고정바 아래
	# 이번 웨이브 예고는 우상단 별도 패널로 분리한다. 좁게 줄바꿈해 필드를 덜 가린다 (기획서 7.2)
	wave_info = Label.new()
	wave_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_info.custom_minimum_size = Vector2(300, 0)
	wave_panel = PanelContainer.new()
	wave_panel.add_child(wave_info)
	wave_panel.visible = false
	layer.add_child(wave_panel)
	wave_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	wave_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wave_panel.position.y = 44
	# 하단: 건설 메뉴 = 카테고리 버튼. 누르면 그 위로 건물 목록이 펼쳐진다 (기획서 7.2)
	var bar: HBoxContainer = HBoxContainer.new()
	var drop_box: VBoxContainer = VBoxContainer.new()
	for i in Balance.CATEGORIES.size():
		var cat: Dictionary = Balance.CATEGORIES[i]
		var cb: Button = Button.new()
		cb.text = cat["name"] + " ▲"
		cb.custom_minimum_size.x = 120
		cb.pressed.connect(_toggle_category.bind(i))
		category_buttons.append(cb)
		bar.add_child(cb)
		var list: VBoxContainer = VBoxContainer.new()
		list.visible = false
		for id in cat["ids"]:
			var b: Button = Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.x = 380
			b.pressed.connect(_on_build_button.bind(id))
			build_buttons[id] = b
			list.add_child(b)
		dropdown_lists.append(list)
		drop_box.add_child(list)
	minimap = TextureRect.new()
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.custom_minimum_size = Vector2.ONE * Balance.MINIMAP_SIZE
	minimap.gui_input.connect(_on_minimap_input)
	minimap_panel = PanelContainer.new()
	var frame: StyleBoxFlat = StyleBoxFlat.new() # 안개와 같은 색이라 테두리로 미니맵 자리를 구분한다
	frame.bg_color = Color(0.05, 0.05, 0.07)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.75, 0.75, 0.8)
	minimap_panel.add_theme_stylebox_override("panel", frame)
	minimap_panel.add_child(minimap)
	minimap_panel.visible = false
	layer.add_child(minimap_panel)
	minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap_panel.offset_bottom -= 56 # 건설 메뉴 한 줄 위
	minimap_panel.offset_top -= 56
	build_panel = PanelContainer.new()
	build_panel.add_child(bar)
	build_panel.visible = false
	layer.add_child(build_panel)
	build_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10) # 건설 메뉴는 오른쪽 아래 (기획서 7.2)
	build_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dropdown_panel = PanelContainer.new()
	dropdown_panel.add_child(drop_box)
	dropdown_panel.visible = false
	layer.add_child(dropdown_panel)
	# 왼쪽: 본부 레벨, 연구
	var side: VBoxContainer = VBoxContainer.new()
	city_list = VBoxContainer.new()
	side.add_child(city_list)
	research_toggle = Button.new()
	research_toggle.pressed.connect(_toggle_research)
	side.add_child(research_toggle)
	repair_all_button = Button.new()
	repair_all_button.pressed.connect(repair_everything)
	side.add_child(repair_all_button)
	side_panel = PanelContainer.new()
	side_panel.add_child(side)
	side_panel.visible = false
	layer.add_child(side_panel)
	side_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	side_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN # 글자가 늘어도 화면 아래로 잘리지 않게 위로 자란다
	# 하단 가운데: 분대 줄. 아이콘을 누르면 고르고, Shift를 누른 채면 더한다 (기획서 6장, 7.2)
	var sbar: HBoxContainer = HBoxContainer.new()
	for n in range(1, Balance.SQUAD_CAP_MAX + 1):
		var sbtn: Button = Button.new()
		sbtn.pressed.connect(func() -> void: select_squad(n, Input.is_key_pressed(KEY_SHIFT)))
		squad_buttons.append(sbtn)
		sbar.add_child(sbtn)
	reinforce_button = Button.new()
	reinforce_button.pressed.connect(reinforce_selected)
	sbar.add_child(reinforce_button)
	found_button = Button.new()
	found_button.pressed.connect(found_with_settler)
	sbar.add_child(found_button)
	squad_panel = PanelContainer.new()
	squad_panel.add_child(sbar)
	squad_panel.visible = false
	layer.add_child(squad_panel)
	squad_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	squad_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	squad_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	squad_panel.offset_bottom -= 56 # 분대가 9개로 늘어도 하단 건설 메뉴와 겹치지 않게 한 줄 위에 둔다
	# 선택한 건물의 레벨업 패널: 위치는 _place_upgrade_panel이 정한다 (기획서 7.2)
	var up: VBoxContainer = VBoxContainer.new()
	upgrade_title = Label.new()
	up.add_child(upgrade_title)
	upgrade_effect = Label.new()
	up.add_child(upgrade_effect)
	upgrade_button = Button.new()
	upgrade_button.pressed.connect(upgrade_selected)
	up.add_child(upgrade_button)
	repair_button = Button.new()
	repair_button.pressed.connect(repair_selected)
	up.add_child(repair_button)
	settler_button = Button.new() # 도시: 개척자 생산 (기획서 4장)
	settler_button.pressed.connect(toggle_settler)
	up.add_child(settler_button)
	var prod: HBoxContainer = HBoxContainer.new() # 병영: 분대 생산과 대기열 (기획서 6장)
	for type: String in Balance.SQUADS:
		var pb: Button = Button.new()
		pb.pressed.connect(queue_selected.bind(type))
		squad_prod_buttons[type] = pb
		prod.add_child(pb)
	up.add_child(prod)
	for i in Balance.SQUAD_QUEUE:
		var qb: Button = Button.new()
		qb.pressed.connect(cancel_queued.bind(i))
		queue_buttons.append(qb)
		up.add_child(qb)
	upgrade_panel = PanelContainer.new()
	var usb: StyleBoxFlat = StyleBoxFlat.new() # 필드 위에 뜨므로 뒤의 글자가 비치지 않게 불투명한 배경
	usb.bg_color = Color(0.08, 0.1, 0.16, 0.97)
	usb.set_content_margin_all(10)
	upgrade_panel.add_theme_stylebox_override("panel", usb)
	upgrade_panel.add_child(up)
	upgrade_panel.visible = false
	layer.add_child(upgrade_panel)
	# 가운데: 연구 패널 (4열 14개, 문명5식)
	var rbox: VBoxContainer = VBoxContainer.new()
	var rtitle: Label = Label.new()
	rtitle.text = "연구 — 연구를 고르면 오른쪽에 자세한 내용이 나옵니다 (연구 후 취소 없음)"
	rbox.add_child(rtitle)
	# 문명5식 연구 화면: 열은 왼쪽에서 오른쪽, 선행 연구에서 후속 연구로 선을 긋는다 (기획서 5.4)
	var tree: Control = Control.new()
	tree.custom_minimum_size = Vector2(Balance.TECH_COLS * TECH_PITCH - (TECH_PITCH - TECH_W), Balance.TECH_ROWS * 74)
	for tid in Balance.TECHS:
		var tb: Button = Button.new()
		tb.size = Vector2(TECH_W, 62)
		tb.position = _tech_pos(tid)
		tb.pressed.connect(select_tech.bind(tid))
		research_buttons[tid] = tb
		tree.add_child(tb)
	tech_lines = tree
	tree.draw.connect(_draw_tech_lines)
	# 오른쪽: 고른 연구의 자세한 내용과 연구 버튼
	var detail: VBoxContainer = VBoxContainer.new()
	detail.custom_minimum_size = Vector2(300, 0)
	tech_detail = RichTextLabel.new()
	tech_detail.bbcode_enabled = true
	tech_detail.fit_content = false
	tech_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(tech_detail)
	tech_do_button = Button.new()
	tech_do_button.pressed.connect(func() -> void: research(selected_tech))
	detail.add_child(tech_do_button)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.add_child(tree)
	body.add_child(detail)
	rbox.add_child(body)
	var rclose: Button = Button.new()
	rclose.text = "닫기"
	rclose.pressed.connect(_toggle_research)
	rbox.add_child(rclose)
	research_panel = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new() # 필드가 비치지 않게 불투명한 배경
	sb.bg_color = Color(0.08, 0.1, 0.16, 0.97)
	sb.set_content_margin_all(10)
	research_panel.add_theme_stylebox_override("panel", sb)
	research_panel.add_child(rbox)
	research_panel.visible = false
	layer.add_child(research_panel)
	research_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	research_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	research_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# 가운데: 교역 NPC 거래 창. 닫아도 NPC가 있는 동안 버튼으로 다시 열 수 있다 (기획서 5.6)
	var tbox: VBoxContainer = VBoxContainer.new()
	var ttitle: Label = Label.new()
	ttitle.text = "교역 NPC — 방문당 한 번씩 거래할 수 있습니다"
	tbox.add_child(ttitle)
	trade_list = VBoxContainer.new()
	tbox.add_child(trade_list)
	var tclose: Button = Button.new()
	tclose.text = "닫기"
	tclose.pressed.connect(_toggle_trade)
	tbox.add_child(tclose)
	trade_panel = PanelContainer.new()
	var tsb: StyleBoxFlat = StyleBoxFlat.new()
	tsb.bg_color = Color(0.12, 0.09, 0.16, 0.97)
	tsb.set_content_margin_all(10)
	trade_panel.add_theme_stylebox_override("panel", tsb)
	trade_panel.add_child(tbox)
	trade_panel.visible = false
	layer.add_child(trade_panel)
	trade_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	trade_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	trade_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _over_ui() -> bool:
	var mp: Vector2 = get_viewport().get_mouse_position()
	for c: Control in [top_panel, res_bar, wave_panel, build_panel, minimap_panel, side_panel, upgrade_panel, research_panel, dropdown_panel, trade_panel, squad_panel]:
		if c.visible and c.get_global_rect().has_point(mp):
			return true
	return false


func _on_build_button(id: int) -> void:
	set_build(0 if build_id == id else id)


func set_build(id: int) -> void:
	build_id = id
	open_category = -1 # 건물을 고르거나 설치 모드가 끝나면 목록을 닫는다
	_update_dropdown()
	_note = ""
	_refresh_hud()


## 건설 메뉴 카테고리를 열고 닫는다 (기획서 7.2)
func _toggle_category(i: int) -> void:
	open_category = -1 if open_category == i else i
	_update_dropdown()


func _update_dropdown() -> void:
	dropdown_panel.visible = open_category >= 0
	for j in dropdown_lists.size():
		dropdown_lists[j].visible = j == open_category
		category_buttons[j].text = "%s %s" % [Balance.CATEGORIES[j]["name"], "▼" if j == open_category else "▲"]
	if dropdown_panel.visible:
		_refresh_hud()
		_place_dropdown()


## 목록을 눌린 카테고리 버튼 바로 위에 붙인다
func _place_dropdown() -> void:
	dropdown_panel.reset_size()
	await get_tree().process_frame
	if open_category < 0:
		return
	var btn: Button = category_buttons[open_category]
	var x: float = clampf(btn.global_position.x, 0.0, get_viewport().get_visible_rect().size.x - dropdown_panel.size.x)
	dropdown_panel.position = Vector2(x, btn.global_position.y - dropdown_panel.size.y - 4.0)


## 교역 NPC: 교역소를 지은 지 2분 뒤 처음, 그 뒤 6분마다 와서 60초 머문다 (기획서 5.6)
func _npc_tick() -> void:
	var post: Vector2i = field.trading_post()
	if post.x < 0:
		npc_next_time = -1.0
		if npc_present:
			_npc_leave()
		return
	if npc_present and game_time >= npc_leave_time:
		_npc_leave()
	if npc_next_time >= 0.0 and game_time >= npc_next_time:
		spawn_npc(post)
		npc_next_time += Balance.TRADE_INTERVAL


func spawn_npc(post: Vector2i) -> void:
	npc_present = true
	trade_sold.clear()
	var pool: Array = Balance.TRADES.duplicate()
	for i in range(pool.size() - 1, 0, -1): # 섞기
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	trade_offers = pool.slice(0, mini(Balance.TRADE_OFFERS_LV[field.levels[post] - 1], pool.size()))
	for ch in trade_list.get_children():
		ch.queue_free()
	trade_buttons.clear()
	for offer: Dictionary in trade_offers:
		var tb: Button = Button.new()
		tb.custom_minimum_size.x = 360
		tb.pressed.connect(do_trade.bind(offer["id"]))
		trade_buttons[offer["id"]] = tb
		trade_list.add_child(tb)
	if npc_node != null:
		npc_node.queue_free()
	npc_node = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.14
	cm.height = 0.5
	npc_node.mesh = cm
	npc_node.material_override = Toon.material(Color(0.85, 0.5, 0.95))
	npc_node.position = field.cell_to_world(post) + Vector3(0.4, Field.BLOCK_H + 0.25, 0.35)
	add_child(npc_node)
	AudioManager.play("npc_visit") # 방문 효과음
	npc_leave_time = game_time + Balance.TRADE_STAY
	_note = "교역 NPC가 방문했습니다! (%d초 머뭅니다)" % roundi(Balance.TRADE_STAY)


func _npc_leave() -> void:
	npc_present = false
	trade_panel.visible = false
	if npc_node != null:
		npc_node.queue_free()
		npc_node = null


func _toggle_trade() -> void:
	trade_panel.visible = npc_present and not trade_panel.visible
	_refresh_hud()


func _trade_def(id: String) -> Dictionary:
	for t: Dictionary in Balance.TRADES:
		if t["id"] == id:
			return t
	return {}


func _trade_ok(id: String) -> bool:
	var t: Dictionary = _trade_def(id)
	return npc_present and not trade_sold.has(id) and GameState.gold >= t["gold"] and GameState.food >= t["food"]


## NPC와 거래한다. 방문당 거래마다 한 번만 (기획서 5.6)
func do_trade(id: String) -> bool:
	if not _trade_ok(id) or not trade_buttons.has(id):
		return false
	var t: Dictionary = _trade_def(id)
	GameState.spend(t["gold"], t["food"])
	trade_sold[id] = true
	if id == "gold_rp":
		GameState.add_research(1)
	_refresh_hud()
	return true


## 판 시작: 안개를 덮고 맵 중심에 가까운 시작 섬에 개척자와 경비병 2명을 둔다. 시간은 처음부터 흐른다 (기획서 2장, 3장)
func _begin() -> void:
	var c: Vector2i = field.settler_start()
	battle = Battle.new()
	add_child(battle)
	battle.setup(field, GameState)
	battle.finished.connect(_on_battle_finished)
	battle.speed_scale = _speed()
	battle.add_guards(c)
	var s: Unit = battle.add_settler(c)
	field.enable_fog()
	var near: Dictionary = {} # 시작 칸 주변 4칸에는 유적지를 두지 않는다 (기획서 3장)
	for y in range(c.y - 4, c.y + 5):
		for x in range(c.x - 4, c.x + 5):
			if Vector2(x - c.x, y - c.y).length() <= Balance.VISION_RANGE:
				near[Vector2i(x, y)] = true
	field.place_ruins(rng, near)
	_explore()
	_build_minimap()
	for p: Control in [minimap_panel, res_bar, build_panel, side_panel, squad_panel, wave_panel, wave_button, pause_button, speed_button]:
		p.visible = true
	wave_timer = Balance.WAVE_FIRST_DELAY # 첫 웨이브 3분은 게임 시작부터 센다 (기획서 2장)
	prod_timer = Balance.PRODUCTION_TICK
	_zoom = 1.0 # 시작 개척자를 비춘다
	_pan = field.cell_to_world(c) - field.center_world()
	_update_camera()
	select_settler(s)


## 점검·캡처용 지름길: 시작 개척자를 c로 옮겨 바로 첫 도시를 세운다. 첫 도시가 이미 있거나 시작 섬의 평원이 아니면 false
func found_start(c: Vector2i) -> bool:
	if not field.can_start(c) or battle.settlers().is_empty():
		return false
	var s: Unit = battle.settlers()[0]
	for u: Unit in [s] + battle.squad_units(1): # 개척자와 시작 경비병이 c에서 시작한 것처럼 옮긴다
		u.position = Vector3(field.cell_to_world(c).x, u.position.y, field.cell_to_world(c).z)
		u.home = c
		u.order = Vector2i(-1, -1)
		u.path.clear()
		u.island = battle.islands.get(c, -1)
	select_settler(s)
	if not found_with_settler():
		return false
	_pan = field.cell_to_world(c) - field.center_world()
	_update_camera()
	_note = ""
	_refresh_hud()
	return true


func try_build(c: Vector2i) -> bool:
	if not _build_ok(c):
		return false
	GameState.spend(_cost_of(build_id))
	field.build(build_id, c)
	if build_id == Balance.TRADING_POST: # 지은 지 2분 뒤 첫 방문 (기획서 5.6)
		npc_next_time = game_time + Balance.TRADE_FIRST_DELAY
	if battle != null and build_id == Balance.PORT:
		battle.add_port(c)
	set_build(0) # 건물을 하나 지으면 설치 모드가 끝난다
	return true


## 건물·도시를 골라 패널을 연다. 둘 다 아니면 선택을 푼다 (기획서 5.2)
func select_building(c: Vector2i) -> bool:
	selected_cell = c if field.buildings.has(c) or field.hqs.has(c) else Vector2i(-1, -1)
	_refresh_hud()
	return selected_cell.x >= 0


func _toggle_research() -> void:
	research_panel.visible = not research_panel.visible
	_refresh_hud()


## 연구 창에서 연구를 고른다. 연구는 오른쪽 상세 창의 버튼으로 한다 (기획서 5.4)
func select_tech(id: String) -> void:
	selected_tech = id
	_refresh_hud()


## 연구포인트로 연구한다 (기획서 5.4)
func research(id: String) -> bool:
	if not GameState.research(id):
		return false
	_note = "연구 완료: " + Balance.TECHS[id]["name"]
	_refresh_hud()
	return true


func _unlocked(id: int) -> bool:
	var tech: String = Balance.BUILDINGS[id].get("tech", "")
	return (tech == "" or GameState.has_tech(tech))


## 병영·사격장 레벨 3 강화는 철기 제작이 필요하다 (기획서 5.2)
func _upgrade_locked(c: Vector2i) -> bool:
	return [Balance.BARRACKS, Balance.SHOOTING_RANGE].has(field.buildings[c]) and field.levels[c] + 1 == Balance.MAX_LEVEL and not GameState.has_tech(Balance.LV3_TECH)


## 레벨 3 기본 건물이 진화할 수 있는지: 진화 건물이 있고 해금 연구를 마쳤는지 (기획서 5.2.1)
func _can_evolve(c: Vector2i) -> bool:
	var to: int = Balance.evolve_to(field.buildings[c])
	return to > 0 and field.levels[c] >= Balance.MAX_LEVEL and GameState.has_tech(Balance.BUILDINGS[to].get("tech", ""))


## 수리할 수 있는지: 파손됐고, 이미 수리 중이 아니고, 3칸 안에 적이 없다 (기획서 5.2.2)
func can_repair(c: Vector2i) -> bool:
	return field.repair_cost(c) > 0 and not repairing.has(c) and not (battle != null and battle.enemy_near(c, Balance.REPAIR_ENEMY_RANGE))


## 고른 건물·도시를 골드로 고친다: 비용을 내면 5초에 걸쳐 체력이 찬다 (기획서 5.2.2)
func repair_selected() -> bool:
	return _start_repair(selected_cell)


func _start_repair(c: Vector2i) -> bool:
	if not can_repair(c) or not GameState.spend(field.repair_cost(c)):
		return false
	repairing[c] = true
	_refresh_hud()
	return true


## 고칠 수 있는 건물·도시를 한 번에 고친다 (기획서 5.2.2)
func repair_everything() -> bool:
	var cost: int = _repair_all_cost()
	if cost <= 0 or GameState.gold < cost:
		return false
	for c in field.targets():
		_start_repair(c)
	return true


func _repair_all_cost() -> int:
	var total: int = 0
	for c in field.targets():
		if can_repair(c):
			total += field.repair_cost(c)
	return total


## 수리 중인 칸의 체력을 채운다. 다 차거나 건물이 없어지면 끝난다
func _repair_tick(dt: float) -> void:
	for c: Vector2i in repairing.keys():
		if not field.targets().has(c) or field.heal(c, dt / Balance.REPAIR_TIME):
			repairing.erase(c)


func upgrade_selected() -> bool:
	if not field.buildings.has(selected_cell) or field.hp_ratio(selected_cell) < 1.0: # 파손되면 먼저 수리한다 (기획서 5.2.2)
		return false
	if selected_cell.x >= 0 and _can_evolve(selected_cell):
		var to: int = Balance.evolve_to(field.buildings[selected_cell])
		if not GameState.spend(GameState.upgrade_discounted(Balance.evolve_cost(to))):
			return false
		field.evolve(selected_cell, to)
		_note = ""
		_refresh_hud()
		return true
	if selected_cell.x < 0 or not field.can_upgrade(selected_cell) or _upgrade_locked(selected_cell):
		return false
	var cost: int = GameState.upgrade_discounted(Balance.upgrade_cost(field.buildings[selected_cell], field.levels[selected_cell] + 1))
	if not GameState.spend(cost):
		return false
	field.upgrade(selected_cell)
	_note = ""
	_refresh_hud()
	return true


func _cost_of(id: int) -> int:
	return int(Balance.BUILDINGS[id]["cost"])


func _build_ok(c: Vector2i) -> bool:
	if build_id == 0 or not _unlocked(build_id) or GameState.gold < _cost_of(build_id):
		return false
	return field.can_build(build_id, c)


## 지금 배속. 일시정지면 0 (기획서 2장)
func _speed() -> float:
	return 0.0 if paused or over else float(Balance.BATTLE_SPEEDS[battle_speed_index])


## 웨이브 부르기: 다음 웨이브를 바로 부르고 남은 시간만큼 골드를 받는다 (기획서 2장)
func call_wave() -> bool:
	if over:
		return false
	var bonus: int = floori(wave_timer * Balance.CALL_WAVE_GOLD)
	GameState.add(bonus, 0)
	_launch_wave()
	_note = "웨이브를 앞당겨 불렀습니다: 골드 +%d" % bonus
	_refresh_hud()
	return true


## 다음 웨이브가 온다. 앞 웨이브의 적이 남아 있어도 된다 (기획서 2장, 6장)
func _launch_wave() -> void:
	battle.launch_wave(GameState.wave)
	if GameState.wave == Balance.WIN_WAVE:
		last_wave_time = game_time
	GameState.next_wave()
	wave_timer = Balance.WAVE_INTERVAL


## 10초마다: 골드·식량·연구수치를 받고 도시 레벨을 올린다 (기획서 2장, 5.3, 5.4)
func _production() -> void:
	var inc: Vector2i = field.income(GameState.researched)
	GameState.add(inc.x, inc.y)
	var ups: Dictionary = field.settle_levels(GameState.researched)
	var rp_gain: int = GameState.add_research_progress(field.research_income(GameState.researched))
	var parts: Array[String] = []
	for h in ups:
		parts.append("도시 %s 레벨 %d!" % [_hq_name(h), field.hq_level[h]])
	if rp_gain > 0:
		parts.append("연구포인트 +%d" % rp_gain)
	if not parts.is_empty():
		_note = " · ".join(parts)


## 게임 시간을 dt만큼 흘린다: 생산 틱, 웨이브, 교역 NPC, 수리, 승리 (기획서 2장)
func advance(dt: float) -> void:
	if over or dt <= 0.0:
		return
	game_time += dt
	prod_timer -= dt
	while prod_timer <= 0.0:
		prod_timer += Balance.PRODUCTION_TICK
		_production()
	wave_timer -= dt
	if wave_timer <= 0.0:
		_launch_wave()
	_npc_tick()
	_repair_tick(dt)
	_take_ruins()
	_explore_timer -= dt
	if _explore_timer <= 0.0: # 밝히기는 0.2초마다면 충분하다
		_explore_timer = 0.2
		_explore()
	_check_victory()


## 30웨이브가 온 뒤 적이 모두 사라지면 승리. 막혀 남은 적은 300초 뒤 정리한다 (기획서 6장, 9.1)
func _check_victory() -> void:
	if victory_shown or GameState.wave <= Balance.WIN_WAVE:
		return
	if battle.enemies_left() > 0 and game_time - last_wave_time < Balance.VICTORY_SAFETY:
		return
	battle.clear_enemies()
	victory_shown = true
	SaveManager.record(Balance.WIN_WAVE)
	_show_victory()


## 배속 버튼: x1 → x2 → x4 → x1 (기획서 2장)
func cycle_speed() -> void:
	battle_speed_index = (battle_speed_index + 1) % Balance.BATTLE_SPEEDS.size()
	speed_button.text = "배속 x%d" % Balance.BATTLE_SPEEDS[battle_speed_index]
	if battle != null:
		battle.speed_scale = _speed()


## 일시정지: 일시정지 중에도 건설·연구·명령은 할 수 있다 (기획서 2장)
func toggle_pause() -> void:
	paused = not paused
	if battle != null:
		battle.speed_scale = _speed()
	_refresh_hud()


## 우클릭한 땅으로 병사들이 이동한다 (분대 지휘는 R3) (기획서 6장)
## 고른 분대를 클릭한 칸으로 보낸다. 고른 분대가 없으면 아무 일도 없다 (기획서 6장)
func command_move(c: Vector2i) -> bool:
	if battle == null or not field.is_walkable(c):
		return false
	if _settler_alive():
		selected_settler.order = c
	elif selected_squads.is_empty():
		return false
	else:
		battle.command_move(c, selected_squads)
	_ping(c)
	return true


## 개척자를 고른다. 분대 선택은 풀린다 (기획서 4장)
func select_settler(u: Unit) -> void:
	selected_settler = u
	selected_squads.clear()
	_refresh_hud()


func _settler_alive() -> bool:
	return selected_settler != null and is_instance_valid(selected_settler) and battle.settlers().has(selected_settler)


## c 칸에 서 있는 개척자 (없으면 null)
func _settler_at(c: Vector2i) -> Unit:
	if battle == null:
		return null
	for u in battle.settlers():
		if field.world_to_cell(u.position) == c:
			return u
	return null


## 고른 개척자가 서 있는 칸에 도시를 세운다. 개척자는 사라진다 (기획서 4장)
func found_with_settler() -> bool:
	if not _settler_alive():
		return false
	var c: Vector2i = selected_settler.home # 도착 판정이 0.6칸이라 위치 대신 도착한 칸(집)에 세운다
	if field.found_block(c) != "":
		return false
	field.found_city(c)
	_explore() # 새 도시 영역을 바로 밝힌다 (기획서 3장)
	battle.soldiers.erase(selected_settler)
	selected_settler.queue_free()
	selected_settler = null
	_note = "도시 %s를 세웠습니다! 분대 수 상한 %d" % [_hq_name(c), battle.squad_cap()]
	_refresh_hud()
	return true


## 고른 도시의 개척자 생산을 넣거나, 생산 중이면 취소한다 (기획서 4장)
func toggle_settler() -> bool:
	if battle == null or not field.hqs.has(selected_cell):
		return false
	var ok: bool = battle.cancel_settler(selected_cell) or battle.queue_settler(selected_cell)
	_refresh_hud()
	return ok


func _on_city_button(i: int) -> void:
	if i < _sorted_hqs().size():
		focus_city(_sorted_hqs()[i])


## 도시 목록을 누르면 카메라가 그 도시로 간다 (기획서 5.3)
func focus_city(h: Vector2i) -> void:
	_pan = field.cell_to_world(h) - field.center_world()
	_update_camera()


## 분대 n을 고른다. add면 고른 분대에 더하고(이미 있으면 뺀다). 0.4초 안에 같은 분대를 다시 고르면 카메라가 그 분대로 간다 (기획서 6장)
func select_squad(n: int, add: bool = false) -> bool:
	if battle == null or not battle.squads.has(n):
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if n == _tap_n and now - _tap_time <= Balance.SQUAD_DOUBLE_TAP:
		focus_squad(n)
	_tap_n = n
	_tap_time = now
	selected_settler = null
	if not add:
		selected_squads = [n]
	elif not selected_squads.has(n):
		selected_squads.append(n)
	elif selected_squads.size() > 1:
		selected_squads.erase(n)
	_refresh_hud()
	return true


## 카메라를 분대 병사들의 가운데로 옮긴다
func focus_squad(n: int) -> void:
	var units: Array[Unit] = battle.squad_units(n)
	if units.is_empty():
		return
	var at: Vector3 = Vector3.ZERO
	for u in units:
		at += u.position
	at /= units.size()
	_pan = Vector3(at.x, 0.0, at.z) - field.center_world()
	_update_camera()


## 고른 분대 중 충원할 수 있는 첫 분대를 충원한다 (기획서 6장)
func reinforce_selected() -> bool:
	var n: int = _reinforce_target()
	if n == 0 or not battle.reinforce(n):
		return false
	_refresh_hud()
	return true


## 고른 분대 중 병영 2칸 안에서 충원할 수 있는 첫 분대, 없으면 0
func _reinforce_target() -> int:
	for n in selected_squads:
		if battle.reinforce_site(n) != Battle.NO_CELL:
			return n
	return 0


## 고른 병영에 분대 생산을 넣는다 (기획서 6장)
func queue_selected(type: String) -> bool:
	if battle == null or not battle.queue_squad(selected_cell, type):
		return false
	_refresh_hud()
	return true


## 고른 병영의 대기열 i번째를 취소한다(비용 환불)
func cancel_queued(i: int) -> bool:
	if battle == null or not battle.cancel_squad(selected_cell, i):
		return false
	_refresh_hud()
	return true


## 클릭한 자리에 잠깐 퍼지는 표시
func _ping(c: Vector2i) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 0.03
	m.mesh = cm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.2, 0.85)
	m.material_override = mat
	m.position = field.cell_to_world(c) + Vector3(0, Field.BLOCK_H + 0.05, 0)
	add_child(m)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1.8, 1.0, 1.8), 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(m.queue_free)


## 모든 도시가 무너지면 패배 (기획서 1장)
func _on_battle_finished(victory: bool) -> void:
	if victory:
		return
	over = true
	SaveManager.record(GameState.wave - 1) # 졌어도 온 웨이브는 기록한다
	_show_defeat()


func _show_defeat() -> void:
	_result_panel("패배 — 웨이브 %d에서 도시가 모두 무너졌습니다" % (GameState.wave - 1), [["다시 시작", get_tree().reload_current_scene], ["처음으로", _to_menu]])
	status.text = ""


## 30웨이브 승리: 결과를 보여 주고 무한 모드로 계속하거나 처음으로 (기획서 9.1)
func _show_victory() -> void:
	var pc: PanelContainer = _result_panel("승리! %d웨이브를 지켜 냈습니다\n도시 %d개 · 최고 웨이브 %d" % [Balance.WIN_WAVE, field.hqs.size(), SaveManager.best_wave], [["계속하기 (무한 모드)", Callable()], ["처음으로", _to_menu]])
	(pc.get_child(0).get_child(1) as Button).pressed.connect(pc.queue_free)


## 메뉴로 나가거나 게임 화면이 사라지면 마우스 가두기를 푼다 (기획서 7.2)
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://assets/scenes/menu.tscn")


func _result_panel(text: String, buttons: Array) -> PanelContainer:
	var box: VBoxContainer = VBoxContainer.new()
	var l: Label = Label.new()
	l.text = text
	box.add_child(l)
	for bd in buttons:
		var b: Button = Button.new()
		b.text = bd[0]
		if not (bd[1] as Callable).is_null():
			b.pressed.connect(bd[1])
		box.add_child(b)
	var pc: PanelContainer = PanelContainer.new()
	pc.add_child(box)
	layer.add_child(pc)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	return pc


## 쿼터뷰 카메라를 놓는다 (기획서 7.2)
func _update_camera() -> void:
	var r: float = deg_to_rad(_pitch)
	# 직교 카메라라 거리는 화면 크기와 무관하다. 낮게 기울여도 땅이 잘리지 않게 멀리 둔다
	var offset: Vector3 = Vector3(0, sin(r), cos(r)).rotated(Vector3.UP, deg_to_rad(_yaw)) * 100.0
	pixel.aim(field.center_world() + _pan + offset, _pitch, _view_size(), _yaw)


## 카메라에 세로로 담기는 크기
func _view_size() -> float:
	return Balance.COMBAT_CAM_SIZE * _zoom


func _wheel_zoom(f: float) -> void:
	_zoom = clampf(_zoom * f, Balance.ZOOM_MIN, Balance.ZOOM_MAX)
	_update_camera()


## 화면 기준 motion(논리 픽셀)만큼 땅을 옮긴다. 화면 중앙은 맵 안에 둔다 (기획서 7.2)
func _pan_camera(motion: Vector2) -> void:
	var per_pixel: float = _view_size() / get_viewport().get_visible_rect().size.y
	var ground: Vector3 = Vector3(-motion.x, 0.0, -motion.y / sin(deg_to_rad(_pitch))) * per_pixel
	_pan += ground.rotated(Vector3.UP, deg_to_rad(_yaw))
	var half: Vector2 = Vector2(field.bounds.size) / 2.0
	_pan.x = clampf(_pan.x, -half.x, half.x)
	_pan.z = clampf(_pan.z, -half.y, half.y)
	_update_camera()


## 마우스가 화면 가장자리에 있으면 그 방향으로 카메라를 옮긴다 (기획서 7.2)
func _edge_pan(delta: float) -> void:
	if not edge_pan or not get_window().has_focus():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var mp: Vector2 = get_viewport().get_mouse_position()
	if not Rect2(Vector2.ZERO, view).has_point(mp):
		return
	var dir: Vector2 = Vector2.ZERO
	var m: float = Balance.EDGE_PAN_MARGIN
	dir.x = -1.0 if mp.x < m else (1.0 if mp.x > view.x - m else 0.0)
	dir.y = -1.0 if mp.y < m else (1.0 if mp.y > view.y - m else 0.0)
	if dir != Vector2.ZERO:
		_pan_camera(-dir.normalized() * view.y * Balance.EDGE_PAN_SPEED * delta)


## 좌클릭 드래그: 가로는 좌우 회전, 세로는 기울기 (기획서 7.2)
func _drag_camera(motion: Vector2) -> void:
	_yaw = wrapf(_yaw - motion.x * Balance.CAM_ROTATE_SENS, -180.0, 180.0)
	_pitch = clampf(_pitch + motion.y * Balance.CAM_ROTATE_SENS, Balance.CAM_PITCH_MIN, Balance.CAM_PITCH_MAX)
	_update_camera()


func _ghost_mat(ok: bool) -> StandardMaterial3D:
	var key: int = int(ok)
	if not _gmats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		var c: Color = Color(0.1, 0.85, 1.0) if ok else Color(0.9, 0.2, 0.2)
		c.a = 0.75
		m.albedo_color = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_gmats[key] = m
	return _gmats[key]


## 건설 위치 표시: 평원(초록)과 구분되도록 하늘색 / 불가는 빨강
func _cursor_mat(ok: bool) -> StandardMaterial3D:
	return _ghost_mat(ok)


func _hover_cell() -> Vector2i:
	var mp: Vector2 = get_viewport().get_mouse_position()
	var ray: Array[Vector3] = pixel.ray(mp)
	var hit: Variant = Plane(Vector3.UP, Field.BLOCK_H).intersects_ray(ray[0], ray[1])
	if hit == null:
		return Vector2i(-100, -100)
	return field.world_to_cell(hit as Vector3)


## 건물 패널을 고른 건물 바로 위에 붙인다. 위에 자리가 없으면 아래, 화면 밖으로는 나가지 않는다 (기획서 7.2)
func _place_upgrade_panel() -> void:
	upgrade_panel.reset_size() # 글자가 줄면 패널도 줄인다
	var view: Vector2 = get_viewport().get_visible_rect().size
	var at: Vector2 = pixel.unproject(field.cell_to_world(selected_cell) + Vector3(0, Field.BLOCK_H, 0))
	var gap: float = 0.5 * view.y / _view_size() + 4.0 # 칸 절반(화면 크기) + 여백
	var size: Vector2 = upgrade_panel.size
	var top: float = res_bar.get_global_rect().end.y
	var y: float = at.y - gap - size.y
	if y < top:
		y = at.y + gap
	upgrade_panel.position = Vector2(clampf(at.x - size.x / 2.0, 0.0, view.x - size.x), clampf(y, top, view.y - size.y))


func _process(delta: float) -> void:
	_edge_pan(delta)
	advance(delta * _speed())
	if battle != null: # 밝히지 않은 곳의 적은 숨긴다: 새로 나온 배가 한 프레임도 보이지 않게 매 프레임 (기획서 3장)
		for u: Unit in battle.pirates + battle.ships:
			u.visible = field.is_explored(field.world_to_cell(u.position))
	if upgrade_panel.visible:
		_place_upgrade_panel() # 줌·창 크기가 바뀌어도 건물을 따라간다
	cursor.visible = false
	_hud_timer -= delta
	if _hud_timer <= 0.0: # 맵이 넓어 생산 계산이 무거워 0.1초마다만 갱신한다
		_hud_timer = 0.1
		_refresh_hud()
	if build_id == 0 or _over_ui():
		return
	if build_id != 0:
		var c: Vector2i = _hover_cell()
		cursor.visible = true
		cursor.position = field.cell_to_world(c) + Vector3(0, (0.05 if Balance.BUILDINGS.get(build_id, {}).get("on_water", false) else Field.BLOCK_H + 0.05), 0)
		cursor.material_override = _cursor_mat(_build_ok(c))


## 건물 패널이 열린 채로 다른 UI를 누르면 건물 선택을 푼다 (기획서 5.2)
func _input(event: InputEvent) -> void:
	if selected_cell.x < 0 or not (event is InputEventMouseButton and event.pressed):
		return
	var h: Control = get_viewport().gui_get_hovered_control()
	if h != null and h != upgrade_panel and not upgrade_panel.is_ancestor_of(h):
		selected_cell = Vector2i(-1, -1)
		_refresh_hud()


## 좌클릭은 놓을 때 클릭으로 친다: 누른 채 CAM_DRAG_THRESHOLD 넘게 끌면 회전이다 (기획서 7.2)
func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var key: int = (event as InputEventKey).keycode if event is InputEventKey and event.pressed else 0
	if key == KEY_P and not event.is_echo(): # 도트 화면 켜고 끄기 (기획서 7.2)
		pixel.set_enabled(not pixel.enabled)
		return
	if key == KEY_SPACE and not event.is_echo(): # 일시정지 (기획서 2장)
		toggle_pause()
		return
	if key >= KEY_1 and key <= KEY_9 and not event.is_echo(): # 숫자키: 분대 고르기, Shift면 더하기 (기획서 6장)
		select_squad(key - KEY_0, (event as InputEventKey).shift_pressed)
		return
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_wheel_zoom(Balance.ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / Balance.ZOOM_STEP)
		return
	if event is InputEventMouseMotion and _pressing:
		if not _rotating and (event as InputEventMouseMotion).position.distance_to(_press) > Balance.CAM_DRAG_THRESHOLD:
			_rotating = true
		if _rotating:
			_drag_camera((event as InputEventMouseMotion).relative)
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressing = true
			_rotating = false
			_press = mb.position
			return
		var was_drag: bool = _rotating
		_pressing = false
		_rotating = false
		if not was_drag:
			click()
		return
	var right: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT
	if open_category >= 0 and (right or key == KEY_ESCAPE): # 목록 바깥을 누르면 닫는다
		open_category = -1
		_update_dropdown()
		return
	if build_id != 0 and (right or key == KEY_ESCAPE):
		set_build(0)
	elif battle != null and right and build_id == 0 and (not selected_squads.is_empty() or _settler_alive()): # 우클릭: 고른 분대·개척자 이동 (기획서 4장, 6장)
		command_move(_hover_cell())
	elif right or key == KEY_ESCAPE:
		select_building(Vector2i(-1, -1))


## 좌클릭 한 번: 시작 위치 고르기, 건설, 건물 고르기 순 (기획서 2장, 5장)
func click() -> void:
	if open_category >= 0: # 목록 바깥을 누르면 닫는다
		open_category = -1
		_update_dropdown()
		return
	var hc: Vector2i = _hover_cell()
	if build_id != 0:
		try_build(hc)
	elif _settler_at(hc) != null: # 개척자를 누르면 고른다 (기획서 4장)
		select_settler(_settler_at(hc))
	else:
		select_building(hc)


## 본부를 위치 순서로 정렬한 목록 (왼쪽 패널 표시용)
func _sorted_hqs() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in field.hqs: # 세운 순서 (딕셔너리는 넣은 순서를 지킨다)
		if field.hq_level.has(h):
			out.append(h)
	return out


## 도시 이름: 세운 순서대로 1, 2, 3 …
func _hq_name(h: Vector2i) -> String:
	return str(_sorted_hqs().find(h) + 1)


func _tech_pos(id: String) -> Vector2:
	return Vector2(int(Balance.TECHS[id]["col"]) * TECH_PITCH, int(Balance.TECHS[id]["row"]) * 74)


## 건물 패널의 체력·파손 설명 (기획서 5.2.2)
func _damage_text(c: Vector2i) -> String:
	var text: String = "체력 %d / %d" % [ceili(field.hp[c]), ceili(field.max_hp(c))]
	var stage: int = Balance.damage_stage(field.hp_ratio(c))
	if stage > 0:
		text += " · 파손 %d단계" % stage
	if field.buildings[c] == Balance.BARRACKS:
		text += " · 병사 체력·공격 %d%%" % roundi(Balance.soldier_damage_mult(field.hp_ratio(c)) * 100.0)
	elif stage > 0 and field.buildings[c] != Balance.TRADING_POST:
		text += " · 성능 %d%%" % roundi(field.performance(c) * 100.0)
	return text


## 선행 연구의 오른쪽에서 후속 연구의 왼쪽으로 선을 긋는다. 선행을 마친 선은 밝게 (기획서 5.4)
func _draw_tech_lines() -> void:
	for id in Balance.TECHS:
		for pre: String in Balance.tech_prereqs(id):
			var col: Color = Color(0.5, 0.9, 0.5) if GameState.has_tech(pre) else Color(0.45, 0.45, 0.5)
			tech_lines.draw_line(_tech_pos(pre) + Vector2(TECH_W, 31), _tech_pos(id) + Vector2(0, 31), col, 2.0)


func _refresh_research() -> void:
	tech_lines.queue_redraw()
	for id in research_buttons:
		var b: Button = research_buttons[id]
		var done: bool = GameState.has_tech(id)
		b.text = "%s%s\n%d점" % ["✓ " if done else "", Balance.TECHS[id]["name"], Balance.tech_cost(id)] # 효과는 상세 창에서만 (기획서 5.4)
		b.modulate = Color(0.55, 1.0, 0.55) if done else (Color(1.0, 0.9, 0.4) if id == selected_tech else (Color.WHITE if GameState.can_research(id) else Color(0.7, 0.7, 0.7)))
	if selected_tech == "":
		tech_detail.text = "왼쪽에서 연구를 고르세요."
		tech_do_button.visible = false
		return
	var t: Dictionary = Balance.TECHS[selected_tech]
	var pres: Array[String] = []
	for pre: String in Balance.tech_prereqs(selected_tech):
		pres.append("[color=%s]%s[/color]" % ["#66e066" if GameState.has_tech(pre) else "#ff5555", Balance.TECHS[pre]["name"]])
	var cost: int = Balance.tech_cost(selected_tech)
	var pre_line: String = "" if pres.is_empty() else "\n선행: " + ", ".join(pres) # 선행이 없으면 줄 자체를 숨김
	tech_detail.text = "%s\n\n효과: %s\n비용: 연구포인트 %d점 (보유 %d점)%s" % [str(t["name"]).replace("[", "[lb]"), str(t["desc"]).replace("[", "[lb]"), cost, GameState.research_points, pre_line]
	tech_do_button.visible = true
	var can: bool = GameState.can_research(selected_tech)
	if GameState.has_tech(selected_tech):
		tech_do_button.text = "연구 완료"
	elif not can:
		tech_do_button.text = "연구할 수 없음 (선행 연구나 포인트 부족)"
	else:
		tech_do_button.text = "연구하기 (%d점)" % cost
	tech_do_button.disabled = GameState.has_tech(selected_tech) or not can


## 분대 줄과 병영 패널의 생산·대기열 (기획서 6장, 7.2)
func _refresh_squads() -> void:
	if battle == null:
		return
	selected_squads = selected_squads.filter(func(n: int) -> bool: return battle.squads.has(n))
	for i in squad_buttons.size():
		var n: int = i + 1
		var sbtn: Button = squad_buttons[i]
		sbtn.visible = battle.squads.has(n)
		if sbtn.visible:
			var sq: Dictionary = battle.squads[n]
			sbtn.text = "%d %s %d/%d" % [n, Balance.UNITS[sq["kind"]]["name"], battle.squad_units(n).size(), sq["size"]]
			sbtn.modulate = Color(1.0, 1.0, 0.55) if selected_squads.has(n) else Color(0.75, 0.75, 0.75)
	var target: int = _reinforce_target()
	reinforce_button.visible = target > 0
	if target > 0:
		var rc: Vector2i = battle.reinforce_cost(target)
		reinforce_button.text = "충원 %dG · 식량 %d" % [rc.x, rc.y]
		reinforce_button.disabled = GameState.gold < rc.x or GameState.food < rc.y
	if selected_settler != null and not _settler_alive():
		selected_settler = null
	found_button.visible = selected_settler != null
	if selected_settler != null:
		var why: String = field.found_block(selected_settler.home)
		found_button.text = "개척자: 도시 세우기"
		found_button.disabled = why != ""
		found_button.tooltip_text = why
	var city: bool = upgrade_panel.visible and field.hqs.has(selected_cell)
	settler_button.visible = city
	if city:
		var cost: Vector2i = Balance.settler_cost(field.hqs.size())
		if battle.settler_jobs.has(selected_cell):
			settler_button.text = "개척자 생산 중 %d초 (누르면 취소)" % ceili(battle.settler_jobs[selected_cell]["left"])
			settler_button.disabled = false
		else:
			settler_button.text = "개척자 생산 %dG · 식량 %d (%d초)" % [cost.x, cost.y, int(Balance.SETTLER_TIME)]
			settler_button.disabled = not battle.can_settler(selected_cell)
	var barracks: bool = upgrade_panel.visible and field.buildings.get(selected_cell, 0) == Balance.BARRACKS
	for type: String in squad_prod_buttons:
		var pb: Button = squad_prod_buttons[type]
		var sq: Dictionary = Balance.SQUADS[type]
		pb.visible = barracks
		if not barracks:
			continue
		var kind: int = sq["units"][field.levels[selected_cell] - 1]
		pb.text = "%s(%s %d명) %dG · 식량 %d" % [sq["name"], Balance.UNITS[kind]["name"], sq["count"], sq["gold"], sq["food"]]
		pb.disabled = not battle.can_queue(selected_cell, type)
		pb.tooltip_text = ""
		if sq.has("tech") and not GameState.has_tech(sq["tech"]):
			pb.tooltip_text = "필요 연구: " + Balance.TECHS[sq["tech"]]["name"]
		elif battle.squad_count() >= battle.squad_cap():
			pb.tooltip_text = "분대 수 상한 %d (대기열 포함)" % battle.squad_cap()
	var q: Array = battle.queues.get(selected_cell, []) if barracks else []
	for i in queue_buttons.size():
		var qb: Button = queue_buttons[i]
		qb.visible = i < q.size()
		if qb.visible:
			qb.text = "✕ %s %s" % [Balance.UNITS[q[i]["kind"]]["name"], ("%d초" % ceili(q[i]["left"])) if i == 0 else "대기"]


func _refresh_hud() -> void:
	var per_min: float = 60.0 / Balance.PRODUCTION_TICK # 생산 틱 수치를 분당으로 보여 준다 (기획서 2장, 7.2)
	var inc: Vector2i = field.income(GameState.researched)
	stats.text = "골드 %d (+%d/분) · 식량 %d (+%d/분) · 연구포인트 %d (%d/%d, +%d/분)   " % [GameState.gold, roundi(inc.x * per_min), GameState.food, roundi(inc.y * per_min), GameState.research_points, GameState.research_progress, Balance.research_threshold(GameState.research_gained), roundi(field.research_income(GameState.researched) * per_min)]
	for id in build_buttons:
		var bb: Button = build_buttons[id]
		bb.text = "%s %dG · %s" % [Balance.BUILDINGS[id]["name"], _cost_of(id), Balance.effect_text(id, 1, GameState.researched)]
		var need: String = Balance.BUILDINGS[id].get("tech", "")
		bb.tooltip_text = "" if _unlocked(id) or need == "" or GameState.has_tech(need) else "필요 연구: " + Balance.TECHS[need]["name"]
		bb.disabled = not _unlocked(id) or GameState.gold < _cost_of(id)
	trade_button.visible = npc_present
	trade_button.text = "교역 NPC 방문! (남은 %d초)" % ceili(maxf(npc_leave_time - game_time, 0.0))
	for tid in trade_buttons:
		var tbtn: Button = trade_buttons[tid]
		tbtn.text = ("✓ 거래 완료 — " if trade_sold.has(tid) else "") + _trade_def(tid)["name"]
		tbtn.disabled = not _trade_ok(tid)
	research_toggle.text = "연구 (연구포인트 %d)" % GameState.research_points
	# 이번 웨이브의 적을 미리 알려 준다. 해적의 세기는 도시 수에 따라 바뀐다 (기획서 6장)
	var comp: Dictionary = Balance.enemy_composition(GameState.wave, GameState.run_seed)
	var comp_parts: Array[String] = []
	for kind in comp:
		comp_parts.append("%s %d명" % [Balance.UNITS[kind]["name"], comp[kind]])
	wave_info.text = "웨이브 %d 예고: %s (전투력 %d · 해적선 %d척) · 체력·공격 ×%.2f" % [GameState.wave, " · ".join(comp_parts), Balance.wave_power(GameState.wave, GameState.run_seed), Balance.ship_count(GameState.wave, GameState.run_seed), Balance.enemy_mult(field.hqs.size())]
	if not field.hqs.is_empty(): # 목표 도시 방향: 해적선은 이 도시에서 가장 가까운 가장자리에서 온다 (기획서 6장)
		wave_info.text += " · %d번 도시 방향" % (Balance.wave_target(GameState.wave, GameState.run_seed, field.hqs.size()) + 1)
	if field.sea_blocked():
		wave_info.text += "\n바닷길이 막혀 해적이 걸어서 바다를 건넙니다"
	for nk in Balance.new_enemy_kinds(GameState.wave): # 새 종류가 처음 나오는 웨이브 안내
		var info: Dictionary = Balance.UNITS[nk]
		wave_info.text += "\n새 적: %s (체력 %d · 공격 %d%s)" % [info["name"], info["hp"], info["atk"], (" · 사거리 %.1f칸" % info["reach"]) if info.get("ranged", false) else ""]
	wave_button.disabled = over
	wave_button.text = "웨이브 %d/%d · 다음까지 %d:%02d · 부르기 (+%dG)" % [GameState.wave - 1, Balance.WIN_WAVE, int(wave_timer) / 60, int(wave_timer) % 60, floori(wave_timer * Balance.CALL_WAVE_GOLD)]
	pause_button.text = "▶ 계속 (Space)" if paused else "❚❚ 일시정지 (Space)"
	if research_panel.visible:
		_refresh_research()
	var cities: Array[Vector2i] = _sorted_hqs()
	while city_list.get_child_count() < cities.size():
		var cb: Button = Button.new()
		cb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx: int = city_list.get_child_count()
		cb.pressed.connect(_on_city_button.bind(idx))
		city_list.add_child(cb)
	for i in city_list.get_child_count():
		var cb: Button = city_list.get_child(i)
		cb.visible = i < cities.size()
		if not cb.visible:
			continue
		var h: Vector2i = cities[i]
		cb.text = "도시 %s Lv %d · 영역 %d칸 · 식량 %d/%d" % [_hq_name(h), field.hq_level[h], field.territory_of[h].size(), field.hq_food[h], field.next_level_food(h)]
		if field.hp_ratio(h) < 1.0:
			cb.text += " · 체력 %d/%d" % [ceili(field.hqs[h]), Balance.HQ_HP]
		if battle != null and battle.settler_jobs.has(h):
			cb.text += " · 개척자 %d초" % ceili(battle.settler_jobs[h]["left"])
	var all_cost: int = _repair_all_cost()
	repair_all_button.visible = all_cost > 0
	repair_all_button.text = "전체 수리 %dG" % all_cost
	repair_all_button.disabled = GameState.gold < all_cost
	field.refresh_hq_bars() # 도시 옆 레벨업 바 (기획서 5.3)
	_refresh_minimap()
	if selected_cell.x >= 0 and not field.buildings.has(selected_cell) and not field.hqs.has(selected_cell):
		selected_cell = Vector2i(-1, -1)
	upgrade_panel.visible = selected_cell.x >= 0
	var fix: int = field.repair_cost(selected_cell)
	repair_button.visible = fix > 0
	repair_button.text = "수리 중…" if repairing.has(selected_cell) else "수리 %dG" % fix
	repair_button.disabled = GameState.gold < fix or not can_repair(selected_cell)
	repair_button.tooltip_text = "3칸 안에 적이 있으면 수리할 수 없습니다" if fix > 0 and not repairing.has(selected_cell) and not can_repair(selected_cell) else ""
	upgrade_button.visible = not field.hqs.has(selected_cell)
	if upgrade_panel.visible and field.hqs.has(selected_cell): # 본부는 강화하지 않고 수리만 한다 (기획서 5.3)
		upgrade_title.text = "도시 %s Lv %d" % [_hq_name(selected_cell), field.hq_level[selected_cell]]
		upgrade_effect.text = "체력 %d / %d" % [ceili(field.hqs[selected_cell]), Balance.HQ_HP]
	elif upgrade_panel.visible:
		var bid: int = field.buildings[selected_cell]
		var lv: int = field.levels[selected_cell]
		upgrade_title.text = "%s Lv %d" % [Balance.BUILDINGS[bid]["name"], lv]
		upgrade_effect.text = Balance.effect_text(bid, lv, GameState.researched)
		if bid == Balance.TRADING_POST and not field.is_post_open(selected_cell):
			upgrade_effect.text += "\n⚠ 물가가 막혀 NPC가 오지 못합니다"
		if bid == Balance.FISHERY or bid == Balance.FISH_VILLAGE: # 이 낚시터의 실제 생산량
			upgrade_effect.text = "식량 +%d (이어진 물가 %d칸)" % [field.fishing_food(selected_cell), field.fishing_cells(selected_cell)]
		if field.can_upgrade(selected_cell):
			var cost: int = GameState.upgrade_discounted(Balance.upgrade_cost(bid, lv + 1))
			upgrade_button.text = "레벨 %d로 강화 %dG" % [lv + 1, cost]
			upgrade_button.tooltip_text = "다음 레벨: " + Balance.effect_text(bid, lv + 1, GameState.researched)
			upgrade_button.disabled = GameState.gold < cost or _upgrade_locked(selected_cell)
			if _upgrade_locked(selected_cell):
				upgrade_button.tooltip_text = "필요 연구: " + Balance.TECHS[Balance.LV3_TECH]["name"]
		elif Balance.evolve_to(bid) > 0: # 레벨 3 기본 건물: 진화 (기획서 5.2.1)
			var to: int = Balance.evolve_to(bid)
			var ecost: int = GameState.upgrade_discounted(Balance.evolve_cost(to))
			upgrade_button.text = "진화: %s %dG" % [Balance.BUILDINGS[to]["name"], ecost]
			upgrade_button.tooltip_text = "진화 후 레벨 1: " + Balance.effect_text(to, 1, GameState.researched)
			upgrade_button.disabled = GameState.gold < ecost or not _can_evolve(selected_cell)
			if not _can_evolve(selected_cell):
				upgrade_button.tooltip_text = "필요 연구: " + Balance.TECHS[Balance.BUILDINGS[to]["tech"]]["name"]
		else:
			upgrade_button.text = "최고 레벨"
			upgrade_button.disabled = true
		if field.hp_ratio(selected_cell) < 1.0:
			upgrade_effect.text += "\n" + _damage_text(selected_cell)
			upgrade_button.disabled = true
			upgrade_button.tooltip_text = "수리해야 강화·진화할 수 있습니다"
	_refresh_squads()
	var s: String
	if field.hqs.is_empty() and build_id == 0: # 첫 도시 전 안내 (기획서 2장)
		s = "개척자를 우클릭으로 옮기고 '도시 세우기'로 첫 도시를 세우세요"
	elif build_id != 0:
		s = "%s 건설: 좌클릭 배치 · 우클릭/Esc 취소" % Balance.BUILDINGS[build_id]["name"]
	else:
		s = battle.summary() + " · 숫자키: 분대 · 개척자 좌클릭 · 우클릭: 이동"
	status.text = (_note + "\n" if _note != "" else "") + s


## 도시 영역과 유닛(분대·개척자) 주변을 밝힌다 (기획서 3장)
func _explore() -> void:
	for h in field.territory_of:
		field.reveal_cells(field.territory_of[h])
	if battle == null:
		return
	for u in battle.soldiers:
		field.reveal(field.world_to_cell(u.position), Balance.VISION_RANGE)


## 유닛이 유적지 칸에 들어가면 보상: 골드 60~100, 30% 확률로 대신 연구포인트 +1 (기획서 3장)
func _take_ruins() -> void:
	for u in battle.soldiers:
		if not field.take_ruin(field.world_to_cell(u.position)):
			continue
		if rng.randf() < Balance.RUIN_RP_CHANCE:
			GameState.add_research(1)
			_note = "유적지 발견: 연구포인트 +1"
		else:
			var g: int = rng.randi_range(Balance.RUIN_GOLD.x, Balance.RUIN_GOLD.y)
			GameState.add(g, 0)
			_note = "유적지 발견: 골드 +%d" % g


## 미니맵 바탕(지형)을 한 번 그린다 (기획서 7.2)
func _build_minimap() -> void:
	var sz: Vector2i = field.bounds.size # 한 칸 = 한 도트, 왼쪽 위가 bounds.position (안개 텍스처와 같다)
	_mini_terrain = Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	_mini_terrain.fill(Color(0.2, 0.48, 0.82))
	for c in field.cells:
		if field.bounds.has_point(c):
			_mini_terrain.set_pixelv(c - field.bounds.position, Field.color_of(field.cells[c]))
	_mini_img = Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	minimap.texture = ImageTexture.create_from_image(_mini_img)
	_refresh_minimap()


## 지형 위에 안개를 덮고 도시(흰색)·분대(하늘색)·보이는 해적(빨강)을 찍는다 (기획서 7.2)
func _refresh_minimap() -> void:
	if _mini_img == null:
		return
	_mini_img.copy_from(_mini_terrain)
	_mini_img.blend_rect(field._fog_img, Rect2i(Vector2i.ZERO, field.bounds.size), Vector2i.ZERO)
	for h in field.hqs:
		_mini_img.fill_rect(Rect2i(h - field.bounds.position - Vector2i.ONE, Vector2i(3, 3)), Color.WHITE)
	if battle != null:
		for u in battle.soldiers:
			_mini_dot(u, Color(0.3, 0.95, 1.0))
		for u in battle.pirates + battle.ships:
			if u.visible:
				_mini_dot(u, Color(1.0, 0.15, 0.15))
	(minimap.texture as ImageTexture).update(_mini_img)


func _mini_dot(u: Unit, col: Color) -> void:
	var c: Vector2i = field.world_to_cell(u.position)
	if field.bounds.has_point(c):
		_mini_img.set_pixelv(c - field.bounds.position, col)


## 미니맵을 누르면 그곳으로 카메라를 옮긴다 (기획서 7.2)
func _on_minimap_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	focus_minimap(mb.position / minimap.size)


## 미니맵 위의 비율 위치(0~1)로 카메라를 옮긴다
func focus_minimap(at: Vector2) -> void:
	var c: Vector2i = (field.bounds.position + Vector2i((at * Vector2(field.bounds.size)).floor())).clamp(field.bounds.position, field.bounds.end - Vector2i.ONE)
	focus_city(c)

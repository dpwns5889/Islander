extends Node3D
## 준비 단계(조각 배치·건설·시장·확장)와 전투 단계 진행 (기획서 2장, 3장, 5장)

const CARD_COUNT: int = 3
const GHOST_Y: float = 0.45

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var field: Field
var pixel: PixelView
var ghost: Node3D
var cursor: MeshInstance3D ## 건물 건설 위치 표시
var current: Piece = null ## 배치 중인 조각
var build_id: int = 0 ## 건설 모드의 건물 종류, 0이면 건설 모드 아님
var pieces_left: int = 0 ## 이번 준비 단계에 더 놓을 수 있는 조각 수
var explored: bool = false ## 이번 준비 단계에 유적지 원정을 보냈는지
var tiles_required: int = 0 ## 이번 준비 단계에 반드시 놓아야 하는 보상 타일 수 (기획서 2장)
var pending_hq: bool = false ## 10·20웨이브를 이긴 뒤 아직 못 놓은 본부 조각이 있는지 (기획서 5.5)
var hq_piece: Piece = null
var placing_hq: bool = false ## 지금 손에 든 조각이 본부 조각인지
var hq_card: PieceCard
var hq_title: Label
var choice_title: Label
var choices: Array[Piece] = []
var cards: Array[PieceCard] = []
var placed_count: int = 0
var panel: PanelContainer
var top_panel: PanelContainer
var res_bar: PanelContainer ## 최상단 고정 자원바 (기획서 7.2)
var build_panel: PanelContainer
var side_panel: PanelContainer
var town_label: Label
var build_buttons: Dictionary = {}
var selected_cell: Vector2i = Vector2i(-1, -1) ## 레벨업 패널에 보이는 건물
var upgrade_panel: PanelContainer
var upgrade_title: Label
var upgrade_effect: Label
var upgrade_button: Button
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
var _warn: bool = false ## 지금 들고 있는 타일이 교역소를 바다와 끊는지 (미리보기 경고) (기획서 5.6)
var _warn_key: String = ""
var _carve_n: int = 0 ## 지금 들고 있는 타일의 바다 칸이 물로 깎을 땅 칸 수
var npc_next_wave: int = -1 ## 교역 NPC가 다음에 방문할 웨이브, 교역소가 없으면 -1 (기획서 5.6)
var npc_present: bool = false ## 교역 NPC가 와 있는지 (기획서 5.6)
var npc_node: MeshInstance3D = null
var trade_offers: Array = []
var trade_sold: Dictionary = {} ## 이번 방문에서 이미 한 거래 id → true
var trade_button: Button
var trade_panel: PanelContainer
var trade_list: VBoxContainer
var trade_buttons: Dictionary = {}
var wave_panel: PanelContainer
var wave_info: Label ## 준비 단계의 이번 웨이브 적 예고
var battle_speed_index: int = 0
var layer: CanvasLayer
var battle: Battle = null
var _pitch: float = 90.0
var _zoom: float = 1.0 ## 준비 단계 휠 줌 배율(작을수록 확대)
var _note: String = ""
var _gmats: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	GameState.reset()
	_build_world()
	field.generate_outside(rng.randi())
	_build_ui()
	GameState.changed.connect(_refresh_hud)
	current = Piece.start_piece(rng)
	_rebuild_ghost()
	_refresh_hud()


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
	# 준비 단계는 완전 탑다운 (기획서 2장)
	pixel = PixelView.new() # 3D를 낮은 해상도로 그려 도트처럼 보이게 한다 (기획서 7.2)
	add_child(pixel)
	field = Field.new()
	field.territory_enabled = true
	add_child(field)
	ghost = Node3D.new()
	add_child(ghost)
	cursor = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(0.9, 0.1, 0.9)
	cursor.mesh = cm
	cursor.visible = false
	add_child(cursor)
	_set_pitch(90.0)


func _build_ui() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	# 조각 카드 (하단, 건물 메뉴 위): 본부 조각 + 전투 보상 타일 선택지
	var hq_box: VBoxContainer = VBoxContainer.new()
	hq_title = Label.new()
	hq_title.text = "본부 조각 (반드시 놓기)"
	hq_title.visible = false
	hq_box.add_child(hq_title)
	hq_card = PieceCard.new()
	hq_card.picked.connect(_on_card_picked)
	hq_card.visible = false
	hq_box.add_child(hq_card)
	var choice_box: VBoxContainer = VBoxContainer.new()
	choice_title = Label.new()
	choice_box.add_child(choice_title)
	var card_row: HBoxContainer = HBoxContainer.new()
	for i in CARD_COUNT:
		var card: PieceCard = PieceCard.new()
		card.picked.connect(_on_card_picked)
		cards.append(card)
		card_row.add_child(card)
	choice_box.add_child(card_row)
	var row_box: HBoxContainer = HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 18)
	row_box.add_child(hq_box)
	row_box.add_child(choice_box)
	panel = PanelContainer.new()
	panel.add_child(row_box)
	panel.visible = false
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN # 본부 카드가 늘어도 화면 밖으로 잘리지 않게
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
	wave_button.text = "웨이브 시작"
	wave_button.pressed.connect(start_wave)
	row.add_child(wave_button)
	speed_button = Button.new()
	speed_button.pressed.connect(cycle_speed)
	speed_button.visible = false # 전투 중에만 보인다
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
	top_panel.visible = false
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
	town_label = Label.new()
	side.add_child(town_label)
	research_toggle = Button.new()
	research_toggle.pressed.connect(_toggle_research)
	side.add_child(research_toggle)
	side_panel = PanelContainer.new()
	side_panel.add_child(side)
	side_panel.visible = false
	layer.add_child(side_panel)
	side_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	side_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN # 글자가 늘어도 화면 아래로 잘리지 않게 위로 자란다
	# 오른쪽 아래: 선택한 건물의 레벨업 패널
	var up: VBoxContainer = VBoxContainer.new()
	upgrade_title = Label.new()
	up.add_child(upgrade_title)
	upgrade_effect = Label.new()
	up.add_child(upgrade_effect)
	upgrade_button = Button.new()
	upgrade_button.pressed.connect(upgrade_selected)
	up.add_child(upgrade_button)
	upgrade_panel = PanelContainer.new()
	upgrade_panel.add_child(up)
	upgrade_panel.visible = false
	layer.add_child(upgrade_panel)
	upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 54) # 건설 메뉴 위
	upgrade_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	upgrade_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	for c: Control in [panel, top_panel, res_bar, wave_panel, build_panel, side_panel, upgrade_panel, research_panel, dropdown_panel, trade_panel]:
		if c.visible and c.get_global_rect().has_point(mp):
			return true
	return false


func _on_card_picked(card: PieceCard) -> void:
	if card == hq_card:
		select_hq()
	else:
		pick(cards.find(card))


## 본부 조각을 집는다 (기획서 5.5)
func select_hq() -> void:
	if not pending_hq:
		return
	set_build(0)
	current = hq_piece
	placing_hq = true
	for card in cards:
		card.selected = false
	hq_card.selected = true
	_note = ""
	_rebuild_ghost()
	_refresh_hud()


func pick(i: int) -> void:
	if pieces_left <= 0:
		return
	set_build(0)
	current = choices[i]
	placing_hq = false
	hq_card.selected = false
	for j in cards.size():
		cards[j].selected = j == i
	_note = ""
	_rebuild_ghost()
	_refresh_hud()


func _on_build_button(id: int) -> void:
	set_build(0 if build_id == id else id)


func set_build(id: int) -> void:
	if id != 0 and _blocked(): # 타일을 먼저 놓아야 한다
		_note = "전투 보상 타일을 먼저 놓아야 건물을 지을 수 있습니다"
		_refresh_hud()
		return
	build_id = id
	if id != 0:
		current = null
		placing_hq = false
		hq_card.selected = false
		for card in cards:
			card.selected = false
		_rebuild_ghost()
	open_category = -1 # 건물을 고르거나 설치 모드가 끝나면 목록을 닫는다
	_update_dropdown()
	_note = ""
	_refresh_hud()


## 건설 메뉴 카테고리를 열고 닫는다 (기획서 7.2)
func _toggle_category(i: int) -> void:
	if _blocked() or battle != null:
		return
	open_category = -1 if open_category == i else i
	_update_dropdown()


func _update_dropdown() -> void:
	dropdown_panel.visible = open_category >= 0 and battle == null
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


## 준비 단계 시작: 조각 선택지를 새로 뽑고, 놓을 수 있는 조각은 1개 (기획서 2장)
func _begin_prep() -> void:
	_note = ""
	pieces_left = 1
	tiles_required = 1 # 전투 보상 타일: 놓기 전에는 건설·강화·웨이브 시작이 막힌다
	if GameState.wave > 1 and (GameState.wave - 1) % Balance.GROW_EVERY == 0: # 2라운드마다 4방으로 확장 (기획서 3장)
		field.expand_all()
		_set_pitch(_pitch)
		_note = "필드가 사방으로 넓어졌습니다 (%dx%d)" % [field.bounds.size.x, field.bounds.size.y]
	explored = false
	_roll_choices()


## 타일(본부 조각 포함)을 놓기 전에는 건물 건설·레벨업·웨이브 시작을 할 수 없다 (기획서 2장)
func _blocked() -> bool:
	return pending_hq or tiles_required > 0


## 주어진 조각 중 하나도 들어갈 자리가 없으면 무료로 한 줄씩 확장한다. 늘린 줄 수를 돌려 준다 (기획서 5.5)
func _make_room(pieces: Array[Piece]) -> int:
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var grown: int = 0
	for attempt in 200:
		var fits: bool = false
		for p in pieces:
			fits = fits or field.has_room(p)
		if fits:
			break
		var d: Vector2i = dirs[attempt % 4]
		if field.can_expand(d):
			field.expand(d)
			grown += 1
	if grown > 0:
		_set_pitch(_pitch)
	return grown


func _roll_choices() -> void:
	choices.clear()
	for i in CARD_COUNT:
		choices.append(Piece.random_piece(rng, GameState.wave > Balance.SEA_TILE_WAVE)) # 10라운드 이후엔 바다 섞인 타일도 나온다
		cards[i].set_piece(choices[i])
	panel.visible = true
	if tiles_required > 0 and _make_room(choices) > 0:
		_note = "놓을 자리가 없어 필드를 무료로 넓혔습니다 (%dx%d)" % [field.bounds.size.x, field.bounds.size.y]


## 놓을 수 있는 조각을 1개 늘리고 선택지를 새로 뽑는다 (NPC 거래) (기획서 5장, 5.6)
func _grant_piece() -> void:
	pieces_left += 1
	current = null
	_rebuild_ghost()
	_roll_choices()
	_note = "조각을 샀습니다 (놓을 수 있는 조각 %d개)" % pieces_left
	_refresh_hud()


## 교역 NPC (기획서 5.6)
func _maybe_visit_npc() -> void:
	var post: Vector2i = field.trading_post()
	if post.x < 0:
		npc_next_wave = -1
	elif npc_next_wave > 0 and GameState.wave >= npc_next_wave:
		if field.is_post_open(post):
			spawn_npc(post)
		else: # 바다가 닫히면 NPC가 오지 못한다. 일정은 3라운드 뒤로 넘어간다 (기획서 5.6)
			_note += "\n교역소가 바다와 이어지지 않아 교역 NPC가 오지 못했습니다"
		npc_next_wave = GameState.wave + Balance.TRADE_INTERVAL # 이후 3라운드마다


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
	_note += "\n교역 NPC가 방문했습니다! (웨이브를 시작하면 떠납니다)"


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
	elif id == "gold_piece":
		_grant_piece()
	elif id == "gold_guards":
		GameState.extra_guards += 2
	_refresh_hud()
	return true


## 유적지 원정: 항구가 있어야 한다. 준비 단계당 1회 (기획서 3장)
func explore(c: Vector2i) -> bool:
	if battle != null or not field.ruins.has(c) or explored:
		return false
	if not field.buildings.values().has(Balance.PORT):
		_note = "유적지 원정에는 항구가 필요합니다"
		_refresh_hud()
		return false
	if not GameState.spend(Balance.EXPLORE_COST):
		_note = "원정 비용 %d골드가 모자랍니다" % Balance.EXPLORE_COST
		_refresh_hud()
		return false
	explored = true
	if rng.randf() < Balance.EXPLORE_RP_CHANCE:
		GameState.add_research(1)
		_note = "원정 성공: 연구포인트 +1"
	else:
		var g: int = rng.randi_range(Balance.EXPLORE_GOLD_MIN, Balance.EXPLORE_GOLD_MAX)
		GameState.add(g, 0)
		_note = "원정 성공: 골드 +%d" % g
	field.loot_ruin(c)
	_refresh_hud()
	return true


func _rotate() -> void:
	current = current.rotated()
	_rebuild_ghost()


func place_current(hover: Vector2i) -> bool:
	if current == null:
		return false
	var origin: Vector2i = current.origin_for(hover)
	if not field.can_place(current, origin):
		return false
	var piece_hq: bool = current.hq_index >= 0
	field.place(current, origin)
	var was_start: bool = placed_count == 0
	placed_count += 1
	var was_hq: bool = placing_hq
	current = null # 고르지 않은 조각은 버려진다 (기획서 2장)
	placing_hq = false
	hq_card.selected = false
	_rebuild_ghost()
	_note = ""
	if was_start:
		top_panel.visible = true
		res_bar.visible = true
		build_panel.visible = true
		side_panel.visible = true
		_begin_prep()
		pieces_left = 0 # 시작 조각 뒤 첫 준비 단계에는 보상 타일이 없다 (기획서 2장)
		tiles_required = 0
		panel.visible = false
	elif was_hq: # 본부 조각은 일반 조각 배치 횟수를 쓰지 않는다 (기획서 5.5)
		pending_hq = false
		_note = "본부를 하나 더 세웠습니다 (본부 %d개)" % field.hqs.size()
	else:
		tiles_required = maxi(0, tiles_required - 1)
		pieces_left -= 1
		if pieces_left > 0:
			_roll_choices()
		else:
			panel.visible = false
	_refresh_hud()
	return true


func try_build(c: Vector2i) -> bool:
	if not _build_ok(c):
		return false
	GameState.spend(_cost_of(build_id))
	field.build(build_id, c)
	if build_id == Balance.TRADING_POST: # 설치한 다음 라운드에 첫 방문 (기획서 5.6)
		npc_next_wave = GameState.wave + 1
	set_build(0) # 건물을 하나 지으면 설치 모드가 끝난다
	return true


## 준비 단계에서 건물을 골라 레벨업 패널을 연다. 건물이 아니면 선택을 푼다 (기획서 5.2)
func select_building(c: Vector2i) -> bool:
	selected_cell = c if battle == null and field.buildings.has(c) else Vector2i(-1, -1)
	_refresh_hud()
	return selected_cell.x >= 0


func _toggle_research() -> void:
	research_panel.visible = not research_panel.visible and battle == null
	_refresh_hud()


## 연구 창에서 연구를 고른다. 연구는 오른쪽 상세 창의 버튼으로 한다 (기획서 5.4)
func select_tech(id: String) -> void:
	selected_tech = id
	_refresh_hud()


## 연구포인트로 연구한다 (기획서 5.4)
func research(id: String) -> bool:
	if battle != null or not GameState.research(id):
		return false
	_note = "연구 완료: " + Balance.TECHS[id]["name"]
	_refresh_hud()
	return true


func _unlocked(id: int) -> bool:
	var tech: String = Balance.BUILDINGS[id].get("tech", "")
	return (tech == "" or GameState.has_tech(tech)) and Balance.menu_visible(id, GameState.researched)


## 병영·사격장 레벨 3 강화는 철기 제작이 필요하다 (기획서 5.2)
func _upgrade_locked(c: Vector2i) -> bool:
	return Balance.MILITARY.has(field.buildings[c]) and field.levels[c] + 1 == Balance.MAX_LEVEL and not GameState.has_tech(Balance.LV3_TECH)


## 레벨 3 기본 건물이 진화할 수 있는지: 진화 건물이 있고 해금 연구를 마쳤는지 (기획서 5.2.1)
func _can_evolve(c: Vector2i) -> bool:
	var to: int = Balance.evolve_to(field.buildings[c])
	return to > 0 and field.levels[c] >= Balance.MAX_LEVEL and GameState.has_tech(Balance.BUILDINGS[to].get("tech", ""))


func upgrade_selected() -> bool:
	if selected_cell.x >= 0 and not _blocked() and _can_evolve(selected_cell):
		var to: int = Balance.evolve_to(field.buildings[selected_cell])
		if not GameState.spend(GameState.upgrade_discounted(Balance.evolve_cost(to))):
			return false
		field.evolve(selected_cell, to)
		_note = ""
		_refresh_hud()
		return true
	if selected_cell.x < 0 or _blocked() or not field.can_upgrade(selected_cell) or _upgrade_locked(selected_cell):
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
	if build_id == 0 or _blocked() or not _unlocked(build_id) or GameState.gold < _cost_of(build_id):
		return false
	return field.can_build(build_id, c)


## 준비 단계를 끝내고 전투를 시작한다. 카메라가 대각선으로 기운다 (기획서 2장)
func start_wave() -> void:
	if battle != null or placed_count == 0 or _blocked(): # 타일(본부 조각 포함)을 놓기 전에는 시작할 수 없다
		return
	current = null
	_rebuild_ghost()
	set_build(0)
	selected_cell = Vector2i(-1, -1)
	_npc_leave() # 전투가 시작되면 NPC가 떠난다 (기획서 5.6)
	research_panel.visible = false
	panel.visible = false
	build_panel.visible = false
	side_panel.visible = false
	wave_button.disabled = true
	_tilt(Balance.COMBAT_PITCH)
	field.buildings_lost.clear()
	battle = Battle.new()
	add_child(battle)
	battle.setup(field, GameState, GameState.wave)
	battle.finished.connect(_on_battle_finished)
	battle.speed_scale = Balance.BATTLE_SPEEDS[battle_speed_index]
	speed_button.visible = true
	speed_button.text = "배속 x%d" % Balance.BATTLE_SPEEDS[battle_speed_index]
	_refresh_hud()


## 전투 배속 버튼: x1 → x2 → x4 → x1 (기획서 2장)
func cycle_speed() -> void:
	battle_speed_index = (battle_speed_index + 1) % Balance.BATTLE_SPEEDS.size()
	speed_button.text = "배속 x%d" % Balance.BATTLE_SPEEDS[battle_speed_index]
	if battle != null:
		battle.speed_scale = Balance.BATTLE_SPEEDS[battle_speed_index]


## 전투 중 클릭한 땅으로 병사들이 이동한다 (깃발 없이 한 번의 명령) (기획서 6장)
func command_move(c: Vector2i) -> bool:
	if battle == null or not field.is_walkable(c):
		return false
	battle.command_move(c)
	_ping(c)
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


func _on_battle_finished(victory: bool) -> void:
	battle.queue_free()
	battle = null
	speed_button.visible = false
	if not victory:
		SaveManager.record(GameState.wave) # 졌어도 도달한 웨이브는 기록한다
		_show_defeat()
		return
	var inc: Vector2i = field.income(GameState.researched)
	var cleared: int = GameState.wave
	GameState.add(inc.x, inc.y)
	GameState.next_wave()
	var ups: Dictionary = field.settle_levels(GameState.researched) # 본부마다 자기 영역 식량으로 레벨·영역 상승 (기획서 5.3)
	var rp_gain: int = GameState.add_research_progress(field.research_income(GameState.researched)) # 도서관·연구소 (기획서 5.4)
	field.repair_all()
	_tilt(90.0)
	build_panel.visible = true
	side_panel.visible = true
	_begin_prep()
	_note = "웨이브 %d 승리: 골드 +%d · 식량 +%d" % [cleared, inc.x, inc.y] + ("\n" + _note if _note != "" else "")
	if not field.buildings_lost.is_empty():
		var parts: Array[String] = []
		for k in field.buildings_lost:
			parts.append("%s %d" % [Balance.BUILDINGS[k]["name"], field.buildings_lost[k]])
		_note += "\n무너진 건물: " + ", ".join(parts)
	for h in ups:
		_note += "\n본부 %s 레벨 %d!" % [_hq_name(h), field.hq_level[h]]
	if rp_gain > 0:
		_note += "\n연구포인트 +%d" % rp_gain
	_maybe_visit_npc() # 3·6·9… 웨이브의 준비 단계에 교역 NPC가 온다 (기획서 5.6)
	if Balance.HQ_PIECE_WAVES.has(cleared): # 보스 라운드를 이기면 본부 조각을 하나 더 받는다 (기획서 5.5)
		_grant_hq_piece()
	_refresh_hud()
	SaveManager.record(GameState.wave) # 무한 모드까지 포함한 최고 웨이브 (기획서 9.1)
	if cleared == Balance.WIN_WAVE:
		_show_victory()


func _grant_hq_piece() -> void:
	pending_hq = true
	hq_piece = Piece.start_piece(rng)
	if _make_room([hq_piece]) > 0: # 자리가 없으면 무료로 한 줄씩 확장한다
		_note += "\n본부를 놓을 자리가 없어 필드를 무료로 넓혔습니다 (%dx%d)" % [field.bounds.size.x, field.bounds.size.y]
	_note += "\n본부 조각을 먼저 놓아야 웨이브를 시작할 수 있습니다"
	select_hq()


func _show_defeat() -> void:
	_result_panel("패배 — 웨이브 %d에서 본부가 무너졌습니다" % GameState.wave, [["다시 시작", get_tree().reload_current_scene], ["처음으로", _to_menu]])
	status.text = ""


## 30웨이브 승리: 결과를 보여 주고 무한 모드로 계속하거나 처음으로 (기획서 9.1)
func _show_victory() -> void:
	var pc: PanelContainer = _result_panel("승리! %d웨이브를 지켜 냈습니다\n땅 칸 %d · 본부 %d개 · 최고 웨이브 %d" % [Balance.WIN_WAVE, field.land_count(), field.hqs.size(), SaveManager.best_wave], [["계속하기 (무한 모드)", Callable()], ["처음으로", _to_menu]])
	(pc.get_child(0).get_child(1) as Button).pressed.connect(pc.queue_free)


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


func _tilt(deg: float) -> void:
	create_tween().tween_method(_set_pitch, _pitch, deg, 0.8)


func _set_pitch(deg: float) -> void:
	_pitch = deg
	var r: float = deg_to_rad(deg)
	var center: Vector3 = field.center_world()
	var cam_pos: Vector3 = center + Vector3(0, 20.0 * sin(r), 20.0 * cos(r))
	var scale: float = maxf(field.bounds.size.x / float(Field.W), field.bounds.size.y / float(Field.H)) # 넓어진 필드에 맞춰 줌아웃
	var t: float = (90.0 - deg) / (90.0 - Balance.COMBAT_PITCH)
	pixel.aim(cam_pos, deg, lerpf(Balance.PREP_CAM_SIZE, Balance.COMBAT_CAM_SIZE, t) * scale * lerpf(_zoom, 1.0, t)) # 전투 때는 더 확대한다, 휠 줌은 준비 단계만 (기획서 2장)


## 준비 단계 휠 확대/축소 (기획서 2장)
func _wheel_zoom(f: float) -> void:
	_zoom = clampf(_zoom * f, Balance.ZOOM_MIN, Balance.ZOOM_MAX)
	_set_pitch(_pitch)


func _rebuild_ghost() -> void:
	_warn = false # 들고 있는 조각이 바뀌면 경고도 다시 계산한다
	_warn_key = ""
	_carve_n = 0
	for c in ghost.get_children():
		ghost.remove_child(c)
		c.queue_free()
	ghost.visible = current != null
	if current == null:
		return
	for _c in current.cells:
		var m: MeshInstance3D = MeshInstance3D.new()
		m.mesh = field.block_mesh
		ghost.add_child(m)


func _ghost_mat(t: int, ok: bool, warn: bool = false) -> StandardMaterial3D:
	var key: int = t * 4 + int(ok) + (2 if warn else 0)
	if not _gmats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		var c: Color = Field.color_of(t) if ok else Color(0.9, 0.2, 0.2)
		if t == -1 and ok:
			c = Color(0.1, 0.85, 1.0)
		if t == -2 and ok:
			c = Color(0.05, 0.4, 0.85)
		if warn and ok: # 놓을 수는 있지만 교역소가 바다와 끊긴다
			c = Color(1.0, 0.55, 0.1)
		c.a = 0.75
		m.albedo_color = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_gmats[key] = m
	return _gmats[key]


## 건설 위치 표시: 평원(초록)과 구분되도록 하늘색 / 불가는 빨강
func _cursor_mat(ok: bool) -> StandardMaterial3D:
	return _ghost_mat(-1, true) if ok else _ghost_mat(-1, false)


func _hover_cell() -> Vector2i:
	var mp: Vector2 = get_viewport().get_mouse_position()
	var ray: Array[Vector3] = pixel.ray(mp)
	var hit: Variant = Plane(Vector3.UP, Field.BLOCK_H).intersects_ray(ray[0], ray[1])
	if hit == null:
		return Vector2i(-100, -100)
	return field.world_to_cell(hit as Vector3)


func _process(_delta: float) -> void:
	cursor.visible = false
	if battle != null:
		_refresh_hud()
	if current == null and build_id == 0:
		return
	if _over_ui():
		ghost.visible = false
		return
	if current != null:
		ghost.visible = true
		var origin: Vector2i = current.origin_for(_hover_cell())
		var ok: bool = field.can_place(current, origin)
		_update_warn(origin, ok)
		for i in current.cells.size():
			var m: MeshInstance3D = ghost.get_child(i) as MeshInstance3D
			m.position = field.cell_to_world(origin + current.cells[i]) + Vector3(0, GHOST_Y, 0)
			var gt: int = current.terrain[i]
			if gt == Piece.SEA and field.cells.has(origin + current.cells[i]):
				gt = -2 # 땅을 물로 깎는 칸은 진한 파랑
			m.material_override = _ghost_mat(gt, ok, _warn)
	else:
		var c: Vector2i = _hover_cell()
		cursor.visible = true
		cursor.position = field.cell_to_world(c) + Vector3(0, (0.05 if Balance.BUILDINGS.get(build_id, {}).get("on_water", false) else Field.BLOCK_H + 0.05), 0)
		cursor.material_override = _cursor_mat(_build_ok(c))


## 들고 있는 타일을 origin에 놓으면 교역소가 바다와 끊기는지 계산해 경고를 켠다. 위치가 바뀔 때만 계산한다 (기획서 5.6)
func _update_warn(origin: Vector2i, ok: bool) -> void:
	var post: Vector2i = field.trading_post()
	var key: String = "%s|%s|%d" % [str(origin), str(current.cells), post.x * 1000 + post.y] if current != null else ""
	if key == _warn_key:
		return
	_warn_key = key
	var warn: bool = ok and post.x >= 0 and field.is_post_open(post) and not field.post_open_after(post, current, origin)
	var carve: int = field.carve_count(current, origin) if ok else 0
	if warn != _warn or carve != _carve_n:
		_warn = warn
		_carve_n = carve
		_refresh_hud()


## 건물 패널이 열린 채로 다른 UI를 누르면 건물 선택을 푼다 (기획서 5.2)
func _input(event: InputEvent) -> void:
	if selected_cell.x < 0 or not (event is InputEventMouseButton and event.pressed):
		return
	var h: Control = get_viewport().gui_get_hovered_control()
	if h != null and h != upgrade_panel and not upgrade_panel.is_ancestor_of(h):
		selected_cell = Vector2i(-1, -1)
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	var left: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var key: int = (event as InputEventKey).keycode if event is InputEventKey and event.pressed else 0
	if battle == null and event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_wheel_zoom(Balance.ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / Balance.ZOOM_STEP)
		return
	if open_category >= 0 and (left or right or key == KEY_ESCAPE): # 목록 바깥을 누르면 닫는다
		open_category = -1
		_update_dropdown()
		return
	if build_id != 0:
		if left:
			try_build(_hover_cell())
		elif right or key == KEY_ESCAPE:
			set_build(0)
	elif current != null:
		if left:
			place_current(_hover_cell())
		elif right or key == KEY_R:
			_rotate()
	elif battle == null: # 아무것도 들고 있지 않으면 건물을 골라 레벨업 패널을 연다
		if left:
			var hc: Vector2i = _hover_cell()
			if field.ruins.has(hc):
				explore(hc)
			else:
				select_building(hc)
		elif right or key == KEY_ESCAPE:
			select_building(Vector2i(-1, -1))
	else: # 전투 중에는 클릭한 땅이 병사 집결지가 된다
		if left:
			command_move(_hover_cell())
		elif right:
			battle.clear_orders()


## 본부를 위치 순서로 정렬한 목록 (왼쪽 패널 표시용)
func _sorted_hqs() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in field.hqs:
		if field.hq_level.has(h):
			out.append(h)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


## 본부 이름: 위치 순서대로 1, 2, 3 …
func _hq_name(h: Vector2i) -> String:
	return str(_sorted_hqs().find(h) + 1)


func _tech_pos(id: String) -> Vector2:
	return Vector2(int(Balance.TECHS[id]["col"]) * TECH_PITCH, int(Balance.TECHS[id]["row"]) * 74)


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


func _refresh_hud() -> void:
	var inc: Vector2i = field.income(GameState.researched) # 웨이브 정산 때 들어올 생산량 (기획서 7.2)
	stats.text = "골드 %d (+%d) · 연구포인트 %d (%d/%d, +%d) · 웨이브 %d   " % [GameState.gold, inc.x, GameState.research_points, GameState.research_progress, Balance.research_threshold(GameState.research_gained), field.research_income(GameState.researched), GameState.wave]
	for id in build_buttons:
		var bb: Button = build_buttons[id]
		bb.text = "%s %dG · %s" % [Balance.BUILDINGS[id]["name"], _cost_of(id), Balance.effect_text(id, 1, GameState.researched)]
		var need: String = Balance.BUILDINGS[id].get("tech", "")
		bb.tooltip_text = "" if _unlocked(id) or need == "" or GameState.has_tech(need) else "필요 연구: " + Balance.TECHS[need]["name"]
		if _blocked():
			bb.tooltip_text = "전투 보상 타일을 먼저 놓으세요"
		bb.disabled = _blocked() or not _unlocked(id) or GameState.gold < _cost_of(id)
		bb.visible = Balance.menu_visible(id, GameState.researched) # 해금 뒤에는 기본 건물이 목록에서 사라진다 (기획서 5.2.1)
	for cbtn in category_buttons:
		cbtn.disabled = _blocked() or battle != null
	if _blocked() and open_category >= 0:
		open_category = -1
		_update_dropdown()
	trade_button.visible = npc_present and battle == null
	for tid in trade_buttons:
		var tbtn: Button = trade_buttons[tid]
		tbtn.text = ("✓ 거래 완료 — " if trade_sold.has(tid) else "") + _trade_def(tid)["name"]
		tbtn.disabled = not _trade_ok(tid)
	research_toggle.text = "연구 (연구포인트 %d)" % GameState.research_points
	# 이번 웨이브의 적을 미리 알려 준다. 해적의 세기는 땅 칸 수·확장 횟수에 따라 바뀐다 (기획서 6장)
	wave_info.visible = battle == null
	wave_panel.visible = top_panel.visible and battle == null
	var comp: Dictionary = Balance.enemy_composition(GameState.wave, GameState.run_seed)
	var comp_parts: Array[String] = []
	for kind in comp:
		comp_parts.append("%s %d명" % [Balance.UNITS[kind]["name"], comp[kind]])
	wave_info.text = "웨이브 %d 예고: %s (전투력 %d · 해적선 %d척) · 체력·공격 ×%.2f" % [GameState.wave, " · ".join(comp_parts), Balance.wave_power(GameState.wave, GameState.run_seed), Balance.ship_count(GameState.wave, GameState.run_seed), Balance.enemy_mult(field.land_count(), field.expansions)]
	if field.sea_blocked():
		wave_info.text += "\n바닷길이 막혀 해적이 걸어서 바다를 건넙니다"
	for nk in Balance.new_enemy_kinds(GameState.wave): # 새 종류가 처음 나오는 웨이브 안내
		var info: Dictionary = Balance.UNITS[nk]
		wave_info.text += "\n새 적: %s (체력 %d · 공격 %d%s)" % [info["name"], info["hp"], info["atk"], (" · 사거리 %.1f칸" % info["reach"]) if info.get("ranged", false) else ""]
	if pending_hq:
		wave_info.text += "\n본부 조각을 먼저 놓으세요 (아래 '본부 조각' 카드)"
	if tiles_required > 0:
		wave_info.text += "\n전투 보상 타일을 먼저 놓으세요 (건설·강화·웨이브 시작은 그다음)"
	var plan: Array = Battle.barracks_plan(field)
	if not plan.is_empty(): # 병영이 웨이브 시작 때 내보낼 병력(병사 생산은 무료)
		var counts: Dictionary = {}
		for entry: Dictionary in plan:
			var unit_name: String = Balance.UNITS[entry["kind"]]["name"]
			counts[unit_name] = int(counts.get(unit_name, 0)) + 1
		var parts: Array[String] = []
		for unit_name in counts:
			parts.append("%s %d" % [unit_name, counts[unit_name]])
		wave_info.text += "\n병영 병력 %d명 (%s)" % [plan.size(), ", ".join(parts)]
	wave_button.disabled = battle != null or _blocked() or placed_count == 0
	wave_button.tooltip_text = "먼저 타일을 놓아야 합니다" if _blocked() else ""
	# 조각 선택 패널: 일반 조각을 놓을 수 있거나 본부 조각이 남아 있을 때만 보인다
	hq_title.visible = pending_hq
	hq_card.visible = pending_hq
	choice_title.visible = pieces_left > 0
	choice_title.text = "전투 보상: 타일 1개를 골라 놓기" if tiles_required > 0 else "조각 선택 (구매한 조각)"
	if pending_hq:
		hq_card.set_piece(hq_piece)
		hq_card.selected = placing_hq
	for card in cards:
		card.visible = pieces_left > 0
	panel.visible = battle == null and placed_count > 0 and (pieces_left > 0 or pending_hq)
	if research_panel.visible:
		_refresh_research()
	var lines: Array[String] = []
	for h in _sorted_hqs():
		var nxt: int = field.next_level_food(h)
		lines.append("본부 %s Lv %d · 영역 %d칸 · 식량 %d/%d" % [_hq_name(h), field.hq_level[h], field.territory_of[h].size(), field.hq_food[h], nxt])
	town_label.text = "\n".join(lines)
	field.refresh_hq_bars(battle == null) # 본부 옆 레벨업 바 (기획서 5.3)
	if selected_cell.x >= 0 and not field.buildings.has(selected_cell):
		selected_cell = Vector2i(-1, -1)
	upgrade_panel.visible = selected_cell.x >= 0 and battle == null
	if upgrade_panel.visible:
		var bid: int = field.buildings[selected_cell]
		var lv: int = field.levels[selected_cell]
		upgrade_title.text = "%s Lv %d%s" % [Balance.BUILDINGS[bid]["name"], lv, " · " + Balance.UNITS[Balance.MILITARY[bid]["units"][lv - 1]]["name"] if Balance.MILITARY.has(bid) else ""]
		upgrade_effect.text = Balance.effect_text(bid, lv, GameState.researched)
		if bid == Balance.TRADING_POST and not field.is_post_open(selected_cell):
			upgrade_effect.text += "\n⚠ 물가가 막혀 NPC가 오지 못합니다"
		if bid == Balance.FISHERY or bid == Balance.FISH_VILLAGE: # 이 낚시터의 실제 생산량
			upgrade_effect.text = "정산 식량 +%d (이어진 물가 %d칸)" % [field.fishing_food(selected_cell), field.fishing_cells(selected_cell)]
		if field.can_upgrade(selected_cell):
			var cost: int = GameState.upgrade_discounted(Balance.upgrade_cost(bid, lv + 1))
			upgrade_button.text = "레벨 %d로 강화 %dG" % [lv + 1, cost]
			upgrade_button.tooltip_text = "다음 레벨: " + Balance.effect_text(bid, lv + 1, GameState.researched)
			upgrade_button.disabled = _blocked() or GameState.gold < cost or _upgrade_locked(selected_cell)
			if _upgrade_locked(selected_cell):
				upgrade_button.tooltip_text = "필요 연구: " + Balance.TECHS[Balance.LV3_TECH]["name"]
		elif Balance.evolve_to(bid) > 0: # 레벨 3 기본 건물: 진화 (기획서 5.2.1)
			var to: int = Balance.evolve_to(bid)
			var ecost: int = GameState.upgrade_discounted(Balance.evolve_cost(to))
			upgrade_button.text = "진화: %s %dG" % [Balance.BUILDINGS[to]["name"], ecost]
			upgrade_button.tooltip_text = "진화 후 레벨 1: " + Balance.effect_text(to, 1, GameState.researched)
			upgrade_button.disabled = _blocked() or GameState.gold < ecost or not _can_evolve(selected_cell)
			if not _can_evolve(selected_cell):
				upgrade_button.tooltip_text = "필요 연구: " + Balance.TECHS[Balance.BUILDINGS[to]["tech"]]["name"]
		else:
			upgrade_button.text = "최고 레벨"
			upgrade_button.disabled = true
	var s: String
	if battle != null:
		s = battle.summary() + "\n땅을 클릭하면 병사가 그곳으로 이동합니다 · 우클릭으로 이동 취소"
	elif placed_count == 0:
		s = "시작 조각을 놓으세요 (빨간 칸이 본부) · 좌클릭 배치 · R/우클릭 회전"
	elif current != null and placing_hq:
		s = "본부 조각: 좌클릭 배치 · R/우클릭 회전 (놓아야 웨이브를 시작할 수 있습니다)"
	elif current != null:
		s = "조각: 좌클릭 배치 · R/우클릭 회전 · 고르지 않은 조각은 버려집니다"
		if _carve_n > 0:
			s += "\n땅 %d칸이 물로 바뀝니다 (진한 파랑, 되돌릴 수 없음)" % _carve_n
		if _warn:
			s += "\n⚠ 이 자리에 놓으면 교역소가 바다와 끊겨 교역 NPC가 오지 못합니다 (주황색)"
	elif pending_hq:
		s = "아래 '본부 조각' 카드를 골라 먼저 놓으세요"
	elif tiles_required > 0:
		s = "아래 카드에서 타일을 1개 골라 놓으세요"
	elif build_id != 0:
		s = "%s 건설: 좌클릭 배치 · 우클릭/Esc 취소" % Balance.BUILDINGS[build_id]["name"]
	elif pieces_left > 0:
		s = "아래 카드에서 조각 1개를 고르거나 건설 메뉴에서 건물을 고르세요"
	else:
		s = "이번 준비 단계의 조각은 다 썼습니다. 건물을 짓거나 웨이브를 시작하세요"
	status.text = (_note + "\n" if _note != "" else "") + s

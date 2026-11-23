extends Node3D
## 준비 단계(조각 배치·건설·시장·확장)와 전투 단계 진행 (기획서 2장, 3장, 5장)

const CARD_COUNT: int = 3
const GHOST_Y: float = 0.45

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var field: Field
var camera: Camera3D
var ghost: Node3D
var cursor: MeshInstance3D ## 건물 건설 위치 표시
var current: Piece = null ## 배치 중인 조각
var build_id: int = 0 ## 건설 모드의 건물 종류, 0이면 건설 모드 아님
var pieces_left: int = 0 ## 이번 준비 단계에 더 놓을 수 있는 조각 수
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
var build_panel: PanelContainer
var side_panel: PanelContainer
var town_label: Label
var expand_label: Label
var buy_button: Button
var expand_buttons: Dictionary = {} ## 방향 → 버튼
var build_buttons: Dictionary = {}
var selected_cell: Vector2i = Vector2i(-1, -1) ## 레벨업 패널에 보이는 건물
var upgrade_panel: PanelContainer
var upgrade_title: Label
var upgrade_effect: Label
var upgrade_button: Button
var unit_row: VBoxContainer
var unit_buttons: Dictionary = {} ## 병종 → 버튼
var research_panel: PanelContainer
var research_buttons: Dictionary = {} ## 연구 id → 버튼
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
var npc_next_wave: int = -1 ## 교역 NPC가 다음에 방문할 웨이브, 교역소가 없으면 -1 (기획서 5.6)
var npc_present: bool = false ## 교역 NPC가 와 있는지 (기획서 5.6)
var npc_node: MeshInstance3D = null
var trade_offers: Array = []
var trade_sold: Dictionary = {} ## 이번 방문에서 이미 한 거래 id → true
var trade_button: Button
var trade_panel: PanelContainer
var trade_list: VBoxContainer
var trade_buttons: Dictionary = {}
var wave_info: Label ## 준비 단계의 이번 웨이브 적 예고
var battle_speed_index: int = 0
var layer: CanvasLayer
var battle: Battle = null
var _pitch: float = 90.0
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.position = Vector3(0, 20, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	add_child(camera)
	camera.current = true
	field = Field.new()
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
	stats = Label.new()
	row.add_child(stats)
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
	wave_info = Label.new()
	top.add_child(wave_info)
	status = Label.new()
	top.add_child(status)
	top_panel = PanelContainer.new()
	top_panel.add_child(top)
	top_panel.visible = false
	layer.add_child(top_panel)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
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
	# 왼쪽: 본부 레벨, 조각 구매(시장), 필드 확장(본부)
	var side: VBoxContainer = VBoxContainer.new()
	town_label = Label.new()
	side.add_child(town_label)
	buy_button = Button.new()
	buy_button.pressed.connect(buy_piece)
	side.add_child(buy_button)
	expand_label = Label.new()
	side.add_child(expand_label)
	var erow: HBoxContainer = HBoxContainer.new()
	for d in [[Vector2i.LEFT, "←"], [Vector2i.UP, "↑"], [Vector2i.DOWN, "↓"], [Vector2i.RIGHT, "→"]]:
		var eb: Button = Button.new()
		eb.text = "확장 " + d[1]
		eb.pressed.connect(expand.bind(d[0]))
		expand_buttons[d[0]] = eb
		erow.add_child(eb)
	side.add_child(erow)
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
	unit_row = VBoxContainer.new()
	for k in Balance.SOLDIER_KINDS:
		var ub: Button = Button.new()
		ub.toggle_mode = true
		ub.pressed.connect(select_unit.bind(k))
		unit_buttons[k] = ub
		unit_row.add_child(ub)
	up.add_child(unit_row)
	upgrade_panel = PanelContainer.new()
	upgrade_panel.add_child(up)
	upgrade_panel.visible = false
	layer.add_child(upgrade_panel)
	upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 54) # 건설 메뉴 위
	upgrade_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	upgrade_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# 가운데: 연구 패널 (4갈래 x 3단계)
	var rbox: VBoxContainer = VBoxContainer.new()
	var rtitle: Label = Label.new()
	rtitle.text = "연구 — 연구포인트로 즉시 연구합니다 (취소 없음)"
	rbox.add_child(rtitle)
	var grid: GridContainer = GridContainer.new()
	grid.columns = Balance.BRANCHES.size()
	for bname in Balance.BRANCHES:
		var hl: Label = Label.new()
		hl.text = bname
		grid.add_child(hl)
	for tier in 3:
		for br in Balance.BRANCHES.size():
			var tid: String = Balance.TECH_ORDER[br][tier]
			var tb: Button = Button.new()
			tb.custom_minimum_size = Vector2(190, 62)
			tb.pressed.connect(research.bind(tid))
			research_buttons[tid] = tb
			grid.add_child(tb)
	rbox.add_child(grid)
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
	for c: Control in [panel, top_panel, build_panel, side_panel, upgrade_panel, research_panel, dropdown_panel, trade_panel]:
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
	pieces_left = 1
	tiles_required = 1 # 전투 보상 타일: 놓기 전에는 건설·강화·웨이브 시작이 막힌다
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
			field.expand(d, true)
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


## 시장에서 조각을 산다: 놓을 수 있는 조각 +1, 선택지 새로 뽑기 (기획서 5장)
func buy_piece() -> bool:
	var price: int = field.market_price()
	if battle != null or placed_count == 0 or price < 0:
		return false
	if not GameState.spend(price):
		return false
	_grant_piece()
	return true


## 놓을 수 있는 조각을 1개 늘리고 선택지를 새로 뽑는다 (시장 구매·NPC 거래) (기획서 5장, 5.6)
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
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.5, 0.95)
	npc_node.material_override = mat
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
	if id == "food_gold":
		GameState.add(20, 0)
	elif id == "gold_rp":
		GameState.add_research(1)
	elif id == "gold_piece":
		_grant_piece()
	elif id == "gold_guards":
		GameState.extra_guards += 2
	_refresh_hud()
	return true


## 본부에서 골드로 필드를 한 줄 넓힌다 (기획서 3장)
func expand(dir: Vector2i) -> bool:
	if battle != null or placed_count == 0 or not field.can_expand(dir):
		return false
	if not GameState.spend(Balance.expand_cost(field.paid_expansions)):
		return false
	field.expand(dir)
	_set_pitch(_pitch) # 카메라가 넓어진 필드를 비춘다
	_note = "필드를 넓혔습니다 (%dx%d)" % [field.bounds.size.x, field.bounds.size.y]
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
		build_panel.visible = true
		side_panel.visible = true
		_begin_prep()
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


## 연구포인트로 연구한다 (기획서 5.4)
func research(id: String) -> bool:
	if battle != null or not GameState.research(id):
		return false
	_note = "연구 완료: " + Balance.TECHS[id]["name"]
	_refresh_hud()
	return true


## 선택한 병영이 만들 병종을 정한다. 해금된 병종만 고를 수 있다 (기획서 6장)
func select_unit(kind: int) -> bool:
	if selected_cell.x < 0 or field.buildings.get(selected_cell, 0) != Balance.BARRACKS or not _unit_unlocked(kind):
		_refresh_hud()
		return false
	field.barracks_unit[selected_cell] = kind
	_refresh_hud()
	return true


func _unlocked(id: int) -> bool:
	var tech: String = Balance.BUILDINGS[id].get("tech", "")
	return tech == "" or GameState.has_tech(tech)


func _unit_unlocked(kind: int) -> bool:
	var tech: String = Balance.UNIT_TECH.get(kind, "")
	return tech == "" or GameState.has_tech(tech)


func upgrade_selected() -> bool:
	if selected_cell.x < 0 or _blocked() or not field.can_upgrade(selected_cell):
		return false
	var cost: int = GameState.discounted(Balance.upgrade_cost(field.buildings[selected_cell], field.levels[selected_cell] + 1))
	if not GameState.spend(cost):
		return false
	field.upgrade(selected_cell)
	_note = ""
	_refresh_hud()
	return true


func _cost_of(id: int) -> int:
	return GameState.discounted(Balance.BUILDINGS[id]["cost"])


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
	if battle == null or not field.is_land(c):
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
		_show_defeat()
		return
	var inc: Vector2i = field.income(GameState.researched)
	var cleared: int = GameState.wave
	GameState.add(inc.x, inc.y)
	GameState.next_wave()
	var levels: int = GameState.check_level() # 본부 레벨이 오르면 레벨마다 연구포인트 +1 (기획서 5.3)
	field.repair_all()
	_tilt(90.0)
	build_panel.visible = true
	side_panel.visible = true
	_begin_prep()
	_note = "웨이브 %d 승리: 골드 +%d · 식량 +%d" % [cleared, inc.x, inc.y]
	if levels > 0:
		_note += "\n본부 레벨 %d! 연구포인트 +%d" % [GameState.hq_level, levels]
	_maybe_visit_npc() # 3·6·9… 웨이브의 준비 단계에 교역 NPC가 온다 (기획서 5.6)
	if Balance.HQ_PIECE_WAVES.has(cleared): # 보스 라운드를 이기면 본부 조각을 하나 더 받는다 (기획서 5.5)
		_grant_hq_piece()
	_refresh_hud()


func _grant_hq_piece() -> void:
	pending_hq = true
	hq_piece = Piece.start_piece(rng)
	if _make_room([hq_piece]) > 0: # 자리가 없으면 무료로 한 줄씩 확장한다
		_note += "\n본부를 놓을 자리가 없어 필드를 무료로 넓혔습니다 (%dx%d)" % [field.bounds.size.x, field.bounds.size.y]
	_note += "\n본부 조각을 먼저 놓아야 웨이브를 시작할 수 있습니다"
	select_hq()


func _show_defeat() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var l: Label = Label.new()
	l.text = "패배 — 웨이브 %d에서 본부가 무너졌습니다" % GameState.wave
	box.add_child(l)
	var b: Button = Button.new()
	b.text = "다시 시작"
	b.pressed.connect(get_tree().reload_current_scene)
	box.add_child(b)
	var pc: PanelContainer = PanelContainer.new()
	pc.add_child(box)
	layer.add_child(pc)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	status.text = ""


func _tilt(deg: float) -> void:
	create_tween().tween_method(_set_pitch, _pitch, deg, 0.8)


func _set_pitch(deg: float) -> void:
	_pitch = deg
	var r: float = deg_to_rad(deg)
	camera.rotation_degrees = Vector3(-deg, 0, 0)
	var center: Vector3 = field.center_world()
	camera.position = center + Vector3(0, 20.0 * sin(r), 20.0 * cos(r))
	var scale: float = maxf(field.bounds.size.x / float(Field.W), field.bounds.size.y / float(Field.H)) # 넓어진 필드에 맞춰 줌아웃
	camera.size = lerpf(Balance.PREP_CAM_SIZE, Balance.COMBAT_CAM_SIZE, (90.0 - deg) / (90.0 - Balance.COMBAT_PITCH)) * scale # 전투 때는 더 확대한다


func _rebuild_ghost() -> void:
	_warn = false # 들고 있는 조각이 바뀌면 경고도 다시 계산한다
	_warn_key = ""
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
	var hit: Variant = Plane(Vector3.UP, Field.BLOCK_H).intersects_ray(camera.project_ray_origin(mp), camera.project_ray_normal(mp))
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
			m.material_override = _ghost_mat(current.terrain[i], ok, _warn)
	else:
		var c: Vector2i = _hover_cell()
		cursor.visible = true
		cursor.position = field.cell_to_world(c) + Vector3(0, (0.05 if build_id == Balance.FISHERY else Field.BLOCK_H + 0.05), 0)
		cursor.material_override = _cursor_mat(_build_ok(c))


## 들고 있는 타일을 origin에 놓으면 교역소가 바다와 끊기는지 계산해 경고를 켠다. 위치가 바뀔 때만 계산한다 (기획서 5.6)
func _update_warn(origin: Vector2i, ok: bool) -> void:
	var post: Vector2i = field.trading_post()
	var key: String = "%s|%s|%d" % [str(origin), str(current.cells), post.x * 1000 + post.y] if current != null else ""
	if key == _warn_key:
		return
	_warn_key = key
	var warn: bool = ok and post.x >= 0 and field.is_post_open(post) and not field.post_open_after(post, current, origin)
	if warn != _warn:
		_warn = warn
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	var left: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var key: int = (event as InputEventKey).keycode if event is InputEventKey and event.pressed else 0
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
			select_building(_hover_cell())
		elif right or key == KEY_ESCAPE:
			select_building(Vector2i(-1, -1))
	else: # 전투 중에는 클릭한 땅이 병사 집결지가 된다
		if left:
			command_move(_hover_cell())
		elif right:
			battle.clear_orders()


func _refresh_research() -> void:
	for id in research_buttons:
		var b: Button = research_buttons[id]
		var info: Dictionary = Balance.TECHS[id]
		var done: bool = GameState.has_tech(id)
		b.text = "%s%s\n%s · %d점" % ["✓ " if done else "", info["name"], info["desc"], Balance.tech_cost(id)]
		b.disabled = done or not GameState.can_research(id)
		b.modulate = Color(0.55, 1.0, 0.55) if done else Color.WHITE
		var pre: String = Balance.tech_prereq(id)
		if done:
			b.tooltip_text = ""
		elif pre != "" and not GameState.has_tech(pre):
			b.tooltip_text = "먼저 %s 연구가 필요합니다" % Balance.TECHS[pre]["name"]
		else:
			b.tooltip_text = "연구포인트 %d점 필요 (보유 %d점)" % [Balance.tech_cost(id), GameState.research_points]


func _refresh_hud() -> void:
	stats.text = "골드 %d · 식량 %d · 연구포인트 %d · 웨이브 %d   " % [GameState.gold, GameState.food, GameState.research_points, GameState.wave]
	for id in build_buttons:
		var bb: Button = build_buttons[id]
		bb.text = "%s %dG · %s" % [Balance.BUILDINGS[id]["name"], _cost_of(id), Balance.effect_text(id, 1)]
		var need: String = Balance.BUILDINGS[id].get("tech", "")
		bb.tooltip_text = "" if _unlocked(id) else "필요 연구: " + Balance.TECHS[need]["name"]
		if _blocked():
			bb.tooltip_text = "전투 보상 타일을 먼저 놓으세요"
		bb.disabled = _blocked() or not _unlocked(id) or GameState.gold < _cost_of(id)
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
	var pirates_n: int = Balance.pirate_count(GameState.wave)
	wave_info.text = "웨이브 %d 예고: 해적 %d명 (해적선 %d척) · 체력·공격 ×%.2f" % [GameState.wave, pirates_n, Balance.ship_count(GameState.wave), Balance.enemy_mult(field.land_count(), field.expansions)]
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
	var nxt: int = GameState.next_level_food()
	town_label.text = "본부 Lv %d · 식량 누적 %d%s" % [GameState.hq_level, GameState.food_total, "/%d" % nxt if nxt > 0 else " (최고)"]
	var price: int = field.market_price()
	buy_button.text = "조각 구매 %dG" % price if price >= 0 else "조각 구매 (시장 필요)"
	buy_button.disabled = price < 0 or GameState.gold < price
	if selected_cell.x >= 0 and not field.buildings.has(selected_cell):
		selected_cell = Vector2i(-1, -1)
	upgrade_panel.visible = selected_cell.x >= 0 and battle == null
	if upgrade_panel.visible:
		var bid: int = field.buildings[selected_cell]
		var lv: int = field.levels[selected_cell]
		var cur_unit: int = field.barracks_unit.get(selected_cell, Balance.U_SOLDIER)
		upgrade_title.text = "%s Lv %d%s" % [Balance.BUILDINGS[bid]["name"], lv, " · 생산: " + Balance.UNITS[cur_unit]["name"] if bid == Balance.BARRACKS else ""]
		upgrade_effect.text = Balance.effect_text(bid, lv)
		if bid == Balance.TRADING_POST and not field.is_post_open(selected_cell):
			upgrade_effect.text += "\n⚠ 물가가 막혀 NPC가 오지 못합니다"
		if bid == Balance.FISHERY: # 이 낚시터의 실제 생산량
			upgrade_effect.text = "정산 식량 +%d (이어진 물가 %d칸)" % [field.fishing_food(selected_cell), field.fishing_cells(selected_cell)]
		unit_row.visible = bid == Balance.BARRACKS
		if unit_row.visible:
			for k in unit_buttons:
				var ub: Button = unit_buttons[k]
				var info: Dictionary = Balance.UNITS[k]
				ub.text = info["name"]
				ub.button_pressed = k == cur_unit
				ub.disabled = not _unit_unlocked(k)
				ub.tooltip_text = "체력 %d · 공격 %d · 속도 %.1f%s" % [info["hp"], info["atk"], info["speed"], (" · 사거리 %d칸" % int(info["reach"])) if info["reach"] > 2.0 else ""]
				if not _unit_unlocked(k):
					ub.tooltip_text = "필요 연구: " + Balance.TECHS[Balance.UNIT_TECH[k]]["name"]
		if field.can_upgrade(selected_cell):
			var cost: int = GameState.discounted(Balance.upgrade_cost(bid, lv + 1))
			upgrade_button.text = "레벨 %d로 강화 %dG" % [lv + 1, cost]
			upgrade_button.tooltip_text = "다음 레벨: " + Balance.effect_text(bid, lv + 1)
			upgrade_button.disabled = _blocked() or GameState.gold < cost
		else:
			upgrade_button.text = "최고 레벨"
			upgrade_button.disabled = true
	var cost: int = Balance.expand_cost(field.paid_expansions)
	expand_label.text = "필드 확장 %dG · 현재 %dx%d" % [cost, field.bounds.size.x, field.bounds.size.y]
	for d in expand_buttons:
		expand_buttons[d].disabled = GameState.gold < cost or not field.can_expand(d)
	var s: String
	if battle != null:
		s = battle.summary() + "\n땅을 클릭하면 병사가 그곳으로 이동합니다 · 우클릭으로 이동 취소"
	elif placed_count == 0:
		s = "시작 조각을 놓으세요 (빨간 칸이 본부) · 좌클릭 배치 · R/우클릭 회전"
	elif current != null and placing_hq:
		s = "본부 조각: 좌클릭 배치 · R/우클릭 회전 (놓아야 웨이브를 시작할 수 있습니다)"
	elif current != null:
		s = "조각: 좌클릭 배치 · R/우클릭 회전 · 고르지 않은 조각은 버려집니다"
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

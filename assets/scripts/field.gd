class_name Field
extends Node3D
## 맵: 96x96 지형 격자와 블록 표시. 판마다 시드로 군도를 만든다. 땅이 아닌 칸은 바다다 (기획서 3장)

const W: int = Balance.MAP_SIZE
const H: int = Balance.MAP_SIZE
const SEA: int = 0
const BLOCK_H: float = 0.08 ## 땅 두께. 입체감 없이 평평한 땅 (기획서 3장)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var bounds: Rect2i = Rect2i(0, 0, W, H) ## 맵 전체
var cells: Dictionary = {} ## 땅 칸 → 지형. 없는 칸은 바다
var _land_nodes: Array[Node] = [] ## 지형 종류별 땅 블록 묶음(MultiMesh)
var hqs: Dictionary = {} ## 살아 있는 본부 위치 → 체력 (여러 개일 수 있다) (기획서 5.5)
var territory_of: Dictionary = {} ## 본부 위치 → 그 본부 영역 칸 집합 (기획서 5.3)
var territory: Dictionary = {} ## 모든 본부 영역의 합집합 (겹치면 하나로 이어진다)
var territory_enabled: bool = false ## true면 건설·생산이 본부 영역 안으로 제한된다. 게임(main.gd)이 켠다 (기획서 5.3)
var _terr_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _terr_nodes: Array[Node] = []
var hq_lost: int = 0 ## 영구히 잃은 본부 수
var buildings_lost: Dictionary = {} ## 이번 전투에서 무너진 건물 종류 → 개수(본부 제외). 전투를 시작할 때 비운다 (기획서 5.2)
var hq_level: Dictionary = {} ## 본부 위치 → 그 본부의 레벨 (본부마다 따로) (기획서 5.3)
const GRID_SHADER: Shader = preload("res://assets/shaders/grid.gdshader")
const BAR_W: float = 0.95 ## 본부 레벨업 바 크기 (기획서 5.3)
const BAR_H: float = 0.21
var _hq_bars: Dictionary = {} ## 본부 위치 → 레벨업까지 식량 바 [배경, 채움, 글자] (기획서 5.3)
var hq_food: Dictionary = {} ## 본부 위치 → 그 본부 영역에서 번 식량 누적
## 첫 번째 본부 위치 (없으면 (-1, -1))
var hq: Vector2i:
	get:
		return hqs.keys()[0] if not hqs.is_empty() else Vector2i(-1, -1)
## 모든 본부의 체력 합 (0이면 모든 본부가 파괴된 것)
var hq_hp: float:
	get:
		var total: float = 0.0
		for c in hqs:
			total += hqs[c]
		return total
var block_mesh: BoxMesh = BoxMesh.new()
var _ver: int = 0 ## 지형이 바뀔 때마다 올라가는 번호 (계산 캐시용)
var _open_ver: int = -1
var _open: Dictionary = {} ## 맵 가장자리 바다와 이어진 바다 칸
var _blocked_ver: int = -1
var _blocked: bool = false
var _start_ver: int = -1
var _start_ok: Dictionary = {} ## 첫 도시를 세울 수 있는 칸 (기획서 2장)
var _frame_nodes: Array[Node] = []
var _mats: Dictionary = {}


static func color_of(t: int) -> Color:
	if t == Piece.SEA:
		return Color(0.42, 0.68, 0.98)
	if t == Piece.FOREST:
		return Color(0.15, 0.45, 0.2)
	if t == Piece.MOUNTAIN:
		return Color(0.5, 0.5, 0.55)
	return Color(0.45, 0.75, 0.35) if t == Piece.PLAINS else Color(0.93, 0.85, 0.55)


func _init() -> void:
	block_mesh.size = Vector3(1.0, BLOCK_H, 1.0)


func _ready() -> void:
	_build_frame()


## 바닥 바다, 격자선, 진한 테두리를 현재 bounds에 맞춰 다시 만든다
func _build_frame() -> void:
	for n in _frame_nodes:
		n.queue_free()
	_frame_nodes.clear()
	_add_plane(bounds, 0.01, Color(0.2, 0.48, 0.82))
	var o: Vector3 = cell_to_world(bounds.position) - Vector3(0.5, 0.0, 0.5) # 필드 왼쪽 위 모서리
	var grid_mesh: PlaneMesh = PlaneMesh.new()
	grid_mesh.size = Vector2(bounds.size)
	var grid_mat: ShaderMaterial = ShaderMaterial.new()
	grid_mat.shader = GRID_SHADER
	grid_mat.set_shader_parameter("origin", Vector2(o.x, o.z))
	grid_mat.render_priority = -1 # 다른 반투명 물체(미리보기·영역선)보다 먼저 그린다
	var grid: MeshInstance3D = MeshInstance3D.new()
	grid.mesh = grid_mesh
	grid.material_override = grid_mat
	grid.position = center_world() + Vector3(0.0, 0.02, 0.0)
	add_child(grid)
	_frame_nodes.append(grid)
	# 맵 경계의 진한 테두리, 바깥쪽 바닥에 붙인다
	var t: float = 0.16
	var sx: float = bounds.size.x
	var sy: float = bounds.size.y
	for r in [Rect2(-t, -t, sx + 2.0 * t, t), Rect2(-t, sy, sx + 2.0 * t, t), Rect2(-t, 0, t, sy), Rect2(sx, 0, t, sy)]:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(r.size.x, 0.04, r.size.y)
		var edge: MeshInstance3D = MeshInstance3D.new()
		edge.mesh = bm
		edge.material_override = _mat(Color(0.02, 0.03, 0.08), true)
		edge.position = o + Vector3(r.position.x + r.size.x / 2.0, 0.03, r.position.y + r.size.y / 2.0)
		add_child(edge)
		_frame_nodes.append(edge)


func _add_plane(rect: Rect2i, y: float, c: Color) -> void:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(rect.size)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = pm
	mi.position = cell_to_world(rect.position) - Vector3(0.5, 0.0, 0.5) + Vector3(rect.size.x / 2.0, y, rect.size.y / 2.0)
	mi.material_override = _mat(c, false)
	add_child(mi)
	_frame_nodes.append(mi)


func _mat(c: Color, unshaded: bool) -> Material:
	var key: String = "%s%s" % [c, unshaded]
	if not _mats.has(key):
		if unshaded:
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.albedo_color = c
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_mats[key] = m
		else:
			_mats[key] = Toon.material(c) # 3단계 빛 (기획서 7.2)
	return _mats[key]


## 월드 좌표는 맵 중심이 원점이다
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5 - W / 2.0, 0.0, c.y + 0.5 - H / 2.0)


func world_to_cell(v: Vector3) -> Vector2i:
	return Vector2i(floori(v.x + W / 2.0), floori(v.z + H / 2.0))


## 맵의 중심
func center_world() -> Vector3:
	return cell_to_world(bounds.position) - Vector3(0.5, 0.0, 0.5) + Vector3(bounds.size.x / 2.0, 0.0, bounds.size.y / 2.0)


func in_bounds(c: Vector2i) -> bool:
	return bounds.has_point(c)


## 칸의 지형. 맵 밖은 바다
func terrain_at(c: Vector2i) -> int:
	return cells.get(c, SEA)


## 본부 영역 안인지. 건설과 생산은 영역 안에서만 된다 (기획서 5.3)
func in_territory(c: Vector2i) -> bool:
	return not territory_enabled or territory.has(c)


## 이 칸을 차지한 본부, 없으면 (-999, -999). 영역은 겹치지 않는다 (기획서 5.3)
func owner_of(c: Vector2i) -> Vector2i:
	for h in territory_of:
		if territory_of[h].has(c):
			return h
	return Vector2i(-999, -999)


## 새 본부의 시작 영역: 본부 칸 주변 3x3 중 아직 아무도 차지하지 않은 필드 안 칸. 레벨은 살아 있는 본부 최고 레벨의 절반(최소 1)에서 시작하고
## 그 레벨만큼 영역을 더 받는다 (기획서 5.3)
func claim_start(hq_cell: Vector2i) -> void:
	var best: int = 1
	for h in hq_level:
		best = maxi(best, hq_level[h])
	var lvl: int = maxi(1, best / 2)
	var set: Dictionary = {}
	var r: int = Balance.TERRITORY_START_RADIUS
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = hq_cell + Vector2i(dx, dy)
			if bounds.has_point(c) and owner_of(c).x == -999:
				set[c] = true
	set[hq_cell] = true # 본부 칸 자체는 항상 자기 영역이다(다른 본부 영역 안이면 가져온다)
	for h in territory_of:
		territory_of[h].erase(hq_cell)
	territory_of[hq_cell] = set
	hq_level[hq_cell] = lvl
	hq_food[hq_cell] = Balance.hq_level_food(lvl - 1) if lvl > 1 else 0
	grow_territory(hq_cell, lvl - 1)
	_rebuild_territory()


## 영역에 칸을 n개 더한다: 정사각형 우선 확률로 외곽 사각형을 채우고, 아니면 붙은 칸 중 무작위. 남의 영역 칸은 못 가져온다 (기획서 5.3)
func grow_territory(hq_cell: Vector2i, n: int, square_chance: float = Balance.TERRITORY_SQUARE_CHANCE) -> void:
	if not territory_of.has(hq_cell):
		return
	var set: Dictionary = territory_of[hq_cell]
	for _i in n:
		var pick: Vector2i = _square_pick(hq_cell, set) if _terr_rng.randf() < square_chance else Vector2i(-999, -999)
		if pick.x == -999:
			var cand: Array[Vector2i] = _adjacent_free(hq_cell, set)
			if cand.is_empty():
				break
			pick = cand[_terr_rng.randi() % cand.size()]
		set[pick] = true
	_rebuild_territory()


## 영역과 4방향으로 붙은, 필드 안의 아직 아무도 차지하지 않은 칸
func _adjacent_free(hq_cell: Vector2i, set: Dictionary) -> Array[Vector2i]:
	var cand: Array[Vector2i] = []
	for c in set:
		for d in DIRS:
			var q: Vector2i = c + d
			if bounds.has_point(q) and not set.has(q) and not cand.has(q) and owner_of(q).x == -999:
				cand.append(q)
	return cand


## 정사각형 우선: 외곽 사각형 안의 빈 칸 → 없으면 짧은 변(같으면 무작위)을 한 줄 늘린 칸. 고를 칸이 없으면 (-999, -999)
func _square_pick(hq_cell: Vector2i, set: Dictionary) -> Vector2i:
	var free: Array[Vector2i] = _adjacent_free(hq_cell, set)
	var lo: Vector2i = Vector2i(99999, 99999)
	var hi: Vector2i = Vector2i(-99999, -99999)
	for c in set:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var inside: Array[Vector2i] = []
	for q in free:
		if q.x >= lo.x and q.x <= hi.x and q.y >= lo.y and q.y <= hi.y:
			inside.append(q)
	if not inside.is_empty():
		return inside[_terr_rng.randi() % inside.size()]
	var w: int = hi.x - lo.x + 1
	var h: int = hi.y - lo.y + 1
	var widen: bool = w < h or (w == h and _terr_rng.randi() % 2 == 0)
	var sides: Array[Vector2i] = []
	sides.assign([Vector2i(-1, 0), Vector2i(1, 0)] if widen else [Vector2i(0, -1), Vector2i(0, 1)])
	if _terr_rng.randi() % 2 == 0:
		sides.reverse()
	for sd in sides:
		var line: Array[Vector2i] = []
		for q in free:
			var on_side: bool = (q.x == lo.x - 1 if sd.x < 0 else q.x == hi.x + 1) if widen else (q.y == lo.y - 1 if sd.y < 0 else q.y == hi.y + 1)
			if on_side and (q.y >= lo.y and q.y <= hi.y if widen else q.x >= lo.x and q.x <= hi.x):
				line.append(q)
		if not line.is_empty():
			return line[_terr_rng.randi() % line.size()]
	return Vector2i(-999, -999)


## 웨이브 정산: 본부마다 자기 영역의 식량을 누적에 더하고, 기준을 넘으면 그 본부의 레벨과 영역이 오른다. 본부 → 오른 레벨 수 (기획서 5.3)
func settle_levels(techs: Dictionary) -> Dictionary:
	var ups: Dictionary = {}
	for h in hqs:
		hq_food[h] = int(hq_food.get(h, 0)) + income(techs, h).y
		var up: int = 0
		while hq_food[h] >= Balance.hq_level_food(hq_level[h]):
			hq_level[h] += 1
			up += 1
		if up > 0:
			grow_territory(h, up)
			ups[h] = up
	return ups


## 본부의 다음 레벨까지 필요한 식량 누적 (최고 레벨은 없다)
func next_level_food(h: Vector2i) -> int:
	var lv: int = hq_level.get(h, 1)
	return Balance.hq_level_food(lv)


## 본부 옆에 레벨업까지 남은 식량 바를 둔다: 현재 레벨 기준에서 다음 기준까지의 진행도와 "남은 식량" (기획서 5.3)
func refresh_hq_bars(show: bool = true) -> void:
	for c in _hq_bars.keys():
		if not hqs.has(c):
			for n: Node in _hq_bars[c]:
				n.queue_free()
			_hq_bars.erase(c)
	for c in hqs:
		if not hq_level.has(c):
			continue
		if not _hq_bars.has(c):
			var label: Label3D = Label3D.new()
			label.font_size = 64
			label.pixel_size = 0.0033
			label.outline_size = 14
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED # 카메라가 기울어도 바는 항상 화면을 향한다
			label.no_depth_test = true
			label.render_priority = 14
			label.layers = PixelView.LABEL_LAYER # 글자는 원래 해상도 화면에 그린다 (기획서 7.2)
			add_child(label)
			_hq_bars[c] = [_bar_quad(Color(0.05, 0.05, 0.07), BAR_W + 0.04, BAR_H + 0.04, 10), _bar_quad(Color(0.28, 0.28, 0.32), BAR_W, BAR_H, 11), _bar_quad(Color(0.35, 0.9, 0.35), BAR_W, BAR_H, 12), label]
		var lv: int = hq_level[c]
		var nxt: int = next_level_food(c)
		var prev: int = Balance.hq_level_food(lv - 1) if lv > 1 else 0
		var ratio: float = clampf(float(int(hq_food.get(c, 0)) - prev) / float(nxt - prev), 0.0, 1.0)
		var text: String = "Lv%d · 남은 %d" % [lv, nxt - int(hq_food.get(c, 0))]
		var base: Vector3 = cell_to_world(c) + Vector3(0.0, BLOCK_H + 0.9, -0.5) # 본부 칸과 위 칸의 경계 (기획서 5.3)
		var bars: Array = _hq_bars[c]
		(bars[0] as MeshInstance3D).position = base
		(bars[1] as MeshInstance3D).position = base
		# 채움은 메시 안에서 왼쪽 정렬한다: 위치를 월드 X로 밀면 카메라가 돌았을 때 바 밖으로 비껴 나간다
		var fill: QuadMesh = (bars[2] as MeshInstance3D).mesh
		fill.size.x = maxf(BAR_W * ratio, 0.001)
		fill.center_offset.x = -BAR_W * 0.5 * (1.0 - ratio)
		(bars[2] as MeshInstance3D).position = base
		(bars[3] as Label3D).text = text
		# 글자가 바보다 넓으면 줄여서 바 안에 맞춘다 (숫자가 세 자리를 넘으면 넘쳤다)
		var text_w: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		(bars[3] as Label3D).pixel_size = minf(0.0033, (BAR_W - 0.06) / text_w)
		(bars[3] as Label3D).position = base
		for n: Node3D in bars:
			n.visible = show # 전투 중에는 숨긴다 (기획서 5.3)


## 카메라를 향하는 평면 사각형 (본부 바용)
func _bar_quad(color: Color, w: float, h: float, priority: int) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = priority
	mi.material_override = m
	mi.layers = PixelView.LABEL_LAYER # 글자와 같은 원래 해상도 화면에 그려 도트·외곽선에 깨지지 않게 한다 (기획서 7.2)
	add_child(mi)
	return mi


## 합집합을 다시 만들고, 바깥 경계선만 그린다: 영역이 겹치면 경계가 이어진다 (문명5 방식) (기획서 5.3)
func _rebuild_territory() -> void:
	territory.clear()
	for h in territory_of:
		for c in territory_of[h]:
			territory[c] = true
	for n in _terr_nodes:
		n.queue_free()
	_terr_nodes.clear()
	var t: float = 0.1
	for c in territory:
		for d in DIRS:
			if territory.has(c + d):
				continue
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(1.0 + t if d.y != 0 else t, 0.04, 1.0 + t if d.x != 0 else t)
			var e: MeshInstance3D = MeshInstance3D.new()
			e.mesh = bm
			e.material_override = _mat(Color(0.98, 0.8, 0.2), true)
			e.position = cell_to_world(c) + Vector3(d.x * 0.5, BLOCK_H + 0.03, d.y * 0.5)
			add_child(e)
			_terr_nodes.append(e)


func is_land(c: Vector2i) -> bool:
	return cells.has(c)


## 걸을 수 있는 땅: 산은 땅이지만 지나갈 수 없다 (기획서 3장)
func is_walkable(c: Vector2i) -> bool:
	return cells.has(c) and cells[c] != Piece.MOUNTAIN


## 위치(월드 좌표) 땅의 이동속도 배율: 숲은 느리다 (기획서 3장)
## crossing: 바다를 걸어 건너는 해적이면 바다 칸에서 느리다 (기획서 6장)
func speed_mult_at(pos: Vector3, crossing: bool = false) -> float:
	var c: Vector2i = world_to_cell(pos)
	if crossing and terrain_at(c) == SEA:
		return Balance.SEA_CROSS_SPEED
	return Balance.FOREST_SPEED if cells.get(c, -1) == Piece.FOREST else 1.0


## 판마다 시드로 군도를 만든다: 노이즈 상위 칸을 땅으로 삼고, 작은 섬은 지우고, 해안은 모래, 안쪽에 숲·산을 섞는다.
## 첫 도시를 세울 섬이 없으면 시드를 바꿔 다시 만든다 (기획서 3장, 9.1)
func generate_map(seed_v: int) -> void:
	for attempt in 20:
		_generate_once(seed_v + attempt)
		if not start_cells().is_empty():
			break
	_draw_land()


func _generate_once(seed_v: int) -> void:
	cells.clear()
	_ver += 1
	var inner: Rect2i = bounds.grow(-Balance.MAP_EDGE_SEA)
	for c in _top_share(_noise_values(seed_v, inner, true), Balance.MAP_LAND_RATIO):
		cells[c] = Piece.PLAINS
	for island: Array in _components(func(c: Vector2i) -> bool: return cells.has(c)):
		if island.size() < Balance.MAP_MIN_ISLAND:
			for c: Vector2i in island:
				cells.erase(c)
	var rough: Dictionary = {} # 해안이 아닌 땅 → 노이즈 값
	var rv: Dictionary = _noise_values(seed_v * 7 + 13, inner, false)
	for c: Vector2i in cells.keys():
		if sea_neighbor(c).x != -999:
			cells[c] = Piece.SAND # 바다와 닿은 땅은 모래
		else:
			rough[c] = rv[c]
	var inland: int = rough.size()
	for c in _top_share(rough, Balance.MAP_MOUNTAIN_RATIO):
		cells[c] = Piece.MOUNTAIN
		rough.erase(c)
	var fv: Dictionary = _noise_values(seed_v * 31 + 5, inner, false)
	for c in rough:
		rough[c] = fv[c]
	for c in _top_share(rough, Balance.MAP_FOREST_RATIO * inland / maxf(rough.size(), 1.0)):
		cells[c] = Piece.FOREST
	_ver += 1


## rect 안 칸마다 노이즈 값. falloff면 가장자리로 갈수록 낮춰 땅이 맵 끝에 붙지 않게 한다
func _noise_values(seed_v: int, rect: Rect2i, falloff: bool) -> Dictionary:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = Balance.MAP_NOISE_FREQ
	var out: Dictionary = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var v: float = noise.get_noise_2d(x, y)
			if falloff:
				var edge: int = mini(mini(x - rect.position.x, rect.end.x - 1 - x), mini(y - rect.position.y, rect.end.y - 1 - y))
				v -= 0.5 * maxf(0.0, 1.0 - edge / 10.0)
			out[Vector2i(x, y)] = v
	return out


## 값이 큰 쪽부터 share 비율만큼의 칸
func _top_share(vals: Dictionary, share: float) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	keys.assign(vals.keys())
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return vals[a] > vals[b])
	return keys.slice(0, roundi(keys.size() * clampf(share, 0.0, 1.0)))


## 땅 칸 중 inside를 만족하는 칸을 4방향으로 이은 덩어리들
func _components(inside: Callable) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for s: Vector2i in cells.keys():
		if seen.has(s) or not inside.call(s):
			continue
		var comp: Array[Vector2i] = [s]
		seen[s] = true
		var i: int = 0
		while i < comp.size():
			for d in DIRS:
				var n: Vector2i = comp[i] + d
				if not seen.has(n) and inside.call(n):
					seen[n] = true
					comp.append(n)
			i += 1
		out.append(comp)
	return out


## 첫 도시를 세울 수 있는 칸: 평원이 START_ISLAND_PLAINS 이상인 섬의 평원 칸 (기획서 2장, 9.1)
func start_cells() -> Dictionary:
	if _start_ver != _ver:
		_start_ver = _ver
		_start_ok.clear()
		for island: Array in _components(is_walkable):
			var plains: Array[Vector2i] = []
			for c: Vector2i in island:
				if cells[c] == Piece.PLAINS:
					plains.append(c)
			if plains.size() >= Balance.START_ISLAND_PLAINS:
				for c in plains:
					_start_ok[c] = true
	return _start_ok


## 시작 개척자가 나올 칸: 시작 섬(평원 START_ISLAND_PLAINS칸 이상)의 평원 중 맵 중심에 가장 가까운 칸 (기획서 2장)
func settler_start() -> Vector2i:
	var mid: Vector2 = Vector2(bounds.get_center())
	var best: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in start_cells():
		if best.x < 0 or Vector2(c).distance_squared_to(mid) < Vector2(best).distance_squared_to(mid):
			best = c
	return best


## 첫 도시 자리로 고를 수 있는지
func can_start(c: Vector2i) -> bool:
	return hqs.is_empty() and start_cells().has(c)


## 개척자가 c에 도시를 세울 수 있는지. 안 되면 이유, 되면 "" (기획서 4장)
func found_block(c: Vector2i) -> String:
	if not [Piece.PLAINS, Piece.SAND].has(cells.get(c, -1)):
		return "평원·모래 칸에만 세울 수 있습니다"
	if buildings.has(c) or hqs.has(c):
		return "건물이 있는 칸에는 세울 수 없습니다"
	for h in hqs:
		if maxi(absi(h.x - c.x), absi(h.y - c.y)) < Balance.CITY_MIN_DIST:
			return "다른 도시와 %d칸 이상 떨어져야 합니다" % Balance.CITY_MIN_DIST
	return ""


## c에 도시를 세운다: 영역을 받고 성 모델을 놓는다 (기획서 2장, 5.3)
func found_city(c: Vector2i) -> void:
	hqs[c] = Balance.HQ_HP
	claim_start(c)
	var marker: MeshInstance3D = MeshInstance3D.new()
	variants[c] = 1 + randi() % Balance.HQ_MODEL_VARIANTS
	add_child(marker)
	_nodes[c] = [marker]
	_tint(c)


## 땅 블록을 지형 종류마다 MultiMesh 하나로 그린다 (칸이 수천 개라 노드를 따로 두지 않는다)
func _draw_land() -> void:
	for n in _land_nodes:
		n.queue_free()
	_land_nodes.clear()
	var by_kind: Dictionary = {}
	for c in cells:
		if not by_kind.has(cells[c]):
			by_kind[cells[c]] = []
		by_kind[cells[c]].append(c)
	# 블록 위에 윗면 판을 살짝 띄워 한 겹 더 덮는다: 칸 경계에 걸린 도트에서 옆면 윗변이 윗면과 깊이가 같아 어두운 점으로 이기는 것을 막는다 (기획서 7.2)
	var top: PlaneMesh = PlaneMesh.new()
	top.size = Vector2(1.0, 1.0)
	for kind in by_kind:
		for part: Array in [[block_mesh, BLOCK_H / 2.0], [top, BLOCK_H + 0.002]]:
			var mm: MultiMesh = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = by_kind[kind].size()
			for i in mm.instance_count:
				mm.set_instance_transform(i, Transform3D(Basis(), cell_to_world(by_kind[kind][i]) + Vector3(0, part[1], 0)))
			var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _mat(color_of(kind), false)
			add_child(mmi)
			_land_nodes.append(mmi)


## "본부 2/3 · 체력 300·120 · 영구 손실 1" (기획서 5.5)
func hq_status() -> String:
	var hps: Array[String] = []
	for c in hqs:
		hps.append(str(ceili(hqs[c])))
	var s: String = "도시 %d/%d · 체력 %s" % [hqs.size(), hqs.size() + hq_lost, "·".join(hps) if not hps.is_empty() else "-"]
	if hq_lost > 0:
		s += " · 영구 손실 %d" % hq_lost
	return s


## 건물 위치 → 건물 종류 (본부는 hq에 따로 기록)
var buildings: Dictionary = {}
var variants: Dictionary = {} ## 모델 건물 위치 → 모델 바리에이션 번호(1부터) (기획서 7.2)
var hp: Dictionary = {} ## 건물 위치 → 체력
var levels: Dictionary = {} ## 건물 위치 → 레벨 (1~3)
var _nodes: Dictionary = {} ## 건물·본부 위치 → 화면 노드들 (첫 번째가 본체)


func _next_to_land(c: Vector2i) -> bool:
	for d in DIRS:
		if cells.has(c + d):
			return true
	return false


func _next_to_sea(c: Vector2i) -> bool:
	return sea_neighbor(c).x != -999


## 땅이고 비어 있으며, 지형·인접 바다 조건을 만족해야 한다 (기획서 3장, 5장)
func can_build(id: int, c: Vector2i) -> bool:
	var data: Dictionary = Balance.BUILDINGS[id]
	if not in_territory(c): # 건설은 본부 영역 안에서만 (기획서 5.3)
		return false
	if data.get("on_water", false): # 낚시터·교역소: 물 위, 땅과 닿은 칸 (교역소는 열린 바다, 1개만) (기획서 5.1, 5.6)
		if not (bounds.has_point(c) and not cells.has(c) and not buildings.has(c) and _next_to_land(c)):
			return false
		if data.get("unique", false) and buildings.values().has(id):
			return false
		return not data.get("open_sea", false) or is_open_sea(c)
	if not cells.has(c) or hqs.has(c) or buildings.has(c) or ruins.has(c): # 유적지 칸에는 짓지 못한다 (기획서 3장)
		return false
	if cells[c] == Piece.SAND and not data["sand"]:
		return false
	if cells[c] == Piece.FOREST and not Balance.FOREST_BUILDINGS.has(id):
		return false
	if cells[c] == Piece.MOUNTAIN and not Balance.MOUNTAIN_BUILDINGS.has(id):
		return false
	if data.get("mountain_only", false) and cells[c] != Piece.MOUNTAIN: # 광산은 산 칸 전용 (기획서 5.1)
		return false
	if data.get("unique", false) and buildings.values().has(id): # 교역소는 1개만 (기획서 5.6)
		return false
	if data.get("open_sea", false) and not _next_to_open_sea(c):
		return false
	return not data["sea"] or _next_to_sea(c)


## 맵 가장자리 바다와 이어진 바다(섬 안에 갇힌 호수 제외)인지 (기획서 5.1)
func is_open_sea(c: Vector2i) -> bool:
	if _open_ver != _ver:
		_open_ver = _ver
		_open.clear()
		var ext: Rect2i = bounds
		var stack: Array[Vector2i] = []
		for y in range(ext.position.y, ext.end.y):
			for x in range(ext.position.x, ext.end.x):
				var e: Vector2i = Vector2i(x, y)
				var on_edge: bool = x == ext.position.x or y == ext.position.y or x == ext.end.x - 1 or y == ext.end.y - 1
				if on_edge and terrain_at(e) == SEA:
					_open[e] = true
					stack.append(e)
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in DIRS:
				var n: Vector2i = cur + d
				if ext.has_point(n) and terrain_at(n) == SEA and not _open.has(n):
					_open[n] = true
					stack.append(n)
	return _open.has(c)


## 교역소처럼 열린 바다와 맞닿아야 하는 건물이 지금도 맞닿아 있는지 (기획서 5.6)
func is_post_open(c: Vector2i) -> bool:
	return _post_open(c)


## 물 위 교역소는 자기 칸이, 땅 위라면 이웃 바다가 열린 바다인지
func _post_open(c: Vector2i) -> bool:
	return is_open_sea(c) if not cells.has(c) else _next_to_open_sea(c)


func _next_to_open_sea(c: Vector2i) -> bool:
	for d in DIRS:
		if terrain_at(c + d) == SEA and is_open_sea(c + d):
			return true
	return false


## 낚시터와 물길로 이어진 바다 칸 수 (최대 FISH_CAP까지만 센다) (기획서 5.1)
func fishing_cells(c: Vector2i) -> int:
	var seen: Dictionary = {}
	var q: Array[Vector2i] = []
	for d in DIRS:
		if terrain_at(c + d) == SEA:
			seen[c + d] = true
			q.append(c + d)
	var i: int = 0
	while i < q.size() and seen.size() < Balance.FISH_CAP:
		var cur: Vector2i = q[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = cur + d
			if terrain_at(n) == SEA and not seen.has(n):
				seen[n] = true
				q.append(n)
	return mini(seen.size(), Balance.FISH_CAP)


func fishing_food(c: Vector2i) -> int:
	return floori(Balance.fishing_food(fishing_cells(c), levels.get(c, 1), buildings.get(c, Balance.FISHERY)) * performance(c))


## 교역소 위치, 없으면 (-1, -1)
func trading_post() -> Vector2i:
	for c in buildings:
		if buildings[c] == Balance.TRADING_POST:
			return c
	return Vector2i(-1, -1)


func max_hp(c: Vector2i) -> float:
	return float(Balance.BUILDINGS[buildings[c]]["hp"]) * Balance.HP_MULT[levels[c] - 1]


func can_upgrade(c: Vector2i) -> bool:
	return buildings.has(c) and levels[c] < Balance.MAX_LEVEL


## 건물 레벨을 한 단계 올린다. 체력도 새 최대치로 채운다 (기획서 5.2)
func upgrade(c: Vector2i) -> void:
	levels[c] += 1
	hp[c] = max_hp(c)
	(_nodes[c][1] as Label3D).text = _label_text(c)
	_tint(c)


## 레벨 3 건물을 진화 건물 to로 바꾼다: 새 건물 레벨 1에서 시작한다 (기획서 5.2.1)
func evolve(c: Vector2i, to: int) -> void:
	variants.erase(c)
	for n: Node in _nodes[c]:
		n.queue_free()
	_nodes.erase(c)
	build(to, c, 1)


func _label_text(c: Vector2i) -> String:
	if Balance.BUILDINGS[buildings[c]].has("model"):
		return "" # 모델 건물은 글자가 모델을 가려서 비운다 (기획서 7.2)
	var name: String = Balance.BUILDINGS[buildings[c]]["name"]
	return name.left(1) + (str(levels[c]) if levels[c] > 1 else "")


func build(id: int, c: Vector2i, level: int = 1, variant: int = 0) -> void:
	buildings[c] = id
	levels[c] = level
	var data: Dictionary = Balance.BUILDINGS[id]
	hp[c] = max_hp(c)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var base_y: float = _base_y(c)
	if data.has("model"): # 블렌더 모델: 지을 때 바리에이션을 무작위로 고르고 레벨이 올라도 같은 번호를 쓴다 (기획서 7.2)
		variants[c] = variant if variant > 0 else 1 + randi() % int(data["model_variants"])
	else:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.72, 0.62, 0.72) if Balance.is_evolved(id) else Vector3(0.6, 0.5, 0.6) # 진화 건물은 더 크게 (기획서 5.2.1)
		mi.mesh = bm
		mi.material_override = Toon.material(Color.WHITE)
		mi.position = cell_to_world(c) + Vector3(0, base_y + 0.25, 0)
	add_child(mi)
	var label: Label3D = Label3D.new()
	label.text = _label_text(c)
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 16
	label.layers = PixelView.LABEL_LAYER
	label.rotation_degrees = Vector3(-90, 0, 0)
	add_child(label)
	_nodes[c] = [mi, label]
	if not variants.has(c):
		label.position = cell_to_world(c) + Vector3(0, base_y + 0.52, 0)
	_tint(c)


## 건물이 놓이는 바닥 높이: 땅 또는 바다
func _base_y(c: Vector2i) -> float:
	return BLOCK_H if cells.has(c) else 0.0


## 모델 건물·본부의 모델을 레벨·바리에이션·파손 단계에 맞게 바꾼다 (기획서 7.2)
func _set_model(c: Vector2i) -> void:
	var kind: String = Balance.HQ_MODEL
	var level: int = 0 # 본부 모델은 레벨 구분이 없다
	if not hqs.has(c):
		kind = Balance.BUILDINGS[buildings[c]]["model"]
		level = mini(levels[c], Balance.MAX_LEVEL)
	var md: Dictionary = Toon.model(Balance.model_path(kind, level, variants[c], Balance.damage_stage(hp_ratio(c))))
	var mi: MeshInstance3D = _nodes[c][0]
	if mi.mesh == md["mesh"]:
		return
	mi.mesh = md["mesh"]
	mi.material_override = Toon.material(Color.WHITE, md["tex"])
	mi.position = cell_to_world(c) + Vector3(0, _base_y(c), 0)


## 피해를 보여 준다: 모델 건물·본부는 파손 모델, 상자 건물은 체력만큼 어둡게 (기획서 5.2.2)
func _tint(c: Vector2i) -> void:
	if variants.has(c):
		_set_model(c)
		return
	var base: Color = Balance.BUILDINGS[buildings[c]]["color"]
	var mi: MeshInstance3D = _nodes[c][0]
	Toon.set_color(mi.material_override, base.lerp(Color.BLACK, (1.0 - hp_ratio(c)) * 0.7))


## 남은 체력 비율(0~1). 건물·본부가 없으면 1
func hp_ratio(c: Vector2i) -> float:
	if hqs.has(c):
		return hqs[c] / Balance.HQ_HP
	return hp[c] / max_hp(c) if hp.has(c) else 1.0


## 파손 단계에 따른 건물 성능 배율 (본부에는 쓰지 않는다) (기획서 5.2.2)
func performance(c: Vector2i) -> float:
	return Balance.DMG_PERF[Balance.damage_stage(hp_ratio(c))]


## c의 건물·본부를 가득 고치는 값, 멀쩡하면 0 (기획서 5.2.2)
func repair_cost(c: Vector2i) -> int:
	if hp_ratio(c) >= 1.0:
		return 0
	if hqs.has(c):
		return Balance.repair_price(Balance.HQ_REPAIR_COST, hp_ratio(c))
	return Balance.repair_price(Balance.invested(buildings[c], levels[c]) * Balance.REPAIR_RATE, hp_ratio(c))


func total_repair_cost() -> int:
	var total: int = 0
	for c in targets():
		total += repair_cost(c)
	return total


## c의 건물·본부 체력을 가득 채운다. 골드는 부르는 쪽이 낸다
func repair(c: Vector2i) -> void:
	if hqs.has(c):
		hqs[c] = Balance.HQ_HP
	elif buildings.has(c):
		hp[c] = max_hp(c)
	else:
		return
	_tint(c)


## 적이 노리는 칸: 건물과 살아 있는 본부
func targets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in buildings:
		out.append(c)
	for c in hqs:
		out.append(c)
	return out


## 피해를 준다. 본부가 이 피해로 파괴되면 true (본부는 복구되지 않고 영구히 사라진다) (기획서 5.5)
func damage(c: Vector2i, amount: float) -> bool:
	if hqs.has(c):
		hqs[c] -= amount
		if hqs[c] <= 0.0:
			hqs.erase(c)
			hq_lost += 1
			hq_level.erase(c)
			hq_food.erase(c)
			territory_of.erase(c) # 본부가 무너지면 그 영역도 사라진다 (기획서 5.3)
			_rebuild_territory()
			for n: Node in _nodes[c]:
				n.queue_free()
			_nodes.erase(c)
			variants.erase(c)
			return true
		_tint(c)
	elif buildings.has(c):
		hp[c] -= amount
		if hp[c] <= 0.0: # 파괴되면 빈 땅이 되고 복구되지 않는다. 다시 지어야 한다 (기획서 5.2)
			for n: Node in _nodes[c]:
				n.queue_free()
			_nodes.erase(c)
			buildings_lost[buildings[c]] = int(buildings_lost.get(buildings[c], 0)) + 1
			buildings.erase(c)
			variants.erase(c)
			hp.erase(c)
			levels.erase(c)
		else:
			_tint(c)
	return false


## c의 건물·도시 체력을 최대치의 frac만큼 채운다. 가득 차면 true (수리는 5초에 걸쳐 찬다) (기획서 5.2.2)
func heal(c: Vector2i, frac: float) -> bool:
	if hqs.has(c):
		hqs[c] = minf(Balance.HQ_HP, hqs[c] + Balance.HQ_HP * frac)
	elif buildings.has(c):
		hp[c] = minf(max_hp(c), hp[c] + max_hp(c) * frac)
	else:
		return true
	_tint(c)
	return hp_ratio(c) >= 1.0


## 살아남은 건물·본부를 모두 고친다(전체 수리). 파괴된 건물·본부는 돌아오지 않는다 (기획서 5.2.2)
func repair_all() -> void:
	for c in targets():
		repair(c)


func land_count() -> int:
	return cells.size()


## c의 4방향 이웃 중 바다인 칸, 없으면 (-999, -999)
func sea_neighbor(c: Vector2i) -> Vector2i:
	for d in DIRS:
		if terrain_at(c + d) == SEA and not buildings.has(c + d): # 수상 건물(낚시터)이 있는 칸은 뱃길로 안 친다
			return c + d
	return Vector2i(-999, -999)


## 맵 가장자리 바다에서 땅(산 제외)의 해안까지 바닷길이 하나도 없으면 true — 해적이 바다를 걸어 건넌다 (기획서 6장)
## 지형이 바뀔 때만 다시 센다 (화면 갱신마다 부른다)
func sea_blocked() -> bool:
	if _blocked_ver != _ver:
		_blocked_ver = _ver
		_blocked = _sea_blocked_now()
	return _blocked


func _sea_blocked_now() -> bool:
	var ext: Rect2i = bounds
	var seen: Dictionary = {}
	var q: Array[Vector2i] = []
	for y in range(ext.position.y, ext.end.y):
		for x in range(ext.position.x, ext.end.x):
			var c: Vector2i = Vector2i(x, y)
			if (x == ext.position.x or y == ext.position.y or x == ext.end.x - 1 or y == ext.end.y - 1) and terrain_at(c) == SEA:
				seen[c] = true
				q.append(c)
	var i: int = 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if not ext.has_point(n) or seen.has(n):
				continue
			if terrain_at(n) == SEA:
				seen[n] = true
				q.append(n)
			elif cells.has(n) and cells[n] != Piece.MOUNTAIN:
				return false
	return true


## 같은 섬(4방향으로 이어진 땅)마다 번호를 붙인다. 땅 칸 -> 섬 번호
func island_map() -> Dictionary:
	var m: Dictionary = {}
	var id: int = 0
	for s in cells:
		if m.has(s) or not is_walkable(s):
			continue
		var stack: Array[Vector2i] = [s]
		m[s] = id
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for d in DIRS:
				if is_walkable(c + d) and not m.has(c + d):
					m[c + d] = id
					stack.append(c + d)
		id += 1
	return m


## 길찾기 격자: sea=true면 바다만, false면 땅만 지나갈 수 있다 (기획서 7.3)
func nav(sea: bool, enemy: bool = false) -> AStarGrid2D:
	var ext: Rect2i = bounds
	var a: AStarGrid2D = AStarGrid2D.new()
	a.region = Rect2i(0, 0, ext.size.x, ext.size.y)
	a.cell_size = Vector2.ONE
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	for y in ext.size.y:
		for x in ext.size.x:
			var c: Vector2i = ext.position + Vector2i(x, y)
			var walkable: bool = (terrain_at(c) == SEA and not buildings.has(c)) if sea else is_walkable(c)
			a.set_point_solid(Vector2i(x, y), not walkable)
	return a


## 바다를 건너는 해적용 길찾기 격자: 산 말고는 어디든 가고, 바다 칸은 느린 만큼 비용이 높아 땅길이 있으면 땅길을 쓴다 (기획서 6장)
func nav_cross() -> AStarGrid2D:
	var ext: Rect2i = bounds
	var a: AStarGrid2D = AStarGrid2D.new()
	a.region = Rect2i(0, 0, ext.size.x, ext.size.y)
	a.cell_size = Vector2.ONE
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	for y in ext.size.y:
		for x in ext.size.x:
			var c: Vector2i = ext.position + Vector2i(x, y)
			var t: int = terrain_at(c)
			a.set_point_solid(Vector2i(x, y), t == Piece.MOUNTAIN)
			if t == SEA:
				a.set_point_weight_scale(Vector2i(x, y), 1.0 / Balance.SEA_CROSS_SPEED)
	return a


## from -> to 칸 경로 (시작 칸 제외). 길이 없으면 빈 배열
func path(nav_grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var ext: Rect2i = bounds
	var off: Vector2i = -ext.position
	var region: Rect2i = Rect2i(0, 0, ext.size.x, ext.size.y)
	if not region.has_point(from + off) or not region.has_point(to + off):
		return out
	if nav_grid.is_point_solid(from + off) or nav_grid.is_point_solid(to + off):
		return out
	for p in nav_grid.get_id_path(from + off, to + off):
		out.append(p - off)
	if not out.is_empty() and out[0] == from:
		out.remove_at(0)
	return out


## 섬의 해안 중 near에 가장 가까운 칸: stop(배가 설 바다 칸), land(내릴 땅 칸). 없으면 빈 Dictionary
func coast_for(island_id: int, near: Vector3, islands: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for c in islands:
		if islands[c] != island_id:
			continue
		var n: Vector2i = sea_neighbor(c)
		if n.x == -999:
			continue
		var w: Vector3 = cell_to_world(c)
		var d: float = Vector2(w.x - near.x, w.z - near.z).length()
		if d < best_d:
			best_d = d
			best = {"stop": n, "land": c}
	return best


## 4방향으로 붙은 시장 중 가장 높은 레벨의 집 골드 보너스 (기획서 5.1)
func _market_bonus(c: Vector2i) -> float:
	var best: float = 0.0
	for d in DIRS:
		if buildings.get(c + d, 0) == Balance.MARKET:
			best = maxf(best, Balance.MARKET_HOUSE_BONUS_LV[levels[c + d] - 1] * performance(c + d))
	return best


## 웨이브 정산 때 얻는 연구수치: 본부 수 + 도서관·학술원·천문대 레벨 합 (기획서 5.4)
func research_income(techs: Dictionary = {}) -> int:
	var n: float = Balance.HQ_RESEARCH * hqs.size() # 본부마다 +1 (파손돼도 그대로)
	for c in buildings:
		if not in_territory(c):
			continue
		if buildings[c] == Balance.LIBRARY:
			n += (Balance.LIBRARY_RESEARCH_LV[levels[c] - 1] + Balance.science_bonus(techs)) * performance(c)
		elif buildings[c] == Balance.LAB:
			n += (Balance.LAB_RESEARCH_LV[levels[c] - 1] + Balance.science_bonus(techs)) * performance(c)
		elif buildings[c] == Balance.OBSERVATORY:
			n += Balance.OBSERVATORY_RESEARCH_LV[levels[c] - 1] * performance(c)
	return floori(n)


## 웨이브 정산 수입: x = 골드, y = 식량 (기획서 5장)
## owner가 있으면 그 본부 영역의 수입만 (기획서 5.3)
func income(techs: Dictionary = {}, owner: Vector2i = Vector2i(-999, -999)) -> Vector2i:
	var gold: float = 0.0
	var food: float = 0.0
	var house_mult: float = 1.2 if techs.has("math") else 1.0
	var farm_mult: float = 1.0 + (0.3 if techs.has("tools") else 0.0) + (0.5 if techs.has("windmill") else 0.0)
	for c in buildings:
		if not _counts(c, owner): # 영역 밖 건물은 생산하지 않는다 (기획서 5.3)
			continue
		if buildings[c] == Balance.HOUSE or buildings[c] == Balance.MANSION:
			gold += Balance.house_gold(levels[c], cells[c] == Piece.SAND, buildings[c]) * (house_mult + _market_bonus(c)) * performance(c)
		elif buildings[c] == Balance.MINE:
			gold += Balance.MINE_GOLD_LV[levels[c] - 1] * performance(c)
		elif buildings[c] == Balance.SMELTER:
			gold += Balance.SMELTER_GOLD_LV[levels[c] - 1] * performance(c)
		elif buildings[c] == Balance.FARM:
			food += Balance.FARM_FOOD_LV[levels[c] - 1] * farm_mult * performance(c)
		elif buildings[c] == Balance.FARMSTEAD:
			food += Balance.FARMSTEAD_FOOD_LV[levels[c] - 1] * farm_mult * performance(c)
		elif buildings[c] == Balance.FISHERY or buildings[c] == Balance.FISH_VILLAGE:
			food += fishing_food(c)
	var per_plain: float = Balance.FOOD_PER_PLAINS * (1.5 if techs.has("waterwheel") else 1.0)
	var plains: int = 0
	for c in cells:
		if cells[c] == Piece.PLAINS and _counts(c, owner):
			plains += 1
	food += plains * per_plain
	gold += Balance.HQ_BASE_GOLD * (hqs.size() if owner.x == -999 else 1) # 살아 있는 본부마다 기본 골드 (기획서 5.1)
	if techs.has("toolmaking"):
		food += Balance.TOOLMAKING_FOOD
	if techs.has("currency"):
		gold *= Balance.CURRENCY_GOLD_MULT
	return Vector2i(floori(gold), floori(food))


## 생산을 세는 칸인지: owner가 없으면 영역 안, 있으면 그 본부 영역 안
func _counts(c: Vector2i, owner: Vector2i) -> bool:
	if owner.x == -999:
		return in_territory(c)
	return territory_of.has(owner) and territory_of[owner].has(c)


## 땅 묶음을 깐다 (테스트가 작은 섬을 만들 때 쓴다). 바다 칸은 땅을 지운다. hq_index 칸에는 도시를 세운다
func place(p: Piece, origin: Vector2i) -> void:
	_ver += 1
	for i in p.cells.size():
		var cell: Vector2i = origin + p.cells[i]
		if p.terrain[i] == Piece.SEA:
			cells.erase(cell)
		else:
			cells[cell] = p.terrain[i]
	_ver += 1
	_draw_land()
	if p.hq_index >= 0:
		found_city(origin + p.cells[p.hq_index])


## ---- 안개 (기획서 3장) ----
var fog_on: bool = false ## 첫 도시를 세우면 켠다. 그 전에는 맵 전체가 보인다
var explored: Dictionary = {} ## 한 번 밝힌 칸 → true (계속 보인다)
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog_dirty: bool = false


## 맵 전체를 안개로 덮는다: 칸마다 한 도트인 텍스처를 맵 크기 판에 씌운다
func enable_fog() -> void:
	fog_on = true
	_fog_img = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8) # 한 칸 = 한 도트, 왼쪽 위가 bounds.position
	_fog_img.fill(Balance.FOG_COLOR)
	for c in explored:
		_fog_img.set_pixelv(c - bounds.position, Color(0, 0, 0, 0))
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # 불투명처럼 깊이를 써서 안개 아래 땅의 외곽선이 비치지 않게 한다
	m.albedo_texture = _fog_tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(bounds.size)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = center_world() + Vector3(0.0, BLOCK_H + 0.03, 0.0)
	add_child(mi)


func is_explored(c: Vector2i) -> bool:
	return not fog_on or explored.has(c)


## center에서 r칸 안을 밝힌다. 새로 밝힌 칸이 있으면 true
func reveal(center: Vector2i, r: float) -> bool:
	var changed: bool = false
	var n: int = ceili(r)
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			if dx * dx + dy * dy <= r * r:
				changed = _reveal_cell(center + Vector2i(dx, dy)) or changed
	return changed


func reveal_cells(set: Dictionary) -> void:
	for c in set:
		_reveal_cell(c)


func _reveal_cell(c: Vector2i) -> bool:
	if explored.has(c) or not bounds.has_point(c):
		return false
	explored[c] = true
	if _fog_img != null:
		_fog_img.set_pixelv(c - bounds.position, Color(0, 0, 0, 0))
		_fog_dirty = true
	if ruins.has(c):
		(ruins[c] as Node3D).visible = true
	return true


func _process(_delta: float) -> void:
	if _fog_dirty: # 한 프레임에 여러 번 밝혀도 텍스처는 한 번만 올린다
		_fog_dirty = false
		_fog_tex.update(_fog_img)


## ---- 유적지 (기획서 3장) ----
var ruins: Dictionary = {} ## 유적지 칸 → 표시 노드


## 평원 칸 RUIN_COUNT곳에 유적지를 둔다. avoid 칸(첫 도시 영역)은 뺀다
func place_ruins(rng: RandomNumberGenerator, avoid: Dictionary) -> void:
	var cands: Array[Vector2i] = []
	for c in cells:
		if cells[c] == Piece.PLAINS and not avoid.has(c) and not hqs.has(c) and not buildings.has(c):
			cands.append(c)
	for i in mini(Balance.RUIN_COUNT, cands.size()):
		var j: int = rng.randi_range(i, cands.size() - 1)
		var c: Vector2i = cands[j]
		cands[j] = cands[i]
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.36, 0.14, 0.36)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = _mat(Color(1.0, 0.9, 0.2), true) # 밝은 노란 표시, 빛 3단계 없이 (기획서 7.2)
		mi.position = cell_to_world(c) + Vector3(0.0, BLOCK_H + 0.07, 0.0)
		mi.visible = is_explored(c)
		add_child(mi)
		ruins[c] = mi


## 유적지를 가져간다. 있었으면 true
func take_ruin(c: Vector2i) -> bool:
	if not ruins.has(c):
		return false
	(ruins[c] as Node).queue_free()
	ruins.erase(c)
	return true

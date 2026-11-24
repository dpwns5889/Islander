class_name Field
extends Node3D
## 필드: 지형 격자와 블록 표시. 비어 있는 칸은 바다다. 처음 15x15, 확장으로 최대 40x30 (기획서 3장)

const W: int = 15 ## 처음 필드 크기
const H: int = 15
const MAX_W: int = 40
const MAX_H: int = 30
const SEA: int = 0
const BLOCK_H: float = 0.08 ## 땅 두께. 입체감 없이 평평한 땅 (기획서 3장)
const HQ_COLOR: Color = Color(0.85, 0.15, 0.15)
const M: int = 8 ## 필드 밖 자동 지형의 폭 (기획서 3장)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var bounds: Rect2i = Rect2i(0, 0, W, H) ## 배치할 수 있는 영역. 확장하면 커진다
var expansions: int = 0 ## 확장 횟수 전체 (적 강도에 반영)
var cells: Dictionary = {} ## 땅 칸 → 지형. 없는 칸은 바다
var _land_nodes: Dictionary = {} ## 땅 칸 위치 → 블록 노드 (바다 칸이 땅을 깎을 때 지우려고 기억한다)
var ruins: Dictionary = {} ## 아직 털지 않은 유적지 위치 → true (필드 밖 대륙) (기획서 3장)
var looted: Dictionary = {} ## 이미 턴 유적지
var water: Dictionary = {} ## 바다 칸이 섞인 타일로 차지된 물 타일 위치 (땅은 아니지만 조각을 놓을 수 없다) (기획서 4장)
var hqs: Dictionary = {} ## 살아 있는 본부 위치 → 체력 (여러 개일 수 있다) (기획서 5.5)
var territory_of: Dictionary = {} ## 본부 위치 → 그 본부 영역 칸 집합 (기획서 5.3)
var territory: Dictionary = {} ## 모든 본부 영역의 합집합 (겹치면 하나로 이어진다)
var territory_enabled: bool = false ## true면 건설·생산이 본부 영역 안으로 제한된다. 게임(main.gd)이 켠다 (기획서 5.3)
var _terr_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _terr_nodes: Array[Node] = []
var hq_lost: int = 0 ## 영구히 잃은 본부 수
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
var _outer: Dictionary = {} ## 필드 밖 땅 칸 → 지형
var _outer_nodes: Array[Node] = []
var _outer_seed: int = 0
var _ver: int = 0 ## 지형이 바뀔 때마다 올라가는 번호 (바깥 바다 계산 캐시용)
var _open_ver: int = -1
var _open: Dictionary = {} ## 바깥 바다와 이어진 바다 칸
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
	var ext: Rect2i = bounds.grow(M)
	_add_plane(ext, 0.0, Color(0.06, 0.17, 0.34)) # 배치할 수 없는 바깥은 어둡게
	_add_plane(bounds, 0.01, Color(0.2, 0.48, 0.82))
	var o: Vector3 = cell_to_world(bounds.position) - Vector3(0.5, 0.0, 0.5) # 필드 왼쪽 위 모서리
	var im: ImmediateMesh = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in bounds.size.x + 1:
		im.surface_add_vertex(o + Vector3(x, 0.02, 0))
		im.surface_add_vertex(o + Vector3(x, 0.02, bounds.size.y))
	for y in bounds.size.y + 1:
		im.surface_add_vertex(o + Vector3(0, 0.02, y))
		im.surface_add_vertex(o + Vector3(bounds.size.x, 0.02, y))
	im.surface_end()
	var lines: MeshInstance3D = MeshInstance3D.new()
	lines.mesh = im
	lines.material_override = _mat(Color(1, 1, 1, 0.25), true)
	add_child(lines)
	_frame_nodes.append(lines)
	# 배치할 수 있는 경계의 진한 테두리, 필드 바깥쪽 바닥에 붙인다
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


func _mat(c: Color, unshaded: bool) -> StandardMaterial3D:
	var key: String = "%s%s" % [c, unshaded]
	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


## 월드 좌표는 처음 15x15 필드의 중심이 원점이다. 확장해도 기존 칸의 위치는 변하지 않는다
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5 - W / 2.0, 0.0, c.y + 0.5 - H / 2.0)


func world_to_cell(v: Vector3) -> Vector2i:
	return Vector2i(floori(v.x + W / 2.0), floori(v.z + H / 2.0))


## 필드 영역의 중심 (카메라가 비추는 곳)
func center_world() -> Vector3:
	return cell_to_world(bounds.position) - Vector3(0.5, 0.0, 0.5) + Vector3(bounds.size.x / 2.0, 0.0, bounds.size.y / 2.0)


func in_bounds(c: Vector2i) -> bool:
	return bounds.has_point(c)


## 필드 안팎 모두의 지형. 필드 밖 8칸 너머는 바다
func terrain_at(c: Vector2i) -> int:
	if bounds.has_point(c):
		return cells.get(c, SEA)
	return _outer.get(c, SEA)


## 본부 영역 안인지. 건설과 생산은 영역 안에서만 된다 (기획서 5.3)
func in_territory(c: Vector2i) -> bool:
	return not territory_enabled or territory.has(c)


## 새 본부의 시작 영역: 본부 칸 주변 3x3 (필드 안만) (기획서 5.3)
func claim_start(hq_cell: Vector2i) -> void:
	var set: Dictionary = {}
	var r: int = Balance.TERRITORY_START_RADIUS
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = hq_cell + Vector2i(dx, dy)
			if bounds.has_point(c):
				set[c] = true
	territory_of[hq_cell] = set
	_rebuild_territory()


## 영역에 4방향으로 붙은 필드 안의 칸 중 무작위로 n칸을 더한다 (기획서 5.3)
func grow_territory(hq_cell: Vector2i, n: int) -> void:
	if not territory_of.has(hq_cell):
		return
	var set: Dictionary = territory_of[hq_cell]
	for _i in n:
		var cand: Array[Vector2i] = []
		for c in set:
			for d in DIRS:
				var q: Vector2i = c + d
				if bounds.has_point(q) and not set.has(q) and not cand.has(q):
					cand.append(q)
		if cand.is_empty():
			break
		set[cand[_terr_rng.randi() % cand.size()]] = true
	_rebuild_territory()


func grow_all_territories(n: int) -> void:
	for h in territory_of:
		grow_territory(h, n)


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


## 필드 밖에 시드 기반 랜덤 지형을 만든다. 필드에서 2칸 안쪽은 항상 바다라서 적이 걸어서 올 수 없다 (기획서 3장)
func generate_outside(seed_v: int) -> void:
	_outer_seed = seed_v
	_ver += 1
	for n in _outer_nodes:
		n.queue_free()
	_outer_nodes.clear()
	_outer.clear()
	ruins.clear()
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = Balance.CONTINENT_FREQ
	var ring: Rect2i = bounds.grow(2)
	var ext: Rect2i = bounds.grow(M)
	for y in range(ext.position.y, ext.end.y):
		for x in range(ext.position.x, ext.end.x):
			var c: Vector2i = Vector2i(x, y)
			if not ring.has_point(c) and noise.get_noise_2d(x, y) > Balance.CONTINENT_LEVEL:
				_outer[c] = Piece.PLAINS
	var shore: Array[Vector2i] = [] # 바다와 닿은 땅은 모래
	for c in _outer:
		if sea_neighbor(c).x != -999:
			shore.append(c)
	for c in shore:
		_outer[c] = Piece.SAND
	for c in _outer:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = block_mesh
		mi.material_override = _mat(color_of(_outer[c]).darkened(0.55), false)
		mi.position = cell_to_world(c) + Vector3(0, BLOCK_H / 2.0, 0)
		add_child(mi)
		_outer_nodes.append(mi)
		# 유적지: 좌표 해시로 정해서 필드를 넓혀도 같은 자리에 남는다 (기획서 3장)
		if _outer[c] == Piece.PLAINS and not looted.has(c) and (hash([seed_v, c.x, c.y]) % 1000) / 1000.0 < Balance.RUIN_CHANCE:
			ruins[c] = true
			var rm: MeshInstance3D = MeshInstance3D.new()
			var rb: BoxMesh = BoxMesh.new()
			rb.size = Vector3(0.5, 0.7, 0.5)
			rm.mesh = rb
			var rmat: StandardMaterial3D = StandardMaterial3D.new()
			rmat.albedo_color = Color(1.0, 0.85, 0.1)
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.material_override = rmat
			rm.position = cell_to_world(c) + Vector3(0, BLOCK_H + 0.35, 0)
			add_child(rm)
			_outer_nodes.append(rm)


## 유적지를 턴다: 다시 만들어도 나오지 않게 기억하고 표시를 지운다 (기획서 3장)
func loot_ruin(c: Vector2i) -> void:
	looted[c] = true
	generate_outside(_outer_seed)


## 한 줄 확장할 수 있는지 (최대 40x30) (기획서 3장)
func can_expand(dir: Vector2i) -> bool:
	return bounds.size.x < MAX_W if dir.x != 0 else bounds.size.y < MAX_H


## dir 방향으로 한 줄 넓힌다(경계만). 넓힌 칸은 바다로 비어 있다
func _grow(dir: Vector2i) -> void:
	var b: Rect2i = bounds
	if dir == Vector2i.LEFT:
		b.position.x -= 1
		b.size.x += 1
	elif dir == Vector2i.UP:
		b.position.y -= 1
		b.size.y += 1
	elif dir == Vector2i.RIGHT:
		b.size.x += 1
	else:
		b.size.y += 1
	bounds = b


func _regrow() -> void:
	_ver += 1
	expansions += 1
	generate_outside(_outer_seed)
	_build_frame()


## 한 방향으로 한 줄 넓힌다(놓을 자리가 없을 때의 자동 확장). 그 줄의 바깥 지형은 다시 만든다
func expand(dir: Vector2i) -> void:
	_grow(dir)
	_regrow()


## 4방향으로 한 줄씩 넓힌다. 확장 횟수는 한 번만 센다 (기획서 3장)
func expand_all() -> void:
	for d in DIRS:
		if can_expand(d):
			_grow(d)
	_regrow()


## 조각을 (회전해서라도) 놓을 자리가 필드 안에 있는지 (기획서 5.5)
func has_room(p: Piece) -> bool:
	var q: Piece = p
	for _r in 4:
		var sz: Vector2i = q.size()
		for y in range(bounds.position.y, bounds.end.y - sz.y + 1):
			for x in range(bounds.position.x, bounds.end.x - sz.x + 1):
				if can_place(q, Vector2i(x, y)):
					return true
		q = q.rotated()
	return false


## "본부 2/3 · 체력 300·120 · 영구 손실 1" (기획서 5.5)
func hq_status() -> String:
	var hps: Array[String] = []
	for c in hqs:
		hps.append(str(ceili(hqs[c])))
	var s: String = "본부 %d/%d · 체력 %s" % [hqs.size(), hqs.size() + hq_lost, "·".join(hps) if not hps.is_empty() else "-"]
	if hq_lost > 0:
		s += " · 영구 손실 %d" % hq_lost
	return s


## 모든 칸이 필드 안이고 빈 칸(바다)이어야 놓을 수 있다 (기획서 4장)
func can_place(p: Piece, origin: Vector2i) -> bool:
	for i in p.cells.size():
		var cell: Vector2i = origin + p.cells[i]
		if not bounds.has_point(cell) or water.has(cell) or buildings.has(cell) or hqs.has(cell): # 물 타일·건물·본부 칸에는 못 놓는다
			return false
		if p.terrain[i] != Piece.SEA and cells.has(cell): # 땅 칸은 빈 칸에만. 바다 칸은 기존 땅을 물로 깎을 수 있다 (기획서 4장)
			return false
	return true


## 조각의 바다 칸이 깎게 될 기존 땅 칸 수 (기획서 4장)
func carve_count(p: Piece, origin: Vector2i) -> int:
	var n: int = 0
	for i in p.cells.size():
		if p.terrain[i] == Piece.SEA and cells.has(origin + p.cells[i]):
			n += 1
	return n


## 건물 위치 → 건물 종류 (본부는 hq에 따로 기록)
var buildings: Dictionary = {}
var hp: Dictionary = {} ## 건물 위치 → 체력
var levels: Dictionary = {} ## 건물 위치 → 레벨 (1~3)
var barracks_unit: Dictionary = {} ## 병영 위치 → 생산할 병종 (없으면 검병)
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
	if data.get("on_water", false): # 낚시터: 필드 안의 물 위, 땅과 닿은 칸 (기획서 5.1)
		return bounds.has_point(c) and not cells.has(c) and not buildings.has(c) and _next_to_land(c)
	if not cells.has(c) or hqs.has(c) or buildings.has(c):
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


## 필드 밖으로 이어진 바다(섬 안에 갇힌 호수 제외)인지 (기획서 5.1)
func is_open_sea(c: Vector2i) -> bool:
	if _open_ver != _ver:
		_open_ver = _ver
		_open.clear()
		var ext: Rect2i = bounds.grow(M)
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
	return _next_to_open_sea(c)


## 조각 p를 origin에 놓으면 교역소(c)가 열린 바다와 끊기는지 미리 계산한다. 끊기면 false (기획서 5.6)
func post_open_after(c: Vector2i, p: Piece, origin: Vector2i) -> bool:
	var added: Array[Vector2i] = []
	var carved: Dictionary = {}
	for i in p.cells.size():
		var cell: Vector2i = origin + p.cells[i]
		if p.terrain[i] == Piece.SEA:
			if cells.has(cell): # 바다 칸이 땅을 깎으면 그만큼 바다가 열린다
				carved[cell] = cells[cell]
				cells.erase(cell)
		elif not cells.has(cell):
			cells[cell] = p.terrain[i]
			added.append(cell)
	_ver += 1
	var open: bool = _next_to_open_sea(c)
	for cell in added:
		cells.erase(cell)
	for cell in carved:
		cells[cell] = carved[cell]
	_ver += 1
	return open


func _next_to_open_sea(c: Vector2i) -> bool:
	for d in DIRS:
		if terrain_at(c + d) == SEA and is_open_sea(c + d):
			return true
	return false


## 낚시터에서 물길로 FISH_RADIUS칸 안에 이어진 바다 칸 수 (최대 FISH_CAP) (기획서 5.1)
func fishing_cells(c: Vector2i) -> int:
	var seen: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for d in DIRS:
		if terrain_at(c + d) == SEA:
			seen[c + d] = true
			frontier.append(c + d)
	for _step in Balance.FISH_RADIUS - 1:
		var next: Array[Vector2i] = []
		for f in frontier:
			for d in DIRS:
				var n: Vector2i = f + d
				if terrain_at(n) == SEA and not seen.has(n):
					seen[n] = true
					next.append(n)
		frontier = next
	return mini(seen.size(), Balance.FISH_CAP)


func fishing_food(c: Vector2i) -> int:
	return Balance.fishing_food(fishing_cells(c), levels.get(c, 1))


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


func _label_text(c: Vector2i) -> String:
	var name: String = Balance.BUILDINGS[buildings[c]]["name"]
	return name.left(1) + (str(levels[c]) if levels[c] > 1 else "")


func build(id: int, c: Vector2i, level: int = 1) -> void:
	buildings[c] = id
	levels[c] = level
	var data: Dictionary = Balance.BUILDINGS[id]
	hp[c] = max_hp(c)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.6, 0.5, 0.6)
	mi.mesh = bm
	mi.material_override = StandardMaterial3D.new()
	var base_y: float = BLOCK_H if cells.has(c) else 0.0 # 물 위 건물은 바다 면에 놓인다
	mi.position = cell_to_world(c) + Vector3(0, base_y + 0.25, 0)
	add_child(mi)
	var label: Label3D = Label3D.new()
	label.text = _label_text(c)
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 16
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = cell_to_world(c) + Vector3(0, base_y + 0.52, 0)
	add_child(label)
	_nodes[c] = [mi, label]
	_tint(c)


## 체력 비율만큼 본체 색을 어둡게 해 피해를 보여 준다
func _tint(c: Vector2i) -> void:
	var base: Color = HQ_COLOR
	var ratio: float = 1.0
	if hqs.has(c):
		ratio = hqs[c] / Balance.HQ_HP
	else:
		var data: Dictionary = Balance.BUILDINGS[buildings[c]]
		base = data["color"]
		ratio = hp[c] / max_hp(c)
	var mi: MeshInstance3D = _nodes[c][0]
	(mi.material_override as StandardMaterial3D).albedo_color = base.lerp(Color.BLACK, (1.0 - ratio) * 0.7)


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
			territory_of.erase(c) # 본부가 무너지면 그 영역도 사라진다 (기획서 5.3)
			_rebuild_territory()
			for n: Node in _nodes[c]:
				n.queue_free()
			_nodes.erase(c)
			return true
		_tint(c)
	elif buildings.has(c):
		hp[c] -= amount
		if hp[c] <= 0.0: # 파괴되면 빈 땅이 되고 복구되지 않는다. 다시 지어야 한다 (기획서 5.2)
			for n: Node in _nodes[c]:
				n.queue_free()
			_nodes.erase(c)
			buildings.erase(c)
			hp.erase(c)
			levels.erase(c)
			barracks_unit.erase(c)
		else:
			_tint(c)
	return false


## 웨이브가 끝나면 살아남은 건물·본부가 입은 피해를 모두 회복한다. 파괴된 건물·본부는 돌아오지 않는다 (기획서 5.2)
func repair_all() -> void:
	for c in hqs:
		hqs[c] = Balance.HQ_HP
	for c in buildings:
		hp[c] = max_hp(c)
	for c in _nodes:
		_tint(c)


func land_count() -> int:
	return cells.size()


## c의 4방향 이웃 중 바다인 칸(필드 밖 포함), 없으면 (-999, -999)
func sea_neighbor(c: Vector2i) -> Vector2i:
	for d in DIRS:
		if terrain_at(c + d) == SEA and not buildings.has(c + d): # 수상 건물(낚시터)이 있는 칸은 뱃길로 안 친다
			return c + d
	return Vector2i(-999, -999)


## 바깥 가장자리 바다에서 필드 땅(산 제외)의 해안까지 바닷길이 하나도 없으면 true — 해적이 바다를 걸어 건넌다 (기획서 6장)
func sea_blocked() -> bool:
	var ext: Rect2i = bounds.grow(M)
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


## 길찾기 격자: sea=true면 바다만, false면 필드 안의 땅만 지나갈 수 있다 (기획서 7.3)
func nav(sea: bool, enemy: bool = false) -> AStarGrid2D:
	var ext: Rect2i = bounds.grow(M)
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
	var ext: Rect2i = bounds.grow(M)
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
	var ext: Rect2i = bounds.grow(M)
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
			best = maxf(best, Balance.MARKET_HOUSE_BONUS_LV[levels[c + d] - 1])
	return best


## 웨이브 정산 때 얻는 연구수치: 도서관·연구소 레벨 합 (기획서 5.4)
func research_income() -> int:
	var n: int = 0
	for c in buildings:
		if not in_territory(c):
			continue
		if buildings[c] == Balance.LIBRARY:
			n += Balance.LIBRARY_RESEARCH_LV[levels[c] - 1]
		elif buildings[c] == Balance.LAB:
			n += Balance.LAB_RESEARCH_LV[levels[c] - 1]
	return n


## 웨이브 정산 수입: x = 골드, y = 식량 (기획서 5장)
func income(techs: Dictionary = {}) -> Vector2i:
	var gold: float = 0.0
	var food: float = 0.0
	var house_mult: float = 1.2 if techs.has("commerce") else 1.0
	var farm_mult: float = 1.0 + (0.3 if techs.has("tools") else 0.0) + (0.5 if techs.has("harvest") else 0.0)
	for c in buildings:
		if not in_territory(c): # 영역 밖 건물은 생산하지 않는다 (기획서 5.3)
			continue
		if buildings[c] == Balance.HOUSE:
			gold += Balance.house_gold(levels[c], cells[c] == Piece.SAND) * (house_mult + _market_bonus(c))
		elif buildings[c] == Balance.MINE:
			gold += Balance.MINE_GOLD_LV[levels[c] - 1]
		elif buildings[c] == Balance.FARM:
			food += Balance.FARM_FOOD_LV[levels[c] - 1] * farm_mult
		elif buildings[c] == Balance.FISHERY:
			food += fishing_food(c)
	var per_plain: float = Balance.FOOD_PER_PLAINS * (1.5 if techs.has("irrigation") else 1.0)
	var plains: int = 0
	for c in cells:
		if cells[c] == Piece.PLAINS and in_territory(c):
			plains += 1
	food += plains * per_plain
	gold += Balance.HQ_BASE_GOLD * hqs.size() # 살아 있는 본부마다 기본 골드 (기획서 5.1)
	return Vector2i(floori(gold), floori(food))


func place(p: Piece, origin: Vector2i) -> void:
	_ver += 1
	for i in p.cells.size():
		var cell: Vector2i = origin + p.cells[i]
		if p.terrain[i] == Piece.SEA: # 바다 칸: 땅이 되지 않고 물 타일로 남는다. 기존 땅(건물·본부 없는 칸)은 물로 깎인다
			if cells.has(cell):
				cells.erase(cell)
				if _land_nodes.has(cell):
					_land_nodes[cell].queue_free()
					_land_nodes.erase(cell)
			water[cell] = true
			var wt: MeshInstance3D = MeshInstance3D.new()
			var wm: BoxMesh = BoxMesh.new()
			wm.size = Vector3(1.0, 0.06, 1.0)
			wt.mesh = wm
			wt.material_override = _mat(color_of(Piece.SEA), false)
			wt.position = cell_to_world(cell) + Vector3(0, 0.03, 0)
			add_child(wt)
			continue
		cells[cell] = p.terrain[i]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = block_mesh
		mi.material_override = _mat(color_of(p.terrain[i]), false)
		mi.position = cell_to_world(cell) + Vector3(0, BLOCK_H / 2.0, 0)
		add_child(mi)
		_land_nodes[cell] = mi
		if i == p.hq_index:
			hqs[cell] = Balance.HQ_HP
			claim_start(cell)
			var marker: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.5, 0.6, 0.5)
			marker.mesh = bm
			marker.material_override = StandardMaterial3D.new()
			marker.position = cell_to_world(cell) + Vector3(0, BLOCK_H + 0.3, 0)
			add_child(marker)
			_nodes[cell] = [marker]
			_tint(cell)

class_name Battle
extends Node3D
## 전투 단계: 해적선이 와서 상륙하고, 병사가 막는다. 섬 사이는 항구의 보트로만 건넌다 (기획서 6장)

signal finished(victory: bool)

const BOAT_IDLE: int = 0
const BOAT_OUT: int = 1
const BOAT_BACK: int = 2

var field: Field
var gs: Node ## GameState (테스트에서 주입할 수 있도록 인자로 받는다)
var wave: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ships: Array[Unit] = []
var boats: Array[Unit] = []
var soldiers: Array[Unit] = []
var pirates: Array[Unit] = []
var done: bool = false
var time: float = 0.0
var land_nav: AStarGrid2D ## 아군용 땅 길찾기 (성벽을 그냥 지난다)
var enemy_nav: AStarGrid2D ## 적용 땅 길찾기 (성벽 칸은 비용이 높다) (기획서 6장)
var _tower_cd: Dictionary = {} ## 방어탑 위치 → 다음 공격까지 남은 시간
var _fx: Array = [] ## 방어탑 공격 선 표시 {node, t}
var _queue: Array[int] = [] ## 아직 해적선에 태우지 않은 적 종류(강한 적이 먼저)
var sea_nav: AStarGrid2D
var islands: Dictionary = {} ## 땅 칸 → 섬 번호
var _ships_left: int = 0
## 아직 해적선에 태우지 않은 적 수 (테스트에서 0으로 줄여 웨이브를 끝낼 수 있다)
var _pirates_left: int:
	get:
		return _queue.size()
	set(v):
		while _queue.size() > maxi(v, 0):
			_queue.pop_back()
var _ship_timer: float = 0.0
var speed_scale: float = 1.0 ## 전투 배속
var _mult: float = 1.0


func setup(f: Field, g: Node, w: int) -> void:
	field = f
	gs = g
	wave = w
	land_nav = f.nav(false)
	enemy_nav = f.nav(false, true)
	sea_nav = f.nav(true)
	islands = f.island_map()
	_ships_left = Balance.ship_count(w)
	_queue = Balance.enemy_queue(w)
	_mult = Balance.enemy_mult(f.land_count(), f.expansions)
	rng.randomize()
	for hq_cell in f.hqs: # 본부마다 수비병 (기획서 5.5)
		for i in Balance.HQ_GUARDS:
			_spawn_unit(Balance.U_SOLDIER, hq_cell)
	for i in g.extra_guards: # 교역 NPC에게 산 수비병 (1회성) (기획서 5.6)
		_spawn_unit(Balance.U_SOLDIER, f.hq)
	g.extra_guards = 0
	# 병영은 웨이브 시작 때만 병사를 만든다. 병사 생산에는 골드·식량이 들지 않는다 (기획서 6장)
	for entry: Dictionary in barracks_plan(f):
		var u: Unit = _spawn_unit(entry["kind"], entry["cell"])
		if entry["lv"] == Balance.MAX_LEVEL:
			u.hp *= Balance.BARRACKS_L3_HP
	for c in f.buildings:
		if f.buildings[c] == Balance.PORT:
			var home: Vector2i = f.sea_neighbor(c)
			if home.x == -999:
				continue
			# 조선술: 항구당 보트 +1척, 속도 +30%(레벨 3 보너스와 더한다)
			var speed_mult: float = Balance.BOAT_SPEED_LV[f.levels[c] - 1] + (0.3 if g.has_tech("ship") else 0.0)
			for i in 2 if g.has_tech("ship") else 1:
				var b: Unit = _add_unit(Balance.U_BOAT, f.cell_to_world(home), 1.0)
				b.home_port = c
				b.home_sea = home
				b.speed *= speed_mult


## 병영이 이번 웨이브에 낼 병력(병영 위치·병종·병영 레벨). 준비 단계 미리보기와 전투 시작이 같은 계산을 쓴다 (기획서 6장)
static func barracks_plan(f: Field) -> Array:
	var plan: Array = []
	for c in f.buildings:
		if f.buildings[c] != Balance.BARRACKS:
			continue
		var lv: int = f.levels[c]
		var kind: int = f.barracks_unit.get(c, Balance.U_SOLDIER)
		for i in Balance.BARRACKS_SOLDIERS_LV[lv - 1]:
			plan.append({"cell": c, "kind": kind, "lv": lv})
	return plan


## 플레이어가 클릭한 칸으로 모든 병사가 이동한다(보트에 탄 병사 포함). 깃발 없이 한 번의 명령이다 (기획서 6장)
func command_move(cell: Vector2i) -> void:
	for u in soldiers:
		u.order = cell
	for b in boats:
		for r in b.cargo:
			r.order = cell


func clear_orders() -> void:
	for u in soldiers:
		u.order = Vector2i(-1, -1)
	for b in boats:
		for r in b.cargo:
			r.order = Vector2i(-1, -1)


func _process(delta: float) -> void:
	var left: float = delta * speed_scale # 배속이 커도 한 번에 0.1초씩만 계산해 움직임이 튀지 않게 한다
	while left > 0.0 and not done:
		var step: float = minf(left, 0.1)
		tick(step)
		left -= step


func tick(dt: float) -> void:
	if done:
		return
	time += dt
	_spawn_ships(dt)
	for s in ships.duplicate():
		_ship_turn(s, dt)
	for u in soldiers.duplicate():
		_soldier_turn(u, dt)
	for u in pirates.duplicate():
		_pirate_turn(u, dt)
	for b in boats.duplicate():
		_boat_turn(b, dt)
	_towers_turn(dt)
	for u in soldiers:
		u.animate(dt)
	for u in pirates:
		u.animate(dt)
	_push_apart(soldiers + pirates, false)
	_push_apart(ships + boats, true)
	_prune(ships)
	_prune(boats)
	_prune(soldiers)
	_prune(pirates)
	if field.hq_hp <= 0.0:
		_finish(false)
	elif time > Balance.WAVE_TIME_LIMIT or (_ships_left == 0 and ships.is_empty() and pirates.is_empty()):
		_finish(true)


func summary() -> String:
	return "전투 중 · %s · 병사 %d · 해적 %d · 해적선 %d" % [field.hq_status(), soldiers.size(), pirates.size(), ships.size() + _ships_left]


func _finish(victory: bool) -> void:
	done = true
	for b in boats:
		for r in b.cargo:
			r.queue_free()
	for e in _fx:
		e["node"].queue_free()
	_fx.clear()
	for arr in [ships, boats, soldiers, pirates]:
		for u: Unit in arr:
			u.queue_free()
	ships.clear()
	boats.clear()
	soldiers.clear()
	pirates.clear()
	finished.emit(victory)


func _add_unit(kind: int, pos: Vector3, mult: float) -> Unit:
	var u: Unit = Unit.new()
	u.setup(kind, mult)
	u.position = Vector3(pos.x, u.base_y, pos.z)
	add_child(u)
	if Balance.SOLDIER_KINDS.has(kind):
		soldiers.append(u)
	elif Balance.ENEMY_KINDS.has(kind):
		pirates.append(u)
	elif kind == Balance.U_BOAT:
		boats.append(u)
	else:
		ships.append(u)
	return u


## 단련은 모든 병사의 체력·공격 +20% (기획서 5.4)
func _spawn_unit(kind: int, cell: Vector2i) -> Unit:
	var m: float = 1.2 if gs.has_tech("drill") else 1.0
	var jitter: Vector3 = Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)) # 한곳에서 한꺼번에 나와도 겹치지 않게
	var u: Unit = _add_unit(kind, field.cell_to_world(cell) + jitter, m)
	u.island = islands.get(cell, -1)
	return u


## 보트 한 척에 탑승할 수 있는 병사 수: 항구 레벨 + 대양 항해 +2명
func boat_capacity(b: Unit) -> int:
	return Balance.PORT_CAPACITY_LV[field.levels[b.home_port] - 1] + (2 if gs.has_tech("ocean") else 0)


func _prune(arr: Array[Unit]) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if arr[i].hp <= 0.0:
			arr[i].queue_free()
			arr.remove_at(i)


func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _nearest(pos: Vector3, arr: Array[Unit], island: int = -2) -> Unit:
	var best: Unit = null
	var best_d: float = INF
	for u in arr:
		if island != -2 and u.island != island:
			continue
		var d: float = _dist(pos, u.position)
		if d < best_d:
			best_d = d
			best = u
	return best


## 경로를 따라 이동한다. 경로 끝에 닿으면 true
func _follow(u: Unit, dt: float) -> bool:
	var budget: float = u.speed * dt * field.speed_mult_at(u.position) # 숲은 느리다 (기획서 3장)
	while budget > 0.0 and not u.path.is_empty():
		var wp: Vector3 = field.cell_to_world(u.path[0])
		var d: Vector3 = Vector3(wp.x - u.position.x, 0.0, wp.z - u.position.z)
		if d.length() <= budget:
			u.position.x = wp.x
			u.position.z = wp.z
			u.path.remove_at(0)
			budget -= d.length()
		else:
			u.position += d.normalized() * budget
			u.rotation.y = -atan2(d.z, d.x)
			budget = 0.0
	return u.path.is_empty()


## 땅 위를 goal 칸으로 걸어간다. 경로는 0.5초마다 다시 계산한다
func _walk(u: Unit, goal: Vector2i, dt: float) -> void:
	u.repath -= dt
	if u.repath <= 0.0:
		u.repath = 0.5
		var nav: AStarGrid2D = enemy_nav if Balance.ENEMY_KINDS.has(u.kind) else land_nav
		u.path = field.path(nav, field.world_to_cell(u.position), goal)
	_follow(u, dt)


## 사거리 밖이면 다가가고, 사거리 안이면 공격 준비가 됐는지를 돌려 준다
func _engage(u: Unit, tpos: Vector3, dt: float) -> bool:
	u.cooldown = maxf(0.0, u.cooldown - dt)
	if _dist(u.position, tpos) > u.reach:
		_walk(u, field.world_to_cell(tpos), dt)
		return false
	return u.cooldown <= 0.0


func _soldier_turn(u: Unit, dt: float) -> void:
	u.waiting = false
	# 이동 명령을 받은 병사는 그곳에 도착할 때까지 가까운 적(AGGRO_RANGE 안)만 상대하고 계속 간다. 도착하면 명령이 끝난다 (기획서 6장)
	if u.order.x >= 0 and islands.get(u.order, -1) == u.island and _dist(u.position, field.cell_to_world(u.order)) <= 0.6:
		u.order = Vector2i(-1, -1)
	var ordered: bool = u.order.x >= 0
	var t: Unit = _nearest(u.position, pirates, u.island)
	if t != null and (not ordered or _dist(u.position, t.position) <= Balance.AGGRO_RANGE):
		if _engage(u, t.position, dt):
			t.hp -= u.atk
			u.cooldown = Balance.ATTACK_INTERVAL
			u.lunge(t.position)
		return
	var goal_island: int = -1
	var goal_pos: Vector3 = Vector3.ZERO
	if ordered:
		goal_island = islands.get(u.order, -1)
		goal_pos = field.cell_to_world(u.order)
	else:
		var far: Unit = _nearest(u.position, pirates)
		if far == null:
			return
		goal_island = far.island
		goal_pos = far.position
	if goal_island == u.island:
		if ordered:
			_walk(u, u.order, dt)
		return
	# 건너가야 한다: 같은 섬의 항구로 가서 보트를 기다린다
	var port: Vector2i = _port_on_island(u)
	if port.x < 0:
		return
	if _dist(u.position, field.cell_to_world(port)) > 0.6:
		_walk(u, port, dt)
		return
	u.waiting = true
	u.port = port
	u.goal_island = goal_island
	u.goal_pos = goal_pos


## 유닛끼리 겹치지 않게 밀어낸다. 땅 유닛은 땅 위에서, 배는 바다 위에서만 움직인다 (기획서 6장)
func _push_apart(units: Array[Unit], sea: bool) -> void:
	for i in units.size():
		for j in range(i + 1, units.size()):
			var a: Unit = units[i]
			var b: Unit = units[j]
			var d: Vector3 = Vector3(a.position.x - b.position.x, 0.0, a.position.z - b.position.z)
			var dist: float = d.length()
			if dist >= Balance.UNIT_GAP:
				continue
			var dir: Vector3 = d / dist if dist > 0.001 else Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
			var push: Vector3 = dir * (Balance.UNIT_GAP - dist) * 0.5
			_nudge(a, push, sea)
			_nudge(b, -push, sea)


func _nudge(u: Unit, push: Vector3, sea: bool) -> void:
	var np: Vector3 = u.position + push
	var c: Vector2i = field.world_to_cell(np)
	if (field.terrain_at(c) == Field.SEA) if sea else field.is_walkable(c):
		u.position = np


func _port_on_island(u: Unit) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = INF
	for c in field.buildings:
		if field.buildings[c] == Balance.PORT and islands.get(c, -1) == u.island:
			var d: float = _dist(u.position, field.cell_to_world(c))
			if d < best_d:
				best_d = d
				best = c
	return best


func _pirate_turn(u: Unit, dt: float) -> void:
	var best_d: float = INF
	var tpos: Vector3 = u.position
	var tunit: Unit = null
	var tcell: Vector2i = Vector2i(-1, -1)
	for s in soldiers:
		var d: float = _dist(u.position, s.position)
		if s.island == u.island and d < best_d:
			best_d = d
			tpos = s.position
			tunit = s
	var tower_first: bool = tunit == null # 같은 섬에 아군 병사가 없으면 방어탑부터 공격한다 (기획서 6장)
	if tower_first:
		tower_first = false
		for c in field.targets():
			if field.buildings.get(c, 0) == Balance.TOWER and islands.get(c, -1) == u.island:
				tower_first = true
				break
	for c in field.targets():
		if tower_first and field.buildings.get(c, 0) != Balance.TOWER:
			continue
		var p: Vector3 = field.cell_to_world(c)
		var d: float = _dist(u.position, p)
		if field.cells.get(c, -1) == Piece.MOUNTAIN: # 산 위 방어탑: 걸어서 못 가므로 사거리 안의 원거리 적만 공격한다 (기획서 3장)
			if u.reach > 2.0 and d <= u.reach and d < best_d:
				best_d = d
				tpos = p
				tunit = null
				tcell = c
			continue
		if islands.get(c, -1) == u.island and d < best_d:
			best_d = d
			tpos = p
			tunit = null
			tcell = c
	if best_d == INF: # 같은 섬에 노릴 대상이 없으면 물러간다
		u.hp = 0.0
		return
	if not _engage(u, tpos, dt):
		return
	u.cooldown = Balance.ATTACK_INTERVAL
	u.lunge(tpos)
	if tunit != null:
		tunit.hp -= u.atk
	elif field.damage(tcell, u.atk): # 본부가 파괴되면 보유 골드·식량이 줄어든다 (기획서 5.5)
		gs.lose_share(Balance.HQ_LOSS_RATE)


## 방어탑: 사거리 안에서 가장 가까운 적 유닛을 1초마다 하나씩 공격한다 (해적선 제외) (기획서 6장)
func _towers_turn(dt: float) -> void:
	for c in field.buildings:
		if field.buildings[c] != Balance.TOWER:
			continue
		_tower_cd[c] = maxf(0.0, float(_tower_cd.get(c, 0.0)) - dt)
		if _tower_cd[c] > 0.0:
			continue
		var lv: int = field.levels[c]
		var from: Vector3 = field.cell_to_world(c)
		var t: Unit = null
		var best: float = Balance.TOWER_RANGE_LV[lv - 1]
		for e in pirates:
			var d: float = _dist(from, e.position)
			if d <= best:
				best = d
				t = e
		if t != null:
			t.hp -= Balance.TOWER_ATK_LV[lv - 1]
			_tower_cd[c] = Balance.TOWER_INTERVAL
			_shot_fx(from, t.position)
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i]["t"] -= dt
		if _fx[i]["t"] <= 0.0:
			_fx[i]["node"].queue_free()
			_fx.remove_at(i)


## 방어탑에서 적에게 가는 짧은 선
func _shot_fx(from: Vector3, to: Vector3) -> void:
	var d: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, maxf(d.length(), 0.1))
	m.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	m.material_override = mat
	m.position = Vector3(from.x + d.x / 2.0, Field.BLOCK_H + 0.6, from.z + d.z / 2.0)
	m.rotation.y = atan2(d.x, d.z)
	add_child(m)
	_fx.append({"node": m, "t": 0.12})


func _boat_turn(b: Unit, dt: float) -> void:
	if not field.buildings.has(b.home_port): # 항구가 부서지면 보트도 잃는다
		for r in b.cargo:
			r.queue_free()
		b.cargo.clear()
		b.hp = 0.0
		return
	match b.state:
		BOAT_IDLE:
			_boat_load(b)
		BOAT_OUT:
			if _follow(b, dt):
				for r in b.cargo:
					r.position = Vector3(b.dest_land.x + rng.randf_range(-0.2, 0.2), r.base_y, b.dest_land.z + rng.randf_range(-0.2, 0.2))
					r.visible = true
					r.island = b.dest_island
					r.path.clear()
					soldiers.append(r)
				b.cargo.clear()
				b.path = field.path(sea_nav, field.world_to_cell(b.position), b.home_sea)
				b.state = BOAT_BACK
		_:
			if _follow(b, dt):
				var home: Vector3 = field.cell_to_world(b.home_sea)
				b.position = Vector3(home.x, b.base_y, home.z)
				b.state = BOAT_IDLE


## 항구에서 기다리는 병사를 태워 목표 섬 해안으로 출발한다
func _boat_load(b: Unit) -> void:
	var riders: Array[Unit] = []
	for s in soldiers:
		if s.waiting and s.port == b.home_port and riders.size() < boat_capacity(b):
			riders.append(s)
	if riders.is_empty():
		return
	var dest: Dictionary = field.coast_for(riders[0].goal_island, riders[0].goal_pos, islands)
	if dest.is_empty():
		return
	var route: Array[Vector2i] = field.path(sea_nav, field.world_to_cell(b.position), dest["stop"])
	if route.is_empty():
		return
	for r in riders:
		soldiers.erase(r)
		r.visible = false
		b.cargo.append(r)
	b.path = route
	b.dest_land = field.cell_to_world(dest["land"])
	b.dest_island = islands.get(dest["land"], -1)
	b.state = BOAT_OUT


func _spawn_ships(dt: float) -> void:
	if _ships_left <= 0:
		return
	_ship_timer -= dt
	if _ship_timer > 0.0:
		return
	_ship_timer = Balance.SHIP_INTERVAL
	_ships_left -= 1
	var load: Array[int] = [] # 강한 적이 먼저 탄다
	var n_load: int = ceili(_queue.size() / float(_ships_left + 1)) # 남은 인원을 남은 배에 고르게 나눠 한 명짜리 배가 없게 한다 (기획서 6장)
	for i in n_load:
		if _queue.is_empty():
			break
		load.append(_queue.pop_front())
	var from: Vector2i = _edge_cell()
	var tgt: Dictionary = _pick_landing(field.cell_to_world(from))
	if tgt.is_empty():
		return
	var route: Array[Vector2i] = field.path(sea_nav, from, tgt["stop"])
	# 대륙에 막혀 길이 없으면 다른 가장자리를 시도하고, 끝내 없으면 상륙 지점 바로 앞 바다에서 출발한다 (전투 없이 끝나는 것을 막는다)
	for _try in 40:
		if not route.is_empty():
			break
		from = _edge_cell()
		route = field.path(sea_nav, from, tgt["stop"])
	if route.is_empty():
		from = tgt["stop"]
	var s: Unit = _add_unit(Balance.U_SHIP, field.cell_to_world(from), 1.0)
	s.path = route
	s.landing = field.cell_to_world(tgt["land"])
	s.island = tgt["island"]
	s.crew = load.size()
	s.crew_kinds = load


## 필드 밖 지형 가장자리의 바다 칸 (기획서 3장)
func _edge_cell() -> Vector2i:
	var ext: Rect2i = field.bounds.grow(Field.M)
	for _i in 100:
		var x: int = rng.randi_range(ext.position.x, ext.end.x - 1)
		var y: int = rng.randi_range(ext.position.y, ext.end.y - 1)
		var c: Vector2i
		match rng.randi() % 4:
			0: c = Vector2i(x, ext.position.y)
			1: c = Vector2i(x, ext.end.y - 1)
			2: c = Vector2i(ext.position.x, y)
			_: c = Vector2i(ext.end.x - 1, y)
		if field.terrain_at(c) == Field.SEA:
			return c
	return ext.position


## 노릴 대상이 있는 섬의 해안(모래·평원 모두) 중 가장 가까운 곳
func _pick_landing(from: Vector3) -> Dictionary:
	var has_target: Dictionary = {}
	for c in field.targets():
		has_target[islands.get(c, -1)] = true
	var best: Dictionary = {}
	var best_d: float = INF
	for c in islands:
		if not has_target.has(islands[c]):
			continue
		var n: Vector2i = field.sea_neighbor(c)
		if n.x == -999:
			continue
		var d: float = _dist(from, field.cell_to_world(n))
		if d < best_d:
			best_d = d
			best = {"stop": n, "land": c, "island": islands[c]}
	return best


func _ship_turn(s: Unit, dt: float) -> void:
	if not _follow(s, dt):
		return
	for kind in s.crew_kinds: # 모래·평원 어느 해안이든 상륙한다 (기획서 6장)
		var p: Unit = _add_unit(kind, s.landing + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)), _mult)
		p.island = s.island
	s.hp = 0.0

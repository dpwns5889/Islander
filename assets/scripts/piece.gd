class_name Piece
extends RefCounted
## 지형 조각: 칸 좌표와 칸별 지형 (기획서 4장)

const SEA: int = 0 ## 바다 칸: 놓으면 그 칸이 물 타일로 차지된다 (기획서 4장)
const PLAINS: int = 1
const SAND: int = 2

const SEVEN: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)]
## 4~7칸 모양 18종 (기획서 4장)
const SHAPES: Array = [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], # I4
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], # O
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], # T4
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], # S
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], # Z
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)], # L4
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)], # J4
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], # I5
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)], # L5
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)], # P
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)], # T5
	[Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], # U
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)], # Z5
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)], # X
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)], # V
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], # 2x3
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 4)], # L6
	SEVEN,
]
## 평원 위주 / 모래 위주 / 반반 (모래가 될 확률)
const SAND_CHANCE: Array[float] = [0.15, 0.85, 0.5]

var cells: Array[Vector2i] = []
var terrain: Array[int] = []
var hq_index: int = -1 ## 본부가 올라가는 칸 번호, 없으면 -1


static func random_piece(rng: RandomNumberGenerator, with_sea: bool = false) -> Piece:
	var p: Piece = Piece.new()
	p.cells.assign(SHAPES[rng.randi() % SHAPES.size()])
	var sand: float = SAND_CHANCE[rng.randi() % SAND_CHANCE.size()]
	for _c in p.cells:
		p.terrain.append(SAND if rng.randf() < sand else PLAINS)
	if with_sea and rng.randf() < Balance.SEA_TILE_CHANCE:
		# 4~5칸은 바다 1칸, 6~7칸은 1~2칸. 땅은 항상 3칸 이상 남는다
		var k: int = 1 if p.cells.size() <= 5 else 1 + rng.randi() % 2
		var idx: Array[int] = []
		for i in p.cells.size():
			idx.append(i)
		for i in range(idx.size() - 1, 0, -1):
			var j: int = rng.randi() % (i + 1)
			var tmp: int = idx[i]
			idx[i] = idx[j]
			idx[j] = tmp
		for i in k:
			p.terrain[idx[i]] = SEA
	return p


func has_sea() -> bool:
	return terrain.has(SEA)


## 시작 조각: 7칸, 평원 위주, 무작위 평원 칸 1개가 본부 (기획서 2장)
static func start_piece(rng: RandomNumberGenerator) -> Piece:
	var p: Piece = Piece.new()
	p.cells.assign(SEVEN)
	for _c in p.cells:
		p.terrain.append(SAND if rng.randf() < SAND_CHANCE[0] else PLAINS)
	p.hq_index = rng.randi() % p.cells.size()
	p.terrain[p.hq_index] = PLAINS
	return p


func size() -> Vector2i:
	var s: Vector2i = Vector2i.ZERO
	for c in cells:
		s = Vector2i(maxi(s.x, c.x + 1), maxi(s.y, c.y + 1))
	return s


## 커서가 조각 중앙에 오도록 한 원점 (좌상단 칸)
func origin_for(hover: Vector2i) -> Vector2i:
	return hover - size() / 2


## 시계 방향 90도 회전한 새 조각 (기획서 4장, 뒤집기는 없음)
func rotated() -> Piece:
	var p: Piece = Piece.new()
	p.terrain.assign(terrain)
	p.hq_index = hq_index
	var min_v: Vector2i = Vector2i(1000, 1000)
	for c in cells:
		var r: Vector2i = Vector2i(-c.y, c.x)
		p.cells.append(r)
		min_v = Vector2i(mini(min_v.x, r.x), mini(min_v.y, r.y))
	for i in p.cells.size():
		p.cells[i] -= min_v
	return p

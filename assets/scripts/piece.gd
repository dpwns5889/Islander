class_name Piece
extends RefCounted
## 지형 값과 땅 묶음. 조각 퍼즐은 0.2.01에서 삭제했고(기획서 1장), 지금은 지형 상수와 테스트가 땅을 깔 때만 쓴다
## shortcut: 이름이 옛 "조각"이다. 테스트를 R2~R3에서 다시 쓸 때 Terrain으로 바꾼다

const SEA: int = 0
const PLAINS: int = 1
const SAND: int = 2
const FOREST: int = 3 ## 숲: 이동 느림, 식량 0 (기획서 3장)
const MOUNTAIN: int = 4 ## 산: 이동 불가 (기획서 3장)

const SEVEN: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)]

var cells: Array[Vector2i] = []
var terrain: Array[int] = []
var hq_index: int = -1 ## 도시가 세워지는 칸 번호, 없으면 -1


## 테스트용 7칸 평원 묶음, 무작위 칸 1개가 도시
static func start_piece(rng: RandomNumberGenerator) -> Piece:
	var p: Piece = Piece.new()
	p.cells.assign(SEVEN)
	for _c in p.cells:
		p.terrain.append(PLAINS)
	p.hq_index = rng.randi() % p.cells.size()
	return p

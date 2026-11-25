class_name Unit
extends Node3D
## 전투 유닛: 병사, 해적, 해적선 (기획서 6장)

var kind: int
var hp: float
var atk: float
var speed: float
var reach: float ## 공격 사거리
var ranged: bool = false ## 원거리 유닛인지 (기획서 6장)
var cooldown: float = 0.0
var base_y: float
## 해적선 전용: 멈출 바다 위치, 상륙할 땅 위치
var stop: Vector3
var landing: Vector3
var crew: int = 0 ## 해적선이 태운 적 수
var crew_kinds: Array[int] = [] ## 해적선이 태운 적 종류(강한 적이 먼저)
## 이동: 경로 칸 목록과 다음 경로 계산까지 남은 시간
var path: Array[Vector2i] = []
var repath: float = 0.0
var island: int = -1
var crossing: bool = false ## 바닷길이 막혀 바다를 걸어 건너는 해적 (기획서 6장)
var home: Vector2i = Vector2i(-1, -1) ## 병사가 지키는 집 칸: 태어난 건물, 이동 명령으로 도착한 칸 (기획서 6장)
var leash: float = 4.0 ## 집에서 수비하는 반경(칸)
var order: Vector2i = Vector2i(-1, -1) ## 플레이어가 클릭해 내린 이동 명령 칸, 없으면 (-1, -1) (기획서 6장)
## 병사: 보트를 기다리는 중인지, 어느 항구에서, 어디로 가려는지
var waiting: bool = false
var port: Vector2i = Vector2i(-1, -1)
var goal_island: int = -1
var goal_pos: Vector3
## 보트: 모항, 상태(0 대기, 1 이동, 2 귀항), 태운 병사, 내릴 곳
var home_port: Vector2i = Vector2i(-1, -1)
var home_sea: Vector2i
var state: int = 0
var cargo: Array[Unit] = []
var dest_land: Vector3
var dest_island: int = -1
## 공격 애니메이션: 몸통(body)이 목표 쪽으로 약진했다가 제자리로 돌아온다 (기획서 6장)
var body: MeshInstance3D
var _lunge_t: float = -1.0
var _lunge_dir: Vector3 = Vector3.ZERO


func setup(k: int, mult: float) -> void:
	kind = k
	var d: Dictionary = Balance.UNITS[k]
	var hp0: float = d["hp"]
	var atk0: float = d["atk"]
	hp = hp0 * mult
	atk = atk0 * mult
	speed = d["speed"]
	reach = d["reach"]
	ranged = d.get("ranged", false)
	var mat: ShaderMaterial = Toon.material(d["color"])
	var mi: MeshInstance3D = MeshInstance3D.new()
	if k == Balance.U_SHIP or k == Balance.U_BOAT:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.9, 0.28, 0.45) if k == Balance.U_SHIP else Vector3(0.65, 0.2, 0.38)
		mi.mesh = bm
		base_y = 0.15
	else:
		var sc: float = Balance.UNIT_SCALE.get(k, 1.0)
		var cm: CapsuleMesh = CapsuleMesh.new()
		cm.radius = 0.12 * sc
		cm.height = 0.42 * sc
		mi.mesh = cm
		base_y = Field.BLOCK_H + 0.21 * sc
	mi.material_override = mat
	add_child(mi)
	body = mi


## 목표 쪽으로 약진했다 돌아오는 공격 애니메이션을 시작한다
func lunge(world_target: Vector3) -> void:
	var d: Vector3 = Vector3(world_target.x - position.x, 0.0, world_target.z - position.z)
	if d.length() < 0.001:
		return
	_lunge_dir = transform.basis.inverse() * d.normalized() # 유닛이 이동 방향으로 회전해 있어도 목표 쪽으로 간다
	_lunge_t = 0.0


## 전투 시간 dt만큼 애니메이션을 진행한다(배속에 따라 같이 빨라진다)
func animate(dt: float) -> void:
	if _lunge_t < 0.0:
		return
	_lunge_t += dt
	var k: float = _lunge_t / Balance.LUNGE_TIME
	if k >= 1.0:
		body.position = Vector3.ZERO
		_lunge_t = -1.0
		return
	body.position = _lunge_dir * Balance.LUNGE_DIST * sin(PI * k)

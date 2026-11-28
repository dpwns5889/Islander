class_name Balance
extends RefCounted
## 밸런스 수치 한 곳 (기획서 5장, 6장). 조정은 여기서만 한다.

const HOUSE: int = 1
const PORT: int = 2
const BARRACKS: int = 3
const MARKET: int = 4
const FARM: int = 5
const FISHERY: int = 6 ## 낚시터
const TRADING_POST: int = 7 ## 교역소
const TOWER: int = 9 ## 방어탑
const SHOOTING_RANGE: int = 13 ## 사격장 (원거리 병사 생산)
const LIBRARY: int = 10 ## 도서관 (임시명)
const LAB: int = 11 ## 연구소 (임시명)
const MINE: int = 12 ## 광산 (산 칸 전용)
const OBSERVATORY: int = 14 ## 천문대 (산 칸 전용, 과학)
const MANSION: int = 15 ## 저택 (집의 진화) (기획서 5.2.1)
const FARMSTEAD: int = 16 ## 농장 (밭의 진화)
const FISH_VILLAGE: int = 17 ## 어촌 (낚시터의 진화)
const SMELTER: int = 18 ## 제련소 (광산의 진화)
const FORTRESS: int = 19 ## 요새 (방어탑의 진화)
const MAX_LEVEL: int = 3
const EVOLVE_COST_RATE: float = 0.7 ## 기존 레벨 3 건물을 진화시키는 비용: 진화 건물 건설 비용의 이 비율 (기획서 5.2.1)

## cost: 건설 골드, hp: 체력(M3부터), sand: 모래 위 건설 가능 여부, sea: 인접 바다 필요 여부
const BUILDINGS: Dictionary = {
	HOUSE: {"name": "집", "cost": 20, "hp": 50, "sand": true, "sea": false, "evolves_to": MANSION, "model": "house", "model_variants": 4, "color": Color(0.6, 0.4, 0.2)},
	PORT: {"name": "항구", "cost": 50, "hp": 80, "sand": true, "sea": true, "color": Color(0.15, 0.25, 0.6)},
	BARRACKS: {"name": "병영", "cost": 30, "hp": 100, "sand": false, "sea": false, "model": "barracks", "model_variants": 2, "color": Color(0.45, 0.45, 0.5)},
	MARKET: {"name": "시장", "cost": 50, "hp": 70, "tech": "math", "sand": false, "sea": false, "color": Color(0.85, 0.65, 0.1)},
	FARM: {"name": "밭", "cost": 25, "hp": 50, "sand": false, "sea": false, "evolves_to": FARMSTEAD, "model": "field", "model_variants": 4, "color": Color(0.35, 0.55, 0.2)},
	FISHERY: {"name": "낚시터", "cost": 25, "hp": 50, "sand": true, "sea": false, "tech": "fishing", "on_water": true, "evolves_to": FISH_VILLAGE, "model": "fishery", "model_variants": 3, "color": Color(0.2, 0.65, 0.75)},
	TRADING_POST: {"name": "교역소", "cost": 40, "hp": 70, "tech": "commerce", "sand": true, "sea": false, "on_water": true, "open_sea": true, "unique": true, "color": Color(0.7, 0.35, 0.75)},
	LIBRARY: {"name": "도서관", "cost": 40, "hp": 60, "sand": true, "sea": false, "evolves_to": LAB, "model": "library", "model_variants": 3, "color": Color(0.55, 0.35, 0.65)},
	LAB: {"name": "대학", "cost": 80, "hp": 120, "tech": "astronomy", "sand": false, "sea": false, "model": "university", "model_variants": 3, "color": Color(0.25, 0.7, 0.6)},
	MINE: {"name": "광산", "cost": 60, "hp": 100, "tech": "mining", "sand": false, "sea": false, "mountain_only": true, "evolves_to": SMELTER, "model": "mine", "model_variants": 3, "color": Color(0.5, 0.45, 0.4)},
	SHOOTING_RANGE: {"name": "사격장", "cost": 30, "hp": 100, "tech": "archery", "sand": false, "sea": false, "model": "archery_range", "model_variants": 3, "color": Color(0.3, 0.5, 0.35)},
	OBSERVATORY: {"name": "천문대", "cost": 60, "hp": 100, "tech": "astronomy", "sand": false, "sea": false, "mountain_only": true, "model": "observatory", "model_variants": 3, "color": Color(0.3, 0.3, 0.6)},
	TOWER: {"name": "방어탑", "cost": 40, "hp": 200, "tech": "archery", "sand": true, "sea": false, "evolves_to": FORTRESS, "model": "defense_tower", "model_variants": 3, "color": Color(0.35, 0.4, 0.55)},
	MANSION: {"name": "저택", "cost": 40, "hp": 100, "tech": "currency", "sand": true, "sea": false, "color": Color(0.85, 0.6, 0.3)},
	FARMSTEAD: {"name": "농장", "cost": 50, "hp": 100, "tech": "windmill", "sand": false, "sea": false, "color": Color(0.5, 0.75, 0.25)},
	FISH_VILLAGE: {"name": "어촌", "cost": 50, "hp": 100, "tech": "waterwheel", "sand": true, "sea": false, "on_water": true, "color": Color(0.1, 0.45, 0.7)},
	SMELTER: {"name": "제련소", "cost": 120, "hp": 200, "tech": "furnace", "sand": false, "sea": false, "mountain_only": true, "color": Color(0.7, 0.4, 0.3)},
	FORTRESS: {"name": "요새", "cost": 80, "hp": 400, "tech": "engineering", "sand": true, "sea": false, "color": Color(0.5, 0.55, 0.8)},
}

## 건설 메뉴 카테고리 (아래에서 위로 펼쳐지는 드롭다운). 진화 건물은 목록에 없고 진화로만 얻는다 (기획서 5.2.1, 7.2)
const CATEGORIES: Array = [
	{"name": "생산", "ids": [HOUSE, FARM, FISHERY, MINE]},
	{"name": "군사·해상", "ids": [BARRACKS, PORT, TOWER]}, # 사격장은 보류: 원거리 분대도 병영이 만든다 (기획서 5.1)
	{"name": "상업", "ids": [MARKET, TRADING_POST]},
	{"name": "과학", "ids": [LIBRARY, OBSERVATORY]},
]

const U_GUARD: int = 0
const U_PIRATE: int = 1
const U_SHIP: int = 2
const U_BOAT: int = 3
const U_ARCHER: int = 4
const U_PIKE: int = 5 ## 파이크병
const U_CROSSBOW: int = 6 ## 석궁수 (적)
const U_AXE: int = 7 ## 도끼병 (적)
const U_SHIELD: int = 8 ## 방패병 (적)
const U_CAPTAIN: int = 9 ## 선장 (보스 라운드의 적)
const U_SPEAR: int = 10 ## 창병
const U_LONGBOW: int = 11 ## 장궁병
const U_ARBALEST: int = 12 ## 쇠뇌병
const U_SETTLER: int = 13 ## 개척자: 공격하지 않고 정착해 도시가 된다 (기획서 4장)
const ENEMY_KINDS: Array[int] = [U_PIRATE, U_CROSSBOW, U_AXE, U_SHIELD, U_CAPTAIN]
const SOLDIER_KINDS: Array[int] = [U_GUARD, U_SPEAR, U_PIKE, U_ARCHER, U_LONGBOW, U_ARBALEST, U_SETTLER] ## 아군 유닛 (개척자도 병사 목록에 든다)
const UNITS: Dictionary = {
	U_GUARD: {"name": "경비병", "hp": 30.0, "atk": 5.0, "speed": 1.5, "reach": 0.7, "color": Color(0.2, 0.4, 1.0)},
	U_PIRATE: {"name": "해적", "hp": 25.0, "atk": 2.0, "speed": 1.2, "reach": 0.7, "color": Color(0.15, 0.05, 0.1)},
	U_SHIP: {"name": "해적선", "hp": 1.0, "atk": 0.0, "speed": 2.0, "reach": 0.7, "color": Color(0.45, 0.3, 0.15)},
	U_BOAT: {"name": "보트", "hp": 1.0, "atk": 0.0, "speed": 2.5, "reach": 0.7, "color": Color(0.85, 0.75, 0.55)},
	U_ARCHER: {"name": "궁수", "hp": 20.0, "atk": 3.0, "speed": 1.5, "reach": 2.0, "ranged": true, "color": Color(0.2, 0.75, 0.3)},
	U_SPEAR: {"name": "창병", "hp": 40.0, "atk": 6.0, "speed": 1.5, "reach": 0.7, "color": Color(0.3, 0.55, 1.0)},
	U_PIKE: {"name": "파이크병", "hp": 55.0, "atk": 7.0, "speed": 2.0, "reach": 0.7, "color": Color(0.95, 0.55, 0.1)},
	U_LONGBOW: {"name": "장궁병", "hp": 25.0, "atk": 4.0, "speed": 1.5, "reach": 2.5, "ranged": true, "color": Color(0.3, 0.85, 0.4)},
	U_ARBALEST: {"name": "쇠뇌병", "hp": 25.0, "atk": 6.0, "speed": 1.5, "reach": 2.5, "ranged": true, "color": Color(0.1, 0.6, 0.45)},
	U_SETTLER: {"name": "개척자", "hp": 20.0, "atk": 0.0, "speed": 1.5, "reach": 0.7, "color": Color(0.95, 0.85, 0.3)},
	U_CROSSBOW: {"name": "석궁수", "hp": 18.0, "atk": 3.0, "speed": 1.1, "reach": 1.8, "ranged": true, "color": Color(0.55, 0.15, 0.3)},
	U_AXE: {"name": "도끼병", "hp": 40.0, "atk": 4.0, "speed": 1.2, "reach": 0.7, "color": Color(0.45, 0.1, 0.1)},
	U_SHIELD: {"name": "방패병", "hp": 100.0, "atk": 2.0, "speed": 0.9, "reach": 0.7, "color": Color(0.3, 0.3, 0.35)},
	U_CAPTAIN: {"name": "선장", "hp": 80.0, "atk": 5.0, "speed": 1.1, "reach": 0.7, "color": Color(0.7, 0.05, 0.05)},
}
const UNIT_SCALE: Dictionary = {U_AXE: 1.1, U_SHIELD: 1.25, U_CAPTAIN: 1.6} ## 강한 적은 더 크게 그린다
const ENEMY_FIRST_WAVE: Dictionary = {U_CROSSBOW: 5, U_AXE: 8, U_SHIELD: 12, U_CAPTAIN: 10} ## 새 적이 처음 나오는 웨이브 (기획서 6장)

## 웨이브의 총 전투력(예산): 기준점 [웨이브, 점수]. 사이는 선형으로 잇고 반올림. 보스 라운드는 선장 점수가 따로 더해진다 (기획서 6장)
const ENEMY_BUDGET: Array = [[1, 2], [4, 3], [7, 6], [10, 12], [15, 30], [20, 52], [25, 80], [30, 110]]
const ENEMY_POWER: Dictionary = {U_PIRATE: 1, U_CROSSBOW: 1, U_AXE: 3, U_SHIELD: 4, U_CAPTAIN: 8} ## 적 한 명의 전투력 점수
const ENEMY_DRAW_ORDER: Array[int] = [U_SHIELD, U_AXE, U_CROSSBOW, U_PIRATE] ## 상륙 순서(강한 적이 먼저)
const HEAVY_POWER: int = 3 ## 이 점수 이상인 적은 뽑힐 가중치가 절반이다
const NEW_KIND_GUARANTEE: int = 3 ## 새 종류는 처음 나온 웨이브부터 이 웨이브 수 동안 최소 1명이 반드시 나온다
const CAPTAINS: Dictionary = {10: 1, 20: 2, 30: 2} ## 보스 라운드의 선장 수
const TOWER_ATK_LV: Array[float] = [4.0, 6.0, 8.0]
const TOWER_RANGE_LV: Array[float] = [3.0, 3.5, 4.0]
const FORTRESS_ATK_LV: Array[float] = [11.0, 13.0, 16.0] ## 요새 (기획서 5.2.1)
const FORTRESS_RANGE_LV: Array[float] = [4.5, 4.75, 5.0]
const TOWER_INTERVAL: float = 1.0
const HQ_HP: float = 300.0
const HQ_MODEL: String = "castle" ## 본부 모델: 레벨 구분 없이 놓을 때 번호를 무작위로 고른다 (기획서 7.2)
const HQ_MODEL_VARIANTS: int = 3
const HQ_LOSS_RATE: float = 0.3 ## 본부가 파괴될 때마다 줄어드는 골드·식량 비율
const BUILDING_EDGE: float = 0.5 ## 건물 칸 중심에서 가장자리까지 (건물 공격 거리는 가장자리부터 잰다) (기획서 6장)
const UNIT_GAP: float = 0.3 ## 유닛끼리 이 거리보다 가까우면 서로 밀어낸다
const LUNGE_TIME: float = 0.22 ## 공격할 때 앞으로 약진했다 돌아오는 시간(초)
const LUNGE_DIST: float = 0.35 ## 약진하는 거리(칸)
const LEASH_MELEE: float = 4.0 ## 근접 병사가 집(태어난 건물 칸)에서 지키는 반경(칸) (기획서 6장)
const LEASH_RANGED: float = 5.0 ## 원거리 병사의 수비 반경
const LEASH_SUPPORT_MULT: float = 2.0 ## 반경 안에 적이 없을 때 지원하러 가는 범위(반경 배율)
const AGGRO_RANGE: float = 2.5 ## 집결지가 있을 때 병사가 이 거리 안의 적만 상대한다
const BATTLE_SPEEDS: Array[int] = [1, 2, 4] ## 전투 배속
const ATTACK_INTERVAL: float = 1.0
const PIRATES_PER_SHIP: int = 3
const MIN_PIRATES_PER_SHIP: int = 2 ## 해적선 한 척의 최소 인원. 한 명만 타고 오는 배는 없다 (기획서 6장)
const SHIP_SPAWN_TIME: float = 2.0 ## 모든 해적선이 이 시간(초) 안에 나타난다 (기획서 6장)
const HQ_GUARDS: int = 2 ## 시작 경비병 수. 첫 도시를 세울 때 한 번만 1번 분대로 나온다 (기획서 2장)
## 분대: 병영에서 한 번 생산하면 한 분대. 병종은 생산을 시작할 때의 병영 레벨로 정한다 (기획서 6장)
## reinforce: 충원 1명당 [골드, 식량]
const SQUADS: Dictionary = {
	"melee": {"name": "근접 분대", "units": [U_GUARD, U_SPEAR, U_PIKE], "count": 3, "gold": 30, "food": 15, "reinforce": [10, 5]},
	"ranged": {"name": "원거리 분대", "units": [U_ARCHER, U_LONGBOW, U_ARBALEST], "count": 2, "gold": 30, "food": 10, "tech": "archery", "reinforce": [15, 5]},
}
const SQUAD_TIME: float = 30.0 ## 한 분대 생산 시간(게임 초)
const SQUAD_QUEUE: int = 3 ## 병영마다 대기열 칸 수
const SQUAD_CAP_BASE: int = 3 ## 첫 도시일 때 분대 수 상한(시작 경비병 포함)
const SQUAD_CAP_PER_CITY: int = 1 ## 도시가 하나 늘 때마다 상한 +1
const SQUAD_CAP_MAX: int = 9 ## 숫자키 1~9
const REINFORCE_RANGE: float = 2.0 ## 분대원이 병영에서 이 거리(칸) 안이면 충원할 수 있다
## 개척자 (기획서 4장)
const SETTLER_COST: Vector2i = Vector2i(30, 30) ## 기본 비용 (골드, 식량)
const SETTLER_COST_RATE: float = 0.5 ## 도시가 하나 늘 때마다 비용 +50%
const SETTLER_TIME: float = 30.0 ## 생산 시간(게임 초), 도시마다 한 번에 1명
const CITY_MIN_DIST: int = 4 ## 다른 도시와 떨어져야 하는 거리(가로·세로 차이 중 큰 값)
## 안개·유적지·미니맵 (기획서 3장, 7.2)
const VISION_RANGE: float = 4.0 ## 유닛(분대·개척자) 주변 이 거리(칸) 안을 밝힌다
const RUIN_COUNT: int = 12 ## 유적지 수 (평원 칸)
const RUIN_GOLD: Vector2i = Vector2i(60, 100) ## 유적지 골드 보상 범위
const RUIN_RP_CHANCE: float = 0.3 ## 골드 대신 연구포인트 +1을 줄 확률
const FOG_COLOR: Color = Color(0.2, 0.22, 0.28) ## 밝히지 않은 칸
const MINIMAP_SIZE: float = 200.0 ## 미니맵 한 변(논리 픽셀)
const SQUAD_DOUBLE_TAP: float = 0.4 ## 숫자키를 이 시간(초) 안에 두 번 누르면 카메라가 분대로 간다
const LV3_TECH: String = "ironwork" ## 병영·사격장 레벨 3 강화에 필요한 연구
## 실시간 진행 (기획서 2장). 모두 게임 시간(초)이라 배속을 따른다
const PRODUCTION_TICK: float = 10.0 ## 이 간격마다 골드·식량·연구수치를 받는다
const WAVE_FIRST_DELAY: float = 60.0 ## 첫 웨이브가 오기까지
const WAVE_INTERVAL: float = 60.0 ## 그 뒤 웨이브 간격
const BUILD_TIME: float = 10.0 ## 건설·레벨업·진화 공사 시간 (기획서 5.1.1)
const CALL_WAVE_GOLD: float = 0.5 ## 웨이브를 앞당겨 부르면 남은 1초당 받는 골드(내림) (기획서 9.1)
const VICTORY_SAFETY: float = 300.0 ## 마지막 웨이브가 온 뒤 적이 막혀 남아도 이 시간이 지나면 정리하고 승리 (기획서 9.1)
const REPAIR_TIME: float = 5.0 ## 수리하면 이 시간에 걸쳐 체력이 찬다 (기획서 5.2.2)
const REPAIR_ENEMY_RANGE: float = 3.0 ## 이 거리(칸) 안에 적이 있으면 수리할 수 없다
const COMBAT_PITCH: float = 35.0 ## 카메라 시작 기울기(도): 쿼터뷰 하나 (기획서 7.2)
const COMBAT_YAW: float = 45.0 ## 카메라 시작 좌우 회전(도)
const CAM_PITCH_MIN: float = 35.0 ## 좌클릭 드래그로 기울일 수 있는 범위(도) (기획서 7.2)
const CAM_PITCH_MAX: float = 90.0
const CAM_ROTATE_SENS: float = 0.3 ## 좌클릭 드래그 1픽셀당 회전 각도(도)
const CAM_DRAG_THRESHOLD: float = 6.0 ## 좌클릭을 이 거리(논리 픽셀) 넘게 끌면 회전, 아니면 클릭 (기획서 7.2)
const EDGE_PAN_MARGIN: float = 12.0 ## 화면 가장자리 이 폭(논리 픽셀) 안에 마우스가 있으면 카메라가 움직인다 (기획서 7.2, 9.1)
const EDGE_PAN_SPEED: float = 1.0 ## 가장자리 이동 속도: 1초에 화면 세로 크기의 이 배수만큼
const PIXEL_HEIGHT: int = 360 ## 도트 화면의 세로 픽셀 수. 1080p는 3배, 1440p는 4배로 정수 배 확대된다 (기획서 7.2)
const ZOOM_MIN: float = 0.4 ## 휠 최대 확대 배율 (기획서 7.2, 9.1)
const ZOOM_MAX: float = 3.0 ## 휠 최대 축소 배율 (넓은 맵을 멀리서 본다)
const ZOOM_START: float = 3.0 ## 시작 위치를 고를 때의 배율
const ZOOM_STEP: float = 0.9 ## 휠 한 칸당 배율
const COMBAT_CAM_SIZE: float = 13.5 ## 배율 1일 때 카메라에 세로로 담기는 크기 (기획서 7.2)

const HQ_LEVEL_FOOD: Array[int] = [5, 12, 22, 35, 50, 70, 95, 125, 160, 200, 245, 295, 350, 410, 475, 545, 620, 700, 785] ## 본부 레벨 2~20이 되는 식량 누적량. 그 뒤는 hq_level_food가 이어 계산한다 (기획서 5.3)
const HQ_LEVEL_FOOD_STEP: int = 5 ## 레벨 20 이후 레벨마다 늘어나는 필요 식량의 증가폭(마지막 구간 85에서 +5씩)


## 본부 레벨 lv에서 lv+1이 되는 식량 누적량. 최고 레벨은 없다 (기획서 5.3)
static func hq_level_food(lv: int) -> int:
	if lv - 1 < HQ_LEVEL_FOOD.size():
		return HQ_LEVEL_FOOD[lv - 1]
	var n: int = lv - HQ_LEVEL_FOOD.size() # 표 다음 몇 번째 레벨인지
	var last: int = HQ_LEVEL_FOOD[-1]
	var step: int = HQ_LEVEL_FOOD[-1] - HQ_LEVEL_FOOD[-2]
	return last + n * step + HQ_LEVEL_FOOD_STEP * n * (n + 1) / 2
const TERRITORY_SQUARE_CHANCE: float = 0.6 ## 영역 확장 때 정사각형 우선으로 고를 확률 (나머지는 무작위) (기획서 5.3)
const TERRITORY_START_RADIUS: int = 1 ## 본부 영역의 시작 크기: 본부 칸 주변 이 거리까지 (3x3) (기획서 5.3)

const EXPLORE_GOLD_MIN: int = 60 ## 유적지 보상 골드 (기획서 3장, R5에서 다시 씀)
const EXPLORE_GOLD_MAX: int = 100
const EXPLORE_RP_CHANCE: float = 0.3 ## 골드 대신 연구포인트 +1을 얻을 확률

## 맵 생성 (기획서 3장, 9.1)
const MAP_SIZE: int = 96 ## 맵 한 변 칸 수
const MAP_EDGE_SEA: int = 4 ## 맵 가장자리에서 항상 바다인 폭
const MAP_LAND_RATIO: float = 0.35 ## 가장자리 안쪽 칸 중 땅 비율
const MAP_NOISE_FREQ: float = 0.045 ## 섬 노이즈 주파수 (낮을수록 큰 섬)
const MAP_MIN_ISLAND: int = 10 ## 이보다 작은 섬은 바다로 지운다
const MAP_FOREST_RATIO: float = 0.15 ## 해안이 아닌 땅 중 숲 비율
const MAP_MOUNTAIN_RATIO: float = 0.08 ## 해안이 아닌 땅 중 산 비율
const START_ISLAND_PLAINS: int = 30 ## 첫 도시는 평원이 이만큼 이상인 섬의 평원 칸에만 세운다
const FOREST_SPEED: float = 0.7 ## 숲 위 이동속도 배율 (아군·적 모두) (기획서 3장)
const SEA_CROSS_SPEED: float = 0.4 ## 바닷길이 막혔을 때 해적이 바다 칸을 걸어 건너는 속도 배율 (기획서 6장)
## 숲·산에 지을 수 있는 건물 (평원은 전부, 모래는 건물의 sand 값) (기획서 3장)
const FOREST_BUILDINGS: Array[int] = [HOUSE, MANSION, LIBRARY, TOWER, FORTRESS]
const MOUNTAIN_BUILDINGS: Array[int] = [TOWER, FORTRESS, MINE, SMELTER, OBSERVATORY]
const MINE_GOLD_LV: Array[int] = [20, 32, 48] ## 광산 정산 골드 (기획서 5.1)
const SMELTER_GOLD_LV: Array[int] = [67, 82, 96] ## 제련소 정산 골드 (기획서 5.2.1)
const HQ_BASE_GOLD: int = 20 ## 살아 있는 본부마다 웨이브 정산 때 받는 기본 골드 (기획서 5.1)

const WIN_WAVE: int = 30 ## 이 웨이브를 이기면 승리 화면 (이후 무한 모드로 계속할 수 있다) (기획서 9.1)
const ENEMY_CITY_RATE: float = 0.15 ## 도시가 하나 늘 때마다 적 체력·공격 증가량 (기획서 6장)
const START_GOLD: int = 50
const START_FOOD: int = 20

## 건물 레벨별 수치 (인덱스 0 = 레벨 1) (기획서 5.2)
const HP_MULT: Array[float] = [1.0, 1.5, 2.0]
## 파손과 수리 (기획서 5.2.2)
const DMG_STAGE1: float = 0.6 ## 체력 비율이 이 이하면 파손 1단계
const DMG_STAGE2: float = 0.3 ## 이 이하면 파손 2단계
const DMG_PERF: Array[float] = [1.0, 0.75, 0.5] ## 파손 단계별 건물 성능
const SOLDIER_DMG_FLOOR: float = 0.5 ## 병영 병사 능력 = 이 값 + (1 - 이 값) × 건물 체력 비율
const REPAIR_RATE: float = 0.5 ## 건물 수리비 = 투자 골드 × 잃은 체력 비율 × 이 값
const HQ_REPAIR_COST: int = 50 ## 본부 수리비 = 이 값 × 잃은 체력 비율
const HOUSE_GOLD_LV: Array[int] = [10, 16, 24] ## 모래 위는 ×1.5
const MANSION_GOLD_LV: Array[int] = [34, 41, 48] ## 저택 정산 골드, 모래 위는 ×1.5 (기획서 5.2.1)
const FARM_FOOD_LV: Array[int] = [5, 8, 12]
const FARMSTEAD_FOOD_LV: Array[int] = [17, 20, 24] ## 농장 정산 식량 (기획서 5.2.1)
const PORT_CAPACITY_LV: Array[int] = [4, 6, 8]
const TOOLMAKING_FOOD: int = 2 ## 도구 연구: 정산 식량 +2 (기획서 5.4)
const ENGINEERING_UPGRADE_DISCOUNT: float = 0.2 ## 공학 연구: 건물 레벨업 비용 -20%
const CURRENCY_GOLD_MULT: float = 1.2 ## 화폐 연구: 정산 골드 ×1.2
const BOAT_SPEED_LV: Array[float] = [1.0, 1.0, 1.3]
const FISHERY_MULT_LV: Array[float] = [1.0, 1.5, 2.0]
const FISH_VILLAGE_MULT_LV: Array[float] = [2.8, 3.4, 4.0] ## 어촌 식량 배율 (기획서 5.2.1)
const FISH_CAP: int = 40
const FISH_BASE: int = 3
const FISH_DIV: int = 6
const FISH_MAX: int = 9
const TRADE_FIRST_DELAY: float = 120.0 ## 교역소를 지은 뒤 거래 NPC가 처음 오기까지(초) (기획서 5.6)
const TRADE_INTERVAL: float = 360.0 ## 그 뒤 방문 간격(초)
const TRADE_STAY: float = 60.0 ## 한 번 오면 머무는 시간(초)
const TRADE_OFFERS_LV: Array[int] = [1, 1, 1] ## 교역소 레벨별 거래 수 (거래 풀이 1종, M8 유물 교역에서 바뀐다) (기획서 5.6)
const TRADES: Array = [
	{"id": "gold_rp", "name": "골드 60 → 연구포인트 1", "gold": 60, "food": 0},
]
const FOOD_PER_PLAINS: int = 1
const MARKET_HOUSE_BONUS_LV: Array[float] = [0.25, 0.4, 0.6] ## 시장과 4방향으로 붙은 집의 정산 골드 보너스 (기획서 5.1)
const LIBRARY_RESEARCH_LV: Array[int] = [3, 4, 5] ## 웨이브 정산 때 얻는 연구수치 (기획서 5.4)
const LAB_RESEARCH_LV: Array[int] = [6, 7, 9] ## 대학 (천문학 보너스 +1을 더하면 7/8/10, 대학은 천문학이 있어야 지을 수 있다) (기획서 5.2.1)
const OBSERVATORY_RESEARCH_LV: Array[int] = [4, 6, 8] ## 천문학 보너스 +1이 이미 들어간 값 (기획서 5.4)
const ASTRONOMY_BONUS: int = 1 ## 천문학 연구: 도서관·대학의 정산 연구수치 +1
const RESEARCH_FIRST: int = 5 ## 첫 연구포인트에 필요한 연구수치 (기획서 5.4)
const RESEARCH_STEP: int = 1 ## 포인트를 얻을 때마다 다음 기준이 이만큼 늘어난다
const HQ_RESEARCH: int = 1 ## 살아 있는 본부마다 정산 때 받는 연구수치


## 연구 (테크트리, 문명5식): 4열 14개. 비용은 max(1, 열 번호)점이고 선행 연구를 모두 마쳐야 한다 (기획서 5.4)
## col: 열(0~3), row: 화면의 줄, pre: 선행 연구 목록
const TECHS: Dictionary = {
	"toolmaking": {"name": "도구", "desc": "웨이브 정산 식량 +2", "col": 0, "row": 2, "pre": []},
	"fishing": {"name": "낚시", "desc": "낚시터 해금", "col": 1, "row": 1, "pre": ["toolmaking"]},
	"tools": {"name": "농기구", "desc": "밭 식량 +30%", "col": 1, "row": 0, "pre": ["toolmaking"]},
	"mining": {"name": "채광", "desc": "광산 해금", "col": 1, "row": 2, "pre": ["toolmaking"]},
	"archery": {"name": "궁술", "desc": "사격장·방어탑 해금", "col": 1, "row": 3, "pre": ["toolmaking"]},
	"waterwheel": {"name": "물레방아", "desc": "평원 칸 식량 +1 → +1.5, 어촌 해금", "col": 2, "row": 0, "pre": ["tools"]},
	"ironwork": {"name": "철기 제작", "desc": "병영·사격장 레벨 3 해금", "col": 2, "row": 2, "pre": ["mining"]},
	"engineering": {"name": "공학", "desc": "건물 레벨업·진화 비용 -20%, 요새 해금", "col": 3, "row": 0, "pre": ["waterwheel"]},
	"windmill": {"name": "풍차", "desc": "밭 식량 +50%, 농장 해금", "col": 3, "row": 1, "pre": ["waterwheel"]},
	"furnace": {"name": "용광로", "desc": "모든 병사 체력·공격 +20%, 제련소 해금", "col": 3, "row": 3, "pre": ["archery", "ironwork"]},
	"math": {"name": "수학", "desc": "시장 해금, 집 골드 +20%", "col": 0, "row": 5, "pre": []},
	"astronomy": {"name": "천문학", "desc": "천문대·대학 해금, 도서관·대학 연구수치 +1", "col": 2, "row": 4, "pre": ["math"]},
	"currency": {"name": "화폐", "desc": "웨이브 정산 골드 +20%, 저택 해금", "col": 2, "row": 5, "pre": ["math"]},
	"commerce": {"name": "상업", "desc": "교역소 해금", "col": 3, "row": 5, "pre": ["currency"]},
}
const TECH_COLS: int = 4
const TECH_ROWS: int = 6


## 연구수치로 이미 포인트를 gained개 얻었을 때 다음 포인트에 필요한 연구수치 (기획서 5.4)
static func research_threshold(gained: int) -> int:
	return RESEARCH_FIRST + gained * RESEARCH_STEP


static func tech_cost(id: String) -> int:
	return 1 # 모든 연구는 연구포인트 1 (기획서 5.4)


static func tech_prereqs(id: String) -> Array:
	return TECHS[id]["pre"]


## 건물을 to_level로 올리는 비용: 레벨 2는 건설비 ×1, 레벨 3은 ×1.5 (기획서 5.2)
static func upgrade_cost(id: int, to_level: int) -> int:
	var base: int = BUILDINGS[id]["cost"]
	return base if to_level <= 2 else roundi(base * 1.5)


static func house_gold(level: int, sand: bool, id: int = HOUSE) -> int:
	return roundi((MANSION_GOLD_LV if id == MANSION else HOUSE_GOLD_LV)[level - 1] * (1.5 if sand else 1.0))


## 낚시터·어촌 식량 배율 (기획서 5.2.1)
static func fishing_mult(id: int, level: int) -> float:
	return (FISH_VILLAGE_MULT_LV if id == FISH_VILLAGE else FISHERY_MULT_LV)[level - 1]


static func is_tower(id: int) -> bool:
	return id == TOWER or id == FORTRESS


static func tower_atk(id: int, level: int) -> float:
	return (FORTRESS_ATK_LV if id == FORTRESS else TOWER_ATK_LV)[level - 1]


static func tower_range(id: int, level: int) -> float:
	return (FORTRESS_RANGE_LV if id == FORTRESS else TOWER_RANGE_LV)[level - 1]


## 모델 파일 경로: 종류별 폴더 안에 레벨·번호마다 한 폴더, 파손 단계는 _dmg1·_dmg2. level 0은 레벨 구분 없는 모델(본부) (기획서 7.2)
static func model_path(kind: String, level: int, variant: int, stage: int = 0) -> String:
	var name: String = "%s_t%d_v%d" % [kind, level, variant] if level > 0 else "%s_v%d" % [kind, variant]
	var suffix: String = "" if stage == 0 else "_dmg%d" % stage
	return "res://assets/models/%s/%s/%s%s.glb" % [kind, name, name, suffix]


## 체력 비율(0~1)에 따른 파손 단계 0~2 (기획서 5.2.2)
static func damage_stage(ratio: float) -> int:
	if ratio <= DMG_STAGE2 + 0.0001:
		return 2
	return 1 if ratio <= DMG_STAGE1 + 0.0001 else 0


## 병영·사격장 건물 체력 비율에 따른 병사 체력·공격 배율 (기획서 5.2.2)
static func soldier_damage_mult(ratio: float) -> float:
	return SOLDIER_DMG_FLOOR + (1.0 - SOLDIER_DMG_FLOOR) * clampf(ratio, 0.0, 1.0)


## 건물에 들인 골드: 건설비 + level까지의 강화비 (기획서 5.2.2)
static func invested(id: int, level: int) -> int:
	var total: int = BUILDINGS[id]["cost"]
	for to in range(2, level + 1):
		total += upgrade_cost(id, to)
	return total


## 수리비: full골드 × 잃은 체력 비율, 올림 (부동소수 오차로 1골드 더 받지 않게 조금 뺀다)
static func repair_price(full: float, ratio: float) -> int:
	return maxi(0, ceili(full * (1.0 - clampf(ratio, 0.0, 1.0)) - 0.001))


## 진화 건물 id, 없으면 0 (기획서 5.2.1)
static func evolve_to(id: int) -> int:
	return int(BUILDINGS[id].get("evolves_to", 0))


## 기존 레벨 3 건물을 to 건물로 진화시키는 비용
static func evolve_cost(to: int) -> int:
	return roundi(BUILDINGS[to]["cost"] * EVOLVE_COST_RATE)


## 다른 건물이 진화해서 되는 건물인지
static func is_evolved(id: int) -> bool:
	for k in BUILDINGS:
		if int(BUILDINGS[k].get("evolves_to", 0)) == id:
			return true
	return false



## 낚시터 식량: 이어진 바다 칸 수와 레벨로 정한다 (기획서 5.1)
static func fishing_food(sea_cells: int, level: int, id: int = FISHERY) -> int:
	var base: int = mini(FISH_MAX, FISH_BASE + floori(mini(sea_cells, FISH_CAP) / float(FISH_DIV)))
	return floori(base * fishing_mult(id, level))


## 천문학을 연구했으면 도서관·학술원의 연구수치에 더하는 값 (기획서 5.4)
static func science_bonus(techs: Dictionary) -> int:
	return ASTRONOMY_BONUS if techs.has("astronomy") else 0


## 레벨별 효과 설명 (UI)
static func effect_text(id: int, level: int, techs: Dictionary = {}) -> String:
	var i: int = level - 1
	if id == HOUSE or id == MANSION:
		return "골드 +%d (모래 위 +%d)" % [house_gold(level, false, id), house_gold(level, true, id)]
	if id == MINE:
		return "산 위에만 · 골드 +%d" % MINE_GOLD_LV[i]
	if id == SMELTER:
		return "산 위에만 · 골드 +%d" % SMELTER_GOLD_LV[i]
	if id == FARM:
		return "식량 +%d" % FARM_FOOD_LV[i]
	if id == FARMSTEAD:
		return "식량 +%d" % FARMSTEAD_FOOD_LV[i]
	if id == BARRACKS:
		return "분대 생산: %s %d명 · %s %d명" % [UNITS[SQUADS["melee"]["units"][i]]["name"], SQUADS["melee"]["count"], UNITS[SQUADS["ranged"]["units"][i]]["name"], SQUADS["ranged"]["count"]]
	if id == SHOOTING_RANGE:
		return "보류 (원거리 분대는 병영이 만든다)"
	if id == PORT:
		return "보트 탑승 %d명%s" % [PORT_CAPACITY_LV[i], ", 보트 속도 +30%" if level == MAX_LEVEL else ""]
	if id == MARKET:
		return "붙어 있는 집의 정산 골드 +%d%%" % roundi(MARKET_HOUSE_BONUS_LV[i] * 100.0)
	if id == LIBRARY:
		return "연구수치 +%d (첫 %d점부터 연구포인트 1)" % [LIBRARY_RESEARCH_LV[i] + science_bonus(techs), RESEARCH_FIRST]
	if id == LAB:
		return "연구수치 +%d (첫 %d점부터 연구포인트 1)" % [LAB_RESEARCH_LV[i] + science_bonus(techs), RESEARCH_FIRST]
	if id == OBSERVATORY:
		return "산 위에만 · 연구수치 +%d" % OBSERVATORY_RESEARCH_LV[i]
	if id == FISHERY or id == FISH_VILLAGE:
		return "물 위에 설치 · 식량 +%d~%d (이어진 물가가 넓을수록)" % [fishing_food(0, level, id), fishing_food(FISH_CAP, level, id)]
	if id == TRADING_POST:
		return "%d분마다 거래 NPC 방문 · 거래 %d개 · 1개만" % [roundi(TRADE_INTERVAL / 60.0), TRADE_OFFERS_LV[i]]
	if is_tower(id):
		return "해적 자동 공격 %d · 사거리 %s칸" % [roundi(tower_atk(id, level)), str(tower_range(id, level))]
	return ""


## 웨이브 n의 일반 적 총 전투력 (선장 제외)
static func wave_budget(wave: int) -> int:
	var a: Array = ENEMY_BUDGET
	if wave <= a[0][0]:
		return a[0][1]
	for i in range(1, a.size()):
		if wave <= a[i][0]:
			var t: float = float(wave - a[i - 1][0]) / float(a[i][0] - a[i - 1][0])
			return roundi(lerpf(float(a[i - 1][1]), float(a[i][1]), t))
	var last: Array = a[a.size() - 1]
	var prev: Array = a[a.size() - 2]
	return roundi(last[1] + float(last[1] - prev[1]) / float(last[0] - prev[0]) * (wave - last[0]))


## 웨이브의 적 구성: 종류 → 인원. 보스 라운드는 선장을 먼저 넣고, 총 전투력(예산)이 다 찰 때까지 그 웨이브에 나올 수 있는 종류를 무작위로 뽑는다.
## 같은 (run_seed, 웨이브)는 항상 같은 결과라서 준비 단계 예고와 전투가 일치한다 (기획서 6장)
static func enemy_composition(wave: int, run_seed: int = 0) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, wave])
	var kinds: Array[int] = [U_PIRATE]
	for k in [U_CROSSBOW, U_AXE, U_SHIELD]:
		if ENEMY_FIRST_WAVE[k] <= wave:
			kinds.append(k)
	var n: Dictionary = {}
	var left: int = wave_budget(wave)
	for k in kinds: # 새 종류는 처음 몇 웨이브 동안 최소 1명
		if wave < ENEMY_FIRST_WAVE.get(k, 0) + NEW_KIND_GUARANTEE and ENEMY_POWER[k] <= left:
			n[k] = 1
			left -= ENEMY_POWER[k]
	while left > 0:
		var pool: Array[int] = []
		var weights: Array[float] = []
		for k in kinds:
			if ENEMY_POWER[k] <= left:
				pool.append(k)
				weights.append(0.5 if ENEMY_POWER[k] >= HEAVY_POWER else 1.0)
		var pick: int = pool[rng.rand_weighted(PackedFloat32Array(weights))]
		n[pick] = n.get(pick, 0) + 1
		left -= ENEMY_POWER[pick]
	var out: Dictionary = {}
	var caps: int = CAPTAINS.get(wave, 0)
	if caps > 0:
		out[U_CAPTAIN] = caps
	for k in ENEMY_DRAW_ORDER:
		if n.has(k):
			out[k] = n[k]
	var total: int = 0
	for k in out:
		total += out[k]
	if total < MIN_PIRATES_PER_SHIP: # 한 명짜리 배는 없다
		out[U_PIRATE] = out.get(U_PIRATE, 0) + MIN_PIRATES_PER_SHIP - total
	return out


## 웨이브의 적 총 인원
static func pirate_count(wave: int, run_seed: int = 0) -> int:
	var total: int = 0
	var comp: Dictionary = enemy_composition(wave, run_seed)
	for k in comp:
		total += comp[k]
	return total


## 웨이브 구성의 총 전투력 점수 (선장 포함)
static func wave_power(wave: int, run_seed: int = 0) -> int:
	var p: int = 0
	var comp: Dictionary = enemy_composition(wave, run_seed)
	for k in comp:
		p += ENEMY_POWER[k] * comp[k]
	return p


## 해적선에 태우는 순서(강한 적이 먼저)로 늘어놓은 적 종류 목록
static func enemy_queue(wave: int, run_seed: int = 0) -> Array[int]:
	var q: Array[int] = []
	var comp: Dictionary = enemy_composition(wave, run_seed)
	for kind in comp:
		for i in comp[kind]:
			q.append(kind)
	return q


## 이 웨이브에 처음 나오는 새 적 종류
static func new_enemy_kinds(wave: int) -> Array[int]:
	var out: Array[int] = []
	for kind in ENEMY_FIRST_WAVE:
		if ENEMY_FIRST_WAVE[kind] == wave:
			out.append(kind)
	return out


## 해적선은 한 척에 최대 PIRATES_PER_SHIP명을 태운다 (기획서 6장)
static func ship_count(wave: int, run_seed: int = 0) -> int:
	return ceili(pirate_count(wave, run_seed) / float(PIRATES_PER_SHIP))


## 개척자 비용 (골드, 식량): 기본 × (1 + 0.5 × (도시 수 − 1)), 반올림 (기획서 4장)
static func settler_cost(cities: int) -> Vector2i:
	var k: float = 1.0 + SETTLER_COST_RATE * maxi(cities - 1, 0)
	return Vector2i(roundi(SETTLER_COST.x * k), roundi(SETTLER_COST.y * k))


## 분대 수 상한: min(9, 3 + (도시 수 − 1)) (기획서 6장)
static func squad_cap(cities: int) -> int:
	return mini(SQUAD_CAP_MAX, SQUAD_CAP_BASE + SQUAD_CAP_PER_CITY * maxi(cities - 1, 0))


## 웨이브의 목표 도시 번호(0부터, 세운 순서). run_seed와 웨이브 번호로 정해 예고와 실제가 같다 (기획서 6장)
static func wave_target(wave: int, run_seed: int, cities: int) -> int:
	return posmod(hash([run_seed, wave, "target"]), maxi(cities, 1))


## 해적 체력·공격 배율: 살아 있는 도시 수에 비례 (기획서 6장)
static func enemy_mult(cities: int) -> float:
	return 1.0 + ENEMY_CITY_RATE * maxi(cities - 1, 0)

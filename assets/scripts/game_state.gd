extends Node
## 오토로드: 판 상태 — 자원과 웨이브 (기획서 5장, 7.5)

signal changed

var gold: int = Balance.START_GOLD
var food: int = Balance.START_FOOD
var wave: int = 1
var food_total: int = 0 ## 정산으로 번 식량 누적 (본부 레벨 기준)
var hq_level: int = 1
var research_points: int = 0 ## 연구수치가 기준을 넘을 때마다 +1 (기획서 5.4)
var research_progress: int = 0 ## 아직 연구포인트가 못 된 연구수치
var research_gained: int = 0 ## 연구수치로 얻은 연구포인트 수 (다음 기준을 정한다) (기획서 5.4)
var researched: Dictionary = {} ## 연구를 마친 항목 id → true (기획서 5.4)
var extra_guards: int = 0 ## 교역 NPC에게 산, 다음 전투의 추가 수비병 (1회성) (기획서 5.6)


func reset() -> void:
	gold = Balance.START_GOLD
	food = Balance.START_FOOD
	wave = 1
	food_total = 0
	hq_level = 1
	research_points = 0
	research_progress = 0
	research_gained = 0
	researched.clear()
	extra_guards = 0
	changed.emit()


func add(g: int, f: int) -> void:
	gold += g
	food += f
	if f > 0:
		food_total += f
	changed.emit()


## 연구수치를 쌓고 기준을 넘은 만큼 연구포인트로 바꾼다. 얻은 연구포인트를 돌려 준다 (기획서 5.4)
func add_research_progress(n: int) -> int:
	research_progress += n
	var gained: int = 0
	while research_progress >= Balance.research_threshold(research_gained):
		research_progress -= Balance.research_threshold(research_gained)
		research_gained += 1
		gained += 1
	research_points += gained
	changed.emit()
	return gained


## 식량 누적이 기준을 넘으면 본부 레벨을 올리고, 오른 레벨 수를 돌려 준다 (기획서 5.3)
func check_level() -> int:
	var up: int = 0
	while hq_level - 1 < Balance.HQ_LEVEL_FOOD.size() and food_total >= Balance.HQ_LEVEL_FOOD[hq_level - 1]:
		hq_level += 1
		up += 1
	if up > 0:
		changed.emit()
	return up


## 다음 레벨까지 필요한 식량 누적, 최고 레벨이면 -1
## 본부가 파괴되면 보유 골드·식량이 rate만큼 줄어든다(내림) (기획서 5.5)
func lose_share(rate: float) -> void:
	gold = floori(gold * (1.0 - rate))
	food = floori(food * (1.0 - rate))
	changed.emit()


func add_research(n: int) -> void:
	research_points += n
	changed.emit()


func has_tech(id: String) -> bool:
	return researched.has(id)


## 포인트가 충분하고 앞 단계를 마쳤으며 아직 안 한 연구인지
func can_research(id: String) -> bool:
	if researched.has(id):
		return false
	var pre: String = Balance.tech_prereq(id)
	return (pre == "" or researched.has(pre)) and research_points >= Balance.tech_cost(id)


func research(id: String) -> bool:
	if not can_research(id):
		return false
	research_points -= Balance.tech_cost(id)
	researched[id] = true
	changed.emit()
	return true


## 금융을 연구하면 건설·레벨업 비용이 15% 싸진다 (기획서 5.4)
func discounted(cost: int) -> int:
	return roundi(cost * (0.85 if has_tech("finance") else 1.0))


func next_level_food() -> int:
	return Balance.HQ_LEVEL_FOOD[hq_level - 1] if hq_level - 1 < Balance.HQ_LEVEL_FOOD.size() else -1


func spend(cost: int, food_cost: int = 0) -> bool:
	if gold < cost or food < food_cost:
		return false
	gold -= cost
	food -= food_cost
	changed.emit()
	return true


func next_wave() -> void:
	wave += 1
	changed.emit()

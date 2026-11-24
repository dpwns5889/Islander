extends Node
## 오토로드: 최고 웨이브 저장 (기획서 7.5, 9.1)

const PATH: String = "user://save.json"
var best_wave: int = 0


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			best_wave = int(d.get("best_wave", 0))


## 더 높은 웨이브면 갱신하고 저장한다. 갱신했으면 true
func record(wave: int) -> bool:
	if wave <= best_wave:
		return false
	best_wave = wave
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best_wave": best_wave}))
	return true

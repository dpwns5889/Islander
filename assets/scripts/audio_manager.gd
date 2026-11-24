extends Node
## 오토로드: 효과음 재생. assets/audio/sfx/<이름>.wav 를 읽어 재생한다 (기획서 7.5)

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last: Dictionary = {} ## 효과음 이름 → 마지막 재생 시각(ms). 같은 소리가 겹쳐 시끄럽지 않게 한다
const MIN_GAP_MS: int = 80


## 재생을 시작했으면 true, 파일이 없으면 false
func play(sfx_name: String) -> bool:
	var path: String = "res://assets/audio/sfx/%s.wav" % sfx_name
	if not _cache.has(sfx_name):
		_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _cache[sfx_name]
	if stream == null:
		return false
	var now: int = Time.get_ticks_msec()
	if now - int(_last.get(sfx_name, -MIN_GAP_MS)) < MIN_GAP_MS:
		return true
	_last[sfx_name] = now
	var player: AudioStreamPlayer = _free_player()
	player.stream = stream
	player.play()
	return true


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var np: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(np)
	_players.append(np)
	return np

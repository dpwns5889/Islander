extends Node
## 오토로드: 효과음 재생. assets/audio/sfx/<이름>.wav 를 읽어 재생한다 (기획서 7.5)

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}


## 재생을 시작했으면 true, 파일이 없으면 false
func play(sfx_name: String) -> bool:
	var path: String = "res://assets/audio/sfx/%s.wav" % sfx_name
	if not _cache.has(sfx_name):
		_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _cache[sfx_name]
	if stream == null:
		return false
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

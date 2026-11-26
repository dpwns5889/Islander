class_name PixelView
extends Node
## 도트 화면: 3D를 낮은 해상도로 그려 최근접으로 정수 배 확대하고, 글자는 원래 해상도로 따로 얹는다.
## 카메라는 픽셀 격자에 맞추고 남은 차이는 화면을 밀어 메운다 (기획서 7.2)

const POST_SHADER: Shader = preload("res://assets/shaders/pixel_post.gdshader")
const LABEL_LAYER: int = 2 ## 글자(Label3D)가 그려지는 3D 레이어 번호 (1은 일반 물체)

var camera: Camera3D ## 도트 화면을 그리는 카메라(격자에 맞춰 움직인다)
var enabled: bool = true ## 끄면 원래 해상도로 외곽선 없이 그린다. 저장하지 않아 시작은 늘 도트 (기획서 7.2)
var _post: MeshInstance3D
var _sub: SubViewport
var _tex: TextureRect
var _lsub: SubViewport
var _ltex: TextureRect
var _lcam: Camera3D
var _pos: Vector3 = Vector3(0, 20, 0)
var _pitch: float = 90.0
var _size: float = 18.0
var _k: float = 1.0 ## 도트 한 개가 화면에서 차지하는 크기(논리 픽셀)


func _ready() -> void:
	var back: CanvasLayer = CanvasLayer.new()
	back.layer = -2
	add_child(back)
	_tex = TextureRect.new()
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	back.add_child(_tex)
	_sub = SubViewport.new()
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.msaa_3d = Viewport.MSAA_DISABLED
	_sub.use_debanding = false
	add_child(_sub)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.cull_mask = 1
	_sub.add_child(camera)
	camera.current = true
	_post = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2, 2)
	_post.mesh = q
	_post.extra_cull_margin = 16384.0
	var pm: ShaderMaterial = ShaderMaterial.new()
	pm.shader = POST_SHADER
	pm.render_priority = 127 # 반투명 물체(격자·영역선·미리보기)를 다 그린 뒤 맨 마지막에 후처리한다
	_post.material_override = pm
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(_post)
	_post.position = Vector3(0, 0, -1)
	# 글자 전용 화면: 원래 해상도로 그려 도트 위에 얹는다
	var front: CanvasLayer = CanvasLayer.new()
	front.layer = -1
	add_child(front)
	_ltex = TextureRect.new()
	_ltex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ltex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ltex.stretch_mode = TextureRect.STRETCH_SCALE
	_ltex.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.add_child(_ltex)
	_lsub = SubViewport.new()
	_lsub.transparent_bg = true
	_lsub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_lsub)
	_lcam = Camera3D.new()
	_lcam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_lcam.cull_mask = LABEL_LAYER
	var lenv: Environment = Environment.new()
	lenv.background_mode = Environment.BG_CLEAR_COLOR
	_lcam.environment = lenv
	_lsub.add_child(_lcam)
	_lcam.current = true
	_ltex.texture = _lsub.get_texture()
	_tex.texture = _sub.get_texture()
	get_viewport().size_changed.connect(_resize)
	_resize()


## 도트 화면을 켜고 끈다 (기획서 7.2)
func set_enabled(on: bool) -> void:
	enabled = on
	_post.visible = on
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if on else CanvasItem.TEXTURE_FILTER_LINEAR
	_resize()


func _resize() -> void:
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var height: int = Balance.PIXEL_HEIGHT if enabled else maxi(1, get_window().size.y)
	_k = logical.y / float(height)
	if enabled:
		_k = maxf(1.0, _k)
	_sub.size = Vector2i(ceili(logical.x / _k) + 2, height + 2) # 위아래·양옆에 1도트씩 여유(카메라 격자 맞춤용)
	_tex.size = Vector2(_sub.size) * _k
	_lsub.size = Vector2i(maxi(1, get_window().size.x), maxi(1, get_window().size.y))


## 카메라가 바라볼 위치·기울기(도)·크기를 정한다. 실제 카메라는 매 프레임 도트 격자에 맞춰진다
func aim(pos: Vector3, pitch_deg: float, size: float) -> void:
	_pos = pos
	_pitch = pitch_deg
	_size = size


func _process(_delta: float) -> void:
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(-_pitch), 0.0, 0.0))
	var texel: float = _size / float(_sub.size.y - 2)
	var x: float = _pos.dot(basis.x)
	var y: float = _pos.dot(basis.y)
	var sx: float = roundf(x / texel) * texel
	var sy: float = roundf(y / texel) * texel
	camera.transform = Transform3D(basis, _pos + basis.x * (sx - x) + basis.y * (sy - y))
	camera.size = texel * float(_sub.size.y)
	_tex.position = Vector2(-_k, -_k) + Vector2(sx - x, -(sy - y)) / texel * _k # 남은 차이만큼 화면을 민다
	_lcam.transform = Transform3D(basis, _pos)
	_lcam.size = _size


## 논리 화면 좌표 → 3D 광선 [시작점, 방향]
func ray(mouse: Vector2) -> Array[Vector3]:
	var p: Vector2 = (mouse - _tex.position) / _k
	return [camera.project_ray_origin(p), camera.project_ray_normal(p)]

class_name Toon
extends RefCounted
## 3단계 빛 재질: 색 하나로 만든다 (기획서 7.2)

static var _shader: Shader = load("res://assets/shaders/toon.gdshader")


static var _models: Dictionary = {} ## 모델 경로 → {mesh, tex}


static func material(color: Color, tex: Texture2D = null) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", color)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
	return m


## glb 모델의 첫 메시와 팔레트 텍스처를 한 번만 읽어 둔다 (기획서 7.2)
static func model(path: String) -> Dictionary:
	if not _models.has(path):
		var root: Node = (load(path) as PackedScene).instantiate()
		var mi: MeshInstance3D = _first_mesh(root)
		var tex: Texture2D = null
		var src: Material = mi.mesh.surface_get_material(0)
		if src is BaseMaterial3D:
			tex = (src as BaseMaterial3D).albedo_texture
		_models[path] = {"mesh": mi.mesh, "tex": tex}
		root.free()
	return _models[path]


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _first_mesh(c)
		if r != null:
			return r
	return null


## 재질의 색을 바꾼다 (건물 피해 표시 등). 일반 재질도 받는다
static func set_color(m: Material, color: Color) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("albedo", color)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = color

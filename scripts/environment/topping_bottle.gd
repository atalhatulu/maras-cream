class_name ToppingBottle
extends StaticBody3D

@export var topping_data: ToppingData
@export var bottle_mesh: MeshInstance3D
@export var label_3d: Label3D

var _base_pos: Vector3
var _base_rot: Vector3
var _base_scale: Vector3
var _is_animating: bool = false
var _original_materials: Array[Material] = []

func _ready() -> void:
	_base_pos = position
	_base_rot = rotation
	_base_scale = scale
	_cache_materials()
	_update_visual()

func _cache_materials() -> void:
	if bottle_mesh:
		for i in range(bottle_mesh.get_surface_override_material_count()):
			_original_materials.append(bottle_mesh.get_surface_override_material(i))

func _update_visual() -> void:
	if topping_data and label_3d:
		label_3d.text = topping_data.topping_name
		label_3d.modulate = topping_data.color.lightened(0.35)

func interact() -> void:
	if _is_animating or topping_data == null:
		return
		
	_is_animating = true
	var lift_pos = _base_pos + Vector3(-0.06, 0.08, -0.04)
	var tilt_rot = _base_rot + Vector3(deg_to_rad(45.0), 0, deg_to_rad(20.0))
	var squeeze_scale = Vector3(0.85, 1.15, 0.85)
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	
	# 1. Havalanma ve Külaha Doğru Eğilme
	tween.set_parallel(true)
	tween.tween_property(self, "position", lift_pos, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", tilt_rot, 0.12).set_ease(Tween.EASE_OUT)
	
	# 2. Şişeyi Sıkma Puls Efekti & Sos Dökümü
	tween.chain().set_parallel(true)
	tween.tween_property(self, "scale", squeeze_scale, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		EventBus.topping_applied.emit(topping_data)
	)
	
	# 3. Şişeyi Eski Haline Getirme ve Masaya Yaylanarak İniş
	tween.chain().set_parallel(true)
	tween.tween_property(self, "scale", _base_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _base_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", _base_rot, 0.22).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		_is_animating = false
	)

func set_highlight(is_on: bool) -> void:
	if bottle_mesh == null:
		return
		
	if is_on:
		var highlight_mat = StandardMaterial3D.new()
		if topping_data:
			highlight_mat.albedo_color = topping_data.color.lightened(0.2)
			highlight_mat.emission_enabled = true
			highlight_mat.emission = topping_data.color
			highlight_mat.emission_energy_multiplier = 0.4
		bottle_mesh.material_override = highlight_mat
	else:
		bottle_mesh.material_override = null

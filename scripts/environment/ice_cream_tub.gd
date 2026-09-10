class_name IceCreamTub
extends StaticBody3D

@export var flavor: FlavorData
@export var tub_name_label_3d: Label3D
@export var ice_cream_surface_mesh: MeshInstance3D

var _is_highlighted: bool = false
var _surface_mat: StandardMaterial3D

func _ready() -> void:
	_apply_flavor_visuals()

func set_flavor(new_flavor: FlavorData) -> void:
	flavor = new_flavor
	_apply_flavor_visuals()

func is_unlocked() -> bool:
	if flavor == null:
		return false
	return GameManager.is_flavor_unlocked(flavor.id)

func _apply_flavor_visuals() -> void:
	if flavor == null:
		return
		
	var unlocked = is_unlocked()
	
	if tub_name_label_3d:
		if unlocked:
			tub_name_label_3d.text = flavor.flavor_name
			tub_name_label_3d.modulate = Color.WHITE
		else:
			tub_name_label_3d.text = "[KİLİTLİ]\n" + flavor.flavor_name
			tub_name_label_3d.modulate = Color(0.7, 0.7, 0.75, 0.8)
		
	if ice_cream_surface_mesh:
		_surface_mat = StandardMaterial3D.new()
		if unlocked:
			_surface_mat.albedo_color = flavor.color
			_surface_mat.roughness = 0.55
			_surface_mat.metallic = 0.0
		else:
			# Kilitli metal kapak dokusu
			_surface_mat.albedo_color = Color(0.28, 0.3, 0.34, 1.0)
			_surface_mat.roughness = 0.3
			_surface_mat.metallic = 0.85
		ice_cream_surface_mesh.material_override = _surface_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _surface_mat == null or flavor == null:
		return
		
	_is_highlighted = enabled
	var unlocked = is_unlocked()
	if enabled:
		_surface_mat.emission_enabled = true
		if unlocked:
			_surface_mat.emission = flavor.color * 0.4
			if tub_name_label_3d:
				tub_name_label_3d.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			_surface_mat.emission = Color(0.8, 0.2, 0.2, 1.0) * 0.3
			if tub_name_label_3d:
				tub_name_label_3d.modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		_surface_mat.emission_enabled = false
		if tub_name_label_3d:
			tub_name_label_3d.modulate = Color.WHITE if unlocked else Color(0.7, 0.7, 0.75, 0.8)

func get_flavor() -> FlavorData:
	return flavor

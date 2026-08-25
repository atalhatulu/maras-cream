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

func _apply_flavor_visuals() -> void:
	if flavor == null:
		return
		
	if tub_name_label_3d:
		tub_name_label_3d.text = flavor.flavor_name
		
	if ice_cream_surface_mesh:
		_surface_mat = StandardMaterial3D.new()
		_surface_mat.albedo_color = flavor.color
		_surface_mat.roughness = 0.55
		ice_cream_surface_mesh.material_override = _surface_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _surface_mat == null or flavor == null:
		return
		
	_is_highlighted = enabled
	if enabled:
		_surface_mat.emission_enabled = true
		_surface_mat.emission = flavor.color * 0.4
		if tub_name_label_3d:
			tub_name_label_3d.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		_surface_mat.emission_enabled = false
		if tub_name_label_3d:
			tub_name_label_3d.modulate = Color.WHITE

func get_flavor() -> FlavorData:
	return flavor

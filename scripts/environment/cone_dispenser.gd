class_name ConeDispenser
extends StaticBody3D

@export var dispenser_label: Label3D
@export var tube_mesh: MeshInstance3D

var _is_highlighted: bool = false
var _tube_mat: StandardMaterial3D

func _ready() -> void:
	if dispenser_label:
		dispenser_label.text = "Külah Standı"
	if tube_mesh == null:
		tube_mesh = get_node_or_null("DispenserTube")
	if tube_mesh:
		_tube_mat = StandardMaterial3D.new()
		_tube_mat.albedo_color = Color(0.75, 0.78, 0.82, 1.0)
		_tube_mat.metallic = 0.8
		_tube_mat.roughness = 0.3
		tube_mesh.material_override = _tube_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _tube_mat == null:
		return
		
	_is_highlighted = enabled
	if enabled:
		_tube_mat.emission_enabled = true
		_tube_mat.emission = Color(0.3, 0.5, 0.8, 1.0) * 0.4
		if dispenser_label:
			dispenser_label.modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		_tube_mat.emission_enabled = false
		if dispenser_label:
			dispenser_label.modulate = Color.WHITE

func interact() -> void:
	EventBus.cone_dispenser_interacted.emit()

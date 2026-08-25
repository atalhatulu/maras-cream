class_name TrashCan
extends StaticBody3D

@export var trash_label: Label3D
@export var trash_body_mesh: MeshInstance3D

var _is_highlighted: bool = false
var _body_mat: StandardMaterial3D

func _ready() -> void:
	if trash_label:
		trash_label.text = "Çöp Kutusu"
	if trash_body_mesh == null:
		trash_body_mesh = get_node_or_null("TrashBody")
	if trash_body_mesh:
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = Color(0.22, 0.24, 0.27, 1.0)
		_body_mat.roughness = 0.6
		trash_body_mesh.material_override = _body_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _body_mat == null:
		return
		
	_is_highlighted = enabled
	if enabled:
		_body_mat.emission_enabled = true
		_body_mat.emission = Color(0.8, 0.3, 0.2, 1.0) * 0.35
		if trash_label:
			trash_label.modulate = Color(1.2, 1.0, 1.0, 1.0)
	else:
		_body_mat.emission_enabled = false
		if trash_label:
			trash_label.modulate = Color.WHITE

func interact() -> void:
	EventBus.trash_can_interacted.emit()

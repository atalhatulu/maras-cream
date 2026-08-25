class_name TubSwitchButton
extends StaticBody3D

@export var button_mesh: MeshInstance3D
@export var button_label: Label3D

var _is_highlighted: bool = false
var _button_mat: StandardMaterial3D
var _base_pos: Vector3
var _is_pressing: bool = false

func _ready() -> void:
	_base_pos = position
	if button_mesh == null:
		button_mesh = get_node_or_null("ButtonMesh")
	if button_label == null:
		button_label = get_node_or_null("ButtonLabel")
		
	if button_label:
		button_label.text = "Sıra Değiştir"
		
	if button_mesh:
		_button_mat = StandardMaterial3D.new()
		_button_mat.albedo_color = Color(0.85, 0.22, 0.18, 1.0) # Parlak Kırmızı Buton
		_button_mat.roughness = 0.4
		button_mesh.material_override = _button_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _button_mat == null:
		return
		
	_is_highlighted = enabled
	if enabled:
		_button_mat.emission_enabled = true
		_button_mat.emission = Color(1.0, 0.4, 0.2, 1.0) * 0.5
		if button_label:
			button_label.modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		_button_mat.emission_enabled = false
		if button_label:
			button_label.modulate = Color.WHITE

func interact() -> void:
	if _is_pressing:
		return
		
	_is_pressing = true
	EventBus.tub_switch_interacted.emit()
	
	# Butona basılma yaylanma animasyonu
	var tween = create_tween()
	tween.tween_property(self, "position:y", _base_pos.y - 0.02, 0.08)
	tween.tween_property(self, "position:y", _base_pos.y, 0.12)
	tween.tween_callback(func():
		_is_pressing = false
	)

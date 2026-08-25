class_name PlayerController
extends Node3D

@export_group("Kamera Ayarları")
@export var mouse_sensitivity: float = 0.002
@export var smooth_speed: float = 22.0
@export var yaw_limit_deg: float = 70.0
@export var pitch_min_deg: float = -68.0
@export var pitch_max_deg: float = 45.0

@export_group("Kamera Eğilme ve Paralaks (Leaning)")
@export var lean_strength_x: float = 0.08
@export var lean_strength_y: float = 0.04
@export var lean_strength_z: float = 0.06
@export var camera_lean_smooth: float = 14.0

@export_group("Kol Salınım Fiziği (Procedural Arms)")
@export var sway_pos_strength: float = 0.04
@export var sway_rot_strength: float = 0.65
@export var sway_smooth: float = 14.0
@export var breathing_speed: float = 1.6
@export var breathing_pos_amount: float = 0.002
@export var breathing_rot_amount: float = 0.008

@onready var camera: Camera3D = $Camera3D
@onready var interaction_raycast: RayCast3D = $Camera3D/InteractionRayCast
@onready var left_hand: LeftHandController = $Camera3D/LeftHandRig
@onready var right_hand: RightHandController = $Camera3D/RightHandRig

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _current_yaw: float = 0.0
var _current_pitch: float = 0.0

var _base_camera_pos: Vector3 = Vector3(0, 1.45, 0)
var _left_hand_base_pos: Vector3
var _right_hand_base_pos: Vector3

var _right_hand_sway_pos: Vector2 = Vector2.ZERO
var _right_hand_sway_rot: Vector3 = Vector3.ZERO
var _idle_time: float = 0.0

var is_mouse_captured: bool = true
var _is_interacting_held: bool = false
var _is_active_scoop_dive: bool = false
var _current_highlighted_target: Object = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		_base_camera_pos = camera.position
	if left_hand:
		_left_hand_base_pos = left_hand.position
	if right_hand:
		_right_hand_base_pos = right_hand.position
		
	EventBus.scoop_filled.connect(func(_f): _is_active_scoop_dive = false)
	EventBus.scoop_dive_cancelled.connect(func(): _is_active_scoop_dive = false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			is_mouse_captured = true
			return
			
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			is_mouse_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			is_mouse_captured = true
		return

	if is_mouse_captured:
		if event.is_action_pressed("interact"):
			_is_interacting_held = true
			var collider = get_interacted_collider()
			_handle_interact_pressed(collider)
			return
			
		elif event.is_action_released("interact"):
			_is_interacting_held = false
			if _is_active_scoop_dive:
				_is_active_scoop_dive = false
				if right_hand:
					right_hand.end_dive()
			return
			
		elif event.is_action_pressed("secondary_interact"):
			EventBus.place_on_cone_attempted.emit()
			return

	if is_mouse_captured and event is InputEventMouseMotion:
		if _is_active_scoop_dive and right_hand and right_hand.is_diving:
			# Dondurma kepçeleme sırasında kamera tamamen sabit kalır, fare sadece kepçelemeyi çeker
			right_hand.process_dive_mouse_input(event.relative)
			return
			
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_pitch -= event.relative.y * mouse_sensitivity
		
		var mouse_rel_x = event.relative.x * 0.001
		var mouse_rel_y = event.relative.y * 0.001
		
		# Sağ elin fare hareketini doğrudan ve dinamik takip etmesi (Mouse-driven leading drag)
		_right_hand_sway_pos.x = clampf(_right_hand_sway_pos.x - mouse_rel_x * sway_pos_strength * 22.0, -0.05, 0.05)
		_right_hand_sway_pos.y = clampf(_right_hand_sway_pos.y + mouse_rel_y * sway_pos_strength * 18.0, -0.04, 0.04)
		
		_right_hand_sway_rot.y = clampf(_right_hand_sway_rot.y - mouse_rel_x * sway_rot_strength * 16.0, -0.16, 0.16)
		_right_hand_sway_rot.x = clampf(_right_hand_sway_rot.x + mouse_rel_y * sway_rot_strength * 16.0, -0.12, 0.12)
		_right_hand_sway_rot.z = clampf(_right_hand_sway_rot.z - mouse_rel_x * sway_rot_strength * 12.0, -0.10, 0.10)
		
		var yaw_limit_rad = deg_to_rad(yaw_limit_deg)
		var pitch_min_rad = deg_to_rad(pitch_min_deg)
		var pitch_max_rad = deg_to_rad(pitch_max_deg)
		
		_target_yaw = clampf(_target_yaw, -yaw_limit_rad, yaw_limit_rad)
		_target_pitch = clampf(_target_pitch, pitch_min_rad, pitch_max_rad)

func _handle_interact_pressed(collider: Object) -> void:
	if collider is IceCreamTub:
		var flavor = collider.get_flavor()
		if right_hand and right_hand.has_ice_cream():
			EventBus.notification_requested.emit("Kepçede zaten dondurma var!", 1.2)
			return
			
		_is_active_scoop_dive = true
		var hit_pos = interaction_raycast.get_collision_point() if (interaction_raycast and interaction_raycast.is_colliding()) else collider.global_position
		EventBus.scoop_dive_started.emit(collider, flavor, hit_pos)
		return
		
	if collider is MarasBell:
		collider.interact()
		return
		
	if collider is TubSwitchButton:
		collider.interact()
		return
		
	if collider is ConeDispenser:
		collider.interact()
		return
		
	if collider is ToppingBottle:
		collider.interact()
		return
		
	if collider is TrashCan:
		collider.interact()
		return
		
	if collider is Customer or (collider and collider.is_in_group("customer")):
		EventBus.order_delivery_attempted.emit()
		return

	if collider and (collider.is_in_group("cone_target") or collider is LeftHandController):
		EventBus.place_on_cone_attempted.emit()
		return

	# Akıllı Teslimat: Sol elde külah varken tezgaha veya karşıya bakıp [E] basıldığında teslimatı dene
	if left_hand and left_hand.has_cone():
		EventBus.order_delivery_attempted.emit()
		return

func _process(delta: float) -> void:
	var safe_delta = min(delta, 0.05)
	_idle_time += safe_delta * breathing_speed
	_current_yaw = lerp_angle(_current_yaw, _target_yaw, smooth_speed * safe_delta)
	_current_pitch = lerp_angle(_current_pitch, _target_pitch, smooth_speed * safe_delta)
	
	rotation.y = _current_yaw
	camera.rotation.x = _current_pitch
	
	_update_camera_translational_motion(safe_delta)
	_update_hands_procedural_motion(safe_delta)
	_update_interaction_highlight()

func _update_camera_translational_motion(delta: float) -> void:
	if not camera:
		return
		
	var target_cam_x = _base_camera_pos.x + (_current_yaw * lean_strength_x)
	var pitch_ratio = _current_pitch / deg_to_rad(pitch_min_deg)
	var target_cam_y = _base_camera_pos.y - (pitch_ratio * lean_strength_y)
	var target_cam_z = _base_camera_pos.z - (pitch_ratio * lean_strength_z)
	
	var target_pos = Vector3(target_cam_x, target_cam_y, target_cam_z)
	camera.position = camera.position.lerp(target_pos, camera_lean_smooth * delta)

func _update_interaction_highlight() -> void:
	var current_collider = get_interacted_collider()
	
	if current_collider != _current_highlighted_target:
		if _current_highlighted_target and _current_highlighted_target.has_method("set_highlight"):
			_current_highlighted_target.set_highlight(false)
			
		_current_highlighted_target = current_collider
		
		if _current_highlighted_target and _current_highlighted_target.has_method("set_highlight"):
			_current_highlighted_target.set_highlight(true)
			
		var hint_text = _get_tooltip_for_collider(current_collider)
		EventBus.interaction_target_changed.emit(hint_text)

func _get_tooltip_for_collider(col: Object) -> String:
	if col == null:
		return ""
	if col is IceCreamTub:
		if col.flavor:
			return "[Sol Tık] %s Al" % col.flavor.flavor_name
		return "[Sol Tık] Dondurma Kepçele"
	if col is ConeDispenser:
		return "[Sol Tık] Külah Al"
	if col is ToppingBottle:
		if col.topping_data:
			return "[Sol Tık] %s Kullan" % col.topping_data.topping_name
		return "[Sol Tık] Sos Kullan"
	if col is MarasBell:
		return "[Sol Tık] Zile Vur"
	if col is TrashCan:
		return "[Sol Tık] Külahı Çöpe At"
	if col is Customer or (col and col.is_in_group("customer")):
		return "[E] Kuleyi Teslim Et"
	if col and (col.is_in_group("cone_target") or col is LeftHandController):
		return "[Sol Tık] Külaha Bırak"
	return ""

func _update_hands_procedural_motion(delta: float) -> void:
	# Sağ el salınımının merkeze dönme lerp'i
	_right_hand_sway_pos = _right_hand_sway_pos.lerp(Vector2.ZERO, sway_smooth * delta)
	_right_hand_sway_rot = _right_hand_sway_rot.lerp(Vector3.ZERO, (sway_smooth * 0.8) * delta)
	
	var breath_y = sin(_idle_time) * breathing_pos_amount
	var breath_x = cos(_idle_time * 0.5) * (breathing_pos_amount * 0.6)
	var breath_roll = sin(_idle_time * 0.7) * breathing_rot_amount
	
	# Tezgaha eğilindiğinde ellerin tezgaha batmaması için geriye/yukarı toparlanması
	var down_pitch_ratio = clampf(_current_pitch / deg_to_rad(pitch_min_deg), 0.0, 1.0)
	var retract_y = down_pitch_ratio * 0.05
	var retract_z = down_pitch_ratio * 0.08
	
	# 1. SOL EL (KÜLAH): Fare hareketlerinden bağımsız, ekranda sabit ve stabil dayanak
	if left_hand and not left_hand.is_reaching_cone:
		var left_breath_offset = Vector3(breath_x * 0.3, (breath_y * 0.3) + retract_y, retract_z)
		var balance_tilt_offset = 0.0
		if left_hand.has_cone():
			balance_tilt_offset = -deg_to_rad(left_hand.current_angle_deg * 0.10)
			
		left_hand.position = left_hand.position.lerp(_left_hand_base_pos + left_breath_offset, 16.0 * delta)
		left_hand.rotation.x = lerp_angle(left_hand.rotation.x, 0.0, 14.0 * delta)
		left_hand.rotation.y = lerp_angle(left_hand.rotation.y, 0.0, 14.0 * delta)
		left_hand.rotation.z = lerp_angle(left_hand.rotation.z, balance_tilt_offset + (breath_roll * 0.2), 14.0 * delta)
		
	# 2. SAĞ EL (KEPÇE): Fare hareketleriyle dinamik süzülen ve hedefe yönelen akıcı kepçe
	if right_hand and not right_hand.is_diving and not right_hand.is_animating:
		var right_pos_offset = Vector3(_right_hand_sway_pos.x + breath_x, _right_hand_sway_pos.y + breath_y + retract_y, retract_z)
		var right_target_rot = Vector3(_right_hand_sway_rot.x, _right_hand_sway_rot.y, _right_hand_sway_rot.z + breath_roll)
		
		right_hand.position = right_hand.position.lerp(_right_hand_base_pos + right_pos_offset, sway_smooth * delta)
		right_hand.rotation.x = lerp_angle(right_hand.rotation.x, right_target_rot.x, 14.0 * delta)
		right_hand.rotation.y = lerp_angle(right_hand.rotation.y, right_target_rot.y, 14.0 * delta)
		right_hand.rotation.z = lerp_angle(right_hand.rotation.z, right_target_rot.z, 14.0 * delta)

func get_interacted_collider() -> Object:
	if interaction_raycast and interaction_raycast.is_colliding():
		return interaction_raycast.get_collider()
	return null

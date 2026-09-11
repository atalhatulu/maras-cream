class_name LeftHandController
extends Node3D

enum ConeState {
	NONE,
	EMPTY,
	PREPARING,
	COMPLETED,
	DROPPED,
	DISCARDED
}

const SCOOP_RADIUS: float = 0.038
const SCOOP_STACK_SPACING: float = 0.046

@export_group("Denge Fiziği Parametreleri")
@export var max_safe_angle_deg: float = 52.0 # Devrilme kritik açısı (Daha geniş tolerans)
@export var balance_input_power: float = 72.0 # A/D maksimum tork gücü
@export var input_accel_rate: float = 380.0 # Girdinin maksimum güce ulaşma ivmesi
@export var damping_factor: float = 3.6 # Sürtünme ve sönümlenme oranı
@export var base_inertia: float = 1.0 # Temel eylemsizlik momenti

@export_group("Top Yaylanma Fiziği (Spring)")
@export var scoop_spring_stiffness: float = 140.0
@export var scoop_spring_damping: float = 9.0

@onready var cone_pivot: Node3D = $ConePivot
@onready var cone_mesh: Node3D = $ConePivot/ConePlaceholder
@onready var scoop_container: Node3D = $ConePivot/ScoopContainer
@onready var stack_marker: Marker3D = $ConePivot/ConeStackMarker

# Durum Değişkenleri
var state: ConeState = ConeState.NONE
var current_angle_deg: float = 0.0
var angular_velocity: float = 0.0
var stacked_flavors: Array[FlavorData] = []
var applied_toppings: Array[ToppingData] = []

# Fizik dahili değişkenleri
var _current_input_torque: float = 0.0
var _physics_time: float = 0.0
var _is_transferring: bool = false
var is_reaching_cone: bool = false
var _base_local_pos: Vector3

# Her top için bağımsız yay ofsetleri ve zincir açıları
var _scoop_offsets: Array[Vector3] = []
var _scoop_vels: Array[Vector3] = []
var _scoop_angles: Array[float] = []
var current_balance_tolerance: float = 1.0

# Şov ve Kurtarma Durumları
var is_flipping: bool = false
var is_clutch_active: bool = false
var clutch_used_this_cone: bool = false
var _clutch_timer: float = 0.0
var _clutch_fall_dir: float = 0.0
const CLUTCH_WINDOW_DURATION: float = 0.52

func _ready() -> void:
	_base_local_pos = position
	cone_pivot.visible = false
	EventBus.place_on_cone_attempted.connect(_on_place_on_cone_attempted)
	EventBus.cone_dispenser_interacted.connect(_on_cone_dispenser_interacted)
	EventBus.trash_can_interacted.connect(_on_trash_can_interacted)
	EventBus.topping_applied.connect(_on_topping_applied)
	EventBus.cone_reset.connect(reset_cone)
	EventBus.customer_arrived.connect(func(cust, _ord):
		if cust and "archetype" in cust and cust.archetype:
			current_balance_tolerance = cust.archetype.balance_tolerance
		else:
			current_balance_tolerance = 1.0
	)
	EventBus.customer_left.connect(func(_c):
		current_balance_tolerance = 1.0
	)
	_notify_state_changed()

func _process(delta: float) -> void:
	var safe_delta = min(delta, 0.05)
	if has_cone():
		_simulate_balance_physics(safe_delta)
		_simulate_scoops_secondary_motion(safe_delta)
		_update_visual_tilt(safe_delta)
	else:
		current_angle_deg = 0.0
		angular_velocity = 0.0
		_current_input_torque = 0.0
		EventBus.cone_balance_updated.emit(0.0, 0.0)

func _simulate_balance_physics(delta: float) -> void:
	if is_flipping:
		current_angle_deg = 0.0
		angular_velocity = 0.0
		_current_input_torque = 0.0
		EventBus.cone_balance_updated.emit(0.0, 0.0)
		return
		
	if is_clutch_active:
		_clutch_timer -= delta
		var jitter = randf_range(-0.015, 0.015)
		if cone_pivot:
			cone_pivot.position.x += jitter
			
		var clutch_input = Input.get_axis("balance_left", "balance_right")
		if clutch_input * _clutch_fall_dir < -0.30:
			_clutch_recover()
			return
			
		if _clutch_timer <= 0.0:
			is_clutch_active = false
			EventBus.clutch_catch_failed.emit()
			_trigger_cone_drop()
		return

	_physics_time += delta
	var scoop_count = stacked_flavors.size()
	
	if scoop_count == 0:
		_current_input_torque = 0.0
		current_angle_deg = move_toward(current_angle_deg, 0.0, 45.0 * delta)
		angular_velocity = 0.0
		EventBus.cone_balance_updated.emit(0.0, current_angle_deg)
		return
		
	var input_axis = Input.get_axis("balance_left", "balance_right")
	
	# Toparlama Desteği + Dükkan Recovery Torque Upgrade'i
	var is_correcting = (input_axis > 0 and current_angle_deg < 0) or (input_axis < 0 and current_angle_deg > 0)
	var torque_upgrade = GameManager.get_upgrade_effect("recovery_torque", "torque_boost")
	var active_power = balance_input_power * (1.40 if is_correcting else 1.0) * (1.0 + torque_upgrade)
	
	var target_torque = input_axis * active_power
	_current_input_torque = move_toward(_current_input_torque, target_torque, input_accel_rate * delta)
	
	var moment_of_inertia = base_inertia + (float(scoop_count) * 0.18)
	var com_height_factor = 1.0 + (float(scoop_count) * 0.14)
	
	var gravity_torque = sin(deg_to_rad(current_angle_deg)) * (10.0 + float(scoop_count) * 3.8) * com_height_factor
	var gentle_sway = sin(_physics_time * 2.2) * (0.35 + float(scoop_count) * 0.22)
	
	var total_torque = gravity_torque + gentle_sway + _current_input_torque
	var angular_accel = total_torque / moment_of_inertia
	
	angular_velocity += angular_accel * delta
	angular_velocity -= angular_velocity * damping_factor * delta
	current_angle_deg += angular_velocity * delta
	
	var stability_angle_bonus = GameManager.get_upgrade_effect("cone_stability", "angle_tolerance")
	var effective_max_angle = (max_safe_angle_deg + stability_angle_bonus) * current_balance_tolerance
	var balance_ratio = clampf(current_angle_deg / effective_max_angle, -1.0, 1.0)
	EventBus.cone_balance_updated.emit(balance_ratio, current_angle_deg)
	
	# Gerilim Tansiyonu: %72 ve üstü kritik açıda külah titremesi ve gerilim uyarısı
	var tilt_severity = abs(balance_ratio)
	if tilt_severity >= 0.72 and cone_pivot:
		var jitter = (tilt_severity - 0.72) * 0.025
		cone_pivot.position.x += randf_range(-jitter, jitter)
		cone_pivot.position.z += randf_range(-jitter, jitter)
		EventBus.cone_critical_tilt.emit(tilt_severity)
	
	if abs(current_angle_deg) >= effective_max_angle:
		if not clutch_used_this_cone and scoop_count >= 2:
			_start_clutch_window(1.0 if current_angle_deg > 0 else -1.0)
		else:
			_trigger_cone_drop()

func _simulate_scoops_secondary_motion(delta: float) -> void:
	var count = stacked_flavors.size()
	while _scoop_offsets.size() < count:
		_scoop_offsets.append(Vector3.ZERO)
		_scoop_vels.append(Vector3.ZERO)
		_scoop_angles.append(0.0)
		
	# Zincirleme Jöle ve Esneme Fiziği (Chain Link S-Curve)
	var prev_angle = current_angle_deg
	for i in range(count):
		# Kule uzadıkça üstteki toplar komik bir dalga halinde gecikmeli kıvrılır
		var target_angle = prev_angle * 1.12 + sin(_physics_time * 3.0 + float(i) * 0.8) * (1.2 + float(i) * 0.4)
		_scoop_angles[i] = lerpf(_scoop_angles[i], target_angle, (18.0 - float(i) * 0.8) * delta)
		prev_angle = _scoop_angles[i]
		
		var spring_force = -_scoop_offsets[i] * scoop_spring_stiffness
		var damping_force = -_scoop_vels[i] * scoop_spring_damping
		var lateral_inertia = Vector3(-angular_velocity * 0.0004 * float(i + 1), 0, 0)
		
		_scoop_vels[i] += (spring_force + damping_force + lateral_inertia) * delta
		_scoop_offsets[i] += _scoop_vels[i] * delta
		_scoop_offsets[i] = _scoop_offsets[i].clamp(Vector3(-0.03, -0.02, -0.03), Vector3(0.03, 0.02, 0.03))

func _update_visual_tilt(delta: float) -> void:
	if not cone_pivot:
		return
		
	cone_pivot.rotation.z = -deg_to_rad(current_angle_deg)
	
	# Absürt Kule Yüksekliğini Ekrana Sığdırma (Dynamic Lowering)
	var scoop_count = stacked_flavors.size()
	var target_pivot_y = 0.05 - (float(scoop_count) * 0.016)
	cone_pivot.position.y = lerpf(cone_pivot.position.y, target_pivot_y, 8.0 * delta)
	
	var children = scoop_container.get_children()
	var base_y = stack_marker.position.y if stack_marker else 0.14
	
	for i in range(children.size()):
		var scoop_node = children[i] as Node3D
		if scoop_node:
			var target_rot = -deg_to_rad(_scoop_angles[i] if i < _scoop_angles.size() else current_angle_deg)
			scoop_node.rotation.z = lerp_angle(scoop_node.rotation.z, target_rot, 20.0 * delta)
			
			var default_y = base_y + (i * SCOOP_STACK_SPACING)
			var spring_offset = _scoop_offsets[i] if i < _scoop_offsets.size() else Vector3.ZERO
			scoop_node.position = Vector3(spring_offset.x, default_y + spring_offset.y, spring_offset.z)

func _on_cone_dispenser_interacted() -> void:
	if has_cone():
		EventBus.notification_requested.emit("Zaten elinde bir külah var!", 1.2)
		return
		
	if is_reaching_cone:
		return
		
	reach_and_take_cone()

func reach_and_take_cone() -> void:
	is_reaching_cone = true
	
	var reach_pos = _base_local_pos + Vector3(-0.46, -0.26, -0.44)
	var reach_rot = Vector3(deg_to_rad(28.0), deg_to_rad(22.0), -deg_to_rad(16.0))
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	
	tween.set_parallel(true)
	tween.tween_property(self, "position", reach_pos, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", reach_rot, 0.18).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		take_cone()
	)
	
	var pull_pos = reach_pos + Vector3(0.08, 0.12, 0.10)
	var pull_rot = Vector3(deg_to_rad(10.0), deg_to_rad(8.0), -deg_to_rad(5.0))
	tween.set_parallel(true)
	tween.tween_property(self, "position", pull_pos, 0.10).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", pull_rot, 0.10).set_ease(Tween.EASE_OUT)
	
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", _base_local_pos, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", Vector3.ZERO, 0.26).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_reaching_cone = false
	)

func _on_trash_can_interacted() -> void:
	if not has_cone():
		EventBus.notification_requested.emit("Çöpe atılacak bir külah yok!", 1.2)
		return
		
	discard_cone_to_trash()

func take_cone() -> void:
	state = ConeState.EMPTY
	cone_pivot.visible = true
	cone_pivot.position = Vector3(0, 0.05, -0.05)
	cone_pivot.rotation = Vector3.ZERO
	cone_pivot.scale = Vector3.ONE
	
	current_angle_deg = 0.0
	angular_velocity = 0.0
	_current_input_torque = 0.0
	is_flipping = false
	is_clutch_active = false
	clutch_used_this_cone = false
	_clutch_timer = 0.0
	stacked_flavors.clear()
	applied_toppings.clear()
	_clear_scoop_meshes()
	_scoop_offsets.clear()
	_scoop_vels.clear()
	_scoop_angles.clear()
	
	_notify_state_changed()
	EventBus.cone_taken.emit()
	EventBus.notification_requested.emit("Külah alındı.", 1.2)

func discard_cone_to_trash() -> void:
	state = ConeState.DISCARDED
	_notify_state_changed()
	EventBus.cone_discarded.emit()
	EventBus.notification_requested.emit("Külah çöpe atıldı.", 1.2)
	
	var throw_tween = create_tween().set_parallel(true)
	throw_tween.tween_property(cone_pivot, "position", cone_pivot.position + Vector3(0.6, -0.4, -0.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	throw_tween.tween_property(cone_pivot, "rotation:z", deg_to_rad(120), 0.35)
	throw_tween.tween_property(cone_pivot, "scale", Vector3.ZERO, 0.35)
	
	throw_tween.chain().tween_callback(func():
		cone_pivot.visible = false
		reset_cone()
	)

func _trigger_cone_drop() -> void:
	state = ConeState.DROPPED
	_notify_state_changed()
	EventBus.cone_dropped.emit()
	EventBus.notification_requested.emit("Devasa dondurma kulesi devrildi!", 2.2)
	
	var fall_tween = create_tween().set_parallel(true)
	var fall_dir = 1.0 if current_angle_deg > 0 else -1.0
	fall_tween.tween_property(cone_pivot, "position", cone_pivot.position + Vector3(fall_dir * 0.4, -0.8, -0.2), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(cone_pivot, "rotation:z", deg_to_rad(fall_dir * 180), 0.4)
	fall_tween.tween_property(cone_pivot, "scale", Vector3.ZERO, 0.4)
	
	fall_tween.chain().tween_callback(func():
		cone_pivot.visible = false
		reset_cone()
	)

func _on_topping_applied(topping: ToppingData) -> void:
	if not has_cone() or stacked_flavors.is_empty():
		EventBus.notification_requested.emit("Önce külaha dondurma koymalısın!", 1.2)
		return
		
	for t in applied_toppings:
		if t.id == topping.id:
			EventBus.notification_requested.emit("Bu sos/süsleme zaten eklendi!", 1.0)
			return
			
	applied_toppings.append(topping)
	_create_topping_mesh_on_top_scoop(topping)
	
	angular_velocity += randf_range(-4.0, 4.0)
	EventBus.topping_added_to_cone.emit(topping)
	EventBus.notification_requested.emit("%s eklendi!" % topping.topping_name, 1.0)
	_notify_state_changed()

func _create_topping_mesh_on_top_scoop(topping: ToppingData) -> void:
	if scoop_container == null or scoop_container.get_child_count() == 0:
		return
		
	var top_scoop = scoop_container.get_child(scoop_container.get_child_count() - 1) as Node3D
	if top_scoop == null:
		return
		
	var topping_mesh = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = topping.color
	
	if topping.type == ToppingData.ToppingType.SAUCE:
		var sauce_sphere = SphereMesh.new()
		sauce_sphere.radius = SCOOP_RADIUS * 1.05
		sauce_sphere.height = SCOOP_RADIUS * 1.35
		sauce_sphere.is_hemisphere = true
		topping_mesh.mesh = sauce_sphere
		mat.roughness = 0.12
		mat.metallic = 0.05
		topping_mesh.position = Vector3(0, 0.005, 0)
	else:
		var sprinkle_mesh = SphereMesh.new()
		sprinkle_mesh.radius = SCOOP_RADIUS * 1.06
		sprinkle_mesh.height = SCOOP_RADIUS * 1.25
		sprinkle_mesh.is_hemisphere = true
		topping_mesh.mesh = sprinkle_mesh
		mat.roughness = 0.65
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.75, 1.0)
		mat.emission_energy_multiplier = 0.6
		topping_mesh.position = Vector3(0, 0.008, 0)
		
	topping_mesh.material_override = mat
	topping_mesh.name = "Topping_" + topping.id
	top_scoop.add_child(topping_mesh)

func _on_place_on_cone_attempted() -> void:
	if _is_transferring:
		return
		
	if not has_cone():
		EventBus.notification_requested.emit("Önce külah standından bir külah al!", 1.5)
		return
		
	var right_hand: RightHandController = _get_right_hand()
	if right_hand == null or not right_hand.has_ice_cream():
		EventBus.notification_requested.emit("Kepçede dondurma yok!", 1.2)
		return
		
	right_hand.animate_reach_and_place_on_cone()
	var flavor = right_hand.get_scooped_flavor()
	_animate_scoop_transfer(flavor, right_hand)

func _animate_scoop_transfer(flavor: FlavorData, right_hand: RightHandController) -> void:
	_is_transferring = true
	var scoop_flavor = right_hand.consume_scoop()
	
	var flying_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = SCOOP_RADIUS
	sphere.height = SCOOP_RADIUS * 1.8
	flying_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = scoop_flavor.color
	mat.roughness = 0.55
	flying_mesh.material_override = mat
	
	get_tree().root.add_child(flying_mesh)
	var start_pos = right_hand.get_scoop_tip_global_position()
	var target_index = stacked_flavors.size()
	var target_local_y = (stack_marker.position.y if stack_marker else 0.14) + (target_index * SCOOP_STACK_SPACING)
	var target_pos = cone_pivot.to_global(Vector3(0, target_local_y, 0))
	
	flying_mesh.global_position = start_pos
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var mid_pos = (start_pos + target_pos) * 0.5 + Vector3(0, 0.1, 0)
	
	tween.tween_method(func(t: float):
		var p1 = start_pos.lerp(mid_pos, t)
		var p2 = mid_pos.lerp(target_pos, t)
		if is_instance_valid(flying_mesh):
			flying_mesh.global_position = p1.lerp(p2, t)
	, 0.0, 1.0, 0.18)
	
	tween.tween_callback(func():
		if is_instance_valid(flying_mesh):
			flying_mesh.queue_free()
		_finalize_add_scoop(scoop_flavor)
		_is_transferring = false
	)

func _finalize_add_scoop(flavor: FlavorData) -> void:
	if not has_cone():
		return
		
	stacked_flavors.append(flavor)
	state = ConeState.PREPARING
	var stack_index = stacked_flavors.size() - 1
	_create_scoop_mesh(flavor, stack_index)
	
	# Dikey Darbe Sönümleme
	var cushion_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	cushion_tween.tween_property(cone_pivot, "position:y", cone_pivot.position.y - 0.02, 0.06).set_ease(Tween.EASE_OUT)
	cushion_tween.tween_property(cone_pivot, "position:y", cone_pivot.position.y, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# İniş Darbesi
	var impulse_dir = 1.0 if (current_angle_deg >= 0) else -1.0
	angular_velocity += impulse_dir * (5.0 + float(stacked_flavors.size()) * 1.5)
	
	for i in range(stacked_flavors.size()):
		var impact_strength = float(i + 1) / float(stacked_flavors.size())
		if i < _scoop_vels.size():
			_scoop_vels[i].y -= 0.10 * impact_strength
			_scoop_vels[i].x += impulse_dir * 0.04 * impact_strength
	
	EventBus.ice_cream_added.emit(flavor, stacked_flavors.size())
	EventBus.ice_cream_placed_on_cone.emit(flavor, stack_index)
	_notify_state_changed()
	
	if stacked_flavors.size() >= 7:
		EventBus.notification_requested.emit("DEV KULE! %s eklendi (Toplam: %d Top!)" % [flavor.flavor_name, stacked_flavors.size()], 1.2)
	else:
		EventBus.notification_requested.emit("Külaha %s eklendi (Toplam: %d)" % [flavor.flavor_name, stacked_flavors.size()], 1.0)

func _create_scoop_mesh(flavor: FlavorData, index: int) -> void:
	if scoop_container == null:
		return
		
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = SCOOP_RADIUS
	sphere_mesh.height = SCOOP_RADIUS * 1.8
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = flavor.color
	mat.roughness = 0.55
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = mat
	mesh_instance.name = "Scoop_%d" % index
	
	var base_y = stack_marker.position.y if stack_marker else 0.14
	var y_offset = base_y + (index * SCOOP_STACK_SPACING)
	mesh_instance.position = Vector3(0, y_offset, 0)
	
	scoop_container.add_child(mesh_instance)
	_scoop_offsets.append(Vector3.ZERO)
	_scoop_vels.append(Vector3.ZERO)
	_scoop_angles.append(current_angle_deg)

func _clear_scoop_meshes() -> void:
	if scoop_container:
		for child in scoop_container.get_children():
			child.queue_free()
	_scoop_offsets.clear()
	_scoop_vels.clear()
	_scoop_angles.clear()

var is_performing_trick: bool = false
var current_trick_count: int = 0

func perform_trick() -> bool:
	if not has_cone() or stacked_flavors.is_empty() or is_performing_trick or is_reaching_cone:
		return false
		
	is_performing_trick = true
	current_trick_count += 1
	
	var trick_multiplier = 1.0 + (float(current_trick_count) * 0.35)
	EventBus.maras_trick_performed.emit(current_trick_count, trick_multiplier)
	EventBus.notification_requested.emit("MARAŞ ŞOVU! #%d (+%%%d Bahşiş)" % [current_trick_count, int((trick_multiplier - 1.0) * 100)], 1.3)
	
	var forward_pos = _base_local_pos + Vector3(0.08, 0.04, -0.36)
	var hide_pos = _base_local_pos + Vector3(-0.16, -0.06, 0.22)
	var hide_rot = Vector3(deg_to_rad(12.0), deg_to_rad(35.0), -deg_to_rad(15.0))
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	# 1. Külahı müşteriye doğru uzat
	tween.set_parallel(true)
	tween.tween_property(self, "position", forward_pos, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", Vector3(deg_to_rad(8), 0, 0), 0.15)
	
	# 2. Son anda aniden geri kaçır ve arkaya sakla
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", hide_pos, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", hide_rot, 0.18).set_ease(Tween.EASE_OUT)
	
	# 3. Normal pozisyona geri dön
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", _base_local_pos, 0.26).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", Vector3.ZERO, 0.26).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_performing_trick = false
	)
	return true

func flip_cone() -> bool:
	if not has_cone() or stacked_flavors.is_empty() or is_flipping or is_performing_trick or is_reaching_cone or is_clutch_active:
		return false
		
	var stability_angle_bonus = GameManager.get_upgrade_effect("cone_stability", "angle_tolerance")
	var effective_max_angle = (max_safe_angle_deg + stability_angle_bonus) * current_balance_tolerance
	
	if abs(current_angle_deg) > effective_max_angle * 0.72:
		EventBus.notification_requested.emit("Kule çok eğik, ters çeviremezsin!", 1.2)
		return false
		
	is_flipping = true
	EventBus.cone_flipped.emit(true)
	EventBus.notification_requested.emit("MARAŞ YERÇEKİMİ ŞOVU! 🔄 (Dökülmüyor!)", 1.4)
	
	current_angle_deg = 0.0
	angular_velocity = 0.0
	
	var flip_lift_pos = _base_local_pos + Vector3(0.04, 0.12, -0.22)
	var tween = create_tween().set_trans(Tween.TRANS_QUAD)
	
	tween.set_parallel(true)
	tween.tween_property(self, "position", flip_lift_pos, 0.20).set_ease(Tween.EASE_OUT)
	tween.tween_property(cone_pivot, "rotation:z", deg_to_rad(180.0), 0.22).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_interval(0.75)
	
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", _base_local_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cone_pivot, "rotation:z", 0.0, 0.22).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_flipping = false
		EventBus.cone_flipped.emit(false)
	)
	return true

func _start_clutch_window(fall_dir: float) -> void:
	if is_clutch_active or state == ConeState.DROPPED or state == ConeState.DISCARDED:
		return
		
	is_clutch_active = true
	clutch_used_this_cone = true
	_clutch_fall_dir = fall_dir
	_clutch_timer = CLUTCH_WINDOW_DURATION
	angular_velocity = 0.0
	EventBus.clutch_window_started.emit(fall_dir, CLUTCH_WINDOW_DURATION)

func _clutch_recover() -> void:
	is_clutch_active = false
	_clutch_timer = 0.0
	angular_velocity = -_clutch_fall_dir * 42.0
	current_angle_deg = move_toward(current_angle_deg, 0.0, 20.0)
	EventBus.clutch_catch_succeeded.emit()
	EventBus.notification_requested.emit("⚡ HARİKA REFLEKS! KULE HAVADA KURTARILDI!", 1.6)

func reset_cone() -> void:
	state = ConeState.NONE
	stacked_flavors.clear()
	applied_toppings.clear()
	current_trick_count = 0
	current_angle_deg = 0.0
	angular_velocity = 0.0
	_current_input_torque = 0.0
	is_flipping = false
	is_clutch_active = false
	clutch_used_this_cone = false
	_clutch_timer = 0.0
	_clear_scoop_meshes()
	if cone_pivot:
		cone_pivot.visible = false
		cone_pivot.position = Vector3(0, 0.05, -0.05)
		cone_pivot.rotation = Vector3.ZERO
	_notify_state_changed()

func has_cone() -> bool:
	return state != ConeState.NONE and state != ConeState.DROPPED and state != ConeState.DISCARDED

func get_state_string() -> String:
	match state:
		ConeState.NONE: return "NONE"
		ConeState.EMPTY: return "EMPTY"
		ConeState.PREPARING: return "PREPARING"
		ConeState.COMPLETED: return "COMPLETED"
		ConeState.DROPPED: return "DROPPED"
		ConeState.DISCARDED: return "DISCARDED"
	return "UNKNOWN"

func _notify_state_changed() -> void:
	EventBus.cone_state_changed.emit(
		get_state_string(),
		stacked_flavors.size(),
		stacked_flavors.duplicate()
	)

func get_cone_info() -> Dictionary:
	return {
		"state": get_state_string(),
		"has_cone": has_cone(),
		"current_count": stacked_flavors.size(),
		"flavors": stacked_flavors.duplicate(),
		"toppings": applied_toppings.duplicate()
	}

func _get_right_hand() -> RightHandController:
	if get_parent():
		return get_parent().get_node_or_null("RightHandRig") as RightHandController
	return null

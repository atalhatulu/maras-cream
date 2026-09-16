extends Node

var main: Node3D
var player: PlayerController
var manager: CustomerManager
var counter: Counter
var checks := 0
var failures := 0
var capture_dir := ""
var auto_balance := false
var elapsed_simulated := 0.0

func _physics_process(delta: float) -> void:
	elapsed_simulated += delta
	if auto_balance and player != null:
		Input.action_release("balance_left")
		Input.action_release("balance_right")
		var projected := player.left_hand.current_angle_deg + player.left_hand.angular_velocity * 0.35
		if projected > 3.0: Input.action_press("balance_left")
		elif projected < -3.0: Input.action_press("balance_right")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = pressed
	player.handle_gameplay_input(event)

func motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	player.handle_gameplay_input(event)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	player.handle_gameplay_input(event)

func aim(target: Node3D, local_point := Vector3(0, 0.15, 0)) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.is_mouse_captured = true
	for attempt in range(4):
		var direction := (target.to_global(local_point) - player.camera.global_position).normalized()
		var yaw := atan2(-direction.x, -direction.z)
		var pitch := asin(direction.y)
		motion(Vector2(player._target_yaw - yaw, player._target_pitch - pitch) / player.mouse_sensitivity)
		await pause(0.25)
		player.interaction_raycast.force_raycast_update()
		if player.get_interacted_collider() == target:
			return true
	print("AIM DEBUG ", target.name, " wanted=", target.to_global(local_point), " camera=", player.camera.global_position, " yaw/pitch=", Vector2(player._current_yaw, player._current_pitch), " mouse=", Input.mouse_mode, " hit=", player.get_interacted_collider(), " point=", player.interaction_raycast.get_collision_point())
	check(false, "Ray can reach " + target.name)
	return false

func scoop(tub: IceCreamTub) -> void:
	if not await aim(tub): return
	mouse(MOUSE_BUTTON_LEFT, true)
	for sample in range(30):
		motion(Vector2(0, 6))
		await pause(0.025)
	mouse(MOUSE_BUTTON_LEFT, false)
	await pause(0.5)
	check(player.right_hand.has_ice_cream(), "Mouse hold and downward drag fill the scoop")

func capture(name_text: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name_text + ".png")) == OK, "Capture " + name_text)

func _ready() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	get_tree().create_timer(240.0).timeout.connect(func():
		push_error("Playability watchdog")
		AudioManager.finish_and_quit(2)
	)
	_run.call_deferred()

func _run() -> void:
	seed(4702)
	Tutorial.completed = false
	Tutorial.dismissed = false
	GameManager.day_active = false
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	player = main.get_node("PlayerRig")
	manager = main.get_node("CustomerManager")
	counter = main.get_node("Counter")
	# Feed reproducible mouse/key events through the production input handler.
	# Physics, camera smoothing, picking rays, hands and order delivery stay live.
	player.set_process_unhandled_input(false)
	GameManager.start_day(1)
	await pause(6.0)
	check(manager.active_customer != null and manager.active_customer.accepts_service(), "First customer arrives")
	check(Tutorial.protects(manager.active_order), "First service activates hands-on tutorial")
	check(manager.active_order.flavors.size() == 2 and manager.active_order.toppings.size() == 1, "Tutorial recipe introduces scooping and sauce")
	manager.active_customer._update_score_and_patience(200.0)
	check(manager.active_order.current_score == 5.0, "Learning pauses customer score and timeout")
	await capture("08-tutorial-start")
	var stand := counter.get_node("ConeDispenser") as Node3D
	if await aim(stand, Vector3(0, 0.3, 0)):
		mouse(MOUSE_BUTTON_LEFT, true)
		mouse(MOUSE_BUTTON_LEFT, false)
		await pause(0.8)
	check(player.left_hand.has_cone(), "Ray-picked dispenser gives a cone")
	var tub := counter.tubs[0]
	if await aim(tub):
		mouse(MOUSE_BUTTON_LEFT, true)
		await pause(0.03)
		mouse(MOUSE_BUTTON_LEFT, false)
		await pause(0.4)
	check(not player.right_hand.is_diving and not player.right_hand.has_ice_cream(), "Early release cancels entry animation without delayed scoop")
	await scoop(tub)
	key(KEY_Q)
	await pause(0.5)
	check(player.left_hand.stacked_flavors.size() == 1 and not player.right_hand.has_ice_cream(), "Q transfers exactly one real scoop")
	check(not Tutorial.balance_practiced, "Transfer alone does not complete balance lesson")
	Input.action_press("balance_left")
	await pause(0.75)
	Input.action_release("balance_left")
	await pause(0.2)
	check(Tutorial.balance_practiced, "A input physically corrects the tutorial tilt")
	await scoop(tub)
	key(KEY_Q)
	await pause(0.5)
	var bottle := counter.get_node("Bottle_CikolataSos") as Node3D
	if await aim(bottle):
		mouse(MOUSE_BUTTON_LEFT, true)
		mouse(MOUSE_BUTTON_LEFT, false)
		await pause(0.6)
	check(player.left_hand.applied_toppings.size() == 1, "Ray-picked bottle applies required sauce")
	check(manager.active_order.check_progress(player.left_hand.stacked_flavors, player.left_hand.applied_toppings).is_completed, "Mouse-prepared recipe is deliverable")
	await capture("09-tutorial-ready")
	if await aim(manager.active_customer, Vector3(0, 1.0, 0)):
		key(KEY_E)
	await pause(0.2)
	check(GameManager.successful_orders == 1, "E delivers the mouse-prepared order exactly once")
	check(Tutorial.completed and Tutorial.training_order == null, "Successful tutorial ends protection")
	Tutorial.completed = false
	Tutorial.load_preferences()
	check(Tutorial.completed, "Tutorial completion persists independently of career save")
	await pause(6.0)
	for attempt in range(100):
		if manager.active_customer != null and manager.active_customer.accepts_service(): break
		await pause(0.1)
	check(not Tutorial.protects(manager.active_order), "Next customer uses normal timing")
	var score_before := manager.active_order.current_score
	await pause(manager.active_customer._reading_time_left + 1.0)
	check(manager.active_order.current_score < score_before, "Next customer score decays")
	await _test_focus_and_target_refresh()
	await _test_recovery_and_skip()
	await _test_tower_with_mouse()
	print("PLAYABILITY REGRESSION: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)

func _test_focus_and_target_refresh() -> void:
	var tub := counter.tubs[0]
	if await aim(tub):
		mouse(MOUSE_BUTTON_LEFT, true)
		await pause(0.03)
		player._release_mouse()
		await pause(0.4)
	check(not player.right_hand.is_diving and not player._is_active_scoop_dive, "Focus loss cancels held gesture")
	if await aim(tub):
		counter.switch_flavor_page()
		await pause(0.1)
		check(player._last_hint.contains("Muz") and player._last_hint.contains("KİLİTLİ"), "Same target refreshes after flavour page switch")
		GameManager.unlocked_flavor_ids.append("muz")
		EventBus.upgrade_purchased.emit("flavor_muz", 1)
		await pause(0.1)
		check(not player._last_hint.contains("KİLİTLİ"), "Same target refreshes after unlock")
		counter.switch_flavor_page()
		await pause(0.1)
	await capture("10-counter-focus")

func _test_recovery_and_skip() -> void:
	Tutorial.begin(manager.active_order)
	var stand := counter.get_node("ConeDispenser") as Node3D
	if await aim(stand, Vector3(0, 0.3, 0)):
		mouse(MOUSE_BUTTON_LEFT, true)
		mouse(MOUSE_BUTTON_LEFT, false)
		await pause(0.8)
	# Force an incorrect recipe through actual scooping and transfer, not fill helpers.
	manager.active_order.flavors.assign([GameManager.get_flavor_by_id("sade")])
	manager.active_order.toppings.clear()
	await scoop(counter.tubs[1])
	check(Tutorial.guidance(player.left_hand, player.right_hand, manager.active_order).step == "KEPÇEYİ BOŞALT", "Wrong held flavour gets a recovery instruction")
	key(KEY_Q)
	await pause(0.5)
	check(Tutorial.guidance(player.left_hand, player.right_hand, manager.active_order).step == "TARİFİ DÜZELT", "Wrong cone recipe gets a recovery instruction")
	var trash := counter.get_node("TrashCan") as Node3D
	if await aim(trash, Vector3(0, 0.3, 0)):
		mouse(MOUSE_BUTTON_LEFT, true)
		mouse(MOUSE_BUTTON_LEFT, false)
		await pause(0.5)
	check(not player.left_hand.has_cone(), "Trash interaction clears a wrong cone")
	check(Tutorial.guidance(player.left_hand, player.right_hand, manager.active_order).step.begins_with("1 /"), "Tutorial returns to cone pickup after loss")
	check(not Tutorial._tilt_introduced, "Replacement cone can replay the balance practice")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F2
	event.pressed = true
	Tutorial._unhandled_input(event)
	check(Tutorial.dismissed and not Tutorial.protects(manager.active_order), "F2 exits protected practice immediately")
	Tutorial.dismissed = false
	Tutorial.load_preferences()
	check(Tutorial.dismissed, "Skip preference survives reload")
	event.physical_keycode = KEY_F1
	Tutorial._unhandled_input(event)
	check(Tutorial.help_visible and not Tutorial.protects(manager.active_order), "F1 restores help without restoring time protection")
	Tutorial._unhandled_input(event)
	# No input may sneak through the shop into the world.
	EventBus.shop_opened.emit()
	var cone_before := player.left_hand.has_cone()
	player._handle_interact_pressed(stand)
	await pause(0.8)
	check(player.left_hand.has_cone() == cone_before, "Shop blocks world interactions")
	EventBus.shop_closed.emit()

func _test_tower_with_mouse() -> void:
	# A deliberately large live recipe tests the complete repeated gesture path.
	manager.active_order.flavors.clear()
	for i in range(14):
		manager.active_order.flavors.append(GameManager.get_flavor_by_id("sade"))
	manager.active_order.toppings.clear()
	manager.active_customer._reading_time_left = 0.0
	manager.active_order.current_score = 5.0
	EventBus.customer_arrived.emit(manager.active_customer, manager.active_order)
	var stand := counter.get_node("ConeDispenser") as Node3D
	if await aim(stand, Vector3(0, 0.3, 0)):
		mouse(MOUSE_BUTTON_LEFT, true)
		mouse(MOUSE_BUTTON_LEFT, false)
		await pause(0.8)
	auto_balance = true
	var started := elapsed_simulated
	for i in range(14):
		await scoop(counter.tubs[0])
		key(KEY_Q)
		await pause(0.45)
		check(player.left_hand.stacked_flavors.size() == i + 1, "Mouse gesture builds tower scoop %d" % (i + 1))
	check(not player.left_hand.is_clutch_active, "Active corrections keep the tall tower controllable")
	var hud: HUD = main.get_node("HUD")
	check(hud.order_items_list.get_child_count() <= 3, "Repeated-flavour tower has a compact order card")
	print("MOUSE TOWER: 14 scoops prepared in %.2f simulated seconds, score %.2f" % [elapsed_simulated - started, manager.active_order.current_score])
	await capture("11-fourteen-scoops")
	if await aim(manager.active_customer, Vector3(0, 1, 0)):
		key(KEY_E)
	await pause(0.2)
	check(GameManager.successful_orders == 2, "Fourteen-scoop mouse-prepared tower settles")
	auto_balance = false
	Input.action_release("balance_left")
	Input.action_release("balance_right")

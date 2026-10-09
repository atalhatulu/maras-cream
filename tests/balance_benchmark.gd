extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(91047)
	Tutorial.dismissed = true
	GameManager.day_active = false
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	var manager: CustomerManager = main.get_node("CustomerManager")
	var hand: LeftHandController = main.get_node("PlayerRig/Camera3D/LeftHandRig")
	hand.set_process(false)
	hand.set_physics_process(false)
	var rows: Array[Dictionary] = []
	for day in range(1, 6):
		GameManager.current_day = day
		GameManager.current_daily_event_id = GameManager.DailyEvents.INTRODUCTIONS[day - 1]
		var revenue := 0.0
		var score := 0.0
		var prep := 0.0
		for sample in range(400):
			var arch := manager.pick_weighted_archetype()
			var order := manager.generate_order_for_archetype(arch)
			# A stated planning model, not a claim about measured human performance:
			# 4 s per scoop incl. finding the tub, 2 s per sauce, 5 s read/deliver.
			var seconds := 5.0 + order.flavors.size() * 4.0 + order.toppings.size() * 2.0
			order.current_score = maxf(order.min_score, 5.0 - maxf(0.0, seconds - order.get_reading_grace()) * arch.score_decay_rate)
			var quote := OrderReward.calculate(order, arch, GameManager.get_base_scoop_price(), 0.0, [], 0.0, GameManager.current_daily_event_id, true, true)
			revenue += quote.total
			score += order.current_score
			prep += seconds
		rows.append({"day": day, "estimated_seconds_per_order": snappedf(prep / 400.0, 0.01), "estimated_score": snappedf(score / 400.0, 0.01), "estimated_day_revenue": snappedf(revenue / 400.0 * (8 + day * 2), 0.01)})
	print("ECONOMY MODEL ", JSON.stringify(rows))
	var starting_upgrade_cost := 0.0
	for id in ["scoop_speed", "snap_lift", "cone_stability", "cushion_spring", "patience_boost", "flavor_muz", "tip_mastery"]:
		starting_upgrade_cost += GameManager.upgrades[id].get_cost_for_next_level()
	print("SEVEN EARLY PURCHASES ", starting_upgrade_cost)
	GameManager.current_daily_event_id = "NORMAL"
	var results: Array[Dictionary] = []
	for count in [2, 5, 8, 14]:
		for fps in [30, 60, 144]:
			for assisted in [false, true]:
				hand.reset_cone()
				hand.take_cone()
				for i in range(count):
					hand.stacked_flavors.append(GameManager.get_flavor_by_id("sade"))
				hand.current_angle_deg = 8.0
				hand.angular_velocity = 0.0
				hand._physics_time = 0.0
				var elapsed := 0.0
				var peak := 0.0
				var reaction_timer := 0.0
				var accumulator := 0.0
				while elapsed < 30.0 and hand.has_cone() and not hand.is_clutch_active:
					if assisted and reaction_timer <= 0.0:
						Input.action_release("balance_left")
						Input.action_release("balance_right")
						var predicted := hand.current_angle_deg + hand.angular_velocity * 0.35
						if predicted > 3.0: Input.action_press("balance_left")
						elif predicted < -3.0: Input.action_press("balance_right")
						reaction_timer = 0.25
					accumulator += 1.0 / fps
					while accumulator >= 1.0 / 60.0:
						hand._simulate_balance_physics(1.0 / 60.0)
						accumulator -= 1.0 / 60.0
					elapsed += 1.0 / fps
					reaction_timer -= 1.0 / fps
					peak = maxf(peak, absf(hand.current_angle_deg))
				Input.action_release("balance_left")
				Input.action_release("balance_right")
				results.append({"scoops": count, "fps": fps, "correction_every_250ms": assisted, "seconds_to_rescue_or_30": snappedf(elapsed, 0.01), "peak_angle": snappedf(peak, 0.01)})
	print("BALANCE MEASUREMENTS ", JSON.stringify(results))
	# Regression: visual warning shake must not accumulate pivot displacement.
	hand.reset_cone()
	hand.take_cone()
	hand.stacked_flavors.append(GameManager.get_flavor_by_id("sade"))
	hand.current_angle_deg = hand.get_safe_angle() * 0.90
	for tick in range(1200):
		hand._physics_time += 1.0 / 60.0
		hand._update_visual_tilt(1.0 / 60.0)
		if absf(hand.cone_pivot.position.x) > 0.01 or absf(hand.cone_pivot.position.z + 0.05) > 0.01:
			push_error("BALANCE REGRESSION: warning shake displaced cone pivot")
			break
	# Disposal animation must own the pivot position.
	hand._is_disposing = true
	hand.cone_pivot.position = Vector3(0.4, -0.2, -0.3)
	hand._update_visual_tilt(1.0 / 60.0)
	if not is_equal_approx(hand.cone_pivot.position.x, 0.4) or not is_equal_approx(hand.cone_pivot.position.z, -0.3):
		push_error("BALANCE REGRESSION: disposal animation position was overwritten")
	hand.reset_cone()
	print("BALANCE VISUAL REGRESSION: checks completed")
	main.queue_free()
	await get_tree().process_frame
	await AudioManager.finish_and_quit()

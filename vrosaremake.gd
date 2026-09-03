extends CharacterBody3D
@export var max_hp: int = 3
@export var hp: int = 3
@export var run_speed: float = 5.0
@export var walk_speed: float = 2.0
@export var detection_distance: float = 20.0
@export var attack_range: float = 2.5
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 20.0
@export var stamina_regen: float = 25.0
@export var minimum_stamina: float = 1.0
@export var stamina_run_threshold: float = 35.0
@export var run_decision_min: float = 0.4
@export var run_decision_max: float = 2.5
@export var attack_hitbox_end_time: float = 0.50
@export var attack_recovery_time: float = 0.60
@export var attack_cooldown: float = 1.5
@export var p2_stun_time: float = 5.0
@export var p2_jump_distance: float = 18.0
@export var p2_jump_speed: float = 70.0
@export var p2_jump_duration: float = 0.60
@export var gravity: float = 25.0
var stamina: float = max_stamina
var running: bool = false
var run_decision_timer: float = 0.0
var phase_2: bool = false
var extra_hp_used: bool = false
var phase_1_transitioning: bool = false
var phase_2_transitioning: bool = false
var target: Node3D = null
var attacking: bool = false
var stunned: bool = false
var dead: bool = false
var attack_on_cooldown: bool = false
var phase_1_died: bool = false
var phase_2_died: bool = false
var current_attack: String = ""
var phase_2_lunge_active: bool = false
var phase_2_lunge_timer: float = 0.0
var phase_2_lunge_speed: float = 0.0
var phase_2_lunge_direction: Vector3 = Vector3.ZERO
var phase_2_jump_active: bool = false
var p2_jump_cooldown_timer: float = 0.0
var hitbox_damage_active: bool = false
var damaged_targets: Array[Node] = []
@onready var armature: Node3D = $Armerature
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_area: Area3D = $Area3D2
@onready var attack_hitbox: CollisionShape3D = $Area3D2/mincro
func _ready():
	hp = max_hp
	stamina = max_stamina
	running = false
	run_decision_timer = randf_range(
		run_decision_min,
		run_decision_max
	)
	p2_jump_cooldown_timer = 0.0
	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_area.collision_mask = 4294967295
	if not attack_area.body_entered.is_connected(_on_attack_body_entered):
		attack_area.body_entered.connect(_on_attack_body_entered)
	disable_attack_hitbox()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = attack_range
	play_animation("idle")
func _physics_process(delta):
	if dead:
		return
	if p2_jump_cooldown_timer > 0.0:
		p2_jump_cooldown_timer -= delta
		if p2_jump_cooldown_timer < 0.0:
			p2_jump_cooldown_timer = 0.0
	if phase_1_transitioning:
		velocity = Vector3.ZERO
		disable_attack_hitbox()
		phase_2_lunge_active = false
		phase_2_jump_active = false
		return
	if phase_2_transitioning:
		velocity = Vector3.ZERO
		disable_attack_hitbox()
		phase_2_lunge_active = false
		phase_2_jump_active = false
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	find_player()
	if target == null:
		running = false
		stop_movement(delta)
		manage_stamina(delta)
		move_and_slide()
		if not attacking and not stunned:
			if phase_2:
				play_animation("p2idle")
			else:
				play_animation("idle")
		return
	var distance_to_target: float = global_position.distance_to(
		target.global_position
	)
	if distance_to_target >= detection_distance:
		running = false
		stop_movement(delta)
		manage_stamina(delta)
		move_and_slide()
		if not attacking and not stunned:
			if phase_2:
				play_animation("p2idle")
			else:
				play_animation("idle")
		return
	if stunned:
		running = false
		stop_movement(delta)
		manage_stamina(delta)
		move_and_slide()
		look_at_player()
		return
	if attacking:
		running = false
		if phase_2_lunge_active:
			if phase_2_jump_active and target != null and is_instance_valid(target):
				var desired_direction: Vector3 = global_position.direction_to(
					target.global_position
				)
				desired_direction.y = 0.0
				if desired_direction.length() > 0.01:
					desired_direction = desired_direction.normalized()
					phase_2_lunge_direction = phase_2_lunge_direction.lerp(
						desired_direction,
						1.25 * delta
					).normalized()
			velocity.x = phase_2_lunge_direction.x * phase_2_lunge_speed
			velocity.z = phase_2_lunge_direction.z * phase_2_lunge_speed
			phase_2_lunge_timer -= delta
			if phase_2_lunge_timer <= 0.0:
				phase_2_lunge_active = false
				phase_2_jump_active = false
		else:
			stop_movement(delta)
		manage_stamina(delta)
		move_and_slide()
		if not phase_2_jump_active:
			look_at_player()
		return
	if phase_2 and distance_to_target <= p2_jump_distance and distance_to_target > attack_range and p2_jump_cooldown_timer <= 0.0 and not attack_on_cooldown:
		start_p2_jump_attack()
		return
	if distance_to_target <= attack_range:
		running = false
		stop_movement(delta)
		manage_stamina(delta)
		move_and_slide()
		look_at_player()
		if not attack_on_cooldown:
			start_attack()
		return
	nav_agent.target_position = target.global_position
	update_run_decision(delta)
	if nav_agent.is_navigation_finished():
		stop_movement(delta)
		manage_stamina(delta)
		move_and_slide()
		if not attacking and not stunned:
			if phase_2:
				play_animation("p2idle")
			else:
				play_animation("idle")
		return
	var next_position: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(
		next_position
	)
	direction.y = 0.0
	if direction.length() > 0.01:
		direction = direction.normalized()
		var movement_speed: float = walk_speed
		if running and stamina > minimum_stamina:
			movement_speed = run_speed
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
		look_at_player()
		manage_stamina(delta)
		move_and_slide()
		if should_jump_to_next_position(next_position):
			running = false
			if phase_2:
				play_animation("p2jumpactual")
			else:
				play_animation("jump")
		else:
			if phase_2:
				play_animation("p2idle")
			else:
				play_animation("idle")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		manage_stamina(delta)
		move_and_slide()
		look_at_player()
func find_player():
	if target != null and is_instance_valid(target):
		return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
func stop_movement(delta):
	velocity.x = move_toward(
		velocity.x,
		0.0,
		run_speed * 5.0 * delta
	)
	velocity.z = move_toward(
		velocity.z,
		0.0,
		run_speed * 5.0 * delta
	)
func should_jump_to_next_position(next_position: Vector3) -> bool:
	var height_difference: float = next_position.y - global_position.y
	return (
		height_difference > 0.75
		and height_difference < 3.5
	)
func update_run_decision(delta):
	if stamina <= minimum_stamina:
		stamina = minimum_stamina
		running = false
		run_decision_timer = 0.0
		return
	if not running and stamina < stamina_run_threshold:
		running = false
		run_decision_timer -= delta
		return
	run_decision_timer -= delta
	if run_decision_timer <= 0.0:
		running = randf() < 0.65
		run_decision_timer = randf_range(
			run_decision_min,
			run_decision_max
		)
	if stamina <= minimum_stamina:
		running = false
func manage_stamina(delta):
	if running:
		stamina -= stamina_drain * delta
		if stamina < minimum_stamina:
			stamina = minimum_stamina
		if stamina <= minimum_stamina:
			running = false
			run_decision_timer = 0.0
	else:
		stamina += stamina_regen * delta
		if stamina > max_stamina:
			stamina = max_stamina
func start_p2_jump_attack():
	if attacking:
		return
	if attack_on_cooldown:
		return
	if stunned:
		return
	if dead:
		return
	if phase_2_transitioning:
		return
	if p2_jump_cooldown_timer > 0.0:
		return
	if target == null:
		return
	if not is_instance_valid(target):
		return
	var distance_to_target: float = global_position.distance_to(
		target.global_position
	)
	if distance_to_target > p2_jump_distance:
		return
	if distance_to_target <= attack_range:
		return
	attacking = true
	running = false
	current_attack = "p2jump"
	p2_jump_cooldown_timer = randf_range(20.0, 50.0)
	phase_2_lunge_active = true
	phase_2_jump_active = true
	phase_2_lunge_speed = p2_jump_speed
	phase_2_lunge_timer = p2_jump_duration
	phase_2_lunge_direction = global_position.direction_to(
		target.global_position
	)
	phase_2_lunge_direction.y = 0.0
	if phase_2_lunge_direction.length() > 0.01:
		phase_2_lunge_direction = phase_2_lunge_direction.normalized()
	velocity.y = 14.0
	play_animation("p2jump")
	await get_tree().create_timer(0.10).timeout
	if not attacking or current_attack != "p2jump":
		return
	start_hitbox_window()
	await get_tree().physics_frame
	damage_attack_targets()
	end_hitbox_window()
	await get_tree().create_timer(0.05).timeout
	if not attacking or current_attack != "p2jump":
		return
	start_hitbox_window()
	await get_tree().physics_frame
	damage_attack_targets()
	end_hitbox_window()
	await get_tree().create_timer(0.05).timeout
	if not attacking or current_attack != "p2jump":
		return
	start_hitbox_window()
	await get_tree().physics_frame
	damage_attack_targets()
	end_hitbox_window()
	var recovery_time: float = attack_recovery_time - 0.30
	if recovery_time > 0.0:
		await get_tree().create_timer(
			recovery_time
		).timeout
	end_attack()
func start_attack():
	if attacking:
		return
	if attack_on_cooldown:
		return
	if stunned:
		return
	if dead:
		return
	if phase_1_transitioning:
		return
	if phase_2_transitioning:
		return
	if target == null:
		return
	if not is_instance_valid(target):
		return
	var distance_to_target: float = global_position.distance_to(
		target.global_position
	)
	if distance_to_target > attack_range:
		return
	attacking = true
	running = false
	look_at_player()
	if phase_2:
		var phase_2_attacks: Array[String] = [
			"p2attack",
			"p2heavy",
			"p2heavy_2"
		]
		current_attack = phase_2_attacks.pick_random()
	else:
		var phase_1_attacks: Array[String] = [
			"attack",
			"attack2",
			"heavy"
		]
		current_attack = phase_1_attacks.pick_random()
	play_animation(current_attack)
	await get_tree().create_timer(0.10).timeout
	if dead:
		end_attack()
		return
	if stunned:
		end_attack()
		return
	if phase_1_transitioning:
		end_attack()
		return
	if phase_2_transitioning:
		end_attack()
		return
	if target == null:
		end_attack()
		return
	if not is_instance_valid(target):
		target = null
		end_attack()
		return
	start_hitbox_window()
	await get_tree().physics_frame
	damage_attack_targets()
	end_hitbox_window()
	await get_tree().create_timer(0.05).timeout
	if not attacking:
		return
	start_hitbox_window()
	await get_tree().physics_frame
	damage_attack_targets()
	end_hitbox_window()
	await get_tree().create_timer(0.05).timeout
	if not attacking:
		return
	start_hitbox_window()
	await get_tree().physics_frame
	damage_attack_targets()
	end_hitbox_window()
	var recovery_time: float = attack_recovery_time - 0.30
	if recovery_time > 0.0:
		await get_tree().create_timer(
			recovery_time
		).timeout
	end_attack()
func start_hitbox_window():
	damaged_targets.clear()
	hitbox_damage_active = true
	enable_attack_hitbox()
func end_hitbox_window():
	hitbox_damage_active = false
	disable_attack_hitbox()
func enable_attack_hitbox():
	if not is_instance_valid(attack_hitbox):
		return
	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_area.collision_mask = 4294967295
	attack_hitbox.set_deferred(
		"disabled",
		false
	)
func disable_attack_hitbox():
	if not is_instance_valid(attack_hitbox):
		return
	hitbox_damage_active = false
	attack_hitbox.set_deferred(
		"disabled",
		true
	)
func _on_attack_body_entered(body: Node3D):
	if not hitbox_damage_active:
		return
	damage_single_target(body)
func damage_attack_targets() -> bool:
	if not is_instance_valid(attack_hitbox):
		return false
	if attack_hitbox.shape == null:
		return false
	if not hitbox_damage_active:
		return false
	var did_damage: bool = false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = attack_hitbox.shape
	query.transform = attack_hitbox.global_transform
	query.collision_mask = 4294967295
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var results: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(
		query,
		32
	)
	for result in results:
		var collider: Object = result.get("collider")
		if collider == null:
			continue
		if collider is Node:
			damage_single_target(collider as Node)
	if target != null and is_instance_valid(target):
		damage_single_target(target)
	return did_damage
func damage_single_target(body: Node) -> bool:
	if not is_instance_valid(body):
		return false
	if body == self:
		return false
	var damage_target: Node = find_damage_target(body)
	if damage_target == null:
		return false
	if damage_target == self:
		return false
	if damaged_targets.has(damage_target):
		return false
	if not damage_target.has_method("take_damage"):
		return false
	damaged_targets.append(damage_target)
	damage_target.take_damage(1)
	return true
func find_damage_target(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("take_damage"):
			return current
		if current == self:
			break
		current = current.get_parent()
	return null
func end_attack():
	disable_attack_hitbox()
	attacking = false
	phase_2_lunge_active = false
	phase_2_jump_active = false
	current_attack = ""
	damaged_targets.clear()
	attack_on_cooldown = true
	await get_tree().create_timer(
		attack_cooldown
	).timeout
	if dead:
		return
	if phase_1_transitioning:
		return
	if phase_2_transitioning:
		return
	attack_on_cooldown = false
func take_damage(amount: int):
	if dead:
		return
	if phase_1_transitioning:
		return
	if phase_2_transitioning:
		return
	hp -= amount
	if hp <= 0:
		if not phase_2:
			await phase_1_death_transition()
		else:
			die_phase_2()
		return
	if stunned:
		return
	if not phase_2:
		if hp == 1:
			disable_attack_hitbox()
			stunned = true
			running = false
			attacking = false
			phase_2_lunge_active = false
			phase_2_jump_active = false
			play_animation("upwards_25percent")
			await wait_for_animation(
				"upwards_25percent"
			)
			if dead:
				return
			if phase_1_transitioning:
				return
			stunned = false
			play_animation("idle")
			return
		stunned = true
		running = false
		attacking = false
		phase_2_lunge_active = false
		phase_2_jump_active = false
		disable_attack_hitbox()
		play_animation("hit")
		await wait_for_animation("hit")
		if dead:
			return
		if phase_1_transitioning:
			return
		stunned = false
		play_animation("idle")
		return
	stunned = true
	running = false
	attacking = false
	phase_2_lunge_active = false
	phase_2_jump_active = false
	disable_attack_hitbox()
	await play_p2_stun()
func play_p2_stun():
	var elapsed: float = 0.0
	while elapsed < p2_stun_time:
		if dead:
			return
		play_animation("staredownp2")
		animation_player.seek(0.0, true)
		var animation_length: float = get_animation_length(
			"staredownp2"
		)
		if animation_length <= 0.0:
			await get_tree().create_timer(
				p2_stun_time - elapsed
			).timeout
			return
		var remaining: float = p2_stun_time - elapsed
		var wait_time: float = min(
			animation_length,
			remaining
		)
		await get_tree().create_timer(
			wait_time
		).timeout
		elapsed += wait_time
	if dead:
		return
	stunned = false
	play_animation("p2idle")
func phase_1_death_transition():
	if phase_2:
		return
	if phase_1_died:
		return
	phase_1_died = true
	phase_1_transitioning = true
	attacking = false
	stunned = true
	running = false
	attack_on_cooldown = false
	phase_2_lunge_active = false
	phase_2_jump_active = false
	velocity = Vector3.ZERO
	disable_attack_hitbox()
	play_animation("die")
	await wait_for_animation("die")
	if dead:
		return
	velocity = Vector3.ZERO
	disable_attack_hitbox()
	await get_tree().create_timer(
		10.0
	).timeout
	if dead:
		return
	velocity = Vector3.ZERO
	start_phase_2()
func start_phase_2():
	if phase_2:
		return
	if extra_hp_used:
		return
	phase_2 = true
	extra_hp_used = true
	phase_1_transitioning = false
	phase_2_transitioning = true
	hp = 10
	stunned = false
	attacking = false
	attack_on_cooldown = false
	running = false
	phase_2_lunge_active = false
	phase_2_jump_active = false
	p2_jump_cooldown_timer = 0.0
	stamina = max_stamina
	velocity = Vector3.ZERO
	disable_attack_hitbox()
	play_animation("phase 2")
	finish_phase_2_transition()
func finish_phase_2_transition():
	await wait_for_animation("phase 2")
	if dead:
		return
	phase_2_transitioning = false
	stunned = false
	attacking = false
	attack_on_cooldown = false
	running = false
	phase_2_lunge_active = false
	phase_2_jump_active = false
	velocity = Vector3.ZERO
	disable_attack_hitbox()
	play_animation("p2idle")
func die_phase_2():
	if dead:
		return
	if phase_2_died:
		return
	phase_2_died = true
	dead = true
	attacking = false
	stunned = false
	running = false
	attack_on_cooldown = false
	phase_2_lunge_active = false
	phase_2_jump_active = false
	velocity = Vector3.ZERO
	disable_attack_hitbox()
	play_animation("p2die")
	await wait_for_animation("p2die")
	queue_free()
func die():
	if phase_2:
		die_phase_2()
	else:
		phase_1_death_transition()
func look_at_player():
	if target == null:
		return
	if not is_instance_valid(target):
		target = null
		return
	var target_position: Vector3 = target.global_position
	target_position.y = global_position.y
	var direction: Vector3 = global_position.direction_to(
		target_position
	)
	if direction.length() <= 0.01:
		return
	rotation.y = lerp_angle(
		rotation.y,
		atan2(
			-direction.x,
			-direction.z
		),
		10.0 * get_process_delta_time()
	)
func get_animation_length(animation_name: String) -> float:
	if not animation_player.has_animation(
		animation_name
	):
		return 0.0
	var animation: Animation = animation_player.get_animation(
		animation_name
	)
	return animation.length
func wait_for_animation(animation_name: String):
	if not animation_player.has_animation(
		animation_name
	):
		return
	var animation_length: float = get_animation_length(
		animation_name
	)
	if animation_length <= 0.0:
		return
	await get_tree().create_timer(
		animation_length
	).timeout
func play_animation(animation_name: String):
	if not animation_player.has_animation(
		animation_name
	):
		return
	if animation_player.current_animation == animation_name:
		return
	animation_player.play(animation_name)

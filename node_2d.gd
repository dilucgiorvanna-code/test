extends CharacterBody3D 
@export var sprint_speed: float = 30.0 
@export var max_stamina: float = 100.0 
@export var stamina_drain: float = 15.0 
@export var stamina_regen: float = 20.0 
@onready var stamina_bar: ProgressBar = $CanvasLayer/StaminaBar 
var stamina: float = max_stamina 
var sprinting := false 
var sprint_exhausted := false 
@export var hp: int = 100 
@export var max_hp: int = 100 
@export var speed := 10.0 
@export var slide_speed := 20.0 
@export var slide_duration := 0.8 
@export var slide_rotation := -20.0 
@export var slide_acceleration := 15.0 
@export var gravity := 20.0 
@export var mouse_sensitivity := 0.002 
@onready var shotgun = $Camera3D/shotgunSELFLESS 
@onready var camera: Camera3D = $Camera3D 
@onready var hp_bar: TextureProgressBar = $CanvasLayer/TextureProgressBar 
@onready var walking_sfx: AudioStreamPlayer = $"WalkingsfxSelfless" 
@onready var jump_height := 30 
@onready var JUMP_VELOCITY : float = 10 
@export var damage: int = 1 
@export var hitbox_interval: float = 0.1
@export var hitbox_active_time: float = 0.2
@export var hitbox_start_delay: float = 0.2
@export var attack_duration: float = 1.0
@export var max_bullets: int = 3
var bullets: int = 3
@onready var hitbox_area: Area3D = $Area3D 
@onready var hitbox_1: CollisionShape3D = $Area3D/CollisionShape3D2 
@onready var hitbox_2: CollisionShape3D = $Area3D/CollisionShape3D3 
@onready var hitbox_3: CollisionShape3D = $Area3D/CollisionShape3D4 
@onready var hitbox_4: CollisionShape3D = $Area3D/CollisionShape3D5 
@onready var hitbox_5: CollisionShape3D = $Area3D/CollisionShape3D6 
@onready var hitbox_6: CollisionShape3D = $Area3D/CollisionShape3D7 
@onready var hitbox_7: CollisionShape3D = get_node_or_null("Area3D/CollisionShape3D8")
var hitboxes: Array[CollisionShape3D] = [] 
var attacking := false 
var hit_targets: Dictionary = {} 
@export var slide_cooldown: float = 3.0 
@export var max_slide_hold: float = 5.0 
var sliding := false 
var slide_cooldown_active := false 
var slide_hold_time := 0.0 
var slide_key_held := false 
var slide_was_started := false 
var move_dir := Vector3.ZERO 
var camera_x_rotation := 0.0 
var slide_velocity := Vector3.ZERO 
var normal_rotation := 0.0 
func _ready(): 
	hp_bar.max_value = max_hp 
	update_hp() 
	stamina_bar.max_value = max_stamina 
	stamina = max_stamina 
	stamina_bar.value = stamina 
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
	hitboxes = [
		hitbox_1,
		hitbox_2,
		hitbox_3,
		hitbox_4,
		hitbox_5,
		hitbox_6
	]
	if hitbox_7 != null:
		hitboxes.append(hitbox_7)
	disable_all_hitboxes() 
func _unhandled_input(event): 
	if event is InputEventMouseMotion: 
		rotate_y(-event.relative.x * mouse_sensitivity) 
		camera_x_rotation -= event.relative.y * mouse_sensitivity 
		camera_x_rotation = clamp(camera_x_rotation, -1.5, 1.5) 
		camera.rotation.x = camera_x_rotation 
	if event.is_action_pressed("CAMR"): 
		camera.rotation = Vector3.ZERO 
		camera_x_rotation = 0.0 
func _physics_process(delta): 
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	move_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if sliding:
		slide_hold_time += delta
		velocity.x = slide_velocity.x
		velocity.z = slide_velocity.z
		if not slide_key_held or slide_hold_time >= max_slide_hold:
			sliding = false
			slide_cooldown_active = true
			slide_hold_time = 0.0
			await get_tree().create_timer(slide_cooldown).timeout
			slide_cooldown_active = false
	else:
		var current_speed = speed
		if sprinting and not sprint_exhausted:
			current_speed = sprint_speed
		var target_velocity = move_dir * current_speed
		velocity.x = move_toward(
			velocity.x,
			target_velocity.x,
			slide_acceleration * delta
		)
		velocity.z = move_toward(
			velocity.z,
			target_velocity.z,
			slide_acceleration * delta
		)
	if Input.is_action_pressed("sprint") and not sprint_exhausted and not sliding:
		sprinting = true
	else:
		sprinting = false
	if sprinting:
		stamina -= stamina_drain * delta
		if stamina <= 0:
			stamina = 0
			sprint_exhausted = true
			sprinting = false
	else:
		stamina += stamina_regen * delta
		if stamina >= max_stamina:
			stamina = max_stamina
			sprint_exhausted = false
	stamina_bar.value = stamina
	if move_dir.length() > 0.1 and not sliding:
		normal_rotation = atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(
			rotation.y,
			normal_rotation,
			10.0 * delta
		)
	move_and_slide()
	if is_on_floor() and move_dir.length() > 0.1 and not sliding:
		if not walking_sfx.playing:
			walking_sfx.play()
	else:
		if walking_sfx.playing:
			walking_sfx.stop()
func _process(_delta): 
	update_hp()
	if Input.is_action_just_pressed("shoot"):
		start_hitbox_attack()
	if Input.is_action_just_pressed("reload"):
		shotgun.reload()
	slide_key_held = Input.is_action_pressed("slide")
	if Input.is_action_just_pressed("slide"):
		if not sliding and not slide_cooldown_active:
			start_slide()
func disable_all_hitboxes():
	for hitbox in hitboxes:
		if hitbox != null:
			hitbox.disabled = true
func activate_hitbox(index: int):
	disable_all_hitboxes()
	if index >= 0 and index < hitboxes.size():
		hitboxes[index].disabled = false
func start_hitbox_attack():
	if attacking:
		return
	if bullets <= 0:
		disable_all_hitboxes()
		return
	bullets -= 1
	attacking = true
	hit_targets.clear()
	shotgun.shoot()
	await get_tree().create_timer(hitbox_start_delay).timeout
	for i in range(hitboxes.size()):
		hitboxes[i].disabled = false
		await get_tree().create_timer(hitbox_interval).timeout
		damage_hitbox(i)
		await get_tree().create_timer(
			hitbox_active_time - hitbox_interval
		).timeout
		hitboxes[i].disabled = true
	disable_all_hitboxes()
	var remaining_animation_time = attack_duration - hitbox_start_delay
	if remaining_animation_time > 0:
		await get_tree().create_timer(
			remaining_animation_time
		).timeout
	attacking = false
	if bullets <= 0:
		disable_all_hitboxes()
func damage_hitbox(index: int):
	if index < 0 or index >= hitboxes.size():
		return
	var hitbox = hitboxes[index]
	if hitbox == null:
		return
	var bodies = hitbox_area.get_overlapping_bodies()
	for body in bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
func start_slide():
	if sliding:
		return
	if slide_cooldown_active:
		return
	if not is_on_floor():
		return
	sliding = true
	slide_hold_time = 0.0
	var forward = -global_transform.basis.z
	slide_velocity = forward * slide_speed
	rotation.x = deg_to_rad(slide_rotation)
func update_hp():
	hp = clamp(hp, 0, max_hp)
	if hp_bar != null:
		hp_bar.value = hp

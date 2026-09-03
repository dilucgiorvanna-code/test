extends CharacterBody3D
signal low_hp_changed(is_low_hp: bool)
@export var sprint_speed: float = 30.0
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 15.0
@export var stamina_regen: float = 20.0
@onready var stamina_bar: ProgressBar = $CanvasLayer/StaminaBar
var stamina: float = max_stamina
var sprinting := false
var sprint_exhausted := false
@export var hp: int = 5
@export var max_hp: int = 5
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
@onready var JUMP_VELOCITY: float = 10.0
@onready var danger_overlay: TextureRect = $CanvasLayer/DangerOverlay
var danger_images: Array[Texture2D] = [
	preload("res://Untitled234.webp"),
	preload("res://Untitled234_20260625135942.webp"),
	preload("res://Untitled234_20260625135947.webp"),
	preload("res://Untitled234_20260625135951.webp"),
	preload("res://Untitled234_20260625135956.webp"),
	preload("res://Untitled234_20260625140000.webp"),
	preload("res://Untitled234_20260625140004.webp"),
	preload("res://Untitled234_20260625140007.webp"),
	preload("res://Untitled234_20260625140011.webp"),
	preload("res://Untitled234_20260625140016.webp"),
	preload("res://Untitled234_20260625140020.webp"),
	preload("res://Untitled234_20260625140423.webp"),
	preload("res://Untitled234_20260625140439.webp"),
	preload("res://Untitled234_20260625140447.webp"),
	preload("res://Untitled234_20260625140453.webp"),
	preload("res://Untitled234_20260625141237.webp"),
	preload("res://Untitled234_20260625141252.webp"),
	preload("res://Untitled234_20260625141309.webp")
]
var low_hp_active := false
var danger_flash_running := false
@export var damage: int = 1
@export var hitbox_interval: float = 0.02
@export var hitbox_active_time: float = 0.1
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
@onready var hitbox_7: CollisionShape3D = get_node_or_null(
	"Area3D/CollisionShape3D8"
)
var hitboxes: Array[CollisionShape3D] = []
var attacking := false
var dead := false
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
	hp = max_hp
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	if hp_bar.texture_over != null:
		hp_bar.texture_progress = hp_bar.texture_over
		hp_bar.texture_over = null
	hp_bar.value = hp
	stamina_bar.min_value = 0
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
	hitbox_area.monitoring = true
	hitbox_area.monitorable = true
	disable_all_hitboxes()
	danger_overlay.texture = null
	danger_overlay.modulate.a = 0.0
	danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_hp()
func _unhandled_input(event):
	if dead:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_x_rotation -= event.relative.y * mouse_sensitivity
		camera_x_rotation = clamp(
			camera_x_rotation,
			-1.5,
			1.5
		)
		camera.rotation.x = camera_x_rotation
	if event.is_action_pressed("CAMR"):
		camera.rotation = Vector3.ZERO
		camera_x_rotation = 0.0
func _physics_process(delta):
	if dead:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = -1
	var input := Input.get_vector(
		"left",
		"right",
		"foward",
		"back"
	)
	var cam_forward = -camera.global_transform.basis.z
	var cam_right = camera.global_transform.basis.x
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	move_dir = (
		cam_right * input.x -
		cam_forward * input.y
	).normalized()
	if sliding:
		velocity.x = slide_velocity.x
		velocity.z = slide_velocity.z
		rotation.z = lerp(
			rotation.z,
			deg_to_rad(slide_rotation),
			slide_acceleration * delta
		)
		slide_hold_time += delta
		if slide_hold_time >= max_slide_hold:
			sliding = false
			slide_velocity = Vector3.ZERO
	else:
		var target_speed := speed
		if (
			Input.is_action_pressed("sprint")
			and move_dir.length() > 0.1
			and stamina > 0.0
			and not sprint_exhausted
		):
			sprinting = true
			stamina -= stamina_drain * delta
			stamina = max(
				stamina,
				0.0
			)
			target_speed = sprint_speed
			if stamina <= 0.0:
				sprinting = false
				sprint_exhausted = true
		else:
			sprinting = false
			stamina += stamina_regen * delta
			stamina = min(
				stamina,
				max_stamina
			)
		var target_velocity := move_dir * target_speed
		var acceleration := 60.0
		var deceleration := 80.0
		if move_dir.length() > 0.1:
			velocity.x = move_toward(
				velocity.x,
				target_velocity.x,
				acceleration * delta
			)
			velocity.z = move_toward(
				velocity.z,
				target_velocity.z,
				acceleration * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				deceleration * delta
			)
			velocity.z = move_toward(
				velocity.z,
				0.0,
				deceleration * delta
			)
	if not Input.is_action_pressed("sprint"):
		sprint_exhausted = false
	rotation.z = lerp(
		rotation.z,
		normal_rotation,
		slide_acceleration * delta
	)
	stamina_bar.value = stamina
	move_and_slide()
	handle_running_sound()
func _process(_delta):
	if dead:
		return
	update_hp()
	if Input.is_action_just_pressed("shoot"):
		start_hitbox_attack()
	if Input.is_action_just_pressed("reload"):
		shotgun.reload()
	if Input.is_action_just_pressed("slide"):
		slide_key_held = true
		if not slide_cooldown_active:
			start_slide()
	if Input.is_action_just_released("slide"):
		slide_key_held = false
		if sliding:
			sliding = false
			slide_velocity = Vector3.ZERO
			slide_hold_time = 0.0
		if slide_was_started:
			slide_was_started = false
			start_slide_cooldown()
func disable_all_hitboxes():
	for hitbox in hitboxes:
		if hitbox != null:
			hitbox.set_deferred(
				"disabled",
				true
			)
func activate_hitbox(index: int):
	if index >= 0 and index < hitboxes.size():
		if hitboxes[index] != null:
			hitboxes[index].set_deferred(
				"disabled",
				false
			)
func start_hitbox_attack():
	if dead:
		return
	if attacking:
		return
	if bullets <= 0:
		disable_all_hitboxes()
		return
	bullets -= 1
	attacking = true
	shotgun.shoot()
	await get_tree().create_timer(
		hitbox_start_delay
	).timeout
	if dead:
		disable_all_hitboxes()
		attacking = false
		return
	for i in range(hitboxes.size()):
		activate_hitbox(i)
		await get_tree().physics_frame
		damage_hitbox(i)
		await get_tree().create_timer(
			hitbox_interval
		).timeout
		if dead:
			disable_all_hitboxes()
			attacking = false
			return
	damage_hitbox(
		hitboxes.size() - 1
	)
	await get_tree().create_timer(
		max(
			hitbox_active_time - hitbox_interval,
			0.0
		)
	).timeout
	disable_all_hitboxes()
	var animation_remaining := (
		attack_duration
		- hitbox_start_delay
		- (
			hitbox_interval
			* hitboxes.size()
		)
	)
	if animation_remaining > 0.0:
		await get_tree().create_timer(
			animation_remaining
		).timeout
	attacking = false
	if bullets <= 0:
		disable_all_hitboxes()
func damage_hitbox(index: int):
	if dead:
		return
	if index < 0:
		return
	if index >= hitboxes.size():
		return
	var hitbox = hitboxes[index]
	if hitbox == null:
		return
	var bodies: Array = hitbox_area.get_overlapping_bodies()
	for body in bodies:
		if not is_instance_valid(body):
			continue
		if body == self:
			continue
		if not body.has_method("take_damage"):
			continue
		body.take_damage(damage)
func start_slide():
	if dead:
		return
	if sliding:
		return
	if slide_cooldown_active:
		return
	sliding = true
	slide_was_started = true
	slide_hold_time = 0.0
	normal_rotation = rotation.z
	if move_dir.length() > 0.1:
		slide_velocity = move_dir * slide_speed
	else:
		var forward = -camera.global_transform.basis.z
		forward.y = 0
		slide_velocity = forward.normalized() * slide_speed
	shotgun.slide()
func start_slide_cooldown():
	if slide_cooldown_active:
		return
	slide_cooldown_active = true
	await get_tree().create_timer(
		slide_cooldown
	).timeout
	slide_cooldown_active = false
func update_hp():
	if not is_instance_valid(hp_bar):
		return
	hp = clamp(
		hp,
		0,
		max_hp
	)
	hp_bar.value = hp
	var hp_percentage: float = float(hp) / float(max_hp)
	var new_low_hp_state: bool = hp_percentage < 0.5
	if new_low_hp_state != low_hp_active:
		low_hp_active = new_low_hp_state
		low_hp_changed.emit(
			low_hp_active
		)
		if low_hp_active:
			start_low_hp_state()
		else:
			stop_low_hp_state()
func take_damage(amount: int):
	if dead:
		return
	if amount <= 0:
		return
	hp -= amount
	hp = clamp(
		hp,
		0,
		max_hp
	)
	update_hp()
	if hp <= 0:
		die()
func heal(amount: int):
	if dead:
		return
	if amount <= 0:
		return
	hp += amount
	hp = clamp(
		hp,
		0,
		max_hp
	)
	update_hp()
func start_low_hp_state():
	if danger_flash_running:
		return
	danger_flash_running = true
	flash_danger_images()
func stop_low_hp_state():
	danger_flash_running = false
	danger_overlay.texture = null
	danger_overlay.modulate.a = 0.0
func flash_danger_images():
	while (
		danger_flash_running
		and low_hp_active
		and not dead
	):
		var image_index: int = randi_range(
			0,
			danger_images.size() - 1
		)
		danger_overlay.texture = danger_images[
			image_index
		]
		danger_overlay.modulate.a = 0.5
		await get_tree().create_timer(
			0.03
		).timeout
	danger_overlay.texture = null
	danger_overlay.modulate.a = 0.0
func die():
	if dead:
		return
	dead = true
	hp = 0
	low_hp_active = false
	danger_flash_running = false
	danger_overlay.texture = null
	danger_overlay.modulate.a = 0.0
	low_hp_changed.emit(false)
	update_hp()
	velocity = Vector3.ZERO
	disable_all_hitboxes()
	attacking = false
	sliding = false
	sprinting = false
	sprint_exhausted = true
	if walking_sfx.playing:
		walking_sfx.stop()
	queue_free()
func handle_running_sound():
	var horizontal_velocity = Vector3(
		velocity.x,
		0,
		velocity.z
	)
	if (
		horizontal_velocity.length() > 0.1
		and is_on_floor()
	):
		if !walking_sfx.playing:
			walking_sfx.play()
	else:
		if walking_sfx.playing:
			walking_sfx.stop()

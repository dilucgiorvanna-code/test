extends Node3D
@export var max_bullets: int = 3
var bullets := 0
var shooting := false
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var shotgun_sfx: AudioStreamPlayer = $Shotgun
func _ready():
	bullets = max_bullets
	anim.play("NOSHOOT")
func shoot():
	if shooting:
		return
	if bullets <= 0:
		return
	shooting = true
	bullets -= 1
	anim.play("shoot")
	shotgun_sfx.play()
	await anim.animation_finished
	shooting = false
	if anim.current_animation != "sliding":
		anim.play("NOSHOOT")
func reload():
	if shooting:
		return
	if bullets >= max_bullets:
		return
	shooting = true
	anim.play("shoot")
	await anim.animation_finished
	bullets = max_bullets
	shooting = false
	anim.play("NOSHOOT")
func slide():
	if anim.current_animation == "sliding":
		return
	anim.stop()
	anim.play("sliding")
	await anim.animation_finished
	if !shooting:
		anim.play("NOSHOOT")
func increase_ammo_capacity(amount:int):
	max_bullets += amount
	bullets += amount

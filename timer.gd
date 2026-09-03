extends Node
@export var player_path: NodePath
@onready var player = get_node(player_path)
var current_time: float = 0.0
var highest_time: float = 0.0
var shortest_time: float = 0.0
var timer_started := false
var timer_finished := false
func _ready() -> void:
	current_time = 0.0
	timer_started = false
	timer_finished = false
	await get_tree().process_frame
	update_display()
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not timer_started and not timer_finished:
		var horizontal_velocity = Vector3(
			player.velocity.x,
			0,
			player.velocity.z
		)
		if horizontal_velocity.length() > 0.1:
			timer_started = true
	if timer_started and not timer_finished:
		current_time += delta
		if player.hp <= 0:
			stop_timer()
		update_display()
func stop_timer() -> void:
	if timer_finished:
		return
	timer_finished = true
	timer_started = false
	if shortest_time == 0.0:
		shortest_time = current_time
	else:
		shortest_time = min(shortest_time, current_time)
	highest_time = max(highest_time, current_time)
	update_display()
func update_display() -> void:
	if not is_instance_valid(player):
		return
	var canvas_layer = player.get_node_or_null("CanvasLayer")
	if canvas_layer == null:
		return
	var current_label = canvas_layer.get_node_or_null("CurrentTime")
	var highest_label = canvas_layer.get_node_or_null("HighestTime")
	var shortest_label = canvas_layer.get_node_or_null("ShortestTime")
	if current_label:
		current_label.text = "TIME: " + format_time(current_time)
	if highest_label:
		highest_label.text = "HIGHEST: " + format_time(highest_time)
	if shortest_label:
		if shortest_time == 0.0:
			shortest_label.text = "SHORTEST: --"
		else:
			shortest_label.text = "SHORTEST: " + format_time(shortest_time)
func format_time(time: float) -> String:
	var minutes := int(time) / 60
	var seconds := fmod(time, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]

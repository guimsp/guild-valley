class_name MegaNode
extends Area2D

@export var node_name: String = ""
@export var resource_type_id: String = "" # e.g. "wheat", "iron_ore", "cotton"
@export var base_fee: int = 50
@export var max_slots: int = 5
@export var base_yield: float = 1.0

var active_gatherers: Array = []

func _ready() -> void:
	add_to_group("MegaNodes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_mask = 1 + 8
	queue_redraw()

func _draw() -> void:
	var color = Color(0.24, 0.52, 0.85, 0.12)
	var border_color = Color(0.24, 0.52, 0.85, 0.6)
	
	if resource_type_id == "wheat":
		color = Color(0.85, 0.75, 0.24, 0.12)
		border_color = Color(0.85, 0.75, 0.24, 0.6)
	elif resource_type_id == "iron_ore":
		color = Color(0.7, 0.7, 0.75, 0.12)
		border_color = Color(0.7, 0.7, 0.75, 0.6)
	elif resource_type_id == "cotton":
		color = Color(0.85, 0.85, 0.9, 0.12)
		border_color = Color(0.85, 0.85, 0.9, 0.6)
		
	var radius = 96.0
	for child in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			radius = child.shape.radius
			break
			
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, border_color, 2.0, true)

func get_congestion_factor() -> float:
	return max(0.4, 1.0 - ((active_gatherers.size() - 1) * 0.15))

func get_entry_fee() -> int:
	return int(base_fee * (1.0 + (active_gatherers.size() * 0.25)))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

	var is_valid_gatherer = false
	if body is GatheringWorker:
		is_valid_gatherer = true
	elif body is NPCAIController and body.is_hired == true:
		is_valid_gatherer = true
	elif (body is Player or body is AIRival) and body.is_harvesting == true:
		is_valid_gatherer = true
			
	if not is_valid_gatherer:
		return
		
	if not active_gatherers.has(body):
		if active_gatherers.size() < max_slots:
			active_gatherers.append(body)
			body.set("is_gathering", true)
			body.set("current_mega_node", self)
			
			var lm = get_node_or_null("/root/LogisticsManager")
			if lm:
				lm.start_gathering(body, self)
			_spawn_floating_text("%s began harvesting!" % body.name)
		else:
			_spawn_floating_text("%s is Full!" % node_name)
			if body.has_method("on_mega_node_full"):
				body.on_mega_node_full(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)
		if body.get("is_harvesting") == true:
			body.set("is_harvesting", false)
			if body.has_meta("gather_time_left"):
				body.remove_meta("gather_time_left")
			if body.has_meta("selected_gather_resource"):
				body.remove_meta("selected_gather_resource")
			var lm = get_node_or_null("/root/LogisticsManager")
			if lm:
				lm.collect_player_yield(body, self)

	if active_gatherers.has(body):
		active_gatherers.erase(body)
		body.set("is_gathering", false)
		body.set("current_mega_node", null)
		
		var lm = get_node_or_null("/root/LogisticsManager")
		if lm:
			lm.stop_gathering(body)
		_spawn_floating_text("%s left the harvesting area." % body.name)

func get_interaction_text() -> String:
	return "Manage " + node_name

func interact(player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("open_mega_node_monitor"):
		hud.open_mega_node_monitor(self)

func _spawn_floating_text(txt: String) -> void:
	var label = Label.new()
	label.text = txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	
	add_child(label)
	label.global_position = global_position + Vector2(-50, -60)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	
	await tween.finished
	label.queue_free()

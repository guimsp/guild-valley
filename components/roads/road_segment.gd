@tool
class_name RoadSegment
extends Area2D

@export var size: Vector2 = Vector2(64, 64):
	set(val):
		size = val
		_update_size()

@export var road_color: Color = Color(0.38, 0.38, 0.42) # Solid rock gray

func _ready() -> void:
	z_index = -1
	y_sort_enabled = false
	add_to_group("Roads")
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_update_size()

func _update_size() -> void:
	queue_redraw()
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		col.shape.size = size
	elif not col:
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape = RectangleShape2D.new()
		shape.size = size
		col.shape = shape
		add_child(col)

func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), road_color)

func _on_body_entered(body: Node2D) -> void:
	if "active_roads_count" in body:
		body.active_roads_count += 1
		body.speed_multiplier = 1.10

func _on_body_exited(body: Node2D) -> void:
	if "active_roads_count" in body:
		body.active_roads_count -= 1
		if body.active_roads_count <= 0:
			body.active_roads_count = 0
			body.speed_multiplier = 1.0

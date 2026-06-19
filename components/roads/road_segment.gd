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
		call_deferred("_setup_navigation_region")
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

func _setup_navigation_region() -> void:
	var region = NavigationRegion2D.new()
	region.name = "RoadNavRegion"
	add_child(region)
	
	var poly = NavigationPolygon.new()
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	poly.source_geometry_group_name = "nav_carve_obstacles"
	poly.agent_radius = 16.0
	
	var half_size = size / 2.0
	var vertices = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	poly.add_outline(vertices)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	
	NavigationServer2D.region_set_enter_cost(region.get_rid(), 0.5)
	NavigationServer2D.region_set_travel_cost(region.get_rid(), 0.5)
	
	# Wait one frame to bake so that world geometry is loaded
	await get_tree().physics_frame
	region.bake_navigation_polygon(true)

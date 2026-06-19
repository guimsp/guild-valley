extends Node2D

@onready var exit_door: TeleportTrigger = get_node_or_null("ExitDoor")

var parent_building: Node2D = null

func _ready() -> void:
	add_to_group("Interiors")

func setup_interior(parent_b: Node2D, exit_pos: Vector2) -> void:
	parent_building = parent_b
	_setup_interior_navigation()
	
	if exit_door:
		exit_door.is_local_teleport = true
		exit_door.target_spawn_position = exit_pos
		exit_door.ownership_type = parent_building.ownership_type
		exit_door.owner_id = parent_building.owner_id
		if exit_door.has_method("_update_door_state"):
			exit_door._update_door_state()

func _setup_interior_navigation() -> void:
	if has_node("Walls"):
		for wall in get_node("Walls").get_children():
			wall.add_to_group("nav_carve_obstacles")
			
	var region = NavigationRegion2D.new()
	region.name = "InteriorNavRegion"
	add_child(region)
	
	var poly = NavigationPolygon.new()
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	poly.source_geometry_group_name = "nav_carve_obstacles"
	poly.agent_radius = 16.0
	
	var vertices = PackedVector2Array([
		Vector2(-450, -300),
		Vector2(450, -300),
		Vector2(450, 300),
		Vector2(-450, 300)
	])
	poly.add_outline(vertices)
	poly.make_polygons_from_outlines()
	region.navigation_polygon = poly
	region.enabled = true
	region.bake_navigation_polygon(false)

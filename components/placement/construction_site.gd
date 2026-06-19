extends StaticBody2D

# Configured dynamically when spawned
var building_data: BuildingData = null
var target_scene_path: String = ""
var build_time: float = 3.0
var building_name: String = ""
var is_rental: bool = false
var builder_ownership_type: String = "Player"
var builder_owner_id: String = "Player"

var _elapsed_time: float = 0.0

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect
@onready var col_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("ConstructionSites")
	if progress_bar:
		progress_bar.max_value = build_time
		progress_bar.value = 0.0
	if label:
		label.text = "Building " + building_name
		
	# Adjust shape size if building is a larger production building
	if building_name in ["Flour Mill", "Smelter", "Loom & Table", "Loom"]:
		# Larger footprint (96x80)
		var shape = RectangleShape2D.new()
		shape.size = Vector2(96, 80)
		col_shape.shape = shape
		color_rect.size = Vector2(96, 80)
		color_rect.position = Vector2(-48, -40)
		label.position = Vector2(-100, -60)
		label.size = Vector2(200, 20)
		progress_bar.position = Vector2(-40, -80)
		progress_bar.size = Vector2(80, 14)
	elif building_name in ["Wheat Field", "Cotton Patch"]:
		# Grid footprint (128x128)
		var shape = RectangleShape2D.new()
		shape.size = Vector2(128, 128)
		col_shape.shape = shape
		color_rect.size = Vector2(128, 128)
		color_rect.position = Vector2(-64, -64)
		label.position = Vector2(-100, -84)
		label.size = Vector2(200, 20)
		progress_bar.position = Vector2(-40, -104)
		progress_bar.size = Vector2(80, 14)

func _process(delta: float) -> void:
	_elapsed_time += delta
	if progress_bar:
		progress_bar.value = _elapsed_time
		
	if _elapsed_time >= build_time:
		_finish_building()

func _finish_building() -> void:
	set_process(false)
	
	if target_scene_path != "":
		var scene = load(target_scene_path)
		if scene:
			var real_node = scene.instantiate() as Node2D
			real_node.global_position = global_position
			
			if "ownership_type" in real_node:
				real_node.ownership_type = builder_ownership_type
			if "owner_id" in real_node:
				real_node.owner_id = builder_owner_id
			if "is_rental" in real_node:
				real_node.is_rental = is_rental
			if "custom_name" in real_node:
				real_node.custom_name = building_name
			if "building_data" in real_node:
				real_node.building_data = building_data
			if real_node.has_method("_update_door_state"):
				real_node._update_door_state()
				
			get_parent().add_child(real_node)
			
			# Bind newly completed building to the lot it occupies
			for lot in get_tree().get_nodes_in_group("BuildingLots"):
				if lot.global_position.distance_to(global_position) < 5.0:
					lot.occupied_node = real_node
					break
			
			# Notify HUD to spawn floating feedback
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if hud and hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("Completed!", global_position)
				
	# Re-bake all navigation regions dynamically to carve out the new building
	if GameState.has_method("rebake_all_navigation_regions"):
		GameState.rebake_all_navigation_regions()
	else:
		await get_tree().physics_frame
		var global_nav = get_tree().get_first_node_in_group("GlobalNavRegion") as NavigationRegion2D
		if global_nav:
			global_nav.bake_navigation_polygon(true)
		
	queue_free()

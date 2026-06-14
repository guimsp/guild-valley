@tool
class_name BuildingLot
extends Area2D

@export var lot_size: Vector2 = Vector2(96, 80):
	set(val):
		lot_size = val
		_update_size()

@export var base_cost: int = 50
@export var is_occupied: bool = false:
	get:
		if is_occupied and not is_instance_valid(occupied_node):
			is_occupied = false
			occupied_node = null
		return is_occupied
	set(val):
		is_occupied = val
		queue_redraw()

@export var occupied_node: Node2D = null:
	get:
		if occupied_node and not is_instance_valid(occupied_node):
			occupied_node = null
			is_occupied = false
		return occupied_node
	set(val):
		occupied_node = val
		if val:
			is_occupied = true
		else:
			is_occupied = false

var calculated_cost: int = 50
var nearest_settlement: Node2D = null

# Visual highlights for Build Mode
var is_highlighted: bool = false:
	set(val):
		if is_highlighted != val:
			is_highlighted = val
			queue_redraw()

var is_selected: bool = false:
	set(val):
		if is_selected != val:
			is_selected = val
			queue_redraw()

func _ready() -> void:
	add_to_group("BuildingLots")
	_update_size()
	
	if not Engine.is_editor_hint():
		# Wait one frame to let settlements load before locating the nearest one
		await get_tree().process_frame
		_find_nearest_settlement()
		calculate_lot_cost()

func _update_size() -> void:
	queue_redraw()
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		col.shape.size = lot_size
	elif not col:
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape = RectangleShape2D.new()
		shape.size = lot_size
		col.shape = shape
		add_child(col)

func _find_nearest_settlement() -> void:
	var min_dist: float = INF
	var closest: Node2D = null
	
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = global_position.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = city
			
	for town in get_tree().get_nodes_in_group("Towns"):
		var dist = global_position.distance_to(town.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = town
			
	nearest_settlement = closest

func calculate_lot_cost() -> int:
	if not nearest_settlement:
		_find_nearest_settlement()
		
	var cost = base_cost
	if nearest_settlement:
		var prosperity = nearest_settlement.prosperity if "prosperity" in nearest_settlement else 0
		cost += prosperity * 2
		
		# Resolve market node
		var market_node: CanvasItem = null
		if "market_node_path" in nearest_settlement and nearest_settlement.market_node_path:
			market_node = nearest_settlement.get_node_or_null(nearest_settlement.market_node_path)
			
		var dist_to_market: float = 0.0
		if market_node:
			dist_to_market = global_position.distance_to(market_node.global_position)
		else:
			dist_to_market = global_position.distance_to(nearest_settlement.global_position)
			
		# Proximity pricing: closer to market = more expensive
		var center_bonus = max(0.0, 300.0 - dist_to_market * 0.5)
		cost += int(center_bonus)
		
	calculated_cost = cost
	return cost

func _draw() -> void:
	var rect = Rect2(-lot_size / 2.0, lot_size)
	
	if Engine.is_editor_hint():
		# Draw a subtle blue outline in the editor
		draw_rect(rect, Color(0.2, 0.5, 0.8, 0.6), false, 2.0)
		draw_rect(rect, Color(0.2, 0.5, 0.8, 0.15), true)
		return
		
	if is_highlighted:
		if is_occupied:
			# Draw a subtle red indicator if occupied
			draw_rect(rect, Color(0.9, 0.2, 0.2, 0.4), false, 1.5)
		else:
			if is_selected:
				# Selected available lot: neon green with fill
				draw_rect(rect, Color(0.2, 0.9, 0.4, 0.95), false, 3.0)
				draw_rect(rect, Color(0.2, 0.9, 0.4, 0.25), true)
			else:
				# Unselected available lot: subtle white outline
				draw_rect(rect, Color(0.8, 0.8, 0.8, 0.4), false, 1.5)

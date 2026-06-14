class_name Town
extends Node2D

signal town_ownership_changed(town: Town, old_province: String, new_province: String)

@export var town_name: String = "Hamlet"
@export var is_resource_node: bool = false # Node towns containing raw material sites (dynamic ownership)
@export var radius_of_influence: float = 600.0
@export var prosperity: int = 20
@export var growth_points: int = 0
@export var growth_milestones: int = 50
@export var is_growing: bool = true
@export var ownership_province: String = "Neutral Province"
@export var market_node_path: NodePath

var controlling_city: City = null

func _ready() -> void:
	add_to_group("Towns")
	call_deferred("_find_controlling_city")

func _find_controlling_city() -> void:
	var closest_city: City = null
	var min_dist: float = INF
	
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = global_position.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_city = city
			
	if closest_city and min_dist <= closest_city.radius_of_influence:
		controlling_city = closest_city
		# If this is a standard build town, its ownership is fixed to the controlling city's province
		if not is_resource_node:
			ownership_province = controlling_city.city_name + " Province"
		print("[Town] %s belongs to the dominion of City: %s (Province: %s)" % [town_name, controlling_city.city_name, ownership_province])
	else:
		if not is_resource_node:
			ownership_province = "Neutral Province"

func change_ownership(new_province: String) -> void:
	if not is_resource_node:
		# Standard building towns have FIXED ownership
		print("[Town] %s is a build town and has FIXED ownership!" % town_name)
		return
	
	# Resource node towns have DYNAMIC ownership
	var old = ownership_province
	if old == new_province:
		return
	ownership_province = new_province
	town_ownership_changed.emit(self, old, new_province)

class_name RivalCareerBehavior
extends Resource

@export var career_name: String = ""
@export var gather_resource_id: String = ""
@export var gather_node_group: String = ""
@export var refining_recipe_path: String = ""
@export var refine_station_group: String = ""
@export var finished_recipe_path: String = ""
@export var finish_station_group: String = ""
@export var final_sell_item_id: String = ""

# Building data files to construct at specific levels
# e.g. { 1: ["res://common/buildings/resources/patreon_mill_l1.tres"], 2: [...] }
@export var building_unlocks_by_level: Dictionary = {}

func has_finished_product() -> bool:
	return finished_recipe_path != ""

static func get_behavior_for_career(career: String) -> RivalCareerBehavior:
	var behavior = RivalCareerBehavior.new()
	behavior.career_name = career
	match career:
		"patreon":
			behavior.gather_resource_id = "wheat"
			behavior.gather_node_group = "WheatFields"
			behavior.refining_recipe_path = "res://common/items/recipes/grind_wheat.tres"
			behavior.refine_station_group = "Mills"
			behavior.finished_recipe_path = "res://common/items/recipes/bake_bread.tres"
			behavior.finish_station_group = "Bakeries"
			behavior.final_sell_item_id = "bread"
			behavior.building_unlocks_by_level = {
				1: ["res://common/buildings/resources/patreon_mill_l1.tres", "res://common/buildings/resources/patreon_bakery_l1.tres"],
				4: ["res://common/buildings/resources/patreon_farmstead_l1.tres"],
				5: ["res://common/buildings/resources/patreon_inn_l1.tres"],
				6: ["res://common/buildings/resources/patreon_tavern_l1.tres"],
				7: ["res://common/buildings/resources/patreon_distillery_l1.tres"],
				8: ["res://common/buildings/resources/patreon_event_hall_l1.tres"]
			}
		"craftsman":
			behavior.gather_resource_id = "iron_ore"
			behavior.gather_node_group = "OreMines"
			behavior.refining_recipe_path = "res://common/items/recipes/smelt_iron.tres"
			behavior.refine_station_group = "Smelters"
			behavior.finished_recipe_path = ""
			behavior.finish_station_group = ""
			behavior.final_sell_item_id = "iron_ingot"
			behavior.building_unlocks_by_level = {
				1: ["res://common/buildings/resources/craftsman_smelter_l1.tres"]
			}
		"tailor":
			behavior.gather_resource_id = "cotton"
			behavior.gather_node_group = "CottonPlants"
			behavior.refining_recipe_path = "res://common/items/recipes/weave_cloth.tres"
			behavior.refine_station_group = "Looms"
			behavior.finished_recipe_path = ""
			behavior.finish_station_group = ""
			behavior.final_sell_item_id = "cloth"
			behavior.building_unlocks_by_level = {
				1: ["res://common/buildings/resources/tailor_loom_l1.tres"]
			}
		"scholar":
			behavior.gather_resource_id = "cotton"
			behavior.gather_node_group = "CottonPlants"
			behavior.refining_recipe_path = "res://common/items/recipes/make_paper.tres"
			behavior.refine_station_group = "PaperMakers"
			behavior.finished_recipe_path = "res://common/items/recipes/print_book.tres"
			behavior.finish_station_group = "PrintingPresses"
			behavior.final_sell_item_id = "book"
			behavior.building_unlocks_by_level = {
				1: ["res://common/buildings/resources/scholar_paper_maker_l1.tres", "res://common/buildings/resources/scholar_press_l1.tres"]
			}
	return behavior

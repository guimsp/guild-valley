class_name NPCRuntimeState
extends Node

var local_state: Dictionary = {}

func initialize_state(spec: Dictionary) -> void:
	# Cache dialogue key
	local_state["active_dialogue_key"] = spec.get("dialogue_key", "")
	
	if spec.get("is_dynamic", false) and is_instance_valid(get_parent()) and get_parent().get("character_resource"):
		var char_res = get_parent().character_resource
		for trait_id in char_res.active_mods:
			var trait_data = WindowManager.get_trait_data(trait_id)
			if not trait_data.is_empty() and trait_data.has("dialogue_key") and trait_data["dialogue_key"] != "":
				local_state["active_dialogue_key"] = trait_data["dialogue_key"]
				break
	
	var rank = spec.get("rank", "").to_lower()
	var office = spec.get("office_name", "").to_lower()
	
	if "steward" in rank or "steward" in office:
		# Materials Steward
		local_state["bundles_list"] = [
			{ "id": "iron_ore", "name": "Wholesale Iron Ore", "req": 30, "gold": 80, "influence": 5, "path": "Raw Materials" },
			{ "id": "iron_ingot", "name": "Wholesale Iron Ingot", "req": 60, "gold": 200, "influence": 15, "path": "Semi-Elaborate" },
			{ "id": "cloth", "name": "Wholesale Cloth", "req": 100, "gold": 350, "influence": 30, "path": "Semi-Elaborate" }
		]
		local_state["purchased_bundles"] = {}
		local_state["refresh_timestamp"] = 0.0
	elif spec.get("is_quest_npc", false) or spec.get("quests", []).size() > 0:
		# Quest Giver
		local_state["available_quest_ids"] = spec.get("quests", [])
	elif "mayor" in rank or "burgomeister" in rank or "councilor" in rank:
		# Politician
		local_state["voter_count"] = randi_range(100, 500)
		local_state["policy_keys"] = ["trade_tax", "property_tax"]
	elif spec.get("is_guild_master", false) or spec.get("is_guild_office_npc", false):
		# Guild Representative
		local_state["training_cap"] = 5
		local_state["tier_progression"] = 1

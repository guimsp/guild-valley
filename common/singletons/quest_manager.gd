extends Node

signal quests_updated


# State arrays
var locked_quests: Array[Resource] = []
var active_quests_list: Array[Resource] = []
var completed_quest_ids: Array[String] = []

# Master list of loaded quests
var all_quests: Array[Resource] = []
var quest_map: Dictionary = {}

# Dictionary of available board quests (keeps 100% compatibility with Quest Board UI)
var active_quests: Dictionary = {}

func initialize_quest_states(provinces: Array[String]) -> void:
	active_quests.clear()
	for prov in provinces:
		active_quests[prov] = []

# Accepted quests array (keeps 100% compatibility with other UI grids/indicators)
var accepted_quests: Array[Resource]:
	get:
		return active_quests_list
	set(val):
		active_quests_list = val

var completed_quests_count: int = 0
var last_checked_day: int = 1

func _ready() -> void:
	initialize_quest_states(["Valley Province", "Oakhaven Province", "Highland Province"])
	# Avoid race conditions: wait for autoload initialization
	call_deferred("_initialize_quest_database")
	TimeManager.time_changed.connect(_on_time_changed)

func _initialize_quest_database() -> void:
	# Yield if EconomyManager hasn't loaded items database yet
	if not EconomyManager or EconomyManager.item_database.is_empty():
		await get_tree().physics_frame
		
	load_quests_from_json()
	generate_quests_for_day(TimeManager.time_days)

func _sanitize_str(val) -> String:
	if val == null:
		return ""
	var s = str(val).strip_edges()
	if s == "" or s.to_lower() == "none":
		return ""
	return s

func get_mapped_title(editor_title: String) -> String:
	match editor_title.to_lower():
		"peasant": return "Apprentice"
		"citizen": return "Journeyman"
		"merchant": return "Guildmaster"
		"noble": return "Patrician"
		_: return editor_title

func load_quests_from_json() -> void:
	all_quests.clear()
	quest_map.clear()
	
	var filepath = "res://common/quests/quests.json"
	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		print("[QuestManager] quests.json not found! Empty quest registry initialized.")
		return
		
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[QuestManager] Failed to parse quests.json: ", json.get_error_message())
		return
		
	if not (json.data is Array):
		print("[QuestManager] quests.json root is not an Array.")
		return
		
	for q_dict in json.data:
		var q = QuestData.new()
		q.id = _sanitize_str(q_dict.get("id", ""))
		if q.id == "":
			continue
			
		q.title = q_dict.get("title", "")
		q.description = q_dict.get("description", "")
		
		var cat_str = _sanitize_str(q_dict.get("category", "AMBIENT_LEAD"))
		match cat_str:
			"STORY_EVENT": q.category = 0 # STORY_EVENT
			"MUNICIPAL": q.category = 1 # MUNICIPAL
			"GUILD": q.category = 2 # GUILD
			_: q.category = 3 # AMBIENT_LEAD
			
		q.quest_level = int(q_dict.get("quest_level", 1))
		q.giver_npc_id = _sanitize_str(q_dict.get("giver_npc_id", ""))
		q.region = _sanitize_str(q_dict.get("region", "Valley Province"))
		q.target_amount = int(q_dict.get("target_amount", 0))
		q.next_quest_id = _sanitize_str(q_dict.get("next_quest_id", ""))
		q.is_hidden_lead = bool(q_dict.get("is_hidden_lead", false))
		q.gates_profession_promotion = _sanitize_str(q_dict.get("gates_profession_promotion", "None"))
		q.gates_title_promotion = _sanitize_str(q_dict.get("gates_title_promotion", "None"))
		q.is_one_time = bool(q_dict.get("is_one_time", false))
		q.target_gold = int(q_dict.get("target_gold", 0))
		q.unlocks_province_license = _sanitize_str(q_dict.get("unlocks_province_license", ""))

		
		q.gold_reward = int(q_dict.get("gold_reward", 0))
		q.xp_reward = int(q_dict.get("xp_reward", 0))
		q.influence_reward = int(q_dict.get("influence_reward", 0))
		
		var item_id = _sanitize_str(q_dict.get("target_item_id", ""))
		if item_id != "" and EconomyManager.item_database.has(item_id):
			q.target_item = EconomyManager.item_database[item_id]
			
		all_quests.append(q)
		quest_map[q.id] = q
		
	# Stitch relational pointers
	for q in all_quests:
		if q.next_quest_id != "" and quest_map.has(q.next_quest_id):
			q.next_quest = quest_map[q.next_quest_id]

func _on_time_changed(_hours: int, _minutes: int, days: int) -> void:
	if days != last_checked_day:
		last_checked_day = days
		on_day_advanced(days)

func on_day_advanced(new_day: int) -> void:
	# Regenerate board quests for the day
	generate_quests_for_day(new_day)

func generate_quests_for_day(_day: int) -> void:
	# Clear unaccepted board quests
	for region in active_quests:
		active_quests[region] = []
		
	_update_quest_states()
	
	# Distribute unlocked municipal/ambient/story quests to the boards
	for q in all_quests:
		if completed_quest_ids.has(q.id) or active_quests_list.has(q) or locked_quests.has(q):
			continue
			
		var reg = q.region
		if reg == "":
			reg = "Valley Province"
			
		if active_quests.has(reg):
			active_quests[reg].append(q)
			
	quests_updated.emit()

func _update_quest_states() -> void:
	locked_quests.clear()
	
	for q in all_quests:
		if completed_quest_ids.has(q.id):
			continue
			
		if active_quests_list.has(q):
			continue
			
		# Check if predecessor chain completed
		var has_incomplete_predecessor = false
		for other in all_quests:
			if other.next_quest_id == q.id:
				if not completed_quest_ids.has(other.id):
					has_incomplete_predecessor = true
					break
		if has_incomplete_predecessor:
			locked_quests.append(q)
			continue
			
		# Global Social Status Check (for MUNICIPAL/AMBIENT_LEAD)
		if q.category == 1 or q.category == 3: # 1: MUNICIPAL, 3: AMBIENT_LEAD
			if q.quest_level > GameState.title_level:
				locked_quests.append(q)
				continue
				
		# Combined Household Competency Check (for GUILD)
		if q.category == 2: # 2: GUILD
			var req_career = "patreon"
			if q.gates_profession_promotion != "":
				req_career = q.gates_profession_promotion.to_lower()
			elif q.target_item:
				req_career = EconomyManager.get_item_career(q.target_item.id)
				
			# Gated if highest level in house is less than the target promotion tier
			if get_household_competency(req_career) < q.quest_level - 1:
				locked_quests.append(q)
				continue

func get_spouse_profession_level(career: String) -> int:
	if not GameState.is_married or GameState.spouse_npc_id == "":
		return 0
		
	var npcs = get_tree().get_nodes_in_group("NPCs")
	for npc in npcs:
		if npc.get("quest_npc_id") == GameState.spouse_npc_id:
			var rel = npc.get_node_or_null("RelationshipComponent")
			if rel and rel.profession_type == career:
				return rel.profession_level
	return 0

func get_household_competency(career: String) -> int:
	var player_lvl = GameState.career_levels.get(career, 0)
	var spouse_lvl = get_spouse_profession_level(career)
	return max(player_lvl, spouse_lvl)

func is_profession_promotion_locked(career: String, target_level: int) -> bool:
	for q in all_quests:
		if q.gates_profession_promotion != "" and q.gates_profession_promotion.to_lower() == career.to_lower():
			if q.quest_level == target_level:
				if not completed_quest_ids.has(q.id):
					return true
	return false

func is_title_promotion_locked(target_title: String) -> bool:
	for q in all_quests:
		if q.gates_title_promotion != "":
			var mapped = get_mapped_title(q.gates_title_promotion)
			if mapped.to_lower() == target_title.to_lower():
				if not completed_quest_ids.has(q.id):
					return true
	return false

func accept_quest(quest_id: String, region: String) -> bool:
	var quest_idx = -1
	var list = active_quests.get(region, [])
	for i in range(list.size()):
		if list[i].id == quest_id:
			quest_idx = i
			break
			
	if quest_idx == -1:
		return false
		
	var quest = list[quest_idx]
	list.remove_at(quest_idx)
	
	active_quests_list.append(quest)
	quests_updated.emit()
	
	GameState.spawn_ui_floating_text("Quest Accepted: " + quest.title)
	return true

func try_complete_quest(npc_id: String, player: CharacterBody2D) -> void:
	var matching_quests = []
	for q in active_quests_list:
		if q.giver_npc_id == npc_id:
			matching_quests.append(q)
			
	var npc_node = null
	var quest_npcs = get_tree().get_nodes_in_group("QuestNPCs")
	for n in quest_npcs:
		if n.get("quest_npc_id") == npc_id:
			npc_node = n
			break
			
	if not npc_node:
		var npcs = get_tree().get_nodes_in_group("NPCs")
		for n in npcs:
			if n.get("quest_npc_id") == npc_id:
				npc_node = n
				break

	var talk_anchor = npc_node if npc_node else player
	var npc_display_name = npc_node.npc_name if npc_node else ("Councilor " + ("Marcus" if npc_id == "councilor_marcus" else "Elena"))

	var greeting = [
		"Greetings! I am " + npc_display_name + ".",
		"I manage local municipal affairs and city administration."
	]
	
	GameState.show_npc_dialogue(talk_anchor, npc_display_name, greeting, func():
		var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
		var bubble = bubble_scene.instantiate()
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if not hud:
			hud = get_tree().get_first_node_in_group("game_hud")
		if hud:
			var parent_node = hud.get_node_or_null("Control")
			if parent_node:
				parent_node.add_child(bubble)
			else:
				hud.add_child(bubble)
				
			player.freeze()
			bubble.start_dialogue(talk_anchor, npc_display_name, ["What can I do for you today?"], func():
				player.unfreeze()
			)
			
			bubble.show_choices(["Lawhouse Politics", "Hand in Quests", "Leave"], func(choice):
				if choice == 0:
					var prov = "Valley Province"
					if npc_node:
						prov = GameState.get_province_of_node(npc_node)
					elif npc_id == "councilor_elena":
						prov = "Oakhaven Province"
					hud.open_lawhouse_ui(prov)
					bubble._on_close_pressed()
				elif choice == 1:
					bubble._on_close_pressed()
					if matching_quests.is_empty():
						GameState.show_npc_dialogue(talk_anchor, npc_display_name, ["You do not have any active quests for me right now. Check the Quest Board outside."])
					else:
						var completed_any = false
						for q in matching_quests:
							var item_id = q.target_item.id if q.target_item else ""
							var req_amount = q.target_amount
							var current_amount = GameState.player_inventory.get_item_amount(item_id) if item_id != "" else 0
							var req_gold = q.target_gold if "target_gold" in q else 0
							
							if (item_id == "" or current_amount >= req_amount) and (req_gold == 0 or GameState.gold >= req_gold):
								if item_id != "":
									GameState.player_inventory.remove_item(item_id, req_amount)
								if req_gold > 0:
									GameState.gold -= req_gold
								
								complete_quest(q)
								
								var reward_g = q.get_gold_reward()
								var lines = []
								if item_id != "":
									lines.append("Ah, the " + str(req_amount) + " " + (q.target_item.name if q.target_item else "items") + "! Fantastic work.")
								if req_gold > 0:
									lines.append("And the processing fee of " + str(req_gold) + " Gold has been cleared. Excellent.")
								lines.append("Thank you for your help, citizen.")
								if reward_g > 0:
									lines.append("Here is your reward of " + str(reward_g) + " Gold.")
								
								GameState.show_npc_dialogue(talk_anchor, npc_display_name, lines, func():
									if reward_g > 0:
										GameState.spawn_ui_floating_text("Quest Completed: " + q.title + "! Received " + str(reward_g) + " Gold")
									else:
										GameState.spawn_ui_floating_text("Quest Completed: " + q.title + "!")
								)
								completed_any = true
								break
						if not completed_any:
							var lines = ["You have active quests for me, but you do not meet the requirements yet:"]
							for q in matching_quests:
								var item_id = q.target_item.id if q.target_item else ""
								var current = GameState.player_inventory.get_item_amount(item_id) if item_id != "" else 0
								var req_gold = q.target_gold if "target_gold" in q else 0
								var req_str = ""
								if item_id != "":
									req_str += "Need " + str(q.target_amount) + " " + (q.target_item.name if q.target_item else "") + " (Have " + str(current) + ")"
								if req_gold > 0:
									if req_str != "":
										req_str += " and "
									req_str += "Need " + str(req_gold) + " Gold (Have " + str(GameState.gold) + ")"
								lines.append("- " + q.title + ": " + req_str)
							GameState.show_npc_dialogue(talk_anchor, npc_display_name, lines)
				else:
					bubble._on_close_pressed()
			)
	)

func complete_quest(quest: Resource) -> void:
	if active_quests_list.has(quest):
		active_quests_list.erase(quest)
		
	if not completed_quest_ids.has(quest.id):
		completed_quest_ids.append(quest.id)
		
	# Apply rewards
	GameState.gold += quest.get_gold_reward()
	
	if "unlocks_province_license" in quest and quest.unlocks_province_license != "":
		ProvinceMasterData.grant_province_license(quest.unlocks_province_license)

	
	var career_ref = quest.gates_profession_promotion if quest.gates_profession_promotion != "" else "patreon"
	if career_ref != "None":
		GameState.gain_profession_xp(career_ref, quest.get_xp_reward())
	else:
		GameState.gain_profession_xp("patreon", quest.get_xp_reward())
		
	GameState.influence += quest.get_influence_reward()
	
	# Award relationship bonus
	var target_id = quest.giver_npc_id
	var npcs = get_tree().get_nodes_in_group("NPCs")
	for npc in npcs:
		if npc.get("quest_npc_id") == target_id:
			var rel = npc.get_node_or_null("RelationshipComponent")
			if rel:
				rel.relationship_value += 15.0
				GameState.spawn_ui_floating_text("Relationship with %s increased (+15 Affinity)!" % npc.npc_name)
				
	completed_quests_count += 1
	_update_quest_states()
	quests_updated.emit()

func get_save_data() -> Dictionary:
	var active_ids = []
	for q in active_quests_list:
		active_ids.append(q.id)
		
	var board_ids = {}
	for region in active_quests:
		board_ids[region] = []
		for q in active_quests[region]:
			board_ids[region].append(q.id)
			
	return {
		"active_quest_ids": active_ids,
		"board_quest_ids": board_ids,
		"completed_quest_ids": completed_quest_ids,
		"completed_quests_count": completed_quests_count
	}

func load_save_data(data: Dictionary) -> void:
	completed_quest_ids = Array(data.get("completed_quest_ids", []))
	completed_quests_count = data.get("completed_quests_count", 0)
	
	active_quests_list.clear()
	var active_ids = data.get("active_quest_ids", [])
	for q_id in active_ids:
		if quest_map.has(q_id):
			active_quests_list.append(quest_map[q_id])
			
	var board_ids = data.get("board_quest_ids", {})
	for region in active_quests:
		active_quests[region] = []
		var ids = board_ids.get(region, [])
		for q_id in ids:
			if quest_map.has(q_id):
				active_quests[region].append(quest_map[q_id])
				
	_update_quest_states()
	quests_updated.emit()

func accept_relationship_quest(quest_dict: Dictionary) -> void:
	var q = QuestData.new()
	q.id = quest_dict.get("id", "rel_" + str(randi() % 10000))
	q.title = quest_dict.get("title", "")
	q.description = quest_dict.get("description", "")
	q.giver_npc_id = quest_dict.get("target_npc_id", "")
	q.region = quest_dict.get("region", "Valley Province")
	
	var item_id = quest_dict.get("item_id", "")
	if item_id != "" and EconomyManager.item_database.has(item_id):
		q.target_item = EconomyManager.item_database[item_id]
	q.target_amount = quest_dict.get("item_amount", 0)
	q.gold_reward = quest_dict.get("reward_gold", 0)
	
	active_quests_list.append(q)
	quests_updated.emit()
	GameState.spawn_ui_floating_text("Quest Accepted: " + q.title)

func get_available_npc_quests(npc_id: String) -> Array[QuestData]:
	var list: Array[QuestData] = []
	for q in all_quests:
		if q.giver_npc_id == npc_id:
			if q.unlocks_province_license != "" and ProvinceMasterData.has_province_license(q.unlocks_province_license):
				continue
			if not completed_quest_ids.has(q.id) and not active_quests_list.has(q) and not locked_quests.has(q):
				list.append(q)
	return list

func accept_npc_quest(q_id: String) -> void:
	if quest_map.has(q_id):
		var q = quest_map[q_id]
		if not active_quests_list.has(q):
			active_quests_list.append(q)
			_update_quest_states()
			quests_updated.emit()
			if GameState.has_method("spawn_ui_floating_text"):
				GameState.spawn_ui_floating_text("Quest Accepted: " + q.title)


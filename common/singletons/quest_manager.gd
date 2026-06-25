extends Node

signal quests_updated

# Dictionary of region_name -> Array of quest Dictionaries
var active_quests: Dictionary = {
	"Valley Province": [],
	"Oakhaven Province": []
}

# Array of quest Dictionaries accepted by player
var accepted_quests: Array = []

# Completed quest count
var completed_quests_count: int = 0

# Database of templates for random quest generation
var quest_templates = [
	{
		"item_id": "iron_ore",
		"item_name": "Iron Ore",
		"base_amount": 10,
		"base_reward": 180,
		"due_days": 2,
		"req_level": 1,
		"difficulty": "Beginner"
	},
	{
		"item_id": "wheat",
		"item_name": "Wheat",
		"base_amount": 15,
		"base_reward": 120,
		"due_days": 2,
		"req_level": 1,
		"difficulty": "Beginner"
	},
	{
		"item_id": "cotton",
		"item_name": "Cotton",
		"base_amount": 12,
		"base_reward": 150,
		"due_days": 2,
		"req_level": 1,
		"difficulty": "Beginner"
	},
	{
		"item_id": "flour",
		"item_name": "Flour",
		"base_amount": 8,
		"base_reward": 200,
		"due_days": 2,
		"req_level": 2,
		"difficulty": "Beginner"
	},
	{
		"item_id": "cloth",
		"item_name": "Cloth",
		"base_amount": 8,
		"base_reward": 250,
		"due_days": 2,
		"req_level": 2,
		"difficulty": "Beginner"
	},
	{
		"item_id": "iron_ingot",
		"item_name": "Iron Ingot",
		"base_amount": 5,
		"base_reward": 300,
		"due_days": 3,
		"req_level": 3,
		"difficulty": "Advanced"
	},
	{
		"item_id": "oil",
		"item_name": "Oil",
		"base_amount": 6,
		"base_reward": 240,
		"due_days": 2,
		"req_level": 3,
		"difficulty": "Advanced"
	},
	{
		"item_id": "paper",
		"item_name": "Paper",
		"base_amount": 12,
		"base_reward": 220,
		"due_days": 2,
		"req_level": 3,
		"difficulty": "Advanced"
	},
	{
		"item_id": "bread",
		"item_name": "Bread",
		"base_amount": 8,
		"base_reward": 350,
		"due_days": 3,
		"req_level": 4,
		"difficulty": "Advanced"
	},
	{
		"item_id": "book",
		"item_name": "Book",
		"base_amount": 4,
		"base_reward": 400,
		"due_days": 3,
		"req_level": 4,
		"difficulty": "Advanced"
	},
	{
		"item_id": "ale",
		"item_name": "Ale",
		"base_amount": 6,
		"base_reward": 320,
		"due_days": 2,
		"req_level": 4,
		"difficulty": "Advanced"
	},
	{
		"item_id": "meadhaven",
		"item_name": "Meadhaven",
		"base_amount": 5,
		"base_reward": 380,
		"due_days": 3,
		"req_level": 5,
		"difficulty": "Expert"
	},
	{
		"item_id": "cured_pork",
		"item_name": "Cured Pork",
		"base_amount": 5,
		"base_reward": 360,
		"due_days": 2,
		"req_level": 5,
		"difficulty": "Expert"
	},
	{
		"item_id": "sweet_berry_cake",
		"item_name": "Sweet Berry Cake",
		"base_amount": 3,
		"base_reward": 450,
		"due_days": 3,
		"req_level": 5,
		"difficulty": "Expert"
	}
]

var last_checked_day: int = 1

func _ready() -> void:
	# Load templates from JSON if available
	var file = FileAccess.open("res://common/singletons/quest_templates.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			if json.data is Array:
				quest_templates = json.data
			else:
				print("[QuestManager] JSON data is not an Array, using defaults.")
		else:
			print("[QuestManager] Failed to parse quest_templates.json: ", json.get_error_message())
	else:
		print("[QuestManager] quest_templates.json not found, using default templates.")

	TimeManager.time_changed.connect(_on_time_changed)
	# Initial generation for Day 1
	call_deferred("generate_quests_for_day", 1)

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	if days != last_checked_day:
		last_checked_day = days
		on_day_advanced(days)


func generate_quests_for_day(day: int) -> void:
	# 1. Clear expired active quests (unaccepted quests expire from boards after 1 day)
	for region in active_quests:
		active_quests[region] = []
	
	# 2. Generate new quests matching player's title level
	var title_lvl = GameState.title_level
	var available_templates = []
	for t in quest_templates:
		if t.req_level <= title_lvl:
			available_templates.append(t)
			
	if available_templates.is_empty():
		available_templates = [quest_templates[0]] # fallback
		
	for region in active_quests:
		# Guarantee the Iron Ore starter quest on Day 1 in Valley Province
		if day == 1 and region == "Valley Province":
			var starter_quest = _create_quest_from_template(quest_templates[0], region, day)
			active_quests[region].append(starter_quest)
			# Add another random early quest
			var t2 = quest_templates[1] # Wheat
			active_quests[region].append(_create_quest_from_template(t2, region, day))
		else:
			# Random generation of 2-3 quests per region
			var count = randi_range(2, 3)
			var picked_templates = []
			var temp_list = available_templates.duplicate()
			temp_list.shuffle()
			for i in range(min(count, temp_list.size())):
				picked_templates.append(temp_list[i])
				
			for t in picked_templates:
				var quest = _create_quest_from_template(t, region, day)
				active_quests[region].append(quest)
				
	quests_updated.emit()

func _create_quest_from_template(t: Dictionary, region: String, day: int) -> Dictionary:
	var target_npc_id = "councilor_marcus" if region == "Valley Province" else "councilor_elena"
	var target_npc_name = "Councilor Marcus" if region == "Valley Province" else "Councilor Elena"
	
	return {
		"id": "q_" + t.item_id + "_" + str(randi() % 10000) + "_" + str(day),
		"title": "Deliver " + t.item_name,
		"description": target_npc_name + " in " + region + " is asking for " + str(t.base_amount) + " " + t.item_name + ".",
		"type": "delivery",
		"difficulty": t.difficulty,
		"req_title_level": t.req_level,
		"region": region,
		"item_id": t.item_id,
		"item_name": t.item_name,
		"item_amount": t.base_amount,
		"target_npc_id": target_npc_id,
		"target_npc_name": target_npc_name,
		"reward_gold": t.base_reward,
		"due_days": t.due_days,
		"generated_day": day,
		"accepted_day": -1,
		"due_day": -1
	}

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
	
	quest["accepted_day"] = TimeManager.time_days
	quest["due_day"] = TimeManager.time_days + quest.due_days
	
	accepted_quests.append(quest)
	quests_updated.emit()
	
	# Spawn alert
	GameState.spawn_ui_floating_text("Quest Accepted: " + quest.title)
	return true

func on_day_advanced(new_day: int) -> void:
	# 1. Check failed quests (due date logic)
	var failed_quests = []
	var remaining_accepted = []
	for q in accepted_quests:
		if new_day > q.due_day:
			failed_quests.append(q)
		else:
			remaining_accepted.append(q)
			
	accepted_quests = remaining_accepted
	
	for q in failed_quests:
		GameState.spawn_ui_floating_text("Quest Failed (Expired): " + q.title)
		
	# 2. Generate quests for the new day
	generate_quests_for_day(new_day)
	quests_updated.emit()

func try_complete_quest(npc_id: String, player: CharacterBody2D) -> void:
	var matching_quests = []
	for q in accepted_quests:
		if q.target_npc_id == npc_id:
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
					hud.call_deferred("open_lawhouse_ui", prov)
					bubble._on_close_pressed()
				elif choice == 1:
					bubble._on_close_pressed()
					if matching_quests.is_empty():
						GameState.show_npc_dialogue(talk_anchor, npc_display_name, ["You do not have any active quests for me right now. Check the Quest Board outside."])
					else:
						var completed_any = false
						for q in matching_quests:
							var item_id = q.item_id
							var req_amount = q.item_amount
							var current_amount = GameState.player_inventory.get_item_amount(item_id)
							
							if current_amount >= req_amount:
								GameState.player_inventory.remove_item(item_id, req_amount)
								GameState.gold += q.reward_gold
								completed_quests_count += 1
								
								var lines = [
									"Ah, the " + str(req_amount) + " " + q.item_name + "! Fantastic work.",
									"Thank you for your help, citizen.",
									"Here is your reward of " + str(q.reward_gold) + " Gold."
								]
								
								GameState.show_npc_dialogue(talk_anchor, npc_display_name, lines, func():
									GameState.spawn_ui_floating_text("Quest Completed: " + q.title + "! Received " + str(q.reward_gold) + " Gold")
								)
								
								accepted_quests.erase(q)
								completed_any = true
								quests_updated.emit()
								break
						if not completed_any:
							var lines = ["You have active quests for me, but you do not have all the required items yet:"]
							for q in matching_quests:
								var current = GameState.player_inventory.get_item_amount(q.item_id)
								lines.append("- " + q.title + ": Need " + str(q.item_amount) + " " + q.item_name + " (Have " + str(current) + ")")
							GameState.show_npc_dialogue(talk_anchor, npc_display_name, lines)
				else:
					bubble._on_close_pressed()
			)
	)

func get_save_data() -> Dictionary:
	return {
		"active_quests": active_quests,
		"accepted_quests": accepted_quests,
		"completed_quests_count": completed_quests_count
	}

func load_save_data(data: Dictionary) -> void:
	active_quests = data.get("active_quests", {
		"Valley Province": [],
		"Oakhaven Province": []
	})
	accepted_quests = data.get("accepted_quests", [])
	completed_quests_count = data.get("completed_quests_count", 0)
	last_checked_day = TimeManager.time_days
	
	# If loaded/active data is empty, populate quests for the current day
	var total_active = 0
	for region in active_quests:
		total_active += active_quests[region].size()
	if total_active == 0 and accepted_quests.is_empty():
		generate_quests_for_day(TimeManager.time_days)
	else:
		quests_updated.emit()

func accept_relationship_quest(quest: Dictionary) -> void:
	accepted_quests.append(quest)
	quests_updated.emit()
	GameState.spawn_ui_floating_text("Quest Accepted: " + quest.title)

func complete_quest(quest: Dictionary) -> void:
	if accepted_quests.has(quest):
		accepted_quests.erase(quest)
	GameState.gold += quest.reward_gold
	
	if GameState.completed_relation_quests == null:
		GameState.completed_relation_quests = []
	GameState.completed_relation_quests.append(quest.id)
	
	# Award relationship bonus
	var target_id = quest.get("target_npc_id")
	var npcs = get_tree().get_nodes_in_group("NPCs")
	for npc in npcs:
		if npc.get("quest_npc_id") == target_id:
			var rel = npc.get_node_or_null("RelationshipComponent")
			if rel:
				rel.relationship_value += 15.0
				GameState.spawn_ui_floating_text("Relationship with %s increased (+15 Affinity)!" % npc.npc_name)
				
	completed_quests_count += 1
	quests_updated.emit()

extends Node

var npc: CharacterBody2D = null
var _relationship_icon: Label = null

func setup(p_npc: CharacterBody2D) -> void:
	npc = p_npc

func get_interaction_text() -> String:
	if npc.has_meta("is_guild_master"):
		return "Talk to " + npc.npc_name
	if npc.has_meta("is_guild_office_npc"):
		return "Talk to " + npc.npc_name
	if npc.is_quest_npc:
		var matching = []
		for q in QuestManager.accepted_quests:
			if q.target_npc_id == npc.quest_npc_id:
				matching.append(q)
		for q in matching:
			var current = GameState.player_inventory.get_item_amount(q.item_id)
			if current >= q.item_amount:
				return "Complete Quest: Deliver " + q.item_name
		return "Talk to Councilor"
	return "Talk to " + npc.npc_name

func interact(player: CharacterBody2D) -> void:
	if npc.npc_rank in ["Mayor", "Burgomeister", "Town Clerk", "High Councilor", "Law Scribe"]:
		_interact_fixed_municipal_npc(player)
		return
		
	if npc.has_meta("is_guild_master") or npc.has_meta("is_guild_office_npc"):
		var npc_prov = GameState.get_province_of_node(npc)
		if not ProvinceMasterData.has_province_license(npc_prov):
			var lines = [
				"Hold on. You are not from around here.",
				"To access local guild services in %s, you must first obtain an operating license from the City Hall." % npc_prov
			]
			GameState.show_npc_dialogue(npc, npc.npc_name, lines)
			return

	if npc.has_meta("is_guild_master"):
		_interact_guild_master(player)
		return
		
	if npc.has_meta("is_guild_office_npc"):
		_interact_guild_office_npc(player)
		return
		
	if npc.npc_type == 1: # TYPE_RELATION_TARGET
		var rel_ui_scene = load("res://UI/relationship_ui.tscn")
		if rel_ui_scene:
			var rel_ui = rel_ui_scene.instantiate()
			var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = npc.get_tree().get_first_node_in_group("game_hud")
			if hud:
				var parent_node = hud.get_node_or_null("Control")
				if parent_node:
					parent_node.add_child(rel_ui)
				else:
					hud.add_child(rel_ui)
				rel_ui.setup(npc)
				return
				
	if npc.is_quest_npc:
		QuestManager.try_complete_quest(npc.quest_npc_id, player)
	else:
		var career_name = npc.career.capitalize() if npc.career != "" else "Citizen"
		var lines = [
			"Hello there! My name is %s." % npc.npc_name,
			"I work as a %s here in %s." % [career_name, npc.province],
			"It's a beautiful day to build and trade in Guild Valley!"
		]
		GameState.show_npc_dialogue(npc, npc.npc_name, lines)

func _interact_guild_master(player: CharacterBody2D) -> void:
	var target_prof = npc.get_meta("guild_profession") if npc.has_meta("guild_profession") else "General"
	
	if target_prof != "General" and GameState.career_levels.get(target_prof, 0) == 0:
		var lines = [
			"Welcome to the %s Guild Hall." % target_prof.capitalize(),
			"I am the Guild Master, but I only deal with rank advancements for %ss." % target_prof.capitalize(),
			"You do not belong to our guild. Please speak to your own Guild Master if you seek rank advancement."
		]
		GameState.show_npc_dialogue(npc, npc.npc_name, lines)
		return

	var eligible = []
	
	# Player
	for cr in GameState.career_levels:
		if target_prof != "General" and cr != target_prof:
			continue
		var lvl = GameState.career_levels[cr]
		if lvl in [3, 6, 9]:
			var already_has = false
			for path in GameState.active_trial_recipes:
				var trial = load(path)
				if trial and trial.required_career == cr and trial.get_meta("character_name") == "Player":
					already_has = true
					break
			if not already_has:
				eligible.append({
					"name": "Player",
					"is_player": true,
					"career": cr,
					"level": lvl,
					"ref": null
				})
				
	# Employees
	var workshops = npc.get_tree().get_nodes_in_group("production_buildings")
	for ws in workshops:
		if ws.ownership_type == "Player":
			for emp in ws.hired_employees:
				var npc_ref = emp.get("npc_ref")
				if is_instance_valid(npc_ref):
					for cr in npc_ref.skills_data:
						if target_prof != "General" and cr != target_prof:
							continue
						var lvl = npc_ref.skills_data[cr].get("level", 1)
						if lvl in [3, 6, 9]:
							var already_has = false
							for path in GameState.active_trial_recipes:
								var trial = load(path)
								if trial and trial.required_career == cr and trial.get_meta("character_name") == npc_ref.npc_name:
									already_has = true
									break
							if not already_has:
								eligible.append({
									"name": npc_ref.npc_name,
									"is_player": false,
									"career": cr,
									"level": lvl,
									"ref": npc_ref
								})
								
	var choices: Array[String] = []
	for data in eligible:
		var fee = 100
		if data.level == 6: fee = 250
		elif data.level == 9: fee = 500
		choices.append("%s: %s Breakthrough (%d Gold)" % [data.name, data.career.capitalize(), fee])
	choices.append("Cancel")
	
	var dialogue_key = ""
	if npc.npc_runtime_state:
		dialogue_key = npc.npc_runtime_state.local_state.get("active_dialogue_key", "")
	
	var fallback = [
		"Welcome to the Guild Hall, citizen.",
		"I manage professional rank advancements here.",
		"Do you or your hired employees have a breakthrough rank trial to request?"
	]
	var lines = WindowManager.get_dialogue(dialogue_key, fallback)
	
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	if not bubble_scene:
		return
	var bubble = bubble_scene.instantiate()
	var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = npc.get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
			
		player.freeze()
		bubble.start_dialogue(npc, npc.npc_name, lines, func():
			player.unfreeze()
		)
		bubble.show_choices(choices, func(choice_idx):
			bubble._on_close_pressed()
			if choice_idx < eligible.size():
				var target_data = eligible[choice_idx]
				_start_breakthrough_quest(target_data)
		)

func _interact_guild_office_npc(player: CharacterBody2D) -> void:
	var target_prof = npc.get_meta("guild_profession") if npc.has_meta("guild_profession") else "General"
	
	if target_prof != "General" and GameState.career_levels.get(target_prof, 0) == 0:
		var office_name = npc.get_meta("office_name") if npc.has_meta("office_name") else "Office"
		var lines = [
			"Hello there. This is the office of the %s for the %s Guild." % [office_name, target_prof.capitalize()],
			"I am afraid we only serve registered guild members here.",
			"Since you are not a %s, I cannot help you." % target_prof.capitalize()
		]
		GameState.show_npc_dialogue(npc, npc.npc_name, lines)
		return

	var office_name = npc.get_meta("office_name") if npc.has_meta("office_name") else "Office"
	
	var lines = []
	var choices = []
	var dialogue_key = ""
	if npc.npc_runtime_state:
		dialogue_key = npc.npc_runtime_state.local_state.get("active_dialogue_key", "")
	
	if office_name == "Grand Chairman":
		var fallback = [
			"Greetings, citizen. I am the Grand Chairman of the conclave.",
			"Here we coordinate political campaigns, seasonal council seat elections, and regulatory audits.",
			"How can I assist you in conclave politics today?"
		]
		lines = WindowManager.get_dialogue(dialogue_key, fallback)
		choices = ["Manage Conclave Elections", "Access Edicts & Audits", "Cancel"]
	elif office_name == "Logistics Overseer":
		var fallback = [
			"Greetings, citizen. I am the Donations Overseer for the guild.",
			"You can donate Gold or commodity stockpiles to elevate our province's prosperity.",
			"Would you like to make a donation?"
		]
		lines = WindowManager.get_dialogue(dialogue_key, fallback)
		choices = ["Open Donations UI", "Cancel"]
	else: # Materials Steward
		var fallback = [
			"Greetings, merchant. I am the Materials Steward.",
			"I authorize the purchase of wholesale material bundles when province prosperity milestones are reached.",
			"Would you like to review available timed bundles?"
		]
		lines = WindowManager.get_dialogue(dialogue_key, fallback)
		choices = ["Open Wholesaler Bundles", "Cancel"]
		
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	if not bubble_scene:
		return
	var bubble = bubble_scene.instantiate()
	var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = npc.get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
			
		player.freeze()
		bubble.start_dialogue(npc, npc.npc_name, lines, func():
			player.unfreeze()
		)
		bubble.show_choices(choices, func(choice_idx):
			bubble._on_close_pressed()
			
			if office_name == "Grand Chairman":
				if choice_idx == 0 or choice_idx == 1:
					WindowManager.open_window(WindowManager.WindowType.WINDOW_GUILD_LEVEL, npc)
			elif office_name == "Logistics Overseer":
				if choice_idx == 0:
					WindowManager.open_window(WindowManager.WindowType.WINDOW_GUILD_LEVEL, npc)
			elif office_name == "Materials Steward":
				if choice_idx == 0:
					WindowManager.open_window(WindowManager.WindowType.WINDOW_SHOP, npc)
		)

func _interact_fixed_municipal_npc(player: CharacterBody2D) -> void:
	var lines = []
	var choices = []
	var dialogue_key = ""
	if npc.npc_runtime_state:
		dialogue_key = npc.npc_runtime_state.local_state.get("active_dialogue_key", "")
	
	if npc.npc_rank in ["Mayor", "Burgomeister"]:
		var fallback = [
			"Greetings, citizen. As {npc_rank} of {city_name}, I oversee our local administration.",
			"We coordinate regional charter policies, tax updates, and regulatory sponsor projects here.",
			"How can I assist you today?"
		]
		lines = WindowManager.get_dialogue(dialogue_key, fallback)
		choices = ["Review Lawhouse Politics", "Request Title Promotion", "Cancel"]
	elif npc.npc_rank in ["High Councilor"]:
		var fallback = [
			"Ah, welcome, traveler. I am {npc_name}, {npc_rank} of the council.",
			"Here at the Lawhouse, we vote on regional edicts and hear sponsors.",
			"Would you like to manage council votes or complete active quests?"
		]
		lines = WindowManager.get_dialogue(dialogue_key, fallback)
		choices = ["Access Council Politics", "Submit Quest Deliveries", "Request Title Promotion", "Cancel"]
	else: # Town Clerk / Law Scribe
		var fallback = [
			"Welcome to the local administration chambers. I am {npc_name}, {npc_rank}.",
			"I keep records of regional contracts, citizen petitions, and active quest listings.",
			"Would you like to review the local Quest Board?"
		]
		lines = WindowManager.get_dialogue(dialogue_key, fallback)
		choices = ["Open Quest Board", "Cancel"]
		
	var avail_quests = QuestManager.get_available_npc_quests(npc.quest_npc_id)
	var cancel_idx = choices.find("Cancel")
	if cancel_idx != -1:
		for q in avail_quests:
			choices.insert(cancel_idx, "Accept Quest: " + q.title)
			cancel_idx += 1
	else:
		for q in avail_quests:
			choices.append("Accept Quest: " + q.title)
			
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	if not bubble_scene:
		return
	var bubble = bubble_scene.instantiate()
	var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = npc.get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
			
		player.freeze()
		bubble.start_dialogue(npc, npc.npc_name, lines, func():
			player.unfreeze()
		)
		bubble.show_choices(choices, func(choice_idx):
			bubble._on_close_pressed()
			
			var base_quest_idx = choices.size() - 1 - avail_quests.size()
			if choice_idx >= base_quest_idx and choice_idx < base_quest_idx + avail_quests.size():
				var q = avail_quests[choice_idx - base_quest_idx]
				QuestManager.accept_npc_quest(q.id)
				return
				
			var selected_choice = choices[choice_idx]
			if selected_choice == "Request Title Promotion":
				_open_title_promotion_screen()
				return
				
			if npc.npc_rank in ["Mayor", "Burgomeister"]:
				if choice_idx == 0:
					WindowManager.open_window(WindowManager.WindowType.WINDOW_POLITICS, npc)
			elif npc.npc_rank == "High Councilor":
				if choice_idx == 0:
					WindowManager.open_window(WindowManager.WindowType.WINDOW_POLITICS, npc)
				elif choice_idx == 1:
					QuestManager.try_complete_quest(npc.quest_npc_id, player)
			else: # Clerk / Scribe
				if choice_idx == 0:
					WindowManager.open_window(WindowManager.WindowType.WINDOW_QUEST_BOARD, npc)
		)

func _open_title_promotion_screen() -> void:
	var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = npc.get_tree().get_first_node_in_group("game_hud")
	if hud:
		var title_window = hud.get("title_upgrade_window")
		if title_window and not title_window.visible:
			hud.call("toggle_window", title_window)

func _start_breakthrough_quest(data: Dictionary) -> void:
	var fee = 100
	if data.level == 6: fee = 250
	elif data.level == 9: fee = 500
	
	if GameState.gold < fee:
		GameState.spawn_ui_floating_text("You need at least %d Gold to start this breakthrough!" % fee)
		return
		
	var trial = Recipe.new()
	trial.recipe_name = "Trial: %s %s" % [data.name, data.career.capitalize()]
	trial.required_career = data.career
	trial.required_level = 1
	trial.xp_reward = 0
	trial.is_breakthrough_only = true
	trial.set_meta("character_name", data.name)
	trial.set_meta("is_player", data.is_player)
	trial.set_meta("career", data.career)
	trial.set_meta("level", data.level)
	trial.set_meta("gold_fee", fee)
	
	var wheat = load("res://common/items/instances/Raw Materials/wheat.tres") as ItemData
	var flour = load("res://common/items/instances/Semi-Elaborate/flour.tres") as ItemData
	var bread = load("res://common/items/instances/Finished Goods/bread.tres") as ItemData
	var cotton = load("res://common/items/instances/Raw Materials/cotton.tres") as ItemData
	var cloth = load("res://common/items/instances/Semi-Elaborate/cloth.tres") as ItemData
	var ore = load("res://common/items/instances/Raw Materials/iron_ore.tres") as ItemData
	var ingot = load("res://common/items/instances/Semi-Elaborate/iron_ingot.tres") as ItemData
	var paper = load("res://common/items/instances/Semi-Elaborate/paper.tres") as ItemData
	var book = load("res://common/items/instances/Skill Items/book_patreon.tres") as ItemData
	
	var inputs: Dictionary[ItemData, int] = {}
	if data.career == "patreon":
		if data.level == 3:
			inputs[wheat] = 5
		elif data.level == 6:
			inputs[flour] = 5
		else:
			inputs[bread] = 10
	elif data.career == "craftsman":
		if data.level == 3:
			inputs[ore] = 5
		elif data.level == 6:
			inputs[ingot] = 5
		else:
			inputs[ingot] = 10
	elif data.career == "tailor":
		if data.level == 3:
			inputs[cotton] = 5
		elif data.level == 6:
			inputs[cloth] = 5
		else:
			inputs[cloth] = 10
	else:
		if data.level == 3:
			inputs[paper] = 5
		elif data.level == 6:
			inputs[book] = 2
		else:
			inputs[book] = 5
			
	var final_inputs: Dictionary[ItemData, int] = {}
	for k in inputs:
		if k != null:
			final_inputs[k] = inputs[k]
	if final_inputs.is_empty() and wheat != null:
		final_inputs[wheat] = 1
		
	trial.inputs = final_inputs
	
	var milestone = ItemData.new()
	milestone.id = ("milestone_%s_%s_%d" % [data.name, data.career, data.level]).validate_node_name()
	milestone.name = "%s's %s Milestone" % [data.name, data.career.capitalize()]
	milestone.base_value = 1
	milestone.is_tradable = false
	trial.output_item = milestone
	trial.output_amount = 1
	
	var file_name = ("breakthrough_%s_%s_%d.tres" % [data.name, data.career, data.level]).validate_node_name()
	var path = "user://" + file_name
	ResourceSaver.save(trial, path)
	
	GameState.active_trial_recipes.append(path)
	
	var message = "I have drafted the trial recipe: '%s'. Craft this milestone item at a Tier 2+ production workshop for %s to break through!" % [trial.recipe_name, data.career.capitalize()]
	GameState.show_npc_dialogue(npc, "Guild Master", [message])

func setup_relationship_component() -> void:
	if npc.npc_type != 1: # TYPE_RELATION_TARGET
		return
	var rel = npc.get_node_or_null("RelationshipComponent")
	if not rel:
		return
	match npc.quest_npc_id:
		"elena":
			rel.hidden_preferences = ["spool_thread", "red_dye", "blue_dye"]
			rel.disliked_preferences = ["iron_ore", "corrosive_acid", "animal_feed", "smugglers_moonshine"]
			rel.profession_type = "tailor"
			rel.profession_level = 3
		"aldous":
			rel.hidden_preferences = ["ancient_manuscript", "ink", "paper"]
			rel.disliked_preferences = ["smugglers_moonshine", "animal_feed", "iron_ore", "corrosive_acid"]
			rel.profession_type = "scholar"
			rel.profession_level = 4
		"valeria":
			rel.hidden_preferences = ["confidential_documents", "gold_ring", "silver_necklace"]
			rel.disliked_preferences = ["animal_feed", "iron_ore", "wheat", "cotton", "smugglers_moonshine"]
			rel.profession_type = "scholar"
			rel.profession_level = 5
		"gideon":
			rel.hidden_preferences = ["standard_timber", "iron_ingot", "iron_ore"]
			rel.disliked_preferences = ["ancient_manuscript", "confidential_documents", "paper", "smugglers_moonshine"]
			rel.profession_type = "craftsman"
			rel.profession_level = 3

func setup_relationship_icon() -> void:
	if npc.npc_type != 1: # TYPE_RELATION_TARGET
		return
	var rel = npc.get_node_or_null("RelationshipComponent")
	if not rel:
		return
	
	_relationship_icon = Label.new()
	_relationship_icon.name = "RelationshipIcon"
	_relationship_icon.text = "♥"
	_relationship_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relationship_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_relationship_icon.add_theme_font_size_override("font_size", 20)
	_relationship_icon.add_theme_color_override("font_outline_color", Color.BLACK)
	_relationship_icon.add_theme_constant_override("outline_size", 4)
	_relationship_icon.custom_minimum_size = Vector2(40, 40)
	_relationship_icon.position = Vector2(-20, -85)
	_relationship_icon.z_index = 21
	npc.add_child(_relationship_icon)
	
	_update_relationship_icon(rel.relationship_value)
	
	if not rel.relationship_changed.is_connected(_update_relationship_icon):
		rel.relationship_changed.connect(_update_relationship_icon)

func _update_relationship_icon(val: float) -> void:
	if not is_instance_valid(_relationship_icon):
		return
	
	var color = Color.YELLOW
	if val < 0.0:
		color = Color.RED
	elif val >= 60.0:
		color = Color(1.0, 0.4, 0.7) # Pink
	elif val >= 30.0:
		color = Color.GREEN
		
	_relationship_icon.add_theme_color_override("font_color", color)

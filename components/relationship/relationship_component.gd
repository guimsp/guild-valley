class_name RelationshipComponent
extends Node

signal relationship_changed(new_value: float)

@export var relationship_value: float = 0.0:
	set(val):
		var old_val = relationship_value
		relationship_value = clamp(val, -100.0, 100.0)
		if relationship_value != old_val:
			relationship_changed.emit(relationship_value)
			_check_milestones(old_val, relationship_value)

@export var has_granted_influence_bonus: bool = false
@export var daily_interaction_slots: int = 3
@export var discovered_likes: Array = []

# List of item IDs this NPC likes
@export var hidden_preferences: Array = []
@export var disliked_preferences: Array = []
@export var profession_type: String = "patreon"
@export var profession_level: int = 1

var irritated_timer: float = 0.0
var retaliation_flag: bool = false

func _ready() -> void:
	# Reset daily slots at day change
	if GameState:
		TimeManager.time_changed.connect(_on_time_changed)

func _process(delta: float) -> void:
	if irritated_timer > 0.0:
		irritated_timer -= delta

func _on_time_changed(_hours: int, _minutes: int, _days: int) -> void:
	# Reset daily slots every morning (6 AM) or at day advance
	if _hours == 6 and _minutes == 0:
		daily_interaction_slots = 3

func is_irritated() -> bool:
	return irritated_timer > 0.0

func get_relationship_stage() -> String:
	if relationship_value <= -50:
		return "Enemy"
	elif relationship_value < 20:
		return "Neutral"
	elif relationship_value < 60:
		return "Friend"
	elif relationship_value < 90:
		return "Dating"
	else:
		return "Spouse"

func _check_milestones(old_val: float, new_val: float) -> void:
	# 20 to 59 (Friend): milestone bonus of +50 Global Influence
	if new_val >= 20.0 and old_val < 20.0 and not has_granted_influence_bonus:
		has_granted_influence_bonus = true
		if GameState:
			GameState.influence += 50
			GameState.spawn_ui_floating_text("+50 Global Influence (Friend Milestone)")

func can_interact() -> bool:
	if relationship_value <= -50:
		return false
	if daily_interaction_slots <= 0:
		return false
	if is_irritated():
		return false
	return true

# Dynamic Success Formula
func get_success_chance(base_chance: float) -> float:
	return clamp(base_chance + (relationship_value / 200.0), 0.05, 0.95)

func chat() -> Dictionary:
	if not can_interact():
		return {"status": "decline", "message": _get_decline_message()}
		
	daily_interaction_slots -= 1
	var chance = get_success_chance(0.70)
	var roll = randf()
	
	if roll <= chance:
		# Success
		var points = randi_range(3, 6)
		relationship_value += points
		
		# Taste discovery: 25% chance
		var discovered_item = ""
		if randf() < 0.25 and not hidden_preferences.is_empty():
			# Pick a preference not yet discovered
			var undiscovered = []
			for pref in hidden_preferences:
				if not (pref in discovered_likes):
					undiscovered.append(pref)
			if not undiscovered.is_empty():
				discovered_item = undiscovered.pick_random()
				discovered_likes.append(discovered_item)
				
		return {
			"status": "success",
			"points": points,
			"discovered_item": discovered_item,
			"message": get_custom_message("chat", "success")
		}
	else:
		# Failure
		# If roll is very high (bad luck) and above success, it's a critical failure
		if roll > 0.90:
			relationship_value -= randi_range(8, 12)
			irritated_timer = 45.0
			return {
				"status": "crit_fail",
				"message": get_custom_message("chat", "crit_fail")
			}
		else:
			relationship_value -= 1
			return {
				"status": "fail",
				"message": get_custom_message("chat", "fail")
			}

func flirt() -> Dictionary:
	if relationship_value < 60.0:
		return {"status": "locked", "message": "Flirting requires Dating stage (60+ relationship)."}
		
	if not can_interact():
		return {"status": "decline", "message": _get_decline_message()}
		
	daily_interaction_slots -= 1
	var chance = get_success_chance(0.50)
	var roll = randf()
	
	if roll <= chance:
		var points = randi_range(6, 12)
		relationship_value += points
		return {
			"status": "success",
			"points": points,
			"message": get_custom_message("flirt", "success")
		}
	else:
		if roll > 0.85:
			relationship_value -= randi_range(12, 18)
			irritated_timer = 60.0
			return {
				"status": "crit_fail",
				"message": get_custom_message("flirt", "crit_fail")
			}
		else:
			relationship_value -= 3
			return {
				"status": "fail",
				"message": get_custom_message("flirt", "fail")
			}

func gift(item: ItemData) -> Dictionary:
	if not can_interact():
		return {"status": "decline", "message": _get_decline_message()}
		
	daily_interaction_slots -= 1
	
	var is_preferred = item.id in hidden_preferences
	var is_disliked = item.id in disliked_preferences
	var is_profession_exclusive = _is_profession_exclusive(item)
	
	var points = 0
	var msg = ""
	var status = "success"
	
	if is_disliked:
		points = randi_range(-8, -4)
		msg = get_custom_message("gift", "dislike")
		status = "dislike"
	elif is_preferred:
		points = randi_range(15, 22)
		msg = "Oh my! How did you know I love %s? This is absolutely perfect!" % item.name
		if not (item.id in discovered_likes):
			discovered_likes.append(item.id)
	elif is_profession_exclusive:
		points = randi_range(18, 25)
		msg = "Incredible! A fine piece of craft from my own trade. I appreciate the high-quality %s!" % item.name
	else:
		points = randi_range(4, 7)
		msg = "Thank you. This is a nice gift of %s." % item.name
		
	relationship_value += points
	return {
		"status": status,
		"points": points,
		"message": msg
	}

func _is_profession_exclusive(item: ItemData) -> bool:
	# Checks if gifted item is a crafted product related to the NPC's profession
	match profession_type:
		"tailor":
			return item.id in ["spool_thread", "concentrated_dyes", "cloth"]
		"scholar":
			return item.id in ["paper", "book", "ancient_manuscript"]
		"rogue":
			return item.id in ["corrosive_acid", "confidential_documents"]
		"woodworker":
			return item.id in ["standard_timber", "heavy_steel_tools"]
		"craftsman":
			return item.id in ["iron_ingot", "iron_nails", "sheet_metal", "simple_iron_tools", "heavy_steel_tools"]
	return false

func propose_marriage(npc_id: String, npc_name: String) -> Dictionary:
	if relationship_value < 90.0:
		return {"status": "locked", "message": "Marriage requires Spouse level relationship (90+)."}
		
	if GameState.is_married:
		return {"status": "rejected", "message": "You are already married!"}
		
	# Enforce personal home requirement
	var player_house = null
	for house in get_tree().get_nodes_in_group("Houses"):
		if is_instance_valid(house) and house.get("ownership_type") == "Player" and not house.get("is_rental"):
			player_house = house
			break
	if not player_house:
		return {"status": "rejected", "message": "Marriage requires a personal home. Please buy or place a personal house first!"}
		
	# Success! Monogamy and Retaliatory Jealousy checks
	GameState.is_married = true
	GameState.spouse_npc_id = npc_id
	
	# Teleport spouse to player's house and update spawn_position
	for npc in get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and npc.get("quest_npc_id") == npc_id:
			npc.global_position = player_house.global_position
			if "spawn_position" in npc:
				npc.spawn_position = player_house.global_position
			break
	
	# Any other NPC in Dating range (>= 60) instantly plummets to -80 (Enemy) and sets retaliation
	var relation_npcs = get_tree().get_nodes_in_group("RelationNPCs")
	for other_npc in relation_npcs:
		if other_npc.get("quest_npc_id") != npc_id:
			var rel = other_npc.get_node_or_null("RelationshipComponent")
			if rel and rel.relationship_value >= 60.0:
				rel.relationship_value = -80.0
				rel.retaliation_flag = true
				GameState.spawn_ui_floating_text("%s feels extremely betrayed and is now an Enemy!" % other_npc.npc_name)
				
	# Unlock profession type and level permanently for player
	if GameState.career_levels.has(profession_type):
		if GameState.career_levels[profession_type] > 0 or GameState.get_active_careers_count() < GameState.max_profession_slots:
			GameState.career_levels[profession_type] = max(GameState.career_levels[profession_type], profession_level)
			GameState.recalculate_career_stats()
		else:
			if GameState:
				GameState.spawn_ui_floating_text("Career slots full! Spouse career not unlocked.")
		
	return {
		"status": "success",
		"message": "They say YES! The wedding bells ring out. %s is now your spouse and has moved into your household." % npc_name
	}

func _get_decline_message() -> String:
	if relationship_value <= -50:
		return "They glare at you and refuse to speak to you."
	if daily_interaction_slots <= 0:
		return "They politely decline: 'I must get going. Let us talk again tomorrow.'"
	if is_irritated():
		return "They look irritated: 'Please leave me alone for a bit.'"
	return "They seem busy right now."

func get_save_data() -> Dictionary:
	return {
		"relationship_value": relationship_value,
		"has_granted_influence_bonus": has_granted_influence_bonus,
		"daily_interaction_slots": daily_interaction_slots,
		"discovered_likes": discovered_likes,
		"irritated_timer": irritated_timer,
		"retaliation_flag": retaliation_flag
	}

func load_save_data(data: Dictionary) -> void:
	relationship_value = data.get("relationship_value", 0.0)
	has_granted_influence_bonus = data.get("has_granted_influence_bonus", false)
	daily_interaction_slots = data.get("daily_interaction_slots", 3)
	discovered_likes = data.get("discovered_likes", [])
	irritated_timer = data.get("irritated_timer", 0.0)
	retaliation_flag = data.get("retaliation_flag", false)

func get_custom_message(action: String, status: String) -> String:
	var npc_id = ""
	if get_parent() and "quest_npc_id" in get_parent():
		npc_id = get_parent().quest_npc_id
		
	# Fallback/default messages
	var default_msgs = {
		"greeting": "Greetings! It is good to see you today. What is on your mind?",
		"chat_success": "We had a wonderful conversation! We both feel closer.",
		"chat_fail": "The conversation was a bit dry and awkward.",
		"chat_crit_fail": "Oh no! A misunderstanding caused offense. I feel irritated.",
		"flirt_success": "A spark flares between you! They smile and lean in closer.",
		"flirt_fail": "They politely brush off your advances.",
		"flirt_crit_fail": "That was terribly awkward! They felt highly uncomfortable and irritated.",
		"gift_dislike": "I don't really care for this gift..."
	}
	
	var custom_db = {
		"elena": {
			"greeting": "Oh, hello! Do you like my new design? The stitching on this sleeve took me hours...",
			"chat_success": "I've been thinking of blending wool and flax for the winter line. What do you think?",
			"chat_fail": "Sorry, I must finish this pattern. Maybe we can chat later when I'm not so busy.",
			"chat_crit_fail": "A needle prick! Oh, you distracted me. Please, I need to focus on my tailoring.",
			"flirt_success": "Oh! That's... very sweet of you to say. It makes my cheeks match this red dye.",
			"flirt_fail": "Ah, please, let's keep things professional. I have order sheets to fill.",
			"flirt_crit_fail": "That was highly inappropriate! I am a respectable tailor, not a tavern flirt.",
			"gift_dislike": "Oh... this is rather dirty and unpleasant. I have no use for such things."
		},
		"aldous": {
			"greeting": "Ah, a visitor! I was just translating an ancient text on early commerce in Valley Province...",
			"chat_success": "Did you know that the trade routes here are built over century-old pathways? History is fascinating!",
			"chat_fail": "I'm at a critical point in this manuscript translation. Pray, give me some quiet.",
			"chat_crit_fail": "You spilled my ink! No, no, years of research... please, just leave me be for today.",
			"flirt_success": "A spark between us? Well, the poetry of the ancient sages does mention unexpected affinity...",
			"flirt_fail": "I'm afraid my heart is currently pledged to the archives. Let us focus on the texts.",
			"flirt_crit_fail": "How preposterous! I am a scholar of history, not some cheap romance subject.",
			"gift_dislike": "A most unrefined offering. I have absolutely no interest in this."
		},
		"valeria": {
			"greeting": "Good day. What brings you to the estate? Please, try not to track dirt on the rugs.",
			"chat_success": "The council has been debate-locked over the timber tariffs. It is refreshing to hear a sensible opinion.",
			"chat_fail": "I have correspondence to attend to. I cannot waste my time on idle chatter.",
			"chat_crit_fail": "What insolence! How dare you speak to a member of the council in such a manner.",
			"flirt_success": "Hmph, you have a bold tongue. I must admit, it is rather... intriguing.",
			"flirt_fail": "Know your place. I do not tolerate such familiarities from just anyone.",
			"flirt_crit_fail": "Guards! ...Ah, they aren't here. Regardless, leave my sight immediately.",
			"gift_dislike": "Are you insulting me with this common trash? Keep it away from my estate."
		},
		"gideon": {
			"greeting": "Hey! Mind the wood shavings. I'm building a sturdier roof beam today.",
			"chat_success": "A good timber joint needs precision and patience. You seem like someone who understands hard work.",
			"chat_fail": "My hammer slipped! Ouch... look, I need to focus on this woodwork right now.",
			"chat_crit_fail": "Hey, watch out! You almost knocked over my toolbox. Go bother someone else.",
			"flirt_success": "Haha, you're pretty charming, aren't you? Let's go get a drink at the tavern sometime!",
			"flirt_fail": "Haha, very funny. But I'm too busy with these raw materials to play games.",
			"flirt_crit_fail": "Woah, hold on. That's a bit too forward. Let's stick to carpentry.",
			"gift_dislike": "What am I supposed to do with this? I can't build anything with papers or rubbish."
		}
	}
	
	var key = action + "_" + status
	if action == "greeting":
		key = "greeting"
		
	if custom_db.has(npc_id) and custom_db[npc_id].has(key):
		return custom_db[npc_id][key]
		
	return default_msgs.get(key, "...")

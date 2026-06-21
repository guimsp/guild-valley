extends Node

signal conclave_day_started(province: String, conclave_day: int)
signal conclave_resolved(province: String, results: Dictionary)

# Province -> Office Name -> { "holder": String, "career": String }
# Factions: "Player", "Fugger Family", "Medici Family", "Welser Family", "Guild Elder"
var office_holders: Dictionary = {
	"Valley Province": {
		"Grand Chairman": { "holder": "Guild Elder", "career": "craftsman" },
		"Logistics Overseer": { "holder": "Guild Elder", "career": "craftsman" },
		"Materials Steward": { "holder": "Guild Elder", "career": "craftsman" }
	},
	"Oakhaven Province": {
		"Grand Chairman": { "holder": "Guild Elder", "career": "craftsman" },
		"Logistics Overseer": { "holder": "Guild Elder", "career": "craftsman" },
		"Materials Steward": { "holder": "Guild Elder", "career": "craftsman" }
	}
}

# Province -> Office Name -> { faction_name (String) -> bid_amount (int) }
var active_bids: Dictionary = {
	"Valley Province": {
		"Grand Chairman": {},
		"Logistics Overseer": {},
		"Materials Steward": {}
	},
	"Oakhaven Province": {
		"Grand Chairman": {},
		"Logistics Overseer": {},
		"Materials Steward": {}
	}
}

# Global persistent audit cooldown (days)
var guild_audit_cooldown: float = 0.0

# Registered candidates for current cycle: Province -> Office -> Array of Dict: { "name": String, "career": String }
var current_candidates: Dictionary = {
	"Valley Province": {
		"Grand Chairman": [],
		"Logistics Overseer": [],
		"Materials Steward": []
	},
	"Oakhaven Province": {
		"Grand Chairman": [],
		"Logistics Overseer": [],
		"Materials Steward": []
	}
}

var last_checked_day: int = 1
var last_checked_hour: int = -1

# Timed bundle variables
var bundle_refresh_time_left: float = 600.0
var purchased_bundles: Dictionary = {
	"iron_ore": false,
	"iron_ingot": false,
	"cloth": false
}

func _ready() -> void:
	if GameState:
		if not TimeManager.time_changed.is_connected(_on_time_changed):
			TimeManager.time_changed.connect(_on_time_changed)
		last_checked_day = TimeManager.time_days
		last_checked_hour = TimeManager.time_hours

func _process(delta: float) -> void:
	bundle_refresh_time_left -= delta
	if bundle_refresh_time_left <= 0.0:
		bundle_refresh_time_left = 600.0
		purchased_bundles["iron_ore"] = false
		purchased_bundles["iron_ingot"] = false
		purchased_bundles["cloth"] = false
		
		# Refresh the open Guild UI panel if active
		var guild_ui = get_tree().get_first_node_in_group("GuildPanel")
		if is_instance_valid(guild_ui):
			if guild_ui.has_method("_refresh_display"):
				guild_ui._refresh_display()

func _on_time_changed(hours: int, minutes: int, days: int) -> void:
	# Hourly / Daily ticks
	var elapsed_hours = 0
	if last_checked_hour != -1:
		if days == last_checked_day:
			elapsed_hours = hours - last_checked_hour
		else:
			elapsed_hours = (24 - last_checked_hour) + hours + (days - last_checked_day - 1) * 24
			
	last_checked_hour = hours
	
	# Decrement building audits
	if elapsed_hours > 0:
		for building in get_tree().get_nodes_in_group("production_buildings"):
			if building.get("is_under_audit") == true:
				building.audit_timer = max(0.0, building.audit_timer - elapsed_hours)
				if building.audit_timer <= 0.0:
					building.is_under_audit = false
					# Restore stall audit status
					for stall in get_tree().get_nodes_in_group("MarketStall"):
						if is_instance_valid(stall) and (stall == building or stall.get("parent_building") == building):
							stall.is_under_audit = false
					if GameState:
						GameState.spawn_ui_floating_text("%s Audit ended!" % building.name)
						
	# Check day advance for cooldowns and loop state
	if days != last_checked_day:
		var days_diff = days - last_checked_day
		last_checked_day = days
		guild_audit_cooldown = max(0.0, guild_audit_cooldown - days_diff)
		
	# Conclave Loop State Machine checks
	var conclave_day = ((days - 1) % 4) + 1
	
	# Day 1, 06:00 AM: Candidates scanned, bids open
	if conclave_day == 1 and hours == 6 and minutes == 0:
		for prov in ["Valley Province", "Oakhaven Province"]:
			_start_conclave_bidding(prov)
			
	# Day 2, 00:00 Midnight (start of Day 2 / end of Day 1): Bids close, resolved
	if conclave_day == 2 and hours == 0 and minutes == 0:
		for prov in ["Valley Province", "Oakhaven Province"]:
			_resolve_conclave_election(prov)

func get_office_holder(province: String, office_name: String) -> String:
	if office_holders.has(province) and office_holders[province].has(office_name):
		return office_holders[province][office_name]["holder"]
	return "Guild Elder"

func get_office_career(province: String, office_name: String) -> String:
	if office_holders.has(province) and office_holders[province].has(office_name):
		return office_holders[province][office_name]["career"]
	return "craftsman"

func place_player_bid(province: String, office_name: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if GameState.influence < amount:
		GameState.spawn_ui_floating_text("Not enough Influence!")
		return false
		
	var conclave_day = ((TimeManager.time_days - 1) % 4) + 1
	if conclave_day != 1:
		GameState.spawn_ui_floating_text("Bidding is only open on Day 1!")
		return false
		
	GameState.influence -= amount
	var current = active_bids[province][office_name].get("Player", 0)
	active_bids[province][office_name]["Player"] = current + amount
	GameState.spawn_ui_floating_text("Placed bid of %d Influence on %s!" % [amount, office_name])
	return true

func _start_conclave_bidding(province: String) -> void:
	# Clear previous bids
	for office in active_bids[province]:
		active_bids[province][office].clear()
		current_candidates[province][office].clear()
		
	# Check Player eligibility for each office
	var max_player_career_level = 0
	var player_best_career = "craftsman"
	for career in GameState.career_levels:
		var lvl = GameState.career_levels[career]
		if lvl > max_player_career_level:
			max_player_career_level = lvl
			player_best_career = career
			
	# Grand Chairman (Requires Master - Lvl 10)
	if max_player_career_level >= 10:
		current_candidates[province]["Grand Chairman"].append({ "name": "Player", "career": player_best_career })
	# Logistics Overseer (Requires Expert - Lvl 7)
	if max_player_career_level >= 7:
		current_candidates[province]["Logistics Overseer"].append({ "name": "Player", "career": player_best_career })
	# Materials Steward (Requires Journeyman - Lvl 4)
	if max_player_career_level >= 4:
		current_candidates[province]["Materials Steward"].append({ "name": "Player", "career": player_best_career })
		
	# Register AI Candidates
	var ai_factions = ["Fugger Family", "Medici Family", "Welser Family"]
	for office in ["Grand Chairman", "Logistics Overseer", "Materials Steward"]:
		for ai in ai_factions:
			var rand_career = ["craftsman", "tailor", "scholar", "patreon"].pick_random()
			current_candidates[province][office].append({ "name": ai, "career": rand_career })
			
	conclave_day_started.emit(province, 1)
	print("[GuildController] Conclave bidding opened for %s on Day 1" % province)
	if GameState:
		GameState.spawn_ui_floating_text("Guild Elections: Blind Bidding is now open!")

func _resolve_conclave_election(province: String) -> void:
	var results = {}
	
	# Simulate AI Bids
	for office in active_bids[province]:
		var candidates = current_candidates[province][office]
		for cand in candidates:
			if cand.name != "Player":
				var roll = randf()
				var bid = 0
				if roll < 0.70:
					bid = randi_range(20, 80)
				active_bids[province][office][cand.name] = bid
				
	# Calculate Vote Weights and Resolution
	for office in active_bids[province]:
		var candidates = current_candidates[province][office]
		var highest_score = -1.0
		var winner_name = "Guild Elder"
		var winner_career = "craftsman"
		
		results[office] = []
		
		for cand in candidates:
			var name = cand.name
			var career = cand.career
			var bid = active_bids[province][office].get(name, 0)
			
			if bid > 0:
				var title_mod = 0.0
				var prestige_mod = 0.0
				
				if name == "Player":
					var tl = GameState.title_level
					if tl == 2: title_mod = 0.10
					elif tl == 3: title_mod = 0.20
					elif tl == 4: title_mod = 0.35
					elif tl >= 5: title_mod = 0.50
					
					prestige_mod = clamp(float(GameState.permanent_influence) / 1000.0 * 0.30, 0.0, 0.30)
				else:
					if name == "Fugger Family":
						title_mod = 0.35
						prestige_mod = 0.20
					elif name == "Medici Family":
						title_mod = 0.50
						prestige_mod = 0.30
					else: # Welser Family
						title_mod = 0.20
						prestige_mod = 0.15
						
				var total_votes = float(bid) * (1.0 + title_mod + prestige_mod)
				
				results[office].append({
					"candidate": name,
					"bid": bid,
					"votes": total_votes
				})
				
				if total_votes > highest_score:
					highest_score = total_votes
					winner_name = name
					winner_career = career
					
		office_holders[province][office]["holder"] = winner_name
		office_holders[province][office]["career"] = winner_career
		print("[GuildController] Office resolved: %s in %s won by %s (%s)" % [office, province, winner_name, winner_career])
		
	# Clear active bids
	for office in active_bids[province]:
		active_bids[province][office].clear()
		
	conclave_resolved.emit(province, results)
	
	if GameState:
		GameState.spawn_ui_floating_text("Guild Conclave Resolved! New office holders swapped.")
		var lines = [
			"The Seasonal Guild Conclave has completed!",
			"Valley Province Guild Offices hold new leaders:",
			"- Grand Chairman: " + office_holders["Valley Province"]["Grand Chairman"]["holder"],
			"- Logistics Overseer: " + office_holders["Valley Province"]["Logistics Overseer"]["holder"],
			"- Materials Steward: " + office_holders["Valley Province"]["Materials Steward"]["holder"]
		]
		GameState.show_npc_dialogue(null, "Guild Edict", lines)

func summon_guild_inspector(target_building: Node) -> void:
	if guild_audit_cooldown > 0.0:
		if GameState:
			GameState.spawn_ui_floating_text("Audit Inspectors are on cooldown for another %.1f days!" % guild_audit_cooldown)
		return
		
	guild_audit_cooldown = 2.0
	
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene:
		return
		
	var inspector = npc_scene.instantiate() as CharacterBody2D
	inspector.name = "GuildInspector"
	inspector.npc_name = "Guild Inspector"
	inspector.npc_type = NPCAIController.NPCType.TYPE_STATIC
	inspector.roams_interior_only = false
	
	inspector.set_meta("is_inspector", true)
	inspector.set_meta("target_building", target_building)
	
	# Spawn near building plaza
	inspector.global_position = target_building.global_position - Vector2(100, 100)
	target_building.get_parent().add_child(inspector)
	
	var sprite = inspector.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color(0.2, 0.4, 0.9)
		
	var target_pos = target_building.global_position
	if target_building.has_method("get_interaction_position"):
		target_pos = target_building.get_interaction_position()
	inspector.call("_generate_path", target_pos)

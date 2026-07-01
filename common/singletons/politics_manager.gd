extends Node

signal law_changed(province: String, law_id: String, is_active: bool)
signal phase_changed(province: String, new_phase: int)
signal tax_processed(province: String, details: Dictionary)

enum Phase {
	PHASE_IDLE = 0,
	PHASE_SPONSORSHIP = 1,
	PHASE_BALLOT_ASSEMBLY = 2,
	PHASE_VOTING = 3
}

var law_paths = [
	"res://common/politics/laws/real_estate_levy_inc.tres",
	"res://common/politics/laws/real_estate_levy_dec.tres",
	"res://common/politics/laws/infrastructure_tariff_inc.tres",
	"res://common/politics/laws/infrastructure_tariff_dec.tres",
	"res://common/politics/laws/garrison_allocation_inc.tres",
	"res://common/politics/laws/garrison_allocation_dec.tres",
	"res://common/politics/laws/labor_welfare_mandate.tres",
	"res://common/politics/laws/hospitality_excise_tax.tres",
	"res://common/politics/laws/crown_forestry_protection.tres",
	"res://common/politics/laws/noble_game_preservation.tres",
	"res://common/politics/laws/metallurgical_monopoly.tres",
	"res://common/politics/laws/courier_curfew.tres",
	"res://common/politics/laws/martial_carriage_ban.tres",
	"res://common/politics/laws/usury_prohibition.tres"
]

var laws_db: Dictionary = {}

var province_states: Dictionary = {}
var delinquent_factions: Dictionary = {}
var tax_backlog: Dictionary = {}

func initialize_politics_states(provinces: Array[String]) -> void:
	province_states.clear()
	delinquent_factions.clear()
	tax_backlog.clear()
	for prov in provinces:
		province_states[prov] = {
			"active_laws": {},
			"current_ballot": [],
			"sponsored_law": null,
			"current_phase": 0,
			"votes_history": []
		}
		delinquent_factions[prov] = {
			"Player": false,
			"Rival": false
		}
		tax_backlog[prov] = {
			"Player": 0,
			"Rival": 0
		}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_load_laws_database()
	initialize_politics_states(["Valley Province", "Oakhaven Province", "Highland Province"])

func _load_laws_database() -> void:
	for path in law_paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res and res is LawResource:
				laws_db[res.id] = res
	print("[PoliticsManager] Loaded %d laws into concept database." % laws_db.size())

func is_law_active(law_id: String, province: String) -> bool:
	if province_states.has(province):
		return province_states[province]["active_laws"].get(law_id, false)
	return false

func is_faction_delinquent(faction: String, province: String) -> bool:
	if delinquent_factions.has(province):
		return delinquent_factions[province].get(faction, false)
	return false

func set_faction_delinquent(faction: String, province: String, delinquent: bool) -> void:
	if delinquent_factions.has(province):
		delinquent_factions[province][faction] = delinquent
		# Instantly apply or clear building debuffs by redrawing or updating building properties
		for building in get_tree().get_nodes_in_group("production_buildings"):
			if is_instance_valid(building) and "ownership_type" in building:
				var b_faction = "Player" if building.ownership_type == "Player" else ("Rival" if building.ownership_type == "NPC" and building.owner_id == "Rival" else "")
				var b_province = GameState.get_province_of_node(building)
				if b_faction == faction and b_province == province:
					if building.has_method("recalculate_attractiveness"):
						building.recalculate_attractiveness()

func register_sponsored_law(province: String, law: LawResource) -> void:
	if province_states.has(province):
		province_states[province]["sponsored_law"] = law
		print("[PoliticsManager] %s sponsored law: %s" % [province, law.name])

func set_phase(province: String, new_phase: int) -> void:
	if province_states.has(province):
		var old_p = province_states[province]["current_phase"]
		if old_p != new_phase:
			province_states[province]["current_phase"] = new_phase
			phase_changed.emit(province, new_phase)
			print("[PoliticsManager] %s phase changed from %d to %d" % [province, old_p, new_phase])

func assemble_ballot(province: String) -> void:
	if not province_states.has(province):
		return
	var state = province_states[province]
	var ballot = []
	if state["sponsored_law"] != null:
		ballot.append(state["sponsored_law"])
	
	var attempts = 0
	while ballot.size() < 3 and attempts < 100:
		attempts += 1
		var keys = laws_db.keys()
		var random_key = keys[randi() % keys.size()]
		var cand = laws_db[random_key]
		
		var is_dup = false
		for b in ballot:
			if b.id == cand.id:
				is_dup = true
				break
			# Prevent mutual exclusion conflicts on ballot
			if (b.id.ends_with("_inc") and cand.id.ends_with("_dec") and b.id.replace("_inc", "") == cand.id.replace("_dec", "")):
				is_dup = true
			if (b.id.ends_with("_dec") and cand.id.ends_with("_inc") and b.id.replace("_dec", "") == cand.id.replace("_inc", "")):
				is_dup = true
				
		if not is_dup:
			ballot.append(cand)
			
	state["current_ballot"] = ballot
	print("[PoliticsManager] %s ballot assembled: %s" % [province, str(ballot.map(func(l): return l.name))])

func resolve_voting_session(province: String, player_votes: Dictionary, player_influence_spent: Dictionary) -> Dictionary:
	if not province_states.has(province):
		return {}
	
	var state = province_states[province]
	var ballot = state["current_ballot"]
	var result_details = {}
	
	var ai_factions = ["Fugger Family", "Medici Family", "Welser Family"]
	
	for law in ballot:
		var p_vote = player_votes.get(law.id, true) # Default Pass
		var p_inf = player_influence_spent.get(law.id, 0)
		var p_weight = 1 + int(p_inf / 10)
		
		var pass_weight = p_weight if p_vote else 0
		var fail_weight = p_weight if not p_vote else 0
		
		var votes_log = []
		votes_log.append({
			"voter": "Player",
			"vote": "Pass" if p_vote else "Fail",
			"weight": p_weight
		})
		
		# AI Voting Decision heuristics
		for ai in ai_factions:
			var ai_vote_pass = true
			var roll = randf()
			
			match law.id:
				"real_estate_levy_inc", "infrastructure_tariff_inc", "hospitality_excise_tax":
					ai_vote_pass = (roll < 0.25)
				"real_estate_levy_dec", "infrastructure_tariff_dec":
					ai_vote_pass = (roll < 0.80)
				"garrison_allocation_inc":
					ai_vote_pass = (roll < 0.70)
				"garrison_allocation_dec":
					ai_vote_pass = (roll < 0.35)
				"labor_welfare_mandate":
					ai_vote_pass = (roll < 0.20)
				"crown_forestry_protection", "noble_game_preservation", "metallurgical_monopoly":
					ai_vote_pass = (roll < 0.45)
				"courier_curfew", "martial_carriage_ban":
					ai_vote_pass = (roll < 0.30)
				"usury_prohibition":
					ai_vote_pass = (roll < 0.20)
				_:
					ai_vote_pass = (roll < 0.50)
					
			if ai_vote_pass:
				pass_weight += 1
			else:
				fail_weight += 1
				
			votes_log.append({
				"voter": ai,
				"vote": "Pass" if ai_vote_pass else "Fail",
				"weight": 1
			})
			
		var passed = pass_weight > fail_weight
		
		var old_state = state["active_laws"].get(law.id, false)
		state["active_laws"][law.id] = passed
		
		if passed != old_state:
			law_changed.emit(province, law.id, passed)
			
		# Handle mutual exclusivity
		if passed:
			var opposite_id = ""
			if law.id.ends_with("_inc"):
				opposite_id = law.id.replace("_inc", "_dec")
			elif law.id.ends_with("_dec"):
				opposite_id = law.id.replace("_dec", "_inc")
				
			if opposite_id != "" and state["active_laws"].get(opposite_id, false):
				state["active_laws"][opposite_id] = false
				law_changed.emit(province, opposite_id, false)
				
		result_details[law.id] = {
			"law_name": law.name,
			"passed": passed,
			"pass_weight": pass_weight,
			"fail_weight": fail_weight,
			"votes": votes_log
		}
		
	state["votes_history"].append({
		"day": TimeManager.time_days if GameState else 1,
		"results": result_details
	})
	
	# Reset sponsorship and ballot
	state["sponsored_law"] = null
	state["current_ballot"] = []
	set_phase(province, Phase.PHASE_IDLE)
	
	return result_details

func pay_player_backlog(province: String) -> bool:
	if not tax_backlog.has(province):
		return false
	var backlog = tax_backlog[province]["Player"]
	if backlog > 0 and GameState.gold >= backlog:
		GameState.gold -= backlog
		tax_backlog[province]["Player"] = 0
		set_faction_delinquent("Player", province, false)
		GameState.spawn_ui_floating_text("Paid tax backlog for %s: -%d Gold!" % [province, backlog])
		return true
	return false

func process_seasonal_taxes() -> void:
	var provinces = GameState.get_provinces()
	var rivals = get_tree().get_nodes_in_group("Rivals")
	
	for prov in provinces:
		var player_tax = 0
		var rival_tax = 0
		
		# 1. Real Estate Tax
		var houses = get_tree().get_nodes_in_group("Houses")
		for house in houses:
			if not is_instance_valid(house):
				continue
			var h_prov = GameState.get_province_of_node(house)
			if h_prov != prov:
				continue
				
			var base_tax = 15
			var level = 1
			if house.building_data:
				level = house.building_data.building_level
			var size_factor = 2.0 if (house.building_data and "rental" in house.building_data.id) else 1.0
			
			var tax = int(base_tax * level * size_factor)
			if is_law_active("real_estate_levy_inc", prov):
				tax = int(tax * 1.3)
			elif is_law_active("real_estate_levy_dec", prov):
				tax = int(tax * 0.7)
				
			if house.ownership_type == "Player":
				player_tax += tax
			elif house.ownership_type == "NPC" and house.owner_id == "Rival":
				rival_tax += tax
				
		# 2. Production Tax
		var workshops = get_tree().get_nodes_in_group("production_buildings")
		for workshop in workshops:
			if not is_instance_valid(workshop):
				continue
			var w_prov = GameState.get_province_of_node(workshop)
			if w_prov != prov:
				continue
				
			var base_tax = 25
			var level = workshop.building_level if "building_level" in workshop else 1
			var tax = base_tax * level
			
			if is_law_active("hospitality_excise_tax", prov):
				if workshop.is_in_group("Inns") or workshop.is_in_group("Taverns"):
					tax = int(tax * 1.4)
					
			# Grand Chairman guild subsidy check
			var building_career = ""
			if workshop.building_data and workshop.building_data.career != "":
				building_career = workshop.building_data.career
			else:
				var bench = workshop.get_node_or_null("CraftingBench")
				if bench and "recipes" in bench and not bench.recipes.is_empty():
					for r in bench.recipes:
						if r and r.required_career != "":
							building_career = r.required_career
							break
			
			var gc = get_node_or_null("/root/GuildController")
			if gc and building_career != "":
				var gc_holder = gc.call("get_office_holder", prov, "Grand Chairman")
				var gc_career = gc.call("get_office_career", prov, "Grand Chairman")
				if gc_holder != "" and gc_career == building_career:
					var workshop_faction = ""
					if workshop.ownership_type == "Player":
						workshop_faction = "Player"
					elif workshop.ownership_type == "NPC" and workshop.owner_id == "Rival":
						workshop_faction = "Rival"
					
					if workshop_faction == gc_holder:
						tax = int(tax * 0.85)
					elif workshop_faction != "" and gc_holder != "Guild Elder":
						tax = int(tax * 1.05)
					
			if workshop.ownership_type == "Player":
				player_tax += tax
			elif workshop.ownership_type == "NPC" and workshop.owner_id == "Rival":
				rival_tax += tax
				
		# Deduct and backlog Player
		var total_player_due = player_tax + tax_backlog[prov]["Player"]
		if total_player_due > 0:
			if GameState.gold >= total_player_due:
				GameState.gold -= total_player_due
				tax_backlog[prov]["Player"] = 0
				set_faction_delinquent("Player", prov, false)
				GameState.spawn_ui_floating_text("Paid seasonal tax in %s: -%d Gold!" % [prov, total_player_due])
			else:
				var paid = GameState.gold
				GameState.gold = 0
				tax_backlog[prov]["Player"] = total_player_due - paid
				set_faction_delinquent("Player", prov, true)
				GameState.spawn_ui_floating_text("Tax Backlog in %s: %d Gold!" % [prov, tax_backlog[prov]["Player"]])
				
		# Deduct and backlog Rival
		var total_rival_due = rival_tax + tax_backlog[prov]["Rival"]
		if total_rival_due > 0 and rivals.size() > 0:
			var rival = rivals[0]
			if rival.gold >= total_rival_due:
				rival.gold -= total_rival_due
				tax_backlog[prov]["Rival"] = 0
				set_faction_delinquent("Rival", prov, false)
			else:
				var paid = rival.gold
				rival.gold = 0
				tax_backlog[prov]["Rival"] = total_rival_due - paid
				set_faction_delinquent("Rival", prov, true)

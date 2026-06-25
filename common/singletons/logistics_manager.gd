extends Node

# Dictionary of character_instance -> { "resource_id": String, "amount": float }
var gathered_buffer: Dictionary = {}

var _tick_timer: float = 3.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# Tick down player harvesting time if active
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.get("is_harvesting") == true and player.has_meta("gather_time_left"):
		var time_left = player.get_meta("gather_time_left") - delta
		if time_left <= 0.0:
			player.set("is_harvesting", false)
			player.remove_meta("gather_time_left")
			if player.has_meta("selected_gather_resource"):
				player.remove_meta("selected_gather_resource")
			
			var current_node = player.get("current_mega_node")
			if is_instance_valid(current_node):
				if current_node.active_gatherers.has(player):
					current_node.active_gatherers.erase(player)
				player.set("is_gathering", false)
				player.set("current_mega_node", null)
				collect_player_yield(player, current_node)
				
				# Update monitor UI if it's open
				var hud = get_tree().get_first_node_in_group("PlayerHUD")
				if hud:
					var monitor = hud.get("mega_node_monitor_window")
					if is_instance_valid(monitor) and monitor.visible and monitor.has_method("update_ui"):
						monitor.update_ui()
		else:
			player.set_meta("gather_time_left", time_left)

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 3.0
		_process_gathering_ticks()

func start_gathering(character: Node2D, node: Area2D) -> void:
	var res_id = node.resource_type_id
	if character.is_in_group("Player") and character.has_meta("selected_gather_resource"):
		res_id = character.get_meta("selected_gather_resource")
		
	gathered_buffer[character] = {
		"resource_id": res_id,
		"amount": 0.0
	}

func stop_gathering(character: Node2D) -> void:
	# Keep the buffer in memory so players can recall and collect even if they walk away,
	# but ensure it can be collected.
	pass

func get_buffer_amount(character: Node2D) -> int:
	if gathered_buffer.has(character):
		return int(floor(gathered_buffer[character]["amount"]))
	return 0

func _process_gathering_ticks() -> void:
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	for node in nodes:
		if not is_instance_valid(node):
			continue
			
		var congestion = node.get_congestion_factor()
		for character in node.active_gatherers:
			if not is_instance_valid(character):
				continue
				
			var prod = character.get("productivity") if "productivity" in character else 1.0
			var base_yield = node.base_yield
			
			var gathering_mult = 1.0
			var eq = character.get_node_or_null("EquipmentComponent")
			if eq:
				gathering_mult += eq.get_total_gathering_bonus()
				
			var tick_yield = base_yield * prod * congestion * gathering_mult
			
			var econ = get_node_or_null("/root/EconomyManager")
			var node_level = 1
			if econ:
				var item_res = econ.item_database.get(node.resource_type_id)
				if item_res:
					node_level = item_res.item_level
					var gather_time = econ.get_algorithmic_gathering_time(item_res.item_level)
					tick_yield = (3.0 / gather_time) * base_yield * prod * congestion * gathering_mult
			
			# Apply Scythe-Wielder gathering speed modifier
			var scythe_bonus = 0.0
			if "character_resource" in character and character.character_resource != null:
				for trait_id in character.character_resource.active_mods:
					if trait_id.begins_with("Scythe-Wielder_Lvl"):
						var lvl = int(trait_id.replace("Scythe-Wielder_Lvl", ""))
						if lvl == 1: scythe_bonus += 0.05
						elif lvl == 2: scythe_bonus += 0.10
						elif lvl == 3: scythe_bonus += 0.15
			tick_yield *= (1.0 + scythe_bonus)
			
			if gathered_buffer.has(character):
				gathered_buffer[character]["amount"] += tick_yield
				
			# Apply Scavenger's Eye extra resource drop
			if node_level > 1 and "character_resource" in character and character.character_resource != null:
				var scavenger_lvl = 0
				for trait_id in character.character_resource.active_mods:
					if trait_id.begins_with("Scavenger's Eye_Lvl"):
						scavenger_lvl = int(trait_id.replace("Scavenger's Eye_Lvl", ""))
						break
				if scavenger_lvl > 0:
					var chance = 0.0
					if scavenger_lvl == 1: chance = 0.03
					elif scavenger_lvl == 2: chance = 0.06
					elif scavenger_lvl == 3: chance = 0.10
					
					if randf() <= chance:
						var extra_item = _get_baseline_level_1_item()
						if extra_item:
							var success = false
							if character.is_in_group("Player"):
								var remainder = GameState.player_inventory.add_item(extra_item, 1)
								if remainder == 0:
									success = true
									GameState.spawn_ui_floating_text("Scavenged 1 %s!" % extra_item.name)
							elif character.is_in_group("Rivals"):
								if "inventory" in character and character.inventory:
									character.inventory.add_item(extra_item, 1)
									success = true
							else:
								var home = character.get("hired_by_building")
								if is_instance_valid(home) and "building_storage" in home and home.building_storage:
									home.building_storage.add_item(extra_item, 1)
									success = true
									
							if success:
								if character.has_method("spawn_debug_emote"):
									character.call("spawn_debug_emote", "Scavenger!", Color.GREEN)
								elif character.has_method("spawn_floating_text"):
									character.call("spawn_floating_text", "Scavenger!")
								elif character.has_method("_spawn_floating_text"):
									character.call("_spawn_floating_text", "Scavenger!")
				
			# Durability tick down
			if eq:
				var broke = eq.damage_tool(1)
				if broke:
					if character.is_in_group("Player"):
						GameState.spawn_ui_floating_text("Your Tool Broke!")
						var hud = get_tree().get_first_node_in_group("PlayerHUD")
						if hud and hud.has_method("update_inventory_panel"):
							hud.update_inventory_panel()
					else:
						if character.has_method("on_tool_broken"):
							character.on_tool_broken()

func collect_worker_yield(worker: Node2D) -> void:
	if not is_instance_valid(worker):
		return
		
	if gathered_buffer.has(worker):
		var data = gathered_buffer[worker]
		var res_id = data["resource_id"]
		var amount = int(floor(data["amount"]))
		
		if amount > 0:
			var econ_mgr = get_node_or_null("/root/EconomyManager")
			var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
			if item_res:
				var home = worker.get("home_workshop")
				var target_storage = null
				if is_instance_valid(home) and "building_storage" in home:
					target_storage = home.building_storage
				else:
					target_storage = GameState.player_inventory
					
				if target_storage:
					target_storage.add_item(item_res, amount)
					# Floating feedback
					var hud = get_tree().get_first_node_in_group("PlayerHUD")
					if hud and hud.has_method("_spawn_floating_text"):
						hud._spawn_floating_text("Deposited %d %s!" % [amount, item_res.name], worker.global_position)

func collect_rival_worker_yield(worker: Node2D) -> void:
	if not is_instance_valid(worker):
		return
		
	if gathered_buffer.has(worker):
		var data = gathered_buffer[worker]
		var res_id = data["resource_id"]
		var amount = int(floor(data["amount"]))
		
		if amount > 0:
			var econ_mgr = get_node_or_null("/root/EconomyManager")
			var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
			if item_res:
				# Try depositing in the home workshop storage if possible
				var home = worker.get("home_workshop")
				var deposited = false
				if is_instance_valid(home) and "building_storage" in home and home.building_storage:
					home.building_storage.add_item(item_res, amount)
					if worker.has_method("_spawn_floating_text"):
						worker.call("_spawn_floating_text", "Deposited %d %s!" % [amount, item_res.name])
					deposited = true
					
				if not deposited:
					var rivals = get_tree().get_nodes_in_group("Rivals")
					if rivals.size() > 0:
						var rival = rivals[0]
						if "inventory" in rival:
							rival.inventory.add_item(item_res, amount)
							rival._spawn_floating_text("Deposited %d %s!" % [amount, item_res.name])

func collect_player_yield(player: Node2D, node: Area2D) -> void:
	if gathered_buffer.has(player):
		var data = gathered_buffer[player]
		var res_id = data["resource_id"]
		var amount = int(floor(data["amount"]))
		
		if amount > 0:
			var econ_mgr = get_node_or_null("/root/EconomyManager")
			var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
			if item_res:
				var remainder = GameState.player_inventory.add_item(item_res, amount)
				var actual_collected = amount - remainder
				if actual_collected > 0:
					GameState.spawn_ui_floating_text("Collected %d %s!" % [actual_collected, item_res.name])
				if remainder > 0:
					GameState.spawn_ui_floating_text("Inventory Full! Left %d in buffer" % remainder)
					# Keep remainder in buffer
					gathered_buffer[player]["amount"] = float(remainder)
					return
					
		# Clear buffer
		gathered_buffer[player]["amount"] = 0.0

func erase_buffer(character: Node2D) -> void:
	if gathered_buffer.has(character):
		gathered_buffer.erase(character)

func _get_baseline_level_1_item() -> ItemData:
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if not econ_mgr:
		return null
	var candidates: Array[ItemData] = []
	for item_id in econ_mgr.item_database:
		var item: ItemData = econ_mgr.item_database[item_id]
		if item.item_level == 1 and item.get_item_category() == 0:
			candidates.append(item)
	if candidates.is_empty():
		return null
	return candidates.pick_random()

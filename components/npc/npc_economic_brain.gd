class_name NPCEconomicBrain
extends Node

var npc: CharacterBody2D = null

func _ready() -> void:
	npc = get_parent() as CharacterBody2D

func request_search(item_id: String) -> void:
	if not npc:
		return
	if npc._economy_manager:
		npc._economy_manager.request_shop_search(npc, item_id, on_shop_search_resolved)
	else:
		on_shop_search_resolved(null)

func on_shop_search_resolved(stall: CollisionObject2D) -> void:
	if not npc:
		return
	npc.is_searching = false
	if not is_instance_valid(stall):
		# No shop found matching criteria/in stock
		# Remove item and put on failed/cooldown penalty in profile
		if npc.profile:
			npc.profile.shopping_queue.erase(npc.target_item_id)
			if npc.profile.demand_timers.has(npc.target_item_id):
				# Increment unmet necessity accumulation count (max 2)
				npc.profile.increment_accumulation(npc.target_item_id)
				# Penalty retry timer (15 to 30 seconds)
				npc.profile.set_retry_timer(npc.target_item_id)
				
		# Visual alert
		npc.spawn_debug_emote("X No Shop", Color.RED)
		
		# Continue shopping next items or go home
		npc.current_state = npc.State.SEARCH_CHOOSE
		return
		
	# Shop found, proceed to travel to its interaction doorstep position
	npc.target_stall = stall
	var target_pos = stall.global_position
	if stall.has_method("get_interaction_position"):
		target_pos = stall.get_interaction_position()
	npc.navigation.generate_path(target_pos)
	npc.current_state = npc.State.TRAVEL
	npc.return_home_requested = false
	npc.spawn_debug_emote("$ Go to shop", Color.YELLOW)

func process_transact() -> void:
	if not npc or not is_instance_valid(npc.target_stall) or not npc.target_stall.inventory:
		# Shop disappeared / invalid
		if npc:
			npc.current_state = npc.State.SEARCH_CHOOSE
		return
		
	if not npc.profile:
		npc.current_state = npc.State.SEARCH_CHOOSE
		return
		
	# Loop over all items in the queue and transact them if in stock
	var items_in_queue = npc.profile.shopping_queue.duplicate()
	
	for item_id in items_in_queue:
		var available_stock = npc.target_stall.inventory.get_item_amount(item_id)
		var item_data: ItemData = npc._economy_manager.item_database.get(item_id) if npc._economy_manager else null
		
		if item_data and available_stock > 0:
			var wanted_amount = 1
			if npc.profile.demand_timers.has(item_id):
				wanted_amount = npc.profile.get_accumulation(item_id)
				
			var buy_limit = 999
			if npc.npc_type == npc.NPCType.TYPE_CONSUMER:
				if item_data.get_item_category() == 2: # Finished Product
					buy_limit = randi_range(1, 2)
					
			var buy_amount = min(wanted_amount, min(available_stock, buy_limit))
			
			if buy_amount > 0:
				var ignore_t = false
				if npc.active_commercial_route and npc.active_commercial_route.get("is_smuggler") == true:
					ignore_t = true
				var price = npc.target_stall.get_buy_price(item_data, ignore_t)
				var total_cost = price * buy_amount
				
				# Deduct stock
				npc.target_stall.inventory.remove_item(item_id, buy_amount)
				
				# Pay the owner
				payout_stall_owner(npc.target_stall, total_cost, item_data, buy_amount)
				
				# Successful transaction feedback
				if buy_amount > 1:
					npc.spawn_debug_emote("+%d %s ($%d)" % [buy_amount, item_data.name, total_cost], Color.GREEN)
				else:
					npc.spawn_debug_emote("+%s ($%d)" % [item_data.name, total_cost], Color.GREEN)
				
				# Remove from queue and list, and reset cooldowns
				npc.profile.shopping_queue.erase(item_id)
				npc.profile.shopping_list.erase(item_id)
				if npc.profile.demand_timers.has(item_id):
					npc.profile.reset_accumulation(item_id)
					npc.profile.reset_demand_cooldown(item_id)
		else:
			# Not in stock. Check if it was the target item
			if item_id == npc.target_item_id:
				npc.spawn_debug_emote("X Sold Out", Color.RED)
				npc.profile.shopping_queue.erase(item_id)
				npc.profile.shopping_list.erase(item_id)
				if npc.profile.demand_timers.has(item_id):
					npc.profile.increment_accumulation(item_id)
					npc.profile.set_retry_timer(item_id)

	# Combo shopping check - transition back to select next target or return home
	npc.current_state = npc.State.SEARCH_CHOOSE

func payout_stall_owner(stall: CollisionObject2D, amount: int, item_data: ItemData, qty: int) -> void:
	if not npc:
		return
	var item_name = item_data.name if item_data else ""
	if stall.ownership_type == "Player" or (stall.ownership_type == "Rented" and stall.owner_id == "Player"):
		var target_node = stall
		if "parent_building" in stall and is_instance_valid(stall.parent_building):
			target_node = stall.parent_building
			
		var strongbox = target_node.get_node_or_null("StrongboxComponent")
		if strongbox:
			var timestamp = TimeManager.get_time_string() if GameState.has_method("get_time_string") else "Day %d" % TimeManager.time_days
			strongbox.add_transaction(item_name, qty, amount, timestamp, npc.npc_name)
			GameState.spawn_ui_floating_text("+%d Gold (Strongbox: %s)" % [amount, target_node.name.replace("Interior_", "")])
		else:
			GameState.gold += amount
			GameState.spawn_ui_floating_text("+%d Gold (Stall Customer)" % amount)
			
		# Award trickle XP to player
		if item_data:
			var em = npc.get_node_or_null("/root/EconomyManager")
			var career_id = em.get_item_career(item_data.id) if em else "patreon"
			var cat = item_data.get_item_category()
			var is_luxury = item_data.is_luxury_product
			
			var trickle_xp = 1
			if is_luxury or cat in [2, 3, 4]: # FINISHED_PRODUCT, EQUIPABLE, CONSUMABLE
				trickle_xp = 3
				
			var total_trickle = trickle_xp * qty
			GameState.add_xp(career_id, total_trickle)
			
	elif stall.ownership_type == "NPC" and stall.owner_id == "Rival":
		var rivals = npc.get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold += amount

func get_required_tool_id_for_node(node_path: String) -> String:
	if not npc:
		return ""
	var node = npc.get_node_or_null(node_path)
	if not is_instance_valid(node):
		return ""
	var res_id = node.get("resource_type_id")
	match res_id:
		"wheat":
			return "bronze_scythe"
		"cotton":
			return "bronze_sickle"
		"iron_ore":
			return "bronze_pickaxe"
	return ""

func try_equip_tool_from_building(node_path: String) -> void:
	if not npc or not is_instance_valid(npc.hired_by_building):
		return
	var eq = npc.get_node_or_null("EquipmentComponent")
	if not eq:
		return
		
	var node = npc.get_node_or_null(node_path)
	var worker_name = npc.get("npc_name")
	var building_name = npc.hired_by_building.name
	
	print("[Tool System] %s starting tool check for node_path: %s (found_node: %s)" % [worker_name, node_path, is_instance_valid(node)])
	
	if not is_instance_valid(node):
		return
		
	var res_id = node.get("resource_type_id")
	if npc.has_meta("selected_gather_resource"):
		res_id = npc.get_meta("selected_gather_resource")
		
	var required_type = GameState.get_required_tool_type_for_resource(res_id)
	
	if required_type == "":
		return
		
	var item_level = 1
	var econ_mgr = npc.get("_economy_manager") if npc.get("_economy_manager") else Engine.get_main_loop().root.get_node_or_null("EconomyManager")
	if econ_mgr and econ_mgr.item_database.has(res_id):
		item_level = econ_mgr.item_database[res_id].item_level
		
	var current_tool = eq.get_equipped_item("tool")
	if current_tool != null and GameState.is_tool_sufficient(current_tool.id, required_type, item_level):
		print("[Tool System] %s already has sufficient tool %s equipped." % [worker_name, current_tool.id])
		return
		
	if current_tool != null:
		var target_storage = npc.hired_by_building.get("building_storage")
		if not target_storage:
			target_storage = npc.hired_by_building.get("inventory")
		if target_storage:
			var leftover = target_storage.add_item(current_tool, 1)
			print("[Tool System] %s unequipping existing tool %s and returning to %s storage (leftover: %d)." % [worker_name, current_tool.id, building_name, leftover])
		eq.unequip_item("tool")
		
	var target_storage = npc.hired_by_building.get("building_storage")
	if not target_storage:
		target_storage = npc.hired_by_building.get("inventory")
		
	if target_storage:
		var tool_to_equip = GameState.find_sufficient_tool(target_storage, required_type, item_level)
		if tool_to_equip != "":
			var found_tool_res: ItemData = null
			for slot in target_storage.slots:
				if slot["item"] and slot["item"].id == tool_to_equip:
					found_tool_res = slot["item"]
					break
			if found_tool_res:
				target_storage.remove_item(tool_to_equip, 1)
				eq.equip_item("tool", found_tool_res)
				print("[Tool System] %s successfully equipped %s from %s storage." % [worker_name, tool_to_equip, building_name])
				return
				
	print("[Tool System] %s failed to find sufficient tool for %s in %s storage!" % [worker_name, res_id, building_name])

func try_equip_item_from_building(slot_name: String, item_id: String) -> void:
	if not npc or not is_instance_valid(npc.hired_by_building):
		return
	var eq = npc.get_node_or_null("EquipmentComponent")
	if not eq:
		return
		
	var current_item = eq.get_equipped_item(slot_name)
	if current_item != null and current_item.id == item_id:
		return
		
	var target_storage = npc.hired_by_building.get("building_storage")
	if not target_storage:
		target_storage = npc.hired_by_building.get("inventory")
		
	if current_item != null:
		if target_storage:
			target_storage.add_item(current_item, 1)
		eq.unequip_item(slot_name)
		
	if target_storage:
		var found_res: ItemData = null
		for slot in target_storage.slots:
			if slot["item"] and slot["item"].id == item_id:
				found_res = slot["item"]
				break
				
		if found_res:
			target_storage.remove_item(item_id, 1)
			eq.equip_item(slot_name, found_res)

func deposit_cargo() -> void:
	if not npc:
		return
	var worker_name = npc.get("npc_name")
	var building_name = npc.hired_by_building.name if is_instance_valid(npc.hired_by_building) else "unknown building"
	print("[Tool System] %s calling deposit_cargo() at %s." % [worker_name, building_name])

	if is_instance_valid(npc.hired_by_building):
		var eq = npc.get_node_or_null("EquipmentComponent")
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null:
				var target_storage = npc.hired_by_building.get("building_storage")
				if not target_storage:
					target_storage = npc.hired_by_building.get("inventory")
				var leftover = 0
				if target_storage:
					leftover = target_storage.add_item(current_tool, 1)
				eq.unequip_item("tool")
				print("[Tool System] %s deposited tool %s to %s storage (leftover: %d)." % [worker_name, current_tool.id, building_name, leftover])

		var lm = npc.get_node_or_null("/root/LogisticsManager")
		if lm and lm.gathered_buffer.has(npc):
			var data = lm.gathered_buffer[npc]
			var res_id = data["resource_id"]
			var amount = int(floor(data["amount"]))
			if amount > 0:
				var econ_mgr = npc.get_node_or_null("/root/EconomyManager")
				var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
				if item_res:
					var strongbox = npc.hired_by_building.get_node_or_null("StrongboxComponent")
					if strongbox and strongbox.has_method("deposit_resources"):
						strongbox.deposit_resources(item_res, amount)
					else:
						var target_storage = npc.hired_by_building.get("building_storage")
						if not target_storage:
							target_storage = npc.hired_by_building.get("inventory")
						if target_storage:
							target_storage.add_item(item_res, amount)
					
					var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
					if hud and hud.has_method("_spawn_floating_text"):
						hud._spawn_floating_text("Deposited %d %s!" % [amount, item_res.name], npc.global_position)
			lm.erase_buffer(npc)

		# Clear the gathering targets on the building's hired employees list
		if "hired_employees" in npc.hired_by_building:
			for emp in npc.hired_by_building.hired_employees:
				if emp.get("npc_ref") == npc:
					if emp.get("is_paused", false) and str(emp.get("active_gathering_node_path", "")) != "":
						emp["active_gathering_node_path"] = ""
						emp["shift_worker_ref"] = null
						emp["shift_status"] = "idle"
					break

func process_commercial_route(delta: float) -> void:
	if not npc:
		return
		
	if npc.commercial_route_sale_cooldown > 0.0:
		npc.commercial_route_sale_cooldown -= delta
		
	match npc.worker_state:
		"commercial_route_loading":
			if is_instance_valid(npc.hired_by_building):
				var target_pos = npc.hired_by_building.get_interaction_position()
				if npc.global_position.distance_to(target_pos) <= 32.0:
					npc.velocity = Vector2.ZERO
					npc.navigation.update_movement_animation(Vector2.ZERO)
						
					if npc.wait_timer > 0.0:
						npc.wait_timer -= delta
						return
						
					var storage = npc.hired_by_building.get("building_storage")
					if storage:
						var econ_mgr = npc.get_node_or_null("/root/EconomyManager")
						var item_res = econ_mgr.item_database.get(npc.active_commercial_route.target_item_id) if econ_mgr else null
						if item_res:
							var avail = storage.get_item_amount(item_res.id)
							if npc.hired_by_building.has_method("get_available_item_amount"):
								avail = npc.hired_by_building.get_available_item_amount(item_res.id)
							var to_load = min(npc.active_commercial_route.target_amount, avail)
							var max_limit = item_res.max_stack if "max_stack" in item_res else 20
							to_load = min(to_load, max_limit)
							
							if to_load > 0:
								storage.remove_item(item_res.id, to_load)
								npc.commercial_route_cargo_item_id = item_res.id
								npc.commercial_route_cargo_amount = to_load
								npc.commercial_route_gold_carried = 0
								npc.commercial_route_current_waypoint_index = 0
								npc.worker_state = "commercial_route_transit"
								start_transit_to_waypoint(0)
							else:
								npc.wait_timer = 5.0
		
		"commercial_route_transit":
			if npc.active_commercial_route and npc.commercial_route_current_waypoint_index < npc.active_commercial_route.market_waypoints.size():
				var wp = npc.active_commercial_route.market_waypoints[npc.commercial_route_current_waypoint_index]
				if is_instance_valid(wp):
					var target_pos = wp.global_position
					if wp.has_method("get_interaction_position"):
						target_pos = wp.get_interaction_position()
						
					if npc.global_position.distance_to(target_pos) <= 32.0:
						npc.velocity = Vector2.ZERO
						npc.navigation.update_movement_animation(Vector2.ZERO)
							
						if npc.commercial_route_sale_cooldown > 0.0:
							return
							
						var econ_mgr = npc.get_node_or_null("/root/EconomyManager")
						var item_res = econ_mgr.item_database.get(npc.commercial_route_cargo_item_id) if econ_mgr else null
						var sold_an_item = false
						if item_res and npc.commercial_route_cargo_amount > 0:
							var price = wp.get_sell_price(item_res)
							if price >= npc.active_commercial_route.minimum_sell_price:
								if wp.inventory and wp.inventory.get_free_space_for_item(item_res) >= 1:
									var can_afford = true
									if wp.ownership_type == "NPC" and wp.owner_id == "Rival":
										var rivals = npc.get_tree().get_nodes_in_group("Rivals")
										if rivals.size() > 0 and rivals[0].gold < price:
											can_afford = false
									
									if can_afford:
										wp.inventory.add_item(item_res, 1)
										if wp.ownership_type == "NPC" and wp.owner_id == "Rival":
											var rivals = npc.get_tree().get_nodes_in_group("Rivals")
											if rivals.size() > 0:
												rivals[0].gold -= price
												
										npc.commercial_route_cargo_amount -= 1
										npc.commercial_route_gold_carried += price
										npc.spawn_debug_emote("Sold 1 ($%d)" % price, Color.GREEN)
										npc.commercial_route_sale_cooldown = 0.5
										sold_an_item = true
										return
										
						if not sold_an_item:
							if npc.commercial_route_cargo_amount <= 0:
								npc.worker_state = "commercial_route_returning"
								if is_instance_valid(npc.hired_by_building):
									npc.navigation.generate_path(npc.hired_by_building.get_interaction_position())
							else:
								npc.commercial_route_current_waypoint_index += 1
								if npc.commercial_route_current_waypoint_index >= npc.active_commercial_route.market_waypoints.size():
									npc.worker_state = "commercial_route_returning"
									if is_instance_valid(npc.hired_by_building):
										npc.navigation.generate_path(npc.hired_by_building.get_interaction_position())
								else:
									start_transit_to_waypoint(npc.commercial_route_current_waypoint_index)
				else:
					skip_to_next_waypoint()
					
		"commercial_route_returning":
			if is_instance_valid(npc.hired_by_building):
				var target_pos = npc.hired_by_building.get_interaction_position()
				if npc.global_position.distance_to(target_pos) <= 32.0:
					var storage = npc.hired_by_building.get("building_storage")
					var econ_mgr = npc.get_node_or_null("/root/EconomyManager")
					var item_res = econ_mgr.item_database.get(npc.commercial_route_cargo_item_id) if econ_mgr else null
					
					if npc.commercial_route_cargo_amount > 0 and storage and item_res:
						storage.add_item(item_res, npc.commercial_route_cargo_amount)
						
					var strongbox = npc.hired_by_building.get_node_or_null("StrongboxComponent")
					if strongbox and npc.commercial_route_gold_carried > 0 and item_res:
						var timestamp = TimeManager.get_time_string() if GameState.has_method("get_time_string") else "Day %d" % TimeManager.time_days
						strongbox.add_transaction("Trade Route (" + item_res.name + ")", npc.active_commercial_route.target_amount - npc.commercial_route_cargo_amount, npc.commercial_route_gold_carried, timestamp, npc.npc_name)
						
					npc.commercial_route_cargo_item_id = ""
					npc.commercial_route_cargo_amount = 0
					npc.commercial_route_gold_carried = 0
					
					npc.worker_state = "commercial_route_loading"
					npc.wait_timer = 2.0

func start_transit_to_waypoint(index: int) -> void:
	if not npc:
		return
	if npc.active_commercial_route and index < npc.active_commercial_route.market_waypoints.size():
		var wp = npc.active_commercial_route.market_waypoints[index]
		if is_instance_valid(wp):
			var current_prov = GameState.get_province_of_node(npc) if GameState else "Unknown Province"
			var target_prov = GameState.get_province_of_node(wp) if GameState else "Unknown Province"
			if current_prov != "Unknown Province" and target_prov != "Unknown Province" and current_prov != target_prov:
				var is_smuggler = false
				if npc.active_commercial_route and npc.active_commercial_route.get("is_smuggler") == true:
					is_smuggler = true
					
				if not is_smuggler:
					var has_passport = false
					if GameState and GameState.player_inventory:
						has_passport = GameState.player_inventory.has_item("trade_passport", 1)
					if not has_passport:
						if GameState:
							GameState.gold = max(0, GameState.gold - 15)
							GameState.spawn_ui_floating_text("Border Toll Paid: 15 G")
			var target_pos = wp.global_position
			if wp.has_method("get_interaction_position"):
				target_pos = wp.get_interaction_position()
			npc.navigation.generate_path(target_pos)
		else:
			npc.call_deferred("_skip_to_next_waypoint")

func skip_to_next_waypoint() -> void:
	if not npc:
		return
	npc.commercial_route_current_waypoint_index += 1
	if npc.commercial_route_current_waypoint_index >= npc.active_commercial_route.market_waypoints.size():
		npc.worker_state = "commercial_route_returning"
		if is_instance_valid(npc.hired_by_building):
			npc.navigation.generate_path(npc.hired_by_building.get_interaction_position())
	else:
		start_transit_to_waypoint(npc.commercial_route_current_waypoint_index)

func process_internal_trade_route(delta: float) -> void:
	if not npc or not npc.active_commercial_route or npc.current_stop_index >= npc.active_commercial_route.route_stops.size():
		return
		
	if npc.wait_timer > 0.0:
		npc.wait_timer -= delta
		return
		
	var stop = npc.active_commercial_route.route_stops[npc.current_stop_index]
	if not is_instance_valid(stop) or not is_instance_valid(stop.target_building):
		advance_to_next_stop()
		return
		
	var target_pos = stop.target_building.get_interaction_position() if stop.target_building.has_method("get_interaction_position") else stop.target_building.global_position
	
	if npc.global_position.distance_to(target_pos) <= 32.0:
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
			
		var is_market = stop.target_building.is_in_group("MarketStall")
		var storage = stop.target_building.get("building_storage") if stop.target_building.get("building_storage") != null else stop.target_building.get("inventory")
		var econ_mgr = npc.get_node_or_null("/root/EconomyManager")
		var item_res = econ_mgr.item_database.get(stop.item_id) if econ_mgr else null
		
		# Deposit gold at workshops
		if not is_market:
			var strongbox = stop.target_building.get_node_or_null("StrongboxComponent")
			if strongbox and npc.commercial_route_gold_carried > 0:
				var timestamp = TimeManager.get_time_string() if GameState.has_method("get_time_string") else "Day %d" % TimeManager.time_days
				strongbox.add_transaction("Market Sales", npc.commercial_route_gold_carried, timestamp, npc.npc_name)
				npc.commercial_route_gold_carried = 0
		
		if storage and item_res:
			if is_market:
				if npc.last_processed_stop_index != npc.current_stop_index:
					npc.last_processed_stop_index = npc.current_stop_index
					npc.current_stop_transacted_count = 0
					
					if stop.target_building.get("ownership_type") == "Public":
						var market_prov = stop.target_building.province_name if "province_name" in stop.target_building else ""
						if market_prov != "" and not ProvinceMasterData.has_province_license(market_prov):
							var fee = 10
							var strongbox = npc.hired_by_building.get_node_or_null("StrongboxComponent") if is_instance_valid(npc.hired_by_building) else null
							if strongbox and strongbox.gold >= fee:
								strongbox.gold -= fee
							else:
								GameState.gold = max(0, GameState.gold - fee)
							npc.spawn_debug_emote("Market Toll Fee (-%d G)" % fee, Color.GOLDENROD)
					
				if npc.current_stop_transacted_count >= stop.target_quantity:
					advance_to_next_stop()
					return
					
				if stop.action_type == "LOAD":
					# Buying from market
					var free_space = npc.cargo_inventory.get_free_space_for_item(item_res)
					var avail = storage.get_item_amount(stop.item_id)
					if is_instance_valid(stop.target_building) and stop.target_building.has_method("get_available_item_amount"):
						avail = stop.target_building.get_available_item_amount(stop.item_id)
						
					if avail <= 0:
						if npc.current_stop_transacted_count == 0:
							var b_name = stop.target_building.custom_name if (stop.target_building.get("custom_name") != "" and "custom_name" in stop.target_building) else stop.target_building.name
							b_name = b_name.replace("Interior_", "")
							AlertManager.add_alert("No Item to Load", "Carrier %s tried to buy/load %s at %s but there was none in stock!" % [npc.npc_name, item_res.name, b_name], "warning", stop.target_building)
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
					if free_space <= 0:
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
					var ignore_t = false
					if npc.active_commercial_route and npc.active_commercial_route.get("is_smuggler") == true:
						ignore_t = true
					var price = stop.target_building.get_buy_price(item_res, ignore_t)
					var strongbox = npc.hired_by_building.get_node_or_null("StrongboxComponent") if is_instance_valid(npc.hired_by_building) else null
					var can_afford = false
					if strongbox and strongbox.gold >= price:
						can_afford = true
					elif not strongbox and GameState.gold >= price:
						can_afford = true
						
					if can_afford:
						if strongbox:
							strongbox.gold -= price
						else:
							GameState.gold -= price
							
						storage.remove_item(stop.item_id, 1)
						npc.cargo_inventory.add_item(item_res, 1)
						
						if stop.target_building.ownership_type == "NPC" and stop.target_building.owner_id == "Rival":
							var rivals = npc.get_tree().get_nodes_in_group("Rivals")
							if rivals.size() > 0:
								rivals[0].gold += price
								
						npc.spawn_debug_emote("Bought 1 (-$%d)" % price, Color.RED)
						npc.current_stop_transacted_count += 1
						npc.wait_timer = 0.5
						return
					else:
						# Cannot afford
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
				elif stop.action_type == "UNLOAD" or stop.action_type == "SELL":
					# Selling to market
					var held = npc.cargo_inventory.get_item_amount(stop.item_id)
					var free_space = storage.get_free_space_for_item(item_res)
					
					if held <= 0:
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
					if free_space <= 0:
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
					var price = stop.target_building.get_sell_price(item_res)
					var min_price = stop.minimum_sell_price if "minimum_sell_price" in stop else 0
					
					if price < min_price:
						# Price below minimum: enforce minor delay, skip stop
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
					var can_afford = true
					if stop.target_building.ownership_type == "NPC" and stop.target_building.owner_id == "Rival":
						var rivals = npc.get_tree().get_nodes_in_group("Rivals")
						if rivals.size() > 0 and rivals[0].gold < price:
							can_afford = false
							
					if can_afford:
						npc.cargo_inventory.remove_item(stop.item_id, 1)
						storage.add_item(item_res, 1)
						
						if stop.target_building.ownership_type == "NPC" and stop.target_building.owner_id == "Rival":
							var rivals = npc.get_tree().get_nodes_in_group("Rivals")
							if rivals.size() > 0:
								rivals[0].gold -= price
								
						npc.commercial_route_gold_carried += price
						npc.spawn_debug_emote("Sold 1 ($%d)" % price, Color.GREEN)
						
						if not "route_sales_in_current_run" in npc:
							npc.set("route_sales_in_current_run", 0)
						npc.route_sales_in_current_run += 1
						
						npc.current_stop_transacted_count += 1
						npc.wait_timer = 0.5
						return
					else:
						# Rival cannot afford
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
			else:
				# Non-market: traditional sequential fast trade
				if stop.action_type == "LOAD":
					var avail = storage.get_item_amount(stop.item_id)
					if is_instance_valid(stop.target_building) and stop.target_building.has_method("get_available_item_amount"):
						avail = stop.target_building.get_available_item_amount(stop.item_id)
						
					if avail <= 0:
						var b_name = stop.target_building.custom_name if (stop.target_building.get("custom_name") != "" and "custom_name" in stop.target_building) else stop.target_building.name
						b_name = b_name.replace("Interior_", "")
						AlertManager.add_alert("No Item to Load", "Carrier %s tried to load %s at %s but there was none in stock!" % [npc.npc_name, item_res.name, b_name], "warning", stop.target_building)
						advance_to_next_stop()
						npc.wait_timer = 1.0
						return
						
					var to_load = min(stop.target_quantity, avail)
					if to_load > 0:
						var free_space = npc.cargo_inventory.get_free_space_for_item(item_res)
						var fit = min(to_load, free_space)
						if fit > 0:
							storage.remove_item(stop.item_id, fit)
							var remaining = npc.cargo_inventory.add_item(item_res, fit)
							npc.spawn_debug_emote("Loaded %d %s" % [fit, item_res.name], Color.CYAN)
							
							if remaining > 0:
								storage.add_item(item_res, remaining)
								GameState.spawn_ui_floating_text("Route Alert: Carrier %s inventory full!" % npc.npc_name)
								npc.wait_timer = 1.0
						else:
							GameState.spawn_ui_floating_text("Route Alert: Carrier %s inventory full!" % npc.npc_name)
							npc.wait_timer = 1.0
							
				elif stop.action_type == "UNLOAD" or stop.action_type == "SELL":
					var held = npc.cargo_inventory.get_item_amount(stop.item_id)
					var to_unload = min(stop.target_quantity, held)
					if to_unload > 0:
						var free_space = storage.get_free_space_for_item(item_res)
						if free_space <= 0:
							var b_name = stop.target_building.custom_name if (stop.target_building.get("custom_name") != "" and "custom_name" in stop.target_building) else stop.target_building.name
							b_name = b_name.replace("Interior_", "")
							AlertManager.add_alert("Storage Full", "Carrier %s tried to unload %s at %s but storage was full!" % [npc.npc_name, item_res.name, b_name], "warning", stop.target_building)
							advance_to_next_stop()
							npc.wait_timer = 1.0
							return
							
						var fit = min(to_unload, free_space)
						if fit > 0:
							npc.cargo_inventory.remove_item(stop.item_id, fit)
							storage.add_item(item_res, fit)
							npc.spawn_debug_emote("Unloaded %d %s" % [fit, item_res.name], Color.ORANGE)
							
		advance_to_next_stop()
	else:
		if npc.nav_motor and npc.nav_motor.nav_agent.is_navigation_finished():
			start_transit_to_stop(npc.current_stop_index)

func start_transit_to_stop(index: int) -> void:
	if not npc:
		return
	if npc.active_commercial_route and index < npc.active_commercial_route.route_stops.size():
		var stop = npc.active_commercial_route.route_stops[index]
		if stop and is_instance_valid(stop.target_building):
			var current_prov = GameState.get_province_of_node(npc) if GameState else "Unknown Province"
			var target_prov = GameState.get_province_of_node(stop.target_building) if GameState else "Unknown Province"
			if current_prov != "Unknown Province" and target_prov != "Unknown Province" and current_prov != target_prov:
				var is_smuggler = false
				if npc.active_commercial_route and npc.active_commercial_route.get("is_smuggler") == true:
					is_smuggler = true
					
				if not is_smuggler:
					var has_passport = false
					if GameState and GameState.player_inventory:
						has_passport = GameState.player_inventory.has_item("trade_passport", 1)
					if not has_passport:
						if GameState:
							GameState.gold = max(0, GameState.gold - 15)
							GameState.spawn_ui_floating_text("Border Toll Paid: 15 G")
			npc.worker_state = "internal_route_transit"
			if randf() < 0.10:
				_trigger_bandit_ambush()
			var target_pos = stop.target_building.get_interaction_position() if stop.target_building.has_method("get_interaction_position") else stop.target_building.global_position
			npc.navigation.generate_path(target_pos)

func advance_to_next_stop() -> void:
	if not npc:
		return
		
	# Check for end of cycle (wrap-around)
	var next_idx = npc.current_stop_index + 1
	if npc.active_commercial_route and next_idx >= npc.active_commercial_route.route_stops.size():
		var has_sell_stop = false
		for stop in npc.active_commercial_route.route_stops:
			if is_instance_valid(stop):
				var is_market = is_instance_valid(stop.target_building) and stop.target_building.is_in_group("MarketStall")
				if stop.action_type == "SELL" or (stop.action_type == "UNLOAD" and is_market):
					has_sell_stop = true
					break
					
		if has_sell_stop:
			var sales = npc.get("route_sales_in_current_run") if "route_sales_in_current_run" in npc else 0
			var consecutive = npc.get("consecutive_no_sales_runs") if "consecutive_no_sales_runs" in npc else 0
			
			if sales == 0:
				consecutive += 1
				if consecutive >= 2:
					var msg = "Carrier %s completed two consecutive trade runs without making any sales at the public market!" % npc.npc_name
					AlertManager.add_alert("No Sales Made", msg, "warning", npc.hired_by_building)
					consecutive = 0
			else:
				consecutive = 0
				
			npc.set("consecutive_no_sales_runs", consecutive)
			npc.set("route_sales_in_current_run", 0)
			
	npc.current_stop_index += 1
	if npc.current_stop_index >= npc.active_commercial_route.route_stops.size():
		npc.current_stop_index = 0
	start_transit_to_stop(npc.current_stop_index)

func _trigger_bandit_ambush() -> void:
	if not npc:
		return
		
	var eq = npc.get_node_or_null("EquipmentComponent")
	
	if eq:
		var neck_item = eq.get_equipped_item("necklace")
		if neck_item and neck_item.id == "bandits_pass":
			AlertManager.add_alert(
				"Bandit Ambush Bypassed",
				"Carrier %s was ambushed by bandits but bypassed them safely using a Bandit's Pass!" % npc.npc_name,
				"info",
				npc.hired_by_building if is_instance_valid(npc.hired_by_building) else null
			)
			return
			
	var has_liner_bag = false
	if eq:
		var bag_item = eq.get_equipped_item("bag")
		if bag_item and bag_item.id == "concealed_liner_bag":
			has_liner_bag = true
			
	if npc.cargo_inventory:
		var items_in_cargo = []
		for slot in npc.cargo_inventory.slots:
			if slot["item"] and slot["amount"] > 0:
				items_in_cargo.append(slot)
				
		if items_in_cargo.is_empty():
			return
			
		if has_liner_bag:
			var slot = items_in_cargo.pick_random()
			npc.cargo_inventory.remove_item(slot["item"].id, 1)
			AlertManager.add_alert(
				"Bandit Ambush: Minor Loss",
				"Carrier %s was ambushed by bandits! Thanks to a Concealed Liner Bag, they lost only 1 unit of cargo." % npc.npc_name,
				"warning",
				npc.hired_by_building if is_instance_valid(npc.hired_by_building) else null
			)
		else:
			var total_lost = 0
			for slot in items_in_cargo:
				var amount = slot["amount"]
				var to_lose = int(ceil(amount * 0.5))
				npc.cargo_inventory.remove_item(slot["item"].id, to_lose)
				total_lost += to_lose
				
			AlertManager.add_alert(
				"Bandit Ambush: Heavy Loss",
				"Carrier %s was ambushed by bandits and lost %d units (50%%) of their cargo!" % [npc.npc_name, total_lost],
				"danger",
				npc.hired_by_building if is_instance_valid(npc.hired_by_building) else null
			)

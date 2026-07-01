extends Node

enum WindowType {
	SELECTOR,
	WINDOW_SHOP,
	WINDOW_QUEST_BOARD,
	WINDOW_POLITICS,
	WINDOW_GUILD_LEVEL
}

var dialogue_database: Dictionary = {}
var traits_database: Dictionary = {}

func _ready() -> void:
	_load_dialogue_database()
	_load_traits_database()

func _load_dialogue_database() -> void:
	dialogue_database.clear()
	var path = "res://common/narrative/dialogues.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.new()
		if json.parse(text) == OK:
			if json.data is Dictionary:
				dialogue_database = json.data
				print("[WindowManager] Dialogue database loaded successfully. Keys: ", dialogue_database.keys().size())
			else:
				print("[WindowManager] ERROR: dialogues.json root is not a dictionary.")
		else:
			print("[WindowManager] ERROR: Failed to parse dialogues.json: ", json.get_error_message())
	else:
		print("[WindowManager] dialogues.json not found, empty registry initialized.")

func get_dialogue(key: String, fallback_lines: Array = []) -> Array:
	if dialogue_database.has(key):
		var pages = dialogue_database[key]
		if pages is Array:
			return pages
	if fallback_lines.is_empty():
		return ["..."]
	return fallback_lines

func _load_traits_database() -> void:
	traits_database.clear()
	var path = "res://common/narrative/traits.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var json = JSON.new()
		if json.parse(text) == OK:
			if json.data is Dictionary:
				traits_database = json.data
				print("[WindowManager] Traits database loaded successfully. Keys: ", traits_database.keys().size())
			else:
				print("[WindowManager] ERROR: traits.json root is not a dictionary.")
		else:
			print("[WindowManager] ERROR: Failed to parse traits.json: ", json.get_error_message())
	else:
		print("[WindowManager] traits.json not found, empty registry initialized.")

func get_trait_data(trait_id: String) -> Dictionary:
	if traits_database.has(trait_id):
		var t_data = traits_database[trait_id]
		if t_data is Dictionary:
			return t_data
	return {}

func open_window(type: int, target_npc: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
		
	if not hud:
		print("[WindowManager] ERROR: Game HUD not found!")
		return
		
	var province = target_npc.hometown if target_npc.hometown != "" else "Valley Province"
	
	match type:
		WindowType.WINDOW_SHOP:
			if hud.has_method("open_guild_ui"):
				hud.call("open_guild_ui", province, "Wholesalers")
				var guild_panel = hud.get("guild_ui_instance")
				if is_instance_valid(guild_panel) and guild_panel.has_method("set_active_npc"):
					guild_panel.call("set_active_npc", target_npc)
					
		WindowType.WINDOW_QUEST_BOARD:
			if hud.has_method("open_quest_board_ui"):
				hud.call("open_quest_board_ui", province)
				var quest_board = hud.get("quest_board_ui_instance")
				if is_instance_valid(quest_board) and quest_board.has_method("set_active_npc"):
					quest_board.call("set_active_npc", target_npc)
					
		WindowType.WINDOW_POLITICS:
			if hud.has_method("open_lawhouse_ui"):
				hud.call("open_lawhouse_ui", province)
				var lawhouse = hud.get("lawhouse_ui_instance")
				if is_instance_valid(lawhouse) and lawhouse.has_method("set_active_npc"):
					lawhouse.call("set_active_npc", target_npc)
					
		WindowType.WINDOW_GUILD_LEVEL:
			# Get target tab depending on NPC role
			var tab = "Elections"
			if target_npc.has_meta("office_name"):
				var office = target_npc.get_meta("office_name")
				if office == "Logistics Overseer" or office == "Donations Overseer":
					tab = "Donations"
				elif office == "Grand Chairman":
					tab = "Elections"
			if hud.has_method("open_guild_ui"):
				hud.call("open_guild_ui", province, tab)
				var guild_panel = hud.get("guild_ui_instance")
				if is_instance_valid(guild_panel) and guild_panel.has_method("set_active_npc"):
					guild_panel.call("set_active_npc", target_npc)

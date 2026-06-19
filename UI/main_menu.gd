extends Control

# UI Outlets
@onready var screen_title: VBoxContainer = %Screen_Title
@onready var screen_settings: VBoxContainer = %Screen_Settings
@onready var screen_creator: VBoxContainer = %Screen_Creator

# Screen 1 (Title)
@onready var start_button: Button = %StartButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton

# Screen 2 (Settings)
@onready var map_option_button: OptionButton = %MapOptionButton
@onready var ai_check_box: CheckBox = %AICheckBox
@onready var settings_back_button: Button = %SettingsBackButton
@onready var settings_next_button: Button = %SettingsNextButton

# Screen 3 (Creator)
@onready var name_input: LineEdit = %NameInput
@onready var card_patreon: PanelContainer = %Card_Patreon
@onready var card_craftsman: PanelContainer = %Card_Craftsman
@onready var card_tailor: PanelContainer = %Card_Tailor
@onready var card_scholar: PanelContainer = %Card_Scholar
@onready var creator_back_button: Button = %CreatorBackButton
@onready var creator_launch_button: Button = %CreatorLaunchButton

# Selected career path (default: patreon)
var _selected_career: String = "patreon"

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat

func _init_styleboxes() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.14, 0.14, 0.19, 0.8)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.3, 0.3, 0.38, 0.5)
	_style_normal.set_corner_radius_all(8)
	_style_normal.content_margin_left = 12
	_style_normal.content_margin_right = 12
	_style_normal.content_margin_top = 12
	_style_normal.content_margin_bottom = 12

	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.16, 0.22, 0.28, 0.9)
	_style_selected.set_border_width_all(2)
	_style_selected.border_color = Color(0.24, 0.6, 0.86, 0.95)
	_style_selected.set_corner_radius_all(8)
	_style_selected.content_margin_left = 12
	_style_selected.content_margin_right = 12
	_style_selected.content_margin_top = 12
	_style_selected.content_margin_bottom = 12

func _ready() -> void:
	_init_styleboxes()
	# Hide settings and creator screens on load
	screen_title.show()
	screen_settings.hide()
	screen_creator.hide()
	
	# Focus first button for keyboard compatibility
	start_button.grab_focus()
	
	# Check if savegame exists to enable/disable loading
	if FileAccess.file_exists("user://savegame.json"):
		load_button.disabled = false
		load_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		load_button.disabled = true
		load_button.modulate = Color(0.5, 0.5, 0.5, 0.6)
		
	# Setup Map Selection Options
	map_option_button.clear()
	map_option_button.add_item("Guild Valley (Standard)")
	map_option_button.select(0)
	
	# Setup default sandbox AI toggle state
	if GameState:
		ai_check_box.button_pressed = GameState.rival_ai_active
	else:
		ai_check_box.button_pressed = true
		
	# Wire Title screen buttons
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Wire Settings screen buttons
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	settings_next_button.pressed.connect(_on_settings_next_pressed)
	
	# Wire Creator screen buttons
	creator_back_button.pressed.connect(_on_creator_back_pressed)
	creator_launch_button.pressed.connect(_on_launch_pressed)
	
	# When pressing Enter inside the NameInput field, focus the first profession card
	name_input.text_submitted.connect(func(_new_text: String):
		card_patreon.grab_focus()
	)
	
	# Wire up Profession cards events
	_setup_career_card("patreon", card_patreon)
	_setup_career_card("craftsman", card_craftsman)
	_setup_career_card("tailor", card_tailor)
	_setup_career_card("scholar", card_scholar)
	
	# Highlight initial selection
	_update_career_highlights()

func _on_start_pressed() -> void:
	# Transition to Settings screen
	screen_title.hide()
	screen_settings.show()
	settings_next_button.grab_focus()

func _on_load_pressed() -> void:
	# Transition directly to map and load save
	if GameState:
		# Temporarily set main scene running, and load the game
		# Since load_game clears and instantiates the world, we can transition first
		TransitionScreen.transition_to_scene("res://entities/world/world.tscn", Vector2(1550, 500))
		await TransitionScreen.faded_out
		GameState.load_game()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_settings_back_pressed() -> void:
	screen_settings.hide()
	screen_title.show()
	start_button.grab_focus()

func _on_settings_next_pressed() -> void:
	# Save sandbox toggle to GameState
	if GameState:
		GameState.rival_ai_active = ai_check_box.button_pressed
		
	screen_settings.hide()
	screen_creator.show()
	name_input.grab_focus()

func _on_creator_back_pressed() -> void:
	screen_creator.hide()
	screen_settings.show()
	settings_next_button.grab_focus()

func _setup_career_card(career_id: String, card_panel: PanelContainer) -> void:
	# Handle mouse click and keyboard input selection
	card_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_selected_career = career_id
			_update_career_highlights()
			card_panel.grab_focus()
		elif event.is_action_pressed("ui_accept"):
			# Select and immediately start/launch!
			_selected_career = career_id
			_update_career_highlights()
			_on_launch_pressed()
	)
	
	# Handle keyboard focus / accept key selection
	card_panel.focus_entered.connect(func():
		# When user tab/WASD navigates to this card, auto-select it
		_selected_career = career_id
		_update_career_highlights()
	)

func _update_career_highlights() -> void:
	# Update theme stylebox overrides depending on current selection
	card_patreon.add_theme_stylebox_override("panel", _style_selected if _selected_career == "patreon" else _style_normal)
	card_craftsman.add_theme_stylebox_override("panel", _style_selected if _selected_career == "craftsman" else _style_normal)
	card_tailor.add_theme_stylebox_override("panel", _style_selected if _selected_career == "tailor" else _style_normal)
	card_scholar.add_theme_stylebox_override("panel", _style_selected if _selected_career == "scholar" else _style_normal)

func _on_launch_pressed() -> void:
	# Validate player name
	var p_name = name_input.text.strip_edges()
	if p_name == "":
		p_name = "Player"
		
	if GameState:
		# Save name and reset career levels
		GameState.player_name = p_name
		for career in GameState.career_levels.keys():
			GameState.career_levels[career] = 1 if career == _selected_career else 0
			GameState.career_xp[career] = 0
			
		# Populate starter inventory based on selection
		if GameState.player_inventory:
			GameState.player_inventory.clear()
			
			# Define starting item resource files
			var wheat_res = load("res://common/items/instances/Raw Materials/wheat.tres")
			var sunflower_res = load("res://common/items/instances/Raw Materials/sunflower.tres")
			var egg_res = load("res://common/items/instances/Raw Materials/egg.tres")
			var ore_res = load("res://common/items/instances/Raw Materials/iron_ore.tres")
			var cotton_res = load("res://common/items/instances/Raw Materials/cotton.tres")
			var paper_res = load("res://common/items/instances/Semi-Elaborate/paper.tres")
			
			match _selected_career:
				"patreon":
					if wheat_res: GameState.player_inventory.add_item(wheat_res, 10)
					if sunflower_res: GameState.player_inventory.add_item(sunflower_res, 5)
					if egg_res: GameState.player_inventory.add_item(egg_res, 5)
				"craftsman":
					if ore_res: GameState.player_inventory.add_item(ore_res, 10)
					if sunflower_res: GameState.player_inventory.add_item(sunflower_res, 5)
				"tailor":
					if cotton_res: GameState.player_inventory.add_item(cotton_res, 10)
					if sunflower_res: GameState.player_inventory.add_item(sunflower_res, 5)
				"scholar":
					if paper_res: GameState.player_inventory.add_item(paper_res, 5)
					if cotton_res: GameState.player_inventory.add_item(cotton_res, 5)
					
		# Recalculate stats with the new career level config
		GameState.recalculate_career_stats()
		
	# Transition smoothly to the world map
	TransitionScreen.transition_to_scene("res://entities/world/world.tscn", Vector2(1550, 500))

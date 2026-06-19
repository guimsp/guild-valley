extends MarginContainer

@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var recipe_list_container: VBoxContainer = %RecipeList

var career_name: String = ""
var all_recipes: Array = []

const CAREER_PROGRESSIONS = {
	"patreon": {
		1: "Unlocks: Flour Mill (T1) and Bakery (T1) buildings.",
		2: "Unlocks: Bakery Level 2 upgrade.",
		3: "Unlocks: Bakery Level 3 upgrade.",
		4: "Unlocks: Mead Tavern (T2) and Farmstead (T2) buildings.",
		5: "Unlocks: Traveler's Inn (T2) building.",
		6: "Unlocks: Grand Hotel (Inn L2) and Casino (Tavern L2) upgrades.",
		7: "Unlocks: Distillery (T3) building.",
		8: "Unlocks: Grand Distillery (Distillery L2) and Event Hall (T3) buildings.",
		9: "Stat Gain: +20% Player Movement Speed & +25 Max Stamina.",
		10: "Stat Gain: +25 Max HP & Civic Landlord passive (+50% tenant occupancy, +15% rent limit)."
	},
	"craftsman": {
		1: "Unlocks: Ore Mine (T1) and Smelter (T1) buildings.",
		2: "Unlocks: Workshop (T1) and Tinker (T1) buildings.",
		3: "Unlocks: Forge (T1) building.",
		4: "Unlocks: Mine T2 and Smelter T2 upgrades.",
		5: "Unlocks: Workshop L2 and Tinker L2 upgrades.",
		6: "Unlocks: Forge L2 upgrade.",
		7: "Unlocks: Mine T3 and Smelter T3 upgrades.",
		8: "Unlocks: Workshop L3 upgrade.",
		9: "Stat Gain: +15% Mining & Gathering Speed.",
		10: "Stat Gain: +25% Crafting Efficiency & Forge L3 upgrade."
	},
	"tailor": {
		1: "Unlocks: Loom (T1) building.",
		2: "Unlocks: Patch Station (T1) building.",
		3: "Stat Gain: +10 Max Weight capacity.",
		4: "Unlocks: Loom T2 upgrade.",
		5: "Unlocks: Patch Station T2 upgrade.",
		6: "Stat Gain: +15% Stamina Recovery rate.",
		7: "Unlocks: Loom T3 upgrade.",
		8: "Unlocks: Patch Station T3 upgrade.",
		9: "Stat Gain: +10% Movement Speed.",
		10: "Stat Gain: +50% Bag weight capacity limit."
	},
	"scholar": {
		1: "Unlocks: Paper Maker (T1) building.",
		2: "Unlocks: Printing Press (T1) building.",
		3: "Unlocks: Bank (T1) building.",
		4: "Stat Gain: +15% Influence gain rate.",
		5: "Unlocks: Printing Press L2 upgrade.",
		6: "Stat Gain: +10% Bank deposit interest.",
		7: "Unlocks: Printing Press L3 upgrade.",
		8: "Stat Gain: +20% overnight passive influence generation.",
		9: "Stat Gain: +15 Max HP & +15 Max Stamina.",
		10: "Unlocks: Grand Library & Master Scholar title."
	}
}

func init_skill(career_id: String, recipes: Array) -> void:
	career_name = career_id
	all_recipes = recipes
	name = career_id.capitalize()
	update_panel()

func update_panel() -> void:
	if not progress_label or not progress_bar:
		return
		
	var lvl = GameState.career_levels.get(career_name, 1)
	var xp = GameState.career_xp.get(career_name, 0)
	var next_xp = GameState.get_xp_for_level(lvl)
	
	progress_label.text = "%d / %d XP" % [xp, next_xp]
	progress_bar.max_value = next_xp
	progress_bar.value = xp
	
	# Clear old list children
	for child in recipe_list_container.get_children():
		child.queue_free()
		
	# Prepend gold-bordered Active Mastery Traits if level >= 5
	if lvl >= 5:
		var traits_card = PanelContainer.new()
		traits_card.custom_minimum_size = Vector2(0, 54)
		
		var style_tc = StyleBoxFlat.new()
		style_tc.bg_color = Color(0.18, 0.14, 0.05, 0.8)
		style_tc.border_color = Color(0.9, 0.75, 0.15, 1.0)
		style_tc.set_border_width_all(2)
		style_tc.set_corner_radius_all(6)
		style_tc.content_margin_left = 12
		style_tc.content_margin_right = 12
		style_tc.content_margin_top = 8
		style_tc.content_margin_bottom = 8
		traits_card.add_theme_stylebox_override("panel", style_tc)
		
		var vbox_tc = VBoxContainer.new()
		vbox_tc.add_theme_constant_override("separation", 4)
		traits_card.add_child(vbox_tc)
		
		var title_lbl = Label.new()
		title_lbl.text = "Active Mastery Traits"
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.modulate = Color(1.0, 0.9, 0.5)
		vbox_tc.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		if lvl >= 8:
			desc_lbl.text = "★ Bountiful Harvest: 35% chance to double output.\n★ Artisan's Efficiency: Luxury production time reduced by 15%."
		else:
			desc_lbl.text = "★ Bountiful Harvest: 20% chance to double output."
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.modulate = Color(0.95, 0.95, 0.9)
		vbox_tc.add_child(desc_lbl)
		
		recipe_list_container.add_child(traits_card)
		
	var progression = CAREER_PROGRESSIONS.get(career_name, {})
	for lvl_idx in range(1, 11):
		var desc_text = progression.get(lvl_idx, "Unlocks and benefits not yet developed.")
		var is_unlocked = lvl >= lvl_idx
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 48)
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		
		if not is_unlocked:
			style.bg_color = Color(0.12, 0.12, 0.16, 0.45)
			style.border_color = Color(0.24, 0.24, 0.3, 0.35)
			style.set_border_width_all(1)
		else:
			style.bg_color = Color(0.12, 0.26, 0.18, 0.75) if career_name == "patreon" else Color(0.16, 0.22, 0.32, 0.75)
			style.border_color = Color(0.24, 0.52, 0.36, 0.6) if career_name == "patreon" else Color(0.28, 0.44, 0.66, 0.6)
			style.set_border_width_all(1)
			
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)
		
		var hbox_title = HBoxContainer.new()
		vbox.add_child(hbox_title)
		
		var name_lbl = Label.new()
		name_lbl.text = "Level %d" % lvl_idx
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		if not is_unlocked:
			name_lbl.modulate = Color(0.55, 0.55, 0.55, 0.8)
		else:
			name_lbl.modulate = Color(0.9, 0.95, 0.9, 1)
		hbox_title.add_child(name_lbl)
		
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 10)
		if is_unlocked:
			status_lbl.text = "Unlocked"
			status_lbl.modulate = Color(0.4, 0.9, 0.4, 1)
		else:
			status_lbl.text = "Locked"
			status_lbl.modulate = Color(0.85, 0.35, 0.35, 0.8)
		hbox_title.add_child(status_lbl)
		
		var details_lbl = Label.new()
		details_lbl.text = desc_text
		details_lbl.add_theme_font_size_override("font_size", 10)
		if not is_unlocked:
			details_lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)
		else:
			details_lbl.modulate = Color(0.8, 0.8, 0.85, 1)
		details_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(details_lbl)
		
		recipe_list_container.add_child(card)

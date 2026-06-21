extends PanelContainer

var _main_hud: CanvasLayer = null

@onready var opponents_scroll_list: VBoxContainer = $VBox/ScrollContainer/OpponentsScrollList

func setup(p_hud: CanvasLayer) -> void:
	_main_hud = p_hud
	TimeManager.time_changed.connect(func(_h, _m, _d): refresh())

func refresh() -> void:
	if not visible:
		return
	if not opponents_scroll_list:
		return
		
	for child in opponents_scroll_list.get_children():
		child.queue_free()
		
	var rivals = get_tree().get_nodes_in_group("Rivals")
	if rivals.is_empty():
		var label = Label.new()
		label.text = "No opponent families detected in this region."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(0.6, 0.6, 0.6, 0.8)
		opponents_scroll_list.add_child(label)
		return
		
	for rival in rivals:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 50)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.22, 0.75)
		style.set_border_width_all(1)
		style.border_color = Color(0.6, 0.3, 0.3, 0.5) # Reddish border for opponents
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		card.add_child(hbox)
		
		var name_lbl = Label.new()
		var rival_family = rival.get("family_name") if rival.get("family_name") else rival.name
		var rival_profession = rival.get("profession") if rival.get("profession") else ""
		var rival_level = rival.get("level") if rival.get("level") != null else 1
		if rival_profession != "":
			name_lbl.text = "%s (%s Lvl %d)" % [rival_family, rival_profession.capitalize(), rival_level]
		else:
			name_lbl.text = rival_family
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(vbox)
		
		var gold_lbl = Label.new()
		gold_lbl.text = "Wealth: %d Gold" % rival.gold
		gold_lbl.add_theme_font_size_override("font_size", 10)
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(gold_lbl)
		
		var standing_lbl = Label.new()
		var r_standing = rival.get("standing") if rival.get("standing") else "Competitor"
		standing_lbl.text = "Standing: " + r_standing
		standing_lbl.add_theme_font_size_override("font_size", 9)
		standing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		standing_lbl.modulate = Color(0.9, 0.6, 0.6)
		vbox.add_child(standing_lbl)
		
		opponents_scroll_list.add_child(card)

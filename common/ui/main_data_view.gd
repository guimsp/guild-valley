extends Control

var _building: Node2D = null
var _coordinator: Control = null
var _updating_ui: bool = false

@onready var workshop_view: Control = $WorkshopView
@onready var warehouse_view: Control = $WarehouseView
@onready var modal_manager: Control = $PopupOverlay

var _last_focused_meta: Dictionary = {}

func setup(building: Node2D, coordinator: Control) -> void:
	_building = building
	_coordinator = coordinator
	workshop_view.setup(self)
	warehouse_view.setup(self)
	modal_manager.setup(self)
	modal_manager.close_all_popups()

func update_view() -> void:
	if not _building:
		return
		
	_updating_ui = true
	_save_current_focus()
	modal_manager.refresh(_building)
	
	if _building.get("is_warehouse"):
		workshop_view.hide()
		warehouse_view.show()
		warehouse_view.refresh(_building)
	else:
		warehouse_view.hide()
		workshop_view.show()
		workshop_view.refresh(_building)
		
	_updating_ui = false
	_restore_saved_focus()

func _process(_delta: float) -> void:
	if not visible or not _building or _updating_ui:
		return
	if workshop_view.visible:
		workshop_view.update_live_progress()

func _save_current_focus() -> void:
	_last_focused_meta.clear()
	var focused = get_viewport().gui_get_focus_owner()
	
	if _coordinator and (not focused or not is_ancestor_of(focused)):
		if is_instance_valid(_coordinator.get("_last_focused_trigger_button")):
			focused = _coordinator._last_focused_trigger_button
			
	if focused and is_instance_valid(focused):
		if focused.has_meta("type"):
			_last_focused_meta["type"] = focused.get_meta("type")
		if focused.has_meta("item_id"):
			_last_focused_meta["item_id"] = focused.get_meta("item_id")
		if focused.has_meta("index"):
			_last_focused_meta["index"] = focused.get_meta("index")

func _restore_saved_focus() -> void:
	if _last_focused_meta.is_empty():
		return
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_inside_tree() or not visible:
		return
		
	var target_btn: Control = null
	var all_focusables = _find_all_focusable_controls(self)
	var type = _last_focused_meta.get("type", "")
	var item_id = _last_focused_meta.get("item_id", "")
	var index = _last_focused_meta.get("index", -1)
	
	if type != "":
		for ctrl in all_focusables:
			if ctrl.get_meta("type", "") == type:
				if item_id != "" and ctrl.get_meta("item_id", "") == item_id:
					target_btn = ctrl
					break
				elif index != -1 and ctrl.get_meta("index", -1) == index:
					target_btn = ctrl
					break
					
		if not target_btn:
			for ctrl in all_focusables:
				if ctrl.get_meta("type", "") == type:
					target_btn = ctrl
					break
					
	if target_btn and is_instance_valid(target_btn) and target_btn.is_inside_tree() and not target_btn.get("disabled") == true:
		target_btn.grab_focus()
	else:
		if _coordinator:
			_coordinator._focus_first_button()
			
	_last_focused_meta.clear()

func _find_all_focusable_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control and node.visible and node.focus_mode == Control.FOCUS_ALL:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_focusable_controls(child))
	return result

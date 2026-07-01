class_name UIFocusHelper
extends RefCounted

## Wire focus neighbors inside a GridContainer for keyboard/controller navigation
static func wire_grid_neighbors(grid: GridContainer, columns: int) -> void:
	if not grid:
		return
		
	var children = []
	for child in grid.get_children():
		if child is Control and child.visible and child.focus_mode != Control.FOCUS_NONE:
			children.append(child)
			
	var count = children.size()
	for i in range(count):
		var child = children[i]
		# Left
		if i > 0:
			child.focus_neighbor_left = children[i - 1].get_path()
		else:
			child.focus_neighbor_left = child.get_path()
			
		# Right
		if i < count - 1:
			child.focus_neighbor_right = children[i + 1].get_path()
		else:
			child.focus_neighbor_right = child.get_path()
			
		# Top
		if i >= columns:
			child.focus_neighbor_top = children[i - columns].get_path()
		else:
			child.focus_neighbor_top = child.get_path()
			
		# Bottom
		if i + columns < count:
			child.focus_neighbor_bottom = children[i + columns].get_path()
		else:
			child.focus_neighbor_bottom = child.get_path()

## Connects all focusable descendant controls to auto-scroll when they receive focus
static func register_scroll_container(scroll_container: ScrollContainer) -> void:
	if not scroll_container:
		return
		
	# Wire dynamically added nodes as well
	if not scroll_container.has_meta("scroll_focus_connected"):
		scroll_container.set_meta("scroll_focus_connected", true)
		scroll_container.child_entered_tree.connect(func(node):
			_connect_focus_recursive(scroll_container, node)
		)
		
	for child in scroll_container.get_children():
		_connect_focus_recursive(scroll_container, child)

static func _connect_focus_recursive(scroll_container: ScrollContainer, node: Node) -> void:
	if node is Control:
		if node.focus_mode != Control.FOCUS_NONE:
			var callable = func():
				_on_control_focused(scroll_container, node)
			if not node.is_meta("focus_scroll_wired"):
				node.set_meta("focus_scroll_wired", true)
				node.focus_entered.connect(callable)
				
	for child in node.get_children():
		_connect_focus_recursive(scroll_container, child)

static func _on_control_focused(scroll_container: ScrollContainer, control: Control) -> void:
	if is_instance_valid(scroll_container) and is_instance_valid(control) and control.is_inside_tree():
		scroll_container.ensure_control_visible(control)

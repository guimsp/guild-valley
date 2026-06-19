class_name InventoryComponent
extends Node

# Signal emitted whenever items are added or removed
signal inventory_changed

@export var max_slots: int = 24
@export var max_weight: float = 50.0
@export var max_stack: int = 20

# List of item stacks: Array of Dictionaries like {"item": ItemData, "amount": int}
var slots: Array = []

# Get the max stack size for a specific item, respecting stackability and item overrides
func get_max_stack_for_item(item: ItemData) -> int:
	if "is_stackable" in item and not item.is_stackable:
		return 1
	if "max_stack" in item and item.max_stack > 0:
		return item.max_stack
	return max_stack

# Get how many more units of this item can fit based on current slots and max_stack limits
func get_free_space_for_item(item: ItemData) -> int:
	var item_max_stack = get_max_stack_for_item(item)
	var free_space = 0
	for slot in slots:
		if slot["item"].id == item.id:
			free_space += max(0, item_max_stack - slot["amount"])
			
	var empty_slots = max(0, max_slots - slots.size())
	free_space += empty_slots * item_max_stack
	return free_space

# Adds items to the inventory. Returns the remaining amount that could not fit (due to slot limits).
func add_item(item: ItemData, amount: int) -> int:
	if amount <= 0:
		return 0
		
	# Calculate how many can fit based on slots and stack limits
	var max_by_slots = get_free_space_for_item(item)
	
	# The actual fit count is the slot limit
	var fit_amount = min(amount, max_by_slots)
	if fit_amount <= 0:
		return amount # Cannot fit any items
		
	_add_item_to_slots(item, fit_amount)
	return amount - fit_amount

func _add_item_to_slots(item: ItemData, amount: int) -> void:
	var remaining = amount
	var item_max_stack = get_max_stack_for_item(item)
	
	# 1. Fill existing slots with matching item ID up to max_stack
	for slot in slots:
		if slot["item"].id == item.id:
			var space = item_max_stack - slot["amount"]
			if space > 0:
				var to_add = min(remaining, space)
				slot["amount"] += to_add
				remaining -= to_add
				if remaining <= 0:
					inventory_changed.emit()
					return
					
	# 2. Create new slots for the remaining amount
	while remaining > 0 and slots.size() < max_slots:
		var to_add = min(remaining, item_max_stack)
		slots.append({
			"item": item,
			"amount": to_add
		})
		remaining -= to_add
		
	if remaining > 0:
		push_warning("[InventoryComponent] Inventory slots are full! Remaining lost: %d" % remaining)
		
	inventory_changed.emit()

# Removes an item by its ID. Returns the amount successfully removed.
func remove_item(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
		
	var remaining_to_remove: int = amount
	var indices_to_remove: Array = []
	
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		if slot["item"].id == item_id:
			if slot["amount"] > remaining_to_remove:
				slot["amount"] -= remaining_to_remove
				remaining_to_remove = 0
				break
			else:
				remaining_to_remove -= slot["amount"]
				indices_to_remove.append(i)
				
	# Remove slots that reached 0 (backwards to keep indices valid during deletion)
	indices_to_remove.reverse()
	for index in indices_to_remove:
		slots.remove_at(index)
		
	var removed_amount: int = amount - remaining_to_remove
	if removed_amount > 0:
		inventory_changed.emit()
		
	return removed_amount

# Checks if the inventory has a specific quantity of an item
func has_item(item_id: String, amount: int) -> bool:
	return get_item_amount(item_id) >= amount

# Gets the total amount of an item in the inventory
func get_item_amount(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if slot["item"].id == item_id:
			total += slot["amount"]
	return total

# Calculate current total weight of all items (disabled/deprecated)
func get_total_weight() -> float:
	return 0.0

# Clears the inventory
func clear() -> void:
	slots.clear()
	inventory_changed.emit()

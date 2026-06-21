class_name EquipmentComponent
extends Node

signal equipment_changed

# Slots map
var slots: Dictionary = {
	"head": null,
	"body": null,
	"gloves": null,
	"weapon": null,
	"tool": null,
	"bag": null,
	"necklace": null,
	"ring": null,
	"transportation": null
}

func get_equipped_item(slot_name: String) -> ItemData:
	return slots.get(slot_name)

func equip_item(slot_name: String, item: ItemData) -> ItemData:
	if not slots.has(slot_name):
		return null
		
	var prev = slots[slot_name]
	slots[slot_name] = item
	equipment_changed.emit()
	return prev

func unequip_item(slot_name: String) -> ItemData:
	if not slots.has(slot_name):
		return null
		
	var prev = slots[slot_name]
	slots[slot_name] = null
	equipment_changed.emit()
	return prev

func get_total_armor() -> int:
	var total = 0
	for item in slots.values():
		if item and "armor_stat" in item:
			total += item.armor_stat
	return total

func get_total_attack() -> int:
	var total = 0
	for item in slots.values():
		if item and "attack_stat" in item:
			total += item.attack_stat
	return total

func get_total_speed_bonus() -> float:
	var total = 0.0
	for item in slots.values():
		if item and "speed_bonus" in item:
			total += item.speed_bonus
	return total

func get_total_capacity_bonus() -> int:
	var total = 0
	for item in slots.values():
		if item and "capacity_bonus" in item:
			total += item.capacity_bonus
	return total

func get_total_gathering_bonus() -> float:
	var total = 0.0
	for item in slots.values():
		if item and "gathering_multiplier_bonus" in item:
			total += item.gathering_multiplier_bonus
	return total

# Decrement tool durability, returns true if tool broke
func damage_tool(amount: int = 1) -> bool:
	var tool = slots.get("tool")
	if tool and tool.is_tool:
		# Enforce 1000% longer lifetime (10x) by having only a 10% chance to apply damage per tick
		if randf() >= 0.10:
			return false
		# Ensure we are modifying a duplicate/instance specific durability if shared
		tool.durability = max(0, tool.durability - amount)
		if tool.durability <= 0:
			slots["tool"] = null
			equipment_changed.emit()
			return true
	return false

func serialize() -> Dictionary:
	var data = {}
	for slot_name in slots:
		var item = slots[slot_name]
		if item:
			# Serialize standard item properties including durability
			data[slot_name] = {
				"item_path": item.resource_path,
				"durability": item.durability
			}
		else:
			data[slot_name] = {}
	return data

func deserialize(data: Dictionary) -> void:
	for slot_name in slots:
		if data.has(slot_name) and data[slot_name] is Dictionary and data[slot_name].has("item_path"):
			var slot_data = data[slot_name]
			var item_path = slot_data["item_path"]
			if item_path != "" and ResourceLoader.exists(item_path):
				var res = load(item_path)
				if res and res is ItemData:
					# Duplicate to make sure this instance's durability is independent
					var dup = res.duplicate()
					if slot_data.has("durability"):
						dup.durability = int(slot_data["durability"])
					slots[slot_name] = dup
					continue
		slots[slot_name] = null
	equipment_changed.emit()

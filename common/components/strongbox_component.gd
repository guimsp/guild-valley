class_name StrongboxComponent
extends Node

@export var strongbox_gold: int = 0
@export var max_gold_capacity: int = 1500
@export var transaction_ledger: Array = []

const MAX_LEDGER_ENTRIES: int = 30

func add_transaction(item_name: String, amount: int, price: int, timestamp: String, buyer_name: String = "Customer") -> void:
	strongbox_gold = min(strongbox_gold + price, max_gold_capacity)
	var entry = {
		"item_name": item_name,
		"amount": amount,
		"price": price,
		"timestamp": timestamp,
		"buyer_name": buyer_name
	}
	transaction_ledger.append(entry)
	while transaction_ledger.size() > MAX_LEDGER_ENTRIES:
		transaction_ledger.pop_front()

func withdraw_all() -> int:
	var gold = strongbox_gold
	strongbox_gold = 0
	return gold

func deposit_resources(item: ItemData, amount: int) -> void:
	var parent = get_parent()
	if parent and "building_storage" in parent and parent.building_storage:
		parent.building_storage.add_item(item, amount)


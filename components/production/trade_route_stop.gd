class_name TradeRouteStop
extends Resource

var target_building: Node2D
@export var action_type: String # "LOAD" or "UNLOAD"
@export var item_id: String
@export var target_quantity: int
@export var minimum_sell_price: int = 0


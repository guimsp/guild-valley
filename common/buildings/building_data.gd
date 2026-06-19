class_name BuildingData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var family: String = ""
@export var building_level: int = 1
@export var career: String = ""
@export var tier: int = 1
@export var level: int = 1
@export var cost: int = 0
@export var time: float = 3.0
@export var scene_path: String = ""
@export_enum("home", "renting", "production", "gathering", "warehouse") var type: String = "production"
@export_enum("outside", "inside", "any") var env: String = "outside"
@export_enum("city", "town", "any") var allowed_settlement: String = "any"
@export var attractiveness: int = 10
@export_multiline var description: String = ""


class_name LawResource
extends Resource

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export_enum("Numerical", "Prohibition") var category: String = "Numerical"
@export var influence_cost: int = 150
@export var value_type: String = ""
@export var effect_value: float = 0.0

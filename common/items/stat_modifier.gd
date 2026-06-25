extends Resource
class_name StatModifier

enum ModificationType { FLAT, MULTIPLIER }

@export var id: String = ""
@export var source: String = "" # For UI debugging display (e.g. "Labor Welfare Mandate")
@export var value: float = 0.0
@export var type: ModificationType = ModificationType.MULTIPLIER

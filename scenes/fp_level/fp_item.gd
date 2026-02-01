extends RigidBody3D

@export var is_evidence : bool = false :
	set(value):
		is_evidence = value
		if is_evidence:
			add_to_group("evidence")
		else :
			remove_from_group("evidence")
@export var held_by_id : int = -1

func _ready() -> void:
	set("is_evidence", is_evidence)

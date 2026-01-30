extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var items : Array[Node3D] = get_overlapping_bodies()
	if items!=[]:
		for body in items:
			if body.is_class("CharacterBody3D"):
				pass

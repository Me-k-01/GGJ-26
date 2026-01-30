extends Control

@export var timer : Timer
@export var timerTextLabel : Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	@warning_ignore("integer_division")
	var minutes = int(timer.time_left) / 60
	var seconds = int(timer.time_left) % 60
	timerTextLabel.text = str(minutes) + ":" + str(seconds)
	if(seconds < 10):
		timerTextLabel.text = str(minutes) + ":0" + str(seconds)

#fin de la partie
func _on_timer_timeout():
	pass
	

extends Area2D

@export var next_scene: String = "res://correct/path/to/randomwalker_generator2.tscn"


func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("🚪 Player has entered the door!")
		get_tree().reload_current_scene()  # This will restart the scene properly

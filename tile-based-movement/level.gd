extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"):
		reset_level()


func reset_level() -> void:
	get_tree().reload_current_scene()

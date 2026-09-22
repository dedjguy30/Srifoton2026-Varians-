class_name GridObstacle
extends StaticBody2D


@export var board: Board


var grid_position: Vector2i


func _ready() -> void:
	if board == null:
		push_error("Wall belum terhubung ke Board!")
		return

	grid_position = board.world_to_grid(global_position)

	global_position = board.grid_to_world(grid_position)

	board.register_object(
		grid_position,
		self
	)

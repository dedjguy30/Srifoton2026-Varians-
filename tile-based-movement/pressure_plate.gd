class_name PressurePlate
extends Area2D


signal activated
signal deactivated


@export var board: Board


var grid_position: Vector2i
var is_pressed: bool = false


func _ready() -> void:
	if board == null:
		push_error("PressurePlate belum terhubung ke Board!")
		return

	grid_position = board.world_to_grid(global_position)
	global_position = board.grid_to_world(grid_position)

	# Pressure Plate sekarang membaca Board,
	# bukan body_entered/body_exited.
	monitoring = false

	board.object_moved.connect(
		_on_board_object_moved
	)

	call_deferred("sync_with_board")


# ==================================================
# PRESS CAPABILITY
# ==================================================

# Pressure Plate tidak peduli object ini:
# Character?
# Box?
# Enemy?
# object masa depan?
#
# Yang penting object tersebut punya capability
# "pressure_plate_activator".
func can_press(object: Node) -> bool:
	if object == null:
		return false

	return object.is_in_group(
		"pressure_plate_activator"
	)


func _on_board_object_moved(
	object: Node2D,
	from_cell: Vector2i,
	to_cell: Vector2i
) -> void:
	if not can_press(object):
		return

	if (
		from_cell != grid_position
		and to_cell != grid_position
	):
		return

	sync_with_board()


func sync_with_board() -> void:
	var occupant := board.get_object_at(
		grid_position
	)

	var should_be_pressed := (
		occupant != null
		and can_press(occupant)
	)

	if should_be_pressed == is_pressed:
		return

	is_pressed = should_be_pressed

	if is_pressed:
		print("PRESSURE PLATE ON: ", occupant.name)
		activated.emit()
	else:
		print("PRESSURE PLATE OFF")
		deactivated.emit()

class_name Goal
extends Area2D


# Board milik level.
@export var board: Board


# Jumlah Nectar yang dibutuhkan untuk menang.
@export var required_nectar: int = 1


# Posisi Goal dalam grid.
var grid_position: Vector2i


func _ready() -> void:
	if board == null:
		push_error("Goal belum terhubung ke Board!")
		return

	grid_position = board.world_to_grid(global_position)

	global_position = board.grid_to_world(grid_position)


func _on_body_entered(body: Node2D) -> void:
	print("GOAL DETECT: ", body.name)

	# Hanya Butterfly yang relevan untuk Goal.
	if not body.is_in_group("butterfly"):
		print("GOAL IGNORE: actor bukan Butterfly")
		return

	# Butterfly nantinya harus mempunyai fungsi ini.
	if not body.has_method("get_nectar_count"):
		push_warning(
			"Butterfly tidak memiliki get_nectar_count()"
		)
		return

	var nectar_count: int = int(
		body.call("get_nectar_count")
	)

	print(
		"BUTTERFLY GOAL | Nectar: ",
		nectar_count,
		"/",
		required_nectar
	)

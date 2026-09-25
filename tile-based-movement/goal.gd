class_name Goal
extends Area2D


# Event kemenangan.
# Level akan mendengarkan signal ini.
signal puzzle_completed(
	butterfly: ButterflyCharacter
)


# Board milik level.
@export var board: Board


# Butterfly wajib membawa tepat 3 Nectar.
@export var required_nectar: int = 3


# Posisi Goal pada grid.
var grid_position: Vector2i


# Mencegah Goal mengirim kemenangan berkali-kali.
var is_completed: bool = false


func _ready() -> void:
	if board == null:
		push_error("Goal belum terhubung ke Board!")
		return

	# Goal mengikuti grid tetapi tidak menjadi blocking object.
	grid_position = board.world_to_grid(
		global_position
	)

	global_position = board.grid_to_world(
		grid_position
	)


func _on_body_entered(body: Node2D) -> void:
	# Kalau level sudah selesai, tidak perlu cek lagi.
	if is_completed:
		return

	print(
		"GOAL DETECT: ",
		body.name
	)

	# Sekarang Butterfly asli sudah ada,
	# jadi Goal bisa mengecek class secara langsung.
	if not body is ButterflyCharacter:
		print(
			"GOAL IGNORE: bukan Butterfly"
		)
		return

	var butterfly := body as ButterflyCharacter

	var nectar_count: int = (
		butterfly.get_nectar_count()
	)

	print(
		"BUTTERFLY GOAL | Nectar: ",
		nectar_count,
		"/",
		required_nectar
	)

	# Harus tepat 3/3.
	if nectar_count != required_nectar:
		print(
			"GOAL LOCKED: Nectar belum lengkap"
		)
		return

	# Kondisi kemenangan terpenuhi.
	is_completed = true

	print(
		"PUZZLE COMPLETE! Butterfly membawa ",
		nectar_count,
		"/",
		required_nectar,
		" Nectar."
	)

	puzzle_completed.emit(
		butterfly
	)

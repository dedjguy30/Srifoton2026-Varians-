class_name Nectar
extends Area2D


# Board level tempat Nectar berada.
@export var board: Board


# Posisi Nectar pada grid.
var grid_position: Vector2i


# Mencegah Nectar yang sama diambil berkali-kali.
var is_collected: bool = false


func _ready() -> void:
	add_to_group("nectars")

	if board == null:
		push_error(
			"Nectar belum terhubung ke Board!"
		)
		return

	grid_position = board.world_to_grid(
		global_position
	)

	global_position = board.grid_to_world(
		grid_position
	)


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	print(
		"NECTAR DETECT: ",
		body.name
	)

	# Hanya Butterfly yang valid.
	if not body is ButterflyCharacter:
		print(
			"NECTAR IGNORE: bukan Butterfly"
		)
		return

	var butterfly := body as ButterflyCharacter

	if not butterfly.can_collect_nectar():
		print(
			"NECTAR IGNORE: Butterfly sudah penuh"
		)
		return

	collect(butterfly)


func collect(
	butterfly: ButterflyCharacter
) -> void:
	if is_collected:
		return

	if not butterfly.add_nectar():
		return

	is_collected = true

	# Sembunyikan Nectar.
	visible = false

	# Nonaktifkan detector.
	set_deferred(
		"monitoring",
		false
	)

	$CollisionShape2D.set_deferred(
		"disabled",
		true
	)

	print(
		"NECTAR COLLECTED | Butterfly: ",
		butterfly.get_nectar_count(),
		"/",
		ButterflyCharacter.MAX_NECTAR
	)

	# Pickup menjadi bagian dari turn movement terakhir.
	board.append_action_to_last_turn({
		"type": "custom",
		"undo_callable": Callable(
			self,
			"_undo_collect"
		),
		"data": {
			"butterfly": butterfly
		}
	})


# Dipanggil Board ketika turn pickup di-Undo.
func _undo_collect(data: Dictionary) -> void:
	var butterfly := (
		data["butterfly"]
		as ButterflyCharacter
	)

	if is_instance_valid(butterfly):
		butterfly.remove_nectar()

	is_collected = false

	visible = true

	# Aktifkan kembali detector setelah physics aman.
	call_deferred(
		"_restore_detector"
	)

	print(
		"UNDO NECTAR | Nectar kembali di cell: ",
		grid_position
	)


func _restore_detector() -> void:
	monitoring = true
	$CollisionShape2D.disabled = false

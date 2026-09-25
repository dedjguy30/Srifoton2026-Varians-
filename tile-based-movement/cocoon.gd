class_name Cocoon
extends Area2D


# Event ini akan dipakai pada Batch C untuk memulai transformasi.
signal caterpillar_entered(
	caterpillar: CaterpillarCharacter,
	cocoon: Cocoon
)


# Board level tempat Cocoon berada.
@export var board: Board


# Posisi Cocoon pada grid.
var grid_position: Vector2i


func _ready() -> void:
	if board == null:
		push_error("Cocoon belum terhubung ke Board!")
		return

	# Cocoon mengikuti grid, tetapi tidak menjadi blocking occupant.
	grid_position = board.world_to_grid(global_position)
	global_position = board.grid_to_world(grid_position)


func _on_body_entered(body: Node2D) -> void:
	print("COCOON DETECT: ", body.name)

	# Kepompong hanya bereaksi terhadap Caterpillar.
	if not body is CaterpillarCharacter:
		print("COCOON IGNORE: bukan Caterpillar")
		return

	var caterpillar := body as CaterpillarCharacter

	print("COCOON: Caterpillar siap transformasi")

	# Batch B hanya mengirim event.
	# Transformasi sebenarnya dibuat pada Batch C.
	caterpillar_entered.emit(
	caterpillar,
	self
)

func deactivate_cocoon() -> void:
	visible = false
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred(
		"disabled",
		true
	)


func activate_cocoon() -> void:
	visible = true
	set_deferred("monitoring", true)
	$CollisionShape2D.set_deferred(
		"disabled",
		false
	)

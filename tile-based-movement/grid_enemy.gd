class_name GridEnemy
extends Node2D


# ==================================================
# SETTINGS
# ==================================================

@export var board: Board

const BOUNCE_DURATION: float = 0.16
const BOUNCE_HEIGHT: float = 6.0

const AFTERIMAGE_LIFETIME: float = 0.18
const AFTERIMAGE_ALPHA: float = 0.42


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var sprite = $Sprite2D


# ==================================================
# RUNTIME DATA
# ==================================================

var grid_position: Vector2i = Vector2i.ZERO
var is_alive: bool = true

var skip_next_turn: bool = false

# HANYA untuk visual.
# Tidak mengatur logical movement.
var move_tween: Tween

# Menyimpan local position asli sprite.
# Berguna untuk Undo / snap.
var sprite_home_position: Vector2 = Vector2.ZERO
var death_tween: Tween

var death_sprite_home_scale: Vector2
var death_sprite_home_rotation: float
var death_sprite_home_modulate: Color

# ==================================================
# READY
# ==================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("pressure_plate_activator")
	add_to_group("hazard_vulnerable")

	if sprite != null:
		sprite_home_position = sprite.position
		death_sprite_home_scale = sprite.scale
		death_sprite_home_rotation = sprite.rotation
		death_sprite_home_modulate = sprite.modulate

	if board == null:
		push_error(
			name + " belum terhubung ke Board!"
		)
		return

	grid_position = board.world_to_grid(
		global_position
	)

	global_position = board.grid_to_world(
		grid_position
	)

	if not board.register_object(
		grid_position,
		self
	):
		return

	if not board.turn_about_to_commit.is_connected(
		_on_turn_about_to_commit
	):
		board.turn_about_to_commit.connect(
			_on_turn_about_to_commit
		)


# ==================================================
# TURN
# ==================================================

func _on_turn_about_to_commit() -> void:
	if not is_alive:
		return

	if skip_next_turn:
		skip_next_turn = false

		print(
			"ENEMY TURN SKIPPED | ",
			name,
			" sudah makan Character turn ini."
		)

		return

	take_turn()


func take_turn() -> void:
	pass


# ==================================================
# FACING
# ==================================================

func update_facing(
	direction: Vector2i
) -> void:
	if sprite == null:
		return

	if direction.x < 0:
		sprite.flip_h = true

	elif direction.x > 0:
		sprite.flip_h = false


# ==================================================
# LOGICAL MOVEMENT
# ==================================================

# PENTING:
#
# Fungsi ini TIDAK memiliki Tween / bounce.
#
# Charger memanggil fungsi ini berkali-kali
# dalam satu serangan, jadi logical movement
# harus selalu langsung selesai.
func move_enemy(
	direction: Vector2i
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	if direction == Vector2i.ZERO:
		return false

	var target_cell: Vector2i = (
		grid_position + direction
	)

	if board.is_occupied(
		target_cell
	):
		return false

	var success: bool = board.move_object(
		grid_position,
		target_cell,
		self
	)

	if not success:
		return false

	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	update_facing(
		direction
	)

	return true


# ==================================================
# BOUNCE VISUAL
# ==================================================

# Dipanggil CHILD enemy setelah move_enemy()
# berhasil.
#
# Logic sudah selesai.
# Ini cuma menggerakkan sprite.
func play_bounce_from(
	old_visual_position: Vector2
) -> void:
	if sprite == null:
		return

	var target_visual_position: Vector2 = (
		sprite.global_position
	)

	if move_tween:
		move_tween.kill()

	sprite.global_position = (
		old_visual_position
	)

	var middle_position: Vector2 = (
		old_visual_position.lerp(
			target_visual_position,
			0.5
		)
	)

	middle_position.y -= BOUNCE_HEIGHT

	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	# Naik.
	move_tween.tween_property(
		sprite,
		"global_position",
		middle_position,
		BOUNCE_DURATION * 0.5
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)

	# Turun / landing.
	move_tween.tween_property(
		sprite,
		"global_position",
		target_visual_position,
		BOUNCE_DURATION * 0.5
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN
	)


# ==================================================
# MOTION AFTERIMAGE
# ==================================================

# Dipakai Charger untuk efek slide.
func create_motion_afterimage() -> void:
	if sprite == null:
		return

	var ghost := Sprite2D.new()

	var frame_texture: Texture2D = null


	# ==================================================
	# NORMAL SPRITE2D
	# ==================================================

	if sprite is Sprite2D:
		var source := (
			sprite as Sprite2D
		)

		frame_texture = source.texture

		if frame_texture == null:
			return

		ghost.centered = source.centered
		ghost.offset = source.offset

		ghost.flip_h = source.flip_h
		ghost.flip_v = source.flip_v


	# ==================================================
	# ANIMATED SPRITE2D
	# ==================================================

	elif sprite is AnimatedSprite2D:
		var source := (
			sprite as AnimatedSprite2D
		)

		if source.sprite_frames == null:
			return

		frame_texture = (
			source.sprite_frames.get_frame_texture(
				source.animation,
				source.frame
			)
		)

		if frame_texture == null:
			return

		ghost.centered = source.centered
		ghost.offset = source.offset

		ghost.flip_h = source.flip_h
		ghost.flip_v = source.flip_v

	else:
		return


	ghost.texture = frame_texture

	ghost.texture_filter = (
		sprite.texture_filter
	)

	ghost.modulate = Color(
		1.0,
		1.0,
		1.0,
		AFTERIMAGE_ALPHA
	)

	var visual_transform: Transform2D = (
		sprite.global_transform
	)

	var ghost_parent: Node = get_parent()

	if ghost_parent == null:
		ghost_parent = (
			get_tree().current_scene
		)

	if ghost_parent == null:
		ghost.queue_free()
		return

	ghost_parent.add_child(
		ghost
	)

	ghost.global_transform = (
		visual_transform
	)

	ghost.z_index = (
		sprite.z_index - 1
	)


	# ==================================================
	# FADE
	# ==================================================

	var fade_tween: Tween = (
		ghost.create_tween()
	)

	fade_tween.tween_property(
		ghost,
		"modulate:a",
		0.0,
		AFTERIMAGE_LIFETIME
	)

	fade_tween.tween_callback(
		Callable(
			ghost,
			"queue_free"
		)
	)


# ==================================================
# PLAYER WALKS INTO ENEMY
# ==================================================

func eat_character_from_player_move(
	character: GridCharacter
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	if character == null:
		return false

	if not character.is_alive:
		return false

	if character.board != board:
		return false

	var defeated: bool = (
		character.defeat()
	)

	if not defeated:
		return false

	skip_next_turn = true

	print(
		"ENEMY ATE CHARACTER | ",
		name,
		" memakan ",
		character.name
	)

	return true


# ==================================================
# ENEMY MOVES INTO CHARACTER
# ==================================================

func move_or_attack_character(
	direction: Vector2i
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	if direction == Vector2i.ZERO:
		return false

	var target_cell: Vector2i = (
		grid_position + direction
	)

	var target_object = board.get_object_at(
		target_cell
	)


	# ==================================================
	# EMPTY
	# ==================================================

	if target_object == null:
		return move_enemy(
			direction
		)


	# ==================================================
	# CHARACTER
	# ==================================================

	if target_object is GridCharacter:
		var character := (
			target_object
			as GridCharacter
		)

		if not character.is_alive:
			return false

		var defeated: bool = (
			character.defeat()
		)

		if not defeated:
			return false

		return move_enemy(
			direction
		)


	return false

# ==================================================
# DEATH VISUAL - FLASH SHRINK
# ==================================================

func play_death_animation() -> void:
	if is_alive:
		return

	if sprite == null:
		visible = false
		return

	if death_tween:
		death_tween.kill()

	if move_tween:
		move_tween.kill()


	# Reset visual dulu.
	sprite.position = sprite_home_position
	sprite.scale = death_sprite_home_scale
	sprite.rotation = death_sprite_home_rotation
	sprite.modulate = death_sprite_home_modulate


	# ==================================================
	# FLASH
	# ==================================================

	sprite.modulate = Color(
		2.0,
		2.0,
		2.0,
		1.0
	)


	death_tween = create_tween()

	death_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)


	# Flash sebentar.
	death_tween.tween_interval(
		0.06
	)


	# Balik ke warna normal.
	death_tween.tween_property(
		sprite,
		"modulate",
		death_sprite_home_modulate,
		0.04
	)


	# ==================================================
	# SHRINK
	# ==================================================

	death_tween.tween_property(
		sprite,
		"scale",
		Vector2(
			death_sprite_home_scale.x * 0.05,
			death_sprite_home_scale.y * 0.05
		),
		0.13
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_IN
	)


	death_tween.parallel().tween_property(
		sprite,
		"modulate:a",
		0.0,
		0.11
	)


	death_tween.finished.connect(
		_finish_enemy_death_animation
	)


func _finish_enemy_death_animation() -> void:
	if is_alive:
		return

	visible = false


func reset_enemy_death_visual() -> void:
	if death_tween:
		death_tween.kill()

	death_tween = null

	if sprite == null:
		return

	sprite.position = sprite_home_position
	sprite.scale = death_sprite_home_scale
	sprite.rotation = death_sprite_home_rotation
	sprite.modulate = death_sprite_home_modulate
# ==================================================
# DEATH
# ==================================================

func defeat() -> bool:
	if not is_alive:
		return false

	if board == null:
		return false

	var death_cell: Vector2i = (
		grid_position
	)

	var previous_visible: bool = (
		visible
	)

	var recorded: bool = (
		board.append_action_to_current_turn({
			"type": "custom",

			"undo_callable": Callable(
				self,
				"_undo_defeat"
			),

			"data": {
				"death_cell":
					death_cell,

				"previous_visible":
					previous_visible
			}
		})
	)

	if not recorded:
		push_warning(
			"Enemy defeat terjadi di luar turn aktif."
		)

		return false

	if board.get_object_at(
		death_cell
	) == self:
		board.unregister_object(
			death_cell,
			self
		)

	if move_tween:
		move_tween.kill()

	is_alive = false
	AudioManager.play_death()
	visible = true

	call_deferred(
	"play_death_animation"
)

	print(
		"ENEMY DEFEATED | ",
		name,
		" | Cell: ",
		death_cell
	)

	return true


# ==================================================
# UNDO DEATH
# ==================================================

func _undo_defeat(
	data: Dictionary
) -> void:
	var death_cell: Vector2i = (
		data["death_cell"]
	)

	if board.is_occupied(
		death_cell
	):
		push_warning(
			"Undo Enemy gagal: "
			+ "cell kematian masih occupied."
		)

		return

	if not board.register_object(
		death_cell,
		self
	):
		return

	is_alive = true
	reset_enemy_death_visual()
	
	visible = data[
		"previous_visible"
	]

	grid_position = death_cell

	global_position = board.grid_to_world(
		grid_position
	)

	if move_tween:
		move_tween.kill()

	if sprite != null:
		sprite.position = (
			sprite_home_position
		)

	print(
		"UNDO ENEMY DEATH | ",
		name
	)


# ==================================================
# SNAP / UNDO MOVEMENT
# ==================================================

func snap_to_cell(
	cell: Vector2i
) -> void:
	if move_tween:
		move_tween.kill()

	grid_position = cell

	global_position = board.grid_to_world(
		grid_position
	)

	if sprite != null:
		sprite.position = (
			sprite_home_position
		)


# ==================================================
# VISUAL MOVEMENT STATE
# ==================================================

func is_moving() -> bool:
	return (
		move_tween != null
		and move_tween.is_running()
	)

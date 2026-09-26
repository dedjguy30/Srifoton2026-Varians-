class_name ElytraCharacter
extends GridCharacter


# ==================================================
# SETTINGS
# ==================================================

# Waktu meluncur satu tile.
const SLIDE_STEP_DURATION: float = 0.07

# Berapa lama bayangan Elytra bertahan.
const AFTERIMAGE_LIFETIME: float = 0.14

# Transparansi awal bayangan.
const AFTERIMAGE_ALPHA: float = 0.38


# ==================================================
# RUNTIME
# ==================================================

var is_sliding: bool = false

var slide_direction: Vector2i = Vector2i.ZERO

var slide_moved: bool = false


# ==================================================
# INPUT
# ==================================================

func _physics_process(
	_delta: float
) -> void:
	if not is_alive:
		return

	if not is_active:
		return

	if board == null:
		return


	# Sedang sliding = tidak boleh dibelokkan.
	if is_sliding:
		return


	var direction: Vector2i = (
		get_just_pressed_direction()
	)

	if direction == Vector2i.ZERO:
		return

	move_one_tile(
		direction
	)


# ==================================================
# JUST PRESSED DIRECTION
# ==================================================

func get_just_pressed_direction() -> Vector2i:
	if Input.is_action_just_pressed(
		"ui_up"
	):
		return Vector2i.UP

	if Input.is_action_just_pressed(
		"ui_down"
	):
		return Vector2i.DOWN

	if Input.is_action_just_pressed(
		"ui_left"
	):
		return Vector2i.LEFT

	if Input.is_action_just_pressed(
		"ui_right"
	):
		return Vector2i.RIGHT

	return Vector2i.ZERO


# ==================================================
# START SLIDE
# ==================================================

func move_one_tile(
	direction: Vector2i
) -> void:
	if board == null:
		return

	if not is_alive:
		return

	if is_sliding:
		return

	if direction == Vector2i.ZERO:
		return


	# Ikut hadap kiri / kanan.
	update_facing(
		direction
	)


	slide_direction = direction

	slide_moved = false

	is_sliding = true


	# Seluruh slide dianggap SATU turn.
	board.begin_turn()


	print(
		"ELYTRA START SLIDE | ",
		name,
		" | Direction: ",
		slide_direction
	)


	_continue_slide()


# ==================================================
# CONTINUE SLIDE
# ==================================================

func _continue_slide() -> void:
	if board == null:
		_finish_slide()
		return


	# ==================================================
	# DIED DURING SLIDE
	# ==================================================

	if not is_alive:
		_finish_slide()
		return


	var next_cell: Vector2i = (
		grid_position
		+ slide_direction
	)

	var target_object = board.get_object_at(
		next_cell
	)


	# ==================================================
	# EMPTY CELL
	# ==================================================

	if target_object == null:
		_slide_one_step()
		return


	# ==================================================
	# BEETLE
	# ==================================================

	if target_object is BeetleCharacter:
		print(
			"ELYTRA HIT BEETLE | ",
			name,
			" berhenti sebelum ",
			target_object.name
		)

		_finish_slide()
		return


	# ==================================================
	# ELYTRA VS ELYTRA
	# ==================================================

	if target_object is ElytraCharacter:
		print(
			"ELYTRA HIT ELYTRA | Stop."
		)

		_finish_slide()
		return


	# ==================================================
	# FRIENDLY CHARACTER
	# ==================================================

	if target_object is GridCharacter:
		var character := (
			target_object
			as GridCharacter
		)

		if not character.is_alive:
			_finish_slide()
			return


		print(
			"ELYTRA HIT CHARACTER | ",
			name,
			" → ",
			character.name
		)


		var defeated: bool = (
			character.defeat()
		)

		if not defeated:
			_finish_slide()
			return


		# Masuk ke cell Character lalu berhenti.
		_slide_one_step(
			true
		)

		return


	# ==================================================
	# ENEMY
	# ==================================================

	if target_object is GridEnemy:
		var enemy := (
			target_object
			as GridEnemy
		)

		if not enemy.is_alive:
			_finish_slide()
			return


		print(
			"ELYTRA HIT ENEMY | ",
			name,
			" → ",
			enemy.name
		)


		var defeated_enemy: bool = (
			enemy.defeat()
		)

		if not defeated_enemy:
			_finish_slide()
			return


		# Masuk ke cell Enemy lalu berhenti.
		_slide_one_step(
			true
		)

		return


	# ==================================================
	# BLOCKER
	# ==================================================

	print(
		"ELYTRA HIT BLOCKER | ",
		target_object.name
	)

	_finish_slide()


# ==================================================
# SLIDE ONE TILE
# ==================================================

func _slide_one_step(
	stop_after_step: bool = false
) -> void:
	if board == null:
		_finish_slide()
		return

	if not is_alive:
		_finish_slide()
		return


	var target_cell: Vector2i = (
		grid_position
		+ slide_direction
	)


	if board.is_occupied(
		target_cell
	):
		_finish_slide()
		return


	# ==================================================
	# VISUAL START
	# ==================================================

	var old_visual_position: Vector2 = (
		sprite.global_position
	)


	# ==================================================
	# LOGICAL MOVE
	# ==================================================

	var success: bool = board.move_object(
		grid_position,
		target_cell,
		self
	)

	if not success:
		_finish_slide()
		return


	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	# Simpan posisi sprite setelah root berpindah.
	# Ini menjaga offset visual.
	var target_visual_position: Vector2 = (
		sprite.global_position
	)


	slide_moved = true


	# ==================================================
	# HAZARD MAY HAVE KILLED ELYTRA
	# ==================================================

	if not is_alive:
		_finish_slide()
		return


	# ==================================================
	# VISUAL TWEEN
	# ==================================================

	if move_tween:
		move_tween.kill()


	# Kembalikan sprite ke posisi visual sebelumnya.
	sprite.global_position = (
		old_visual_position
	)


	# Buat bayangan dari posisi lama.
	_create_slide_afterimage()


	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	move_tween.tween_property(
		sprite,
		"global_position",
		target_visual_position,
		SLIDE_STEP_DURATION
	).set_trans(
		Tween.TRANS_LINEAR
	)


	# ==================================================
	# AFTER ONE TILE
	# ==================================================

	if stop_after_step:
		move_tween.finished.connect(
			_finish_slide
		)

	else:
		move_tween.finished.connect(
			_continue_slide
		)


# ==================================================
# AFTERIMAGE / MOTION BLUR
# ==================================================

func _create_slide_afterimage() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(
		sprite.animation
	):
		return


	# Ambil texture frame yang sedang tampil.
	var frame_texture: Texture2D = (
		sprite.sprite_frames.get_frame_texture(
			sprite.animation,
			sprite.frame
		)
	)

	if frame_texture == null:
		return


	# Simpan transform posisi asli sebelum
	# ghost dimasukkan ke node lain.
	var old_transform: Transform2D = (
		sprite.global_transform
	)


	var ghost := Sprite2D.new()

	ghost.texture = frame_texture

	ghost.centered = sprite.centered
	ghost.offset = sprite.offset

	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v

	ghost.texture_filter = (
		sprite.texture_filter
	)

	# Transparan supaya terasa seperti blur.
	ghost.modulate = Color(
		1.0,
		1.0,
		1.0,
		AFTERIMAGE_ALPHA
	)


	# Taruh sebagai sibling Elytra,
	# bukan child Elytra.
	#
	# Jadi ghost tidak ikut bergerak
	# saat root Elytra pindah cell.
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
		old_transform
	)

	# Z sama dengan Elytra supaya tidak
	# tenggelam di bawah ground.
	ghost.z_index = z_index


	# ==================================================
	# FADE OUT
	# ==================================================

	var fade_tween: Tween = (
		ghost.create_tween()
	)

	fade_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	fade_tween.tween_property(
		ghost,
		"modulate",
		Color(
			1.0,
			1.0,
			1.0,
			0.0
		),
		AFTERIMAGE_LIFETIME
	)

	fade_tween.tween_callback(
		Callable(
			ghost,
			"queue_free"
		)
	)


# ==================================================
# FINISH SLIDE
# ==================================================

func _finish_slide() -> void:
	if not is_sliding:
		return


	is_sliding = false

	slide_direction = Vector2i.ZERO


	# ==================================================
	# TURN RESULT
	# ==================================================

	if slide_moved:
		board.commit_turn()

	else:
		board.cancel_turn()


	slide_moved = false


	print(
		"ELYTRA STOP | ",
		name,
		" | Cell: ",
		grid_position
	)


# ==================================================
# MOVEMENT STATE
# ==================================================

func is_moving() -> bool:
	if is_sliding:
		return true

	return (
		move_tween != null
		and move_tween.is_running()
	)

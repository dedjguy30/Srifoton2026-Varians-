class_name GridCharacter
extends CharacterBody2D


# ==================================================
# LIFE STATE
# ==================================================

var is_alive: bool = true


# ==================================================
# SETTINGS
# ==================================================

const MOVE_DURATION: float = 0.185

# Tinggi bounce ketika pindah tile.
const BOUNCE_HEIGHT: float = 7.0

@export var board: Board
@export var push_strength: int = 1

# Level yang menentukan siapa Character aktif.
var is_active: bool = false


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var sprite: AnimatedSprite2D = $Sprite2D

@onready var ray_up: RayCast2D = $up
@onready var ray_down: RayCast2D = $down
@onready var ray_left: RayCast2D = $left
@onready var ray_right: RayCast2D = $right


# ==================================================
# RUNTIME DATA
# ==================================================

var grid_position: Vector2i = Vector2i.ZERO
var move_tween: Tween
var death_tween: Tween

var death_sprite_home_position: Vector2
var death_sprite_home_scale: Vector2
var death_sprite_home_rotation: float
var death_sprite_home_modulate: Color
var active_indicator: Polygon2D
@export var active_indicator_offset: Vector2 = Vector2(
	0,
	-25
)
@export var active_indicator_scale: Vector2 = Vector2.ONE
# ==================================================
# READY
# ==================================================

func _ready() -> void:
	is_active = false
	set_physics_process(false)

	# Animasi normal.
	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
	death_sprite_home_position = sprite.position
	
	death_sprite_home_scale = sprite.scale
	death_sprite_home_rotation = sprite.rotation
	death_sprite_home_modulate = sprite.modulate

	create_active_indicator()

	add_to_group("characters")
	add_to_group("pressure_plate_activator")
	add_to_group("hazard_vulnerable")

	if board == null:
		push_error(
			"Player belum terhubung ke Board!"
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
		push_error(
			"Gagal register Character: "
			+ name
		)
		return



# ==================================================
# ACTIVE CHARACTER INDICATOR
# ==================================================

func create_active_indicator() -> void:
	active_indicator = Polygon2D.new()

	active_indicator.name = "ActiveIndicator"

	active_indicator.polygon = PackedVector2Array([
		Vector2(-5, -4),
		Vector2(5, -4),
		Vector2(0, 3)
	])

	active_indicator.color = Color(
		0.15,
		0.55,
		1.0,
		1.0
	)

	active_indicator.position = active_indicator_offset
	active_indicator.scale = active_indicator_scale
	active_indicator.z_index = 10
	active_indicator.visible = false

	add_child(active_indicator)


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

	if is_moving():
		return


	# ==================================================
	# ACTIVE SKILL
	# ==================================================

	if Input.is_action_just_pressed(
		"use_skill"
	):
		try_use_skill()
		return


	# ==================================================
	# MOVEMENT
	# ==================================================

	var direction: Vector2i = (
		get_input_direction()
	)

	if direction == Vector2i.ZERO:
		return

	move_one_tile(
		direction
	)


# ==================================================
# SKILL SYSTEM
# ==================================================

func try_use_skill() -> void:
	if board == null:
		return

	if not is_alive:
		return

	board.begin_turn()

	var skill_success: bool = use_skill()

	if skill_success:
		board.commit_turn()

		play_skill_animation()

	else:
		board.cancel_turn()


func play_skill_animation() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(
		"skill"
	):
		return

	sprite.play("skill")

	await sprite.animation_finished

	if not is_instance_valid(sprite):
		return

	if sprite.sprite_frames.has_animation(
		"default"
	):
		sprite.play("default")


func use_skill() -> bool:
	return false


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
# MOVEMENT INPUT
# ==================================================

func get_input_direction() -> Vector2i:
	if Input.is_action_pressed(
		"ui_up"
	):
		return Vector2i.UP

	if Input.is_action_pressed(
		"ui_down"
	):
		return Vector2i.DOWN

	if Input.is_action_pressed(
		"ui_left"
	):
		update_facing(
			Vector2i.LEFT
		)

		return Vector2i.LEFT

	if Input.is_action_pressed(
		"ui_right"
	):
		update_facing(
			Vector2i.RIGHT
		)

		return Vector2i.RIGHT

	return Vector2i.ZERO


# ==================================================
# LEGACY RAYCAST
# ==================================================

func is_direction_blocked(
	direction: Vector2i
) -> bool:
	if direction == Vector2i.UP:
		return ray_up.is_colliding()

	if direction == Vector2i.DOWN:
		return ray_down.is_colliding()

	if direction == Vector2i.LEFT:
		return ray_left.is_colliding()

	if direction == Vector2i.RIGHT:
		return ray_right.is_colliding()

	return true


# ==================================================
# NORMAL CHARACTER MOVEMENT
# ==================================================

func move_one_tile(
	direction: Vector2i
) -> void:
	if board == null:
		return

	if not is_alive:
		return

	if direction == Vector2i.ZERO:
		return

	update_facing(
		direction
	)

	var target_cell: Vector2i = (
		grid_position
		+ direction
	)
	var pushed_this_move: bool = false

	board.begin_turn()


	# ==================================================
	# TARGET OCCUPIED
	# ==================================================

	if board.is_occupied(
		target_cell
	):
		var target_object = (
			board.get_object_at(
				target_cell
			)
		)


		# ==================================================
		# PUSHABLE BOX
		# ==================================================

		if target_object is PushableBox:
			var box := (
				target_object
				as PushableBox
			)

			var push_success: bool = (
				box.try_push(
					push_strength,
					direction
				)
			)

			if not push_success:
				board.cancel_turn()
				return

			pushed_this_move = true


		# ==================================================
		# PLAYER WALKS INTO ENEMY
		# ==================================================

		elif target_object is GridEnemy:
			var enemy := (
				target_object
				as GridEnemy
			)

			if not enemy.is_alive:
				board.cancel_turn()
				return

			print(
				"CHARACTER WALKED INTO ENEMY | ",
				name,
				" → ",
				enemy.name
			)

			var eaten: bool = (
				enemy.eat_character_from_player_move(
					self
				)
			)

			if not eaten:
				board.cancel_turn()
				return

			board.commit_turn()

			return


		# ==================================================
		# OTHER BLOCKER
		# ==================================================

		else:
			board.cancel_turn()
			return


	# ==================================================
	# VISUAL POSITION BEFORE MOVE
	# ==================================================

	var old_visual_position: Vector2 = (
		sprite.global_position
	)


	# ==================================================
	# LOGICAL MOVE
	# ==================================================

	var success: bool = (
		board.move_object(
			grid_position,
			target_cell,
			self
		)
	)

	if not success:
		board.cancel_turn()
		return

	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	# Posisi visual sebenarnya setelah root
	# berpindah. Ini menjaga offset sprite.
	var target_visual_position: Vector2 = (
		sprite.global_position
	)

	board.commit_turn()


	# ==================================================
	# DIED DURING MOVEMENT
	# ==================================================

	if not is_alive:
		return
	
	if pushed_this_move:
		AudioManager.play_push_then_move()
	else:
		AudioManager.play_move()


	# ==================================================
	# BOUNCE VISUAL
	# ==================================================

	sprite.global_position = (
		old_visual_position
	)

	if move_tween:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	# Titik tengah perjalanan.
	var middle_position: Vector2 = (
		old_visual_position.lerp(
			target_visual_position,
			0.5
		)
	)

	# Naik sedikit = bounce.
	middle_position.y -= BOUNCE_HEIGHT


	# ==================================================
	# BOUNCE UP
	# ==================================================

	move_tween.tween_property(
		sprite,
		"global_position",
		middle_position,
		MOVE_DURATION * 0.5
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)


	# ==================================================
	# BOUNCE LAND
	# ==================================================

	move_tween.tween_property(
		sprite,
		"global_position",
		target_visual_position,
		MOVE_DURATION * 0.5
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN
	)


# ==================================================
# EXTERNAL MOVEMENT
# ==================================================

func move_to_cell_in_current_turn(
	target_cell: Vector2i,
	duration: float = MOVE_DURATION
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	if board.is_occupied(
		target_cell
	):
		return false

	var old_visual_position: Vector2 = (
		sprite.global_position
	)

	var success: bool = (
		board.move_object(
			grid_position,
			target_cell,
			self
		)
	)

	if not success:
		return false

	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	var target_visual_position: Vector2 = (
		sprite.global_position
	)


	# Hazard bisa membunuh Character.
	if not is_alive:
		return true


	sprite.global_position = (
		old_visual_position
	)

	if move_tween:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	# External movement tidak pakai bounce.
	# Contoh: dilempar Grasshopper.
	move_tween.tween_property(
		sprite,
		"global_position",
		target_visual_position,
		duration
	).set_trans(
		Tween.TRANS_SINE
	)

	return true


# ==================================================
# MOVEMENT STATE
# ==================================================

func is_moving() -> bool:
	return (
		move_tween != null
		and move_tween.is_running()
	)


# ==================================================
# SNAP / UNDO
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

	sprite.global_position = (
		global_position
	)


# ==================================================
# ACTIVE CHARACTER
# ==================================================

func set_active(
	value: bool
) -> void:
	is_active = (
		value
		and is_alive
	)

	set_physics_process(
		is_active
	)

	if active_indicator != null:
		active_indicator.visible = (
			is_active
			and is_alive
		)

	print(
		name,
		" | is_active = ",
		is_active,
		" | physics = ",
		is_physics_processing()
	)


# ==================================================
# CHARACTER CAPABILITIES
# ==================================================

func can_cross_pit() -> bool:
	return false

# ==================================================
# DEATH VISUAL - KNOCKBACK FALL
# ==================================================

# ==================================================
# DEATH VISUAL - KNOCKBACK FALL
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


	# ==================================================
	# RESET VISUAL
	# ==================================================

	sprite.position = death_sprite_home_position
	sprite.scale = death_sprite_home_scale
	sprite.rotation = death_sprite_home_rotation
	sprite.modulate = death_sprite_home_modulate


	# ==================================================
	# KNOCKBACK DIRECTION
	# ==================================================

	var knockback_sign: float = -1.0

	# Menghadap kiri -> mental ke kanan.
	if sprite.flip_h:
		knockback_sign = 1.0


	var knockback_position: Vector2 = (
		death_sprite_home_position
		+ Vector2(
			8.0 * knockback_sign,
			-6.0
		)
	)


	var fall_position: Vector2 = (
		death_sprite_home_position
		+ Vector2(
			14.0 * knockback_sign,
			8.0
		)
	)


	var fall_rotation: float = (
		death_sprite_home_rotation
		+ 0.75 * knockback_sign
	)


	# ==================================================
	# CREATE TWEEN
	# ==================================================

	death_tween = create_tween()

	death_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)


	# ==================================================
	# PHASE 1 - KNOCKBACK
	# ==================================================

	death_tween.tween_property(
		sprite,
		"position",
		knockback_position,
		0.09
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


	death_tween.parallel().tween_property(
		sprite,
		"scale",
		Vector2(
			death_sprite_home_scale.x * 1.08,
			death_sprite_home_scale.y * 0.92
		),
		0.09
	)


	# ==================================================
	# PHASE 2 - FALL
	# ==================================================

	death_tween.tween_property(
		sprite,
		"position",
		fall_position,
		0.22
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)


	death_tween.parallel().tween_property(
		sprite,
		"rotation",
		fall_rotation,
		0.22
	)


	death_tween.parallel().tween_property(
		sprite,
		"scale",
		Vector2(
			death_sprite_home_scale.x * 0.90,
			death_sprite_home_scale.y * 0.72
		),
		0.22
	)


	death_tween.parallel().tween_property(
		sprite,
		"modulate:a",
		0.0,
		0.22
	)


	death_tween.finished.connect(
		_finish_character_death_animation
	)


# ==================================================
# FINISH DEATH
# ==================================================

func _finish_character_death_animation() -> void:
	if is_alive:
		return

	visible = false


# ==================================================
# RESET DEATH VISUAL FOR UNDO
# ==================================================

func reset_character_death_visual() -> void:
	if death_tween:
		death_tween.kill()

	death_tween = null

	if sprite == null:
		return


	sprite.position = death_sprite_home_position
	sprite.scale = death_sprite_home_scale
	sprite.rotation = death_sprite_home_rotation
	sprite.modulate = death_sprite_home_modulate


	if (
		sprite.sprite_frames != null
		and sprite.sprite_frames.has_animation(
			"default"
		)
	):
		sprite.play(
			"default"
		)
# ==================================================
# CHARACTER DEATH
# ==================================================

func defeat() -> bool:
	if not is_alive:
		return false

	if board == null:
		return false

	var death_cell: Vector2i = (
		grid_position
	)

	var previous_active: bool = (
		is_active
	)

	var previous_visible: bool = (
		visible
	)

	var previous_collision_layer: int = (
		collision_layer
	)

	var previous_collision_mask: int = (
		collision_mask
	)


	# ==================================================
	# SAVE DEATH FOR UNDO
	# ==================================================

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

				"previous_active":
					previous_active,

				"previous_visible":
					previous_visible,

				"previous_collision_layer":
					previous_collision_layer,

				"previous_collision_mask":
					previous_collision_mask
			}
		})
	)

	if not recorded:
		push_warning(
			"Character defeat terjadi "
			+ "di luar turn aktif."
		)

		return false


	# ==================================================
	# REMOVE FROM BOARD
	# ==================================================

	if board.get_object_at(
		death_cell
	) == self:
		board.unregister_object(
			death_cell,
			self
		)


	# ==================================================
	# DEAD STATE
	# ==================================================

	if move_tween:
		move_tween.kill()

	is_alive = false

	AudioManager.play_death()

	set_active(false)

	collision_layer = 0
	collision_mask = 0

	# Tetap terlihat supaya Knockback Fall bisa dimainkan.
	visible = true

	call_deferred(
		"play_death_animation"
	)


	print(
		"CHARACTER DEFEATED | ",
		name,
		" | Cell: ",
		death_cell
	)

	return true


# ==================================================
# UNDO CHARACTER DEATH
# ==================================================

func _undo_defeat(
	data: Dictionary
) -> void:
	var death_cell: Vector2i = (
		data["death_cell"]
	)

	print(
		"DEBUG UNDO DEATH START | ",
		name,
		" | Cell: ",
		death_cell
	)


	# ==================================================
	# BOARD CHECK
	# ==================================================

	if board == null:
		push_error(
			"UNDO DEATH ERROR | Board null | "
			+ name
		)
		return


	# ==================================================
	# CHECK OCCUPANCY
	# ==================================================

	var occupant = board.get_object_at(
		death_cell
	)

	# Cell boleh kosong.
	# Kalau ternyata self sendiri sudah ter-register,
	# juga jangan dianggap gagal.
	if (
		occupant != null
		and occupant != self
	):
		push_warning(
			"UNDO DEATH GAGAL | Cell occupied oleh: "
			+ str(occupant.name)
			+ " | Cell: "
			+ str(death_cell)
		)

		return


	# ==================================================
	# REVIVE LOGICAL STATE
	# ==================================================

	is_alive = true


	# ==================================================
	# RESET DEATH ANIMATION
	# ==================================================

	reset_character_death_visual()


	# ==================================================
	# RESTORE VISUAL / COLLISION
	# ==================================================

	visible = data.get(
		"previous_visible",
		true
	)

	collision_layer = data.get(
		"previous_collision_layer",
		1
	)

	collision_mask = data.get(
		"previous_collision_mask",
		1
	)


	# ==================================================
	# RESTORE POSITION
	# ==================================================

	grid_position = death_cell

	global_position = board.grid_to_world(
		death_cell
	)

	# Sprite sudah di-reset oleh
	# reset_character_death_visual().
	# Pastikan root + sprite kembali sinkron.
	sprite.position = (
		death_sprite_home_position
	)


	# ==================================================
	# REGISTER AGAIN
	# ==================================================

	# Kalau belum terdaftar, register ulang.
	if occupant != self:
		var register_success: bool = (
			board.register_object(
				death_cell,
				self
			)
		)

		if not register_success:
			push_error(
				"UNDO DEATH ERROR | "
				+ "Gagal register Character | "
				+ name
			)

			is_alive = false
			visible = false

			return


	# ==================================================
	# RESTORE ACTIVE STATE
	# ==================================================

	var was_active: bool = (
		data.get(
			"previous_active",
			false
		)
	)


	if was_active:
		# Pastikan tidak ada dua Character aktif.
		for node in get_tree().get_nodes_in_group(
			"characters"
		):
			if not node is GridCharacter:
				continue

			var character := (
				node as GridCharacter
			)

			if not is_instance_valid(
				character
			):
				continue

			if character == self:
				continue

			character.set_active(
				false
			)


		set_active(
			true
		)

	else:
		set_active(
			false
		)


	print(
		"DEBUG UNDO DEATH SUCCESS | ",
		name,
		" | Alive: ",
		is_alive,
		" | Visible: ",
		visible,
		" | Cell: ",
		grid_position
	)

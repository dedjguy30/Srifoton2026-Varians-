class_name GridCharacter
extends CharacterBody2D


# ==================================================
# LIFE STATE
# ==================================================

# Character mati tetap ada sebagai Node.
# Jangan queue_free karena Undo membutuhkannya.
var is_alive: bool = true


# ==================================================
# SETTINGS
# ==================================================

const MOVE_DURATION: float = 0.185

@export var board: Board

@export var push_strength: int = 1

# Jangan export.
# Level yang menentukan siapa Character aktif.
var is_active: bool = false


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var sprite: Sprite2D = $Sprite2D

# Legacy RayCast.
@onready var ray_up: RayCast2D = $up
@onready var ray_down: RayCast2D = $down
@onready var ray_left: RayCast2D = $left
@onready var ray_right: RayCast2D = $right


# ==================================================
# RUNTIME DATA
# ==================================================

var grid_position: Vector2i = Vector2i.ZERO
var move_tween: Tween

# Penanda biru di atas Character yang sedang aktif.
var active_indicator: Polygon2D


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	# Semua Character mulai inactive.
	# Level nanti memilih tepat SATU Character.
	is_active = false
	set_physics_process(false)

	# Semua Character otomatis punya indikator aktif.
	create_active_indicator()

	add_to_group("characters")
	add_to_group("pressure_plate_activator")
	add_to_group("hazard_vulnerable")
		# Semua Character selalu mulai inactive.
	# Level nanti memilih SATU Character.
	is_active = false
	# Playable Character.
	add_to_group(
		"characters"
	)

	# Bisa menekan Pressure Plate.
	add_to_group(
		"pressure_plate_activator"
	)

	# Bisa mati karena Hazard seperti Spike.
	add_to_group(
		"hazard_vulnerable"
	)

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

	print(
		"Character ready: ",
		name,
		" | Cell: ",
		grid_position
	)
	
	


# ==================================================
# ACTIVE CHARACTER INDICATOR
# ==================================================

func create_active_indicator() -> void:
	active_indicator = Polygon2D.new()

	active_indicator.name = "ActiveIndicator"

	# Segitiga lebih kecil.
	active_indicator.polygon = PackedVector2Array([
		Vector2(-5, -4),
		Vector2(5, -4),
		Vector2(0, 3)
	])

	# Biru terang.
	active_indicator.color = Color(
		0.15,
		0.55,
		1.0,
		1.0
	)

	# Lebih turun / lebih dekat ke kepala.
	active_indicator.position = Vector2(
		0,
		-20
	)

	active_indicator.z_index = 10
	active_indicator.visible = false

	add_child(active_indicator)


# ==================================================
# INPUT
# ==================================================

func _physics_process(
	_delta: float
) -> void:
	# Character mati tidak menerima input.
	if not is_alive:
		return

	# Character nonaktif tidak menerima input.
	if not is_active:
		return

	if board == null:
		return

	if is_moving():
		return


	# ==================================================
	# PENTING
	# ==================================================
	#
	# UNDO SUDAH TIDAK ADA DI SINI.
	#
	# Z sekarang ditangani level.gd secara global.
	#
	# Jadi kalau Character ini mati,
	# Z tetap bisa digunakan.


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

	var skill_success: bool = (
		use_skill()
	)

	if skill_success:
		board.commit_turn()
	else:
		board.cancel_turn()


# Default Character tidak punya active skill.
func use_skill() -> bool:
	return false


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
		return Vector2i.LEFT

	if Input.is_action_pressed(
		"ui_right"
	):
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

	var target_cell: Vector2i = (
		grid_position
		+ direction
	)

	# Mulai satu turn.
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


		# ==================================================
		# PLAYER WALKS INTO ENEMY
		# ==================================================

		elif target_object is GridEnemy:
			var enemy := (
				target_object
				as GridEnemy
			)

			# Enemy mati tidak bisa makan Player.
			if not enemy.is_alive:
				board.cancel_turn()
				return


			print(
				"CHARACTER WALKED INTO ENEMY | ",
				name,
				" → ",
				enemy.name
			)


			# Enemy memakan Character.
			#
			# Character tetap berada di cell asal,
			# lalu mati dari sana.
			var eaten: bool = (
				enemy.eat_character_from_player_move(
					self
				)
			)

			if not eaten:
				board.cancel_turn()
				return


			# ==================================================
			# VALID TURN
			# ==================================================

			# Walaupun Character tidak benar-benar
			# bergerak ke cell Enemy,
			# keputusan maju ke Enemy tetap dianggap
			# sebagai satu turn yang valid.
			board.commit_turn()

			return


		# ==================================================
		# OTHER BLOCKER
		# ==================================================

		else:
			board.cancel_turn()
			return


	# ==================================================
	# NORMAL CHARACTER MOVEMENT
	# ==================================================

	var old_world_position: Vector2 = (
		global_position
	)

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

	board.commit_turn()


	# ==================================================
	# DIED DURING MOVEMENT
	# ==================================================

	# Contoh:
	# Character masuk Spike.
	if not is_alive:
		return


	# ==================================================
	# VISUAL TWEEN
	# ==================================================

	sprite.global_position = (
		old_world_position
	)

	if move_tween:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	move_tween.tween_property(
		sprite,
		"global_position",
		global_position,
		MOVE_DURATION
	).set_trans(
		Tween.TRANS_SINE
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


	# Hazard saat external movement
	# bisa membunuh Character.
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

	move_tween.tween_property(
		sprite,
		"global_position",
		global_position,
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

	# PENTING:
	# Character inactive sama sekali tidak menjalankan
	# _physics_process(), jadi tidak bisa ikut membaca
	# tombol movement milik Character aktif.
	set_physics_process(
		is_active
	)

	# Indikator hanya terlihat pada Character aktif.
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

# Matikan input + physics process Character mati.
	set_active(false)

	# Sementara hidden.
	# Nanti bisa diganti death animation.
	visible = false

	collision_layer = 0
	collision_mask = 0

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


	# ==================================================
	# VALIDATE CELL
	# ==================================================

	if board.is_occupied(
		death_cell
	):
		push_warning(
			"Undo Character Death gagal: "
			+ "cell masih occupied."
		)

		return


	# ==================================================
	# REVIVE
	# ==================================================

	is_alive = true

	visible = data[
		"previous_visible"
	]

	collision_layer = data[
		"previous_collision_layer"
	]

	collision_mask = data[
		"previous_collision_mask"
	]

	grid_position = death_cell

	global_position = board.grid_to_world(
		death_cell
	)

	sprite.global_position = (
		global_position
	)


	# ==================================================
	# REGISTER AGAIN
	# ==================================================

	if not board.register_object(
		death_cell,
		self
	):
		is_alive = false
		return


	# Kalau Character ini aktif sebelum mati,
	# kembalikan status tersebut.
	#
	# Level kemudian akan memastikan hanya
	# satu Character hidup yang aktif.
	set_active(
	data["previous_active"]
)

	print(
		"UNDO CHARACTER DEATH | ",
		name
	)

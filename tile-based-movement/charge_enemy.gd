class_name ChargerEnemy
extends GridEnemy


# ==================================================
# CHARGER SETTINGS
# ==================================================

@export_group("Charger Settings")

@export_range(1, 20, 1)
var detection_range: int = 6

@export_range(1, 5, 1)
var charge_delay_turns: int = 2


# Waktu visual untuk setiap tile yang dilewati.
const CHARGE_VISUAL_STEP_DURATION: float = 0.055

# Interval pembuatan bayangan.
const CHARGE_TRAIL_INTERVAL: float = 0.035


# ==================================================
# RUNTIME DATA
# ==================================================

var is_charging: bool = false

var charge_turn_counter: int = 0

var charge_direction: Vector2i = Vector2i.ZERO


# Khusus VISUAL.
var charge_visual_active: bool = false

var charge_trail_timer: float = 0.0


# ==================================================
# PROCESS VISUAL TRAIL
# ==================================================

func _process(
	delta: float
) -> void:
	if not charge_visual_active:
		return

	if not is_alive:
		charge_visual_active = false
		return

	charge_trail_timer -= delta

	if charge_trail_timer > 0.0:
		return

	create_motion_afterimage()

	charge_trail_timer = (
		CHARGE_TRAIL_INTERVAL
	)


# ==================================================
# ENEMY TURN
# ==================================================

func take_turn() -> void:
	if board == null:
		return

	if is_charging:
		continue_charging()
		return

	var target: GridCharacter = (
		find_visible_character()
	)

	if target == null:
		print(
			"CHARGER IDLE | ",
			name
		)

		return

	start_charging(
		target
	)


# ==================================================
# START CHARGING
# ==================================================

func start_charging(
	target: GridCharacter
) -> void:
	var direction: Vector2i = (
		get_direction_to_cell(
			target.grid_position
		)
	)

	if direction == Vector2i.ZERO:
		return

	save_charge_state_undo()

	is_charging = true

	charge_turn_counter = 0

	charge_direction = direction


	# Langsung menghadap arah target.
	update_facing(
		direction
	)


	print(
		"CHARGER START CHARGING | ",
		name,
		" | Direction: ",
		charge_direction
	)


# ==================================================
# CONTINUE CHARGING
# ==================================================

func continue_charging() -> void:
	save_charge_state_undo()

	charge_turn_counter += 1

	if charge_turn_counter < charge_delay_turns:
		print(
			"CHARGER CHARGING | ",
			name,
			" | ",
			charge_turn_counter,
			"/",
			charge_delay_turns
		)

		return


	var attack_direction: Vector2i = (
		charge_direction
	)

	is_charging = false

	charge_turn_counter = 0

	charge_direction = (
		Vector2i.ZERO
	)


	print(
		"CHARGER ATTACK | ",
		name,
		" | Direction: ",
		attack_direction
	)


	perform_charge(
		attack_direction
	)


# ==================================================
# FIND TARGET
# ==================================================

func find_visible_character() -> GridCharacter:
	var nearest: GridCharacter = null
	var nearest_distance: int = 999999

	for node in get_tree().get_nodes_in_group(
		"characters"
	):
		if not node is GridCharacter:
			continue

		var character := (
			node as GridCharacter
		)

		if character.board != board:
			continue

		if board.get_object_at(
			character.grid_position
		) != character:
			continue

		var difference: Vector2i = (
			character.grid_position
			- grid_position
		)

		var same_row: bool = (
			difference.y == 0
		)

		var same_column: bool = (
			difference.x == 0
		)

		if not same_row and not same_column:
			continue

		var distance: int = (
			abs(difference.x)
			+ abs(difference.y)
		)

		if distance > detection_range:
			continue

		if not has_clear_line_to(
			character.grid_position
		):
			continue

		if distance < nearest_distance:
			nearest = character
			nearest_distance = distance

	return nearest


# ==================================================
# LINE OF SIGHT
# ==================================================

func has_clear_line_to(
	target_cell: Vector2i
) -> bool:
	var direction: Vector2i = (
		get_direction_to_cell(
			target_cell
		)
	)

	if direction == Vector2i.ZERO:
		return false

	var check_cell: Vector2i = (
		grid_position + direction
	)

	while check_cell != target_cell:
		if board.is_occupied(
			check_cell
		):
			return false

		check_cell += direction

	return true


# ==================================================
# DIRECTION
# ==================================================

func get_direction_to_cell(
	target_cell: Vector2i
) -> Vector2i:
	var difference: Vector2i = (
		target_cell - grid_position
	)

	if (
		difference.x > 0
		and difference.y == 0
	):
		return Vector2i.RIGHT

	if (
		difference.x < 0
		and difference.y == 0
	):
		return Vector2i.LEFT

	if (
		difference.y > 0
		and difference.x == 0
	):
		return Vector2i.DOWN

	if (
		difference.y < 0
		and difference.x == 0
	):
		return Vector2i.UP

	return Vector2i.ZERO


# ==================================================
# CHARGE ATTACK
# ==================================================

func perform_charge(
	direction: Vector2i
) -> void:
	if direction == Vector2i.ZERO:
		return

	update_facing(
		direction
	)


	# ==================================================
	# SAVE VISUAL START
	# ==================================================

	var charge_start_visual_position: Vector2 = (
		sprite.global_position
	)

	var moved_steps: int = 0


	# ==================================================
	# LOGICAL CHARGE
	# ==================================================

	for step in range(
		detection_range
	):
		var next_cell: Vector2i = (
			grid_position + direction
		)

		var target_object = board.get_object_at(
			next_cell
		)


		# ==================================================
		# EMPTY CELL
		# ==================================================

		if target_object == null:
			var moved: bool = (
				move_enemy(
					direction
				)
			)

			if not moved:
				break

			moved_steps += 1

			continue


		# ==================================================
		# CHARACTER HIT
		# ==================================================

		if target_object is GridCharacter:
			var character := (
				target_object
				as GridCharacter
			)

			if character.is_alive:
				print(
					"CHARGER HIT | ",
					name,
					" → ",
					character.name
				)

				var defeated: bool = (
					character.defeat()
				)

				if defeated:
					# Character sudah keluar
					# dari occupancy Board.
					#
					# Charger masuk ke cell-nya.
					var entered_cell: bool = (
						move_enemy(
							direction
						)
					)

					if entered_cell:
						moved_steps += 1

			# Serangan berhenti setelah impact.
			break


		# ==================================================
		# BLOCKER
		# ==================================================

		print(
			"CHARGER IMPACT | ",
			name,
			" | ",
			next_cell
		)

		break


	# ==================================================
	# PLAY VISUAL AFTER LOGIC IS FINISHED
	# ==================================================

	if moved_steps > 0:
		_play_charge_visual(
			charge_start_visual_position,
			moved_steps
		)


	print(
		"CHARGER STOP | ",
		name,
		" | Cell: ",
		grid_position
	)


# ==================================================
# CHARGE VISUAL
# ==================================================

func _play_charge_visual(
	start_visual_position: Vector2,
	moved_steps: int
) -> void:
	if sprite == null:
		return

	var target_visual_position: Vector2 = (
		sprite.global_position
	)

	if move_tween:
		move_tween.kill()


	# Logical root sudah berada di final cell.
	#
	# Sprite saja kita kembalikan ke titik awal.
	sprite.global_position = (
		start_visual_position
	)


	charge_visual_active = true

	charge_trail_timer = 0.0


	# Ghost pertama.
	create_motion_afterimage()


	var duration: float = (
		CHARGE_VISUAL_STEP_DURATION
		* float(moved_steps)
	)

	# Jangan sampai animasi terlalu singkat.
	duration = max(
		duration,
		0.07
	)


	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	move_tween.tween_property(
		sprite,
		"global_position",
		target_visual_position,
		duration
	).set_trans(
		Tween.TRANS_LINEAR
	)

	move_tween.finished.connect(
		_on_charge_visual_finished
	)


func _on_charge_visual_finished() -> void:
	charge_visual_active = false

	# Pastikan visual benar-benar menyatu
	# dengan root di akhir charge.
	if sprite != null:
		sprite.position = (
			sprite_home_position
		)


# ==================================================
# SNAP / UNDO
# ==================================================

func snap_to_cell(
	cell: Vector2i
) -> void:
	charge_visual_active = false

	super.snap_to_cell(
		cell
	)


# ==================================================
# DEATH
# ==================================================

func defeat() -> bool:
	var defeated: bool = (
		super.defeat()
	)

	if defeated:
		charge_visual_active = false

	return defeated


# ==================================================
# UNDO CHARGE STATE
# ==================================================

func save_charge_state_undo() -> void:
	board.append_action_to_current_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_charge_state"
		),

		"data": {
			"is_charging":
				is_charging,

			"charge_turn_counter":
				charge_turn_counter,

			"charge_direction":
				charge_direction
		}
	})


func _undo_charge_state(
	data: Dictionary
) -> void:
	is_charging = data[
		"is_charging"
	]

	charge_turn_counter = data[
		"charge_turn_counter"
	]

	charge_direction = data[
		"charge_direction"
	]

	charge_visual_active = false

	if move_tween:
		move_tween.kill()

	if sprite != null:
		sprite.position = (
			sprite_home_position
		)

	# Saat kembali ke charging state,
	# hadapkan sprite ke arah charge.
	if (
		is_charging
		and charge_direction
		!= Vector2i.ZERO
	):
		update_facing(
			charge_direction
		)


	print(
		"UNDO CHARGER STATE | ",
		name,
		" | Charging: ",
		is_charging,
		" | Counter: ",
		charge_turn_counter
	)

class_name ChargerEnemy
extends GridEnemy


# ==================================================
# CHARGER SETTINGS
# ==================================================

@export_group("Charger Settings")


# Seberapa jauh Charger bisa melihat Character
# dalam satu garis lurus.
#
# Contoh:
# 4 = pendek
# 6 = normal
# 10 = jauh
@export_range(1, 20, 1)
var detection_range: int = 6


# Berapa turn Charger menunggu setelah
# mendeteksi Character sebelum menyerang.
#
# Contoh:
# 1 = cepat
# 2 = normal / recommended
# 3 = lebih mudah dihindari
@export_range(1, 5, 1)
var charge_delay_turns: int = 2


# ==================================================
# RUNTIME DATA
# ==================================================

# Apakah Charger sedang mempersiapkan serangan.
var is_charging: bool = false


# Berapa turn charging yang sudah dilewati.
var charge_turn_counter: int = 0


# Arah serangan yang dikunci saat
# Character pertama kali terdeteksi.
#
# Player boleh bergerak setelah itu,
# tetapi Charger tetap menyerang arah lama.
var charge_direction: Vector2i = Vector2i.ZERO


# ==================================================
# ENEMY TURN
# ==================================================

func take_turn() -> void:
	if board == null:
		return

	# Kalau sudah charging,
	# lanjutkan countdown.
	if is_charging:
		continue_charging()
		return

	# Belum charging:
	# cari Character dalam satu garis lurus.
	var target: GridCharacter = (
		find_visible_character()
	)

	# Tidak melihat Character.
	if target == null:
		print(
			"CHARGER IDLE | ",
			name
		)
		return

	# Character terlihat.
	# Mulai charging dan kunci arah.
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

	# Simpan state sebelum berubah
	# supaya Undo bisa membatalkan charging.
	save_charge_state_undo()

	is_charging = true
	charge_turn_counter = 0

	# Arah dikunci SEKARANG.
	#
	# Misalnya target berada di kanan:
	#
	# E . . C
	#
	# walaupun C kemudian bergerak ke atas,
	# Charger tetap menyerang ke kanan.
	charge_direction = direction

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
	# Simpan state sebelum counter berubah.
	save_charge_state_undo()

	charge_turn_counter += 1

	# Belum selesai charging.
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


	# ==================================================
	# CHARGE READY
	# ==================================================

	# Simpan arah serangan sebelum
	# state Charging dibersihkan.
	var attack_direction: Vector2i = (
		charge_direction
	)

	is_charging = false
	charge_turn_counter = 0
	charge_direction = Vector2i.ZERO

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

# Mencari Character yang:
#
# - berada satu garis horizontal / vertical
# - berada dalam detection_range
# - masih terdaftar di Board
# - tidak ada blocker di tengah
#
# Kalau ada beberapa Character,
# pilih yang paling dekat.
func find_visible_character() -> GridCharacter:
	var nearest: GridCharacter = null
	var nearest_distance: int = 999999

	for node in get_tree().get_nodes_in_group(
		"characters"
	):
		if not node is GridCharacter:
			continue

		var character := node as GridCharacter

		# Harus memakai Board yang sama.
		if character.board != board:
			continue

		# Character harus benar-benar masih
		# berada dalam occupancy Board.
		#
		# Ini penting untuk Character yang:
		# - sudah transform
		# - nanti mati
		# - sedang tidak berada di arena
		if board.get_object_at(
			character.grid_position
		) != character:
			continue

		var difference: Vector2i = (
			character.grid_position
			- grid_position
		)

		# Charger hanya mendeteksi:
		#
		# ↑
		# ↓
		# ←
		# →
		#
		# Bukan diagonal.
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

		# Target terlalu jauh.
		if distance > detection_range:
			continue

		# Ada blocker di tengah.
		if not has_clear_line_to(
			character.grid_position
		):
			continue

		# Ambil Character terdekat.
		if distance < nearest_distance:
			nearest = character
			nearest_distance = distance

	return nearest


# ==================================================
# LINE OF SIGHT
# ==================================================

# Mengecek cell DI ANTARA Charger dan target.
#
# Cell Character target sendiri tidak dihitung
# sebagai blocker.
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
		# Wall, Box, Door tertutup,
		# Character lain, Enemy lain, dll
		# memutus line of sight.
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

	if difference.x > 0 and difference.y == 0:
		return Vector2i.RIGHT

	if difference.x < 0 and difference.y == 0:
		return Vector2i.LEFT

	if difference.y > 0 and difference.x == 0:
		return Vector2i.DOWN

	if difference.y < 0 and difference.x == 0:
		return Vector2i.UP

	return Vector2i.ZERO


# ==================================================
# CHARGE ATTACK
# ==================================================

# Charger bergerak lurus dalam arah yang
# sudah dikunci ketika mulai charging.
#
# Untuk SEKARANG:
# semua occupant Board masih menjadi blocker.
#
# Jadi kalau Character ada di depannya:
# Charger berhenti tepat sebelum Character.
#
# Nanti saat Character Death System kita pasang,
# bagian ini akan kita upgrade supaya Charger
# benar-benar bisa menabrak / membunuh Character.
func perform_charge(
	direction: Vector2i
) -> void:
	if direction == Vector2i.ZERO:
		return

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
			var moved: bool = move_enemy(
				direction
			)

			if not moved:
				break

			continue


		# ==================================================
		# CHARACTER HIT
		# ==================================================

		if target_object is GridCharacter:
			var character := (
				target_object as GridCharacter
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
					# Masuk cell bekas Character.
					move_enemy(
						direction
					)

			# Setelah menghantam Character,
			# Charger langsung berhenti.
			break


		# ==================================================
		# WALL / BOX / DOOR / ENEMY
		# ==================================================

		print(
			"CHARGER IMPACT | ",
			name,
			" | ",
			next_cell
		)

		break


	print(
		"CHARGER STOP | ",
		name,
		" | Cell: ",
		grid_position
	)


# ==================================================
# UNDO CHARGE STATE
# ==================================================

# Menyimpan state Charger dalam current turn.
#
# Jadi Z bukan cuma mengembalikan posisi,
# tetapi juga:
#
# charging / tidak
# counter
# arah yang dikunci
func save_charge_state_undo() -> void:
	board.append_action_to_current_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_charge_state"
		),

		"data": {
			"is_charging": is_charging,
			"charge_turn_counter": charge_turn_counter,
			"charge_direction": charge_direction
		}
	})


# Mengembalikan state Charging
# sebelum Player turn tadi.
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

	print(
		"UNDO CHARGER STATE | ",
		name,
		" | Charging: ",
		is_charging,
		" | Counter: ",
		charge_turn_counter
	)

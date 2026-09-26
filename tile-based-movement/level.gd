extends Node2D


# ==================================================
# EXPORTED REFERENCES
# ==================================================

@export var nectar_label: Label

@export var level_complete_label: Label

@export var butterfly_scene: PackedScene


# ==================================================
# CHARACTER CONTROLLER
# ==================================================

var characters: Array[GridCharacter] = []

# -1 berarti tidak ada Character hidup
# yang sedang aktif.
var active_character_index: int = -1


# ==================================================
# LEVEL STATE
# ==================================================

var is_level_complete: bool = false


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	AudioManager.play_stage_bgm()
	print(
		"=== SCENE YANG JALAN: ",
		get_tree().current_scene.scene_file_path,
		" ==="
	)
	collect_characters()

	connect_hazards()

	validate_nectar_count()

	update_nectar_ui(0)

	update_hazard_nectar(0)

	if level_complete_label != null:
		level_complete_label.visible = false


# ==================================================
# CHARACTER COLLECTION
# ==================================================
func _process(
	_delta: float
) -> void:
	if is_level_complete:
		return

	# Kalau Character aktif mati,
	# otomatis cari Character hidup lain.
	if (
		active_character_index >= 0
		and active_character_index < characters.size()
	):
		var current := characters[
			active_character_index
		]

		if (
			not is_instance_valid(current)
			or not current.is_alive
		):
			ensure_active_character()

	else:
		# Misalnya semua Character sebelumnya mati
		# lalu salah satunya hidup karena Undo.
		ensure_active_character()
		
func collect_characters() -> void:
	characters.clear()

	for node in get_tree().get_nodes_in_group(
		"characters"
	):
		if node is GridCharacter:
			characters.append(
				node as GridCharacter
			)

	if characters.is_empty():
		active_character_index = -1

		push_warning(
			"Level tidak menemukan GridCharacter!"
		)

		return


	# ==================================================
	# FORCE ALL INACTIVE
	# ==================================================

	# Ini menjamin tidak mungkin dua Character
	# aktif bersamaan saat level mulai.
	for character in characters:
		if not is_instance_valid(
			character
		):
			continue

		character.set_active(
			false
		)


	# ==================================================
	# ACTIVATE FIRST ALIVE CHARACTER
	# ==================================================

	active_character_index = -1

	for i in range(
		characters.size()
	):
		var character := characters[i]

		if not is_instance_valid(
			character
		):
			continue

		if not character.is_alive:
			continue

		activate_character_at(
			i
		)

		break

	print(
		"Characters found: ",
		characters.size()
	)




# ==================================================
# GLOBAL INPUT
# ==================================================

func _unhandled_input(
	event: InputEvent
) -> void:
	# ==================================================
	# RESET
	# ==================================================

	# R selalu boleh digunakan.
	if event.is_action_pressed(
		"reset_level"
	):
		reset_level()
		return


	# Gameplay dikunci setelah level selesai.
	if is_level_complete:
		return


	# ==================================================
	# GLOBAL UNDO
	# ==================================================

	# Undo sekarang ada di Level.
	#
	# Jadi walaupun:
	# - Character aktif mati
	# - semua Character mati
	#
	# Z tetap bekerja.
	if event.is_action_pressed(
		"undo"
	):
		# Jangan Undo saat visual movement
		# masih berjalan.
		if is_any_character_moving():
			return

		var level_board: Board = (
			get_level_board()
		)

		if level_board != null:
			level_board.undo_last_turn()

			# Pastikan setelah Undo ada
			# selection yang valid.
			ensure_active_character()

		get_viewport().set_input_as_handled()
		return


	# ==================================================
	# SWITCH CHARACTER
	# ==================================================

	if event.is_action_pressed(
		"switch_next"
	):
		switch_character(
			1
		)
		return

	if event.is_action_pressed(
		"switch_previous"
	):
		switch_character(
			-1
		)
		return


# ==================================================
# GLOBAL BOARD
# ==================================================

func get_level_board() -> Board:
	for character in characters:
		if not is_instance_valid(
			character
		):
			continue

		if character.board != null:
			return character.board

	return null


# ==================================================
# MOVEMENT STATE
# ==================================================

func is_any_character_moving() -> bool:
	for character in characters:
		if not is_instance_valid(
			character
		):
			continue

		if not character.is_alive:
			continue

		if character.is_moving():
			return true

	return false


# ==================================================
# CHARACTER ACTIVATION
# ==================================================

func activate_character_at(
	index: int
) -> bool:
	if index < 0:
		return false

	if index >= characters.size():
		return false

	var target := characters[index]

	if not is_instance_valid(
		target
	):
		return false

	if not target.is_alive:
		return false


	# ==================================================
	# MATIKAN SEMUA CHARACTER
	# ==================================================

	for character in characters:
		if not is_instance_valid(
			character
		):
			continue

		character.set_active(
			false
		)


	# ==================================================
	# AKTIFKAN CUMA SATU
	# ==================================================

	active_character_index = index

	target.set_active(
		true
	)

	print(
		"ONLY ACTIVE CHARACTER: ",
		target.name
	)

	return true


func ensure_active_character() -> void:
	# ==================================================
	# FIND ALL ACTIVE + ALIVE CHARACTERS
	# ==================================================

	var active_indices: Array[int] = []

	for i in range(
		characters.size()
	):
		var character := characters[i]

		if not is_instance_valid(
			character
		):
			continue

		if not character.is_alive:
			continue

		if character.is_active:
			active_indices.append(
				i
			)


	# ==================================================
	# THERE IS AT LEAST ONE ACTIVE CHARACTER
	# ==================================================

	if not active_indices.is_empty():
		var chosen_index: int = (
			active_indices[0]
		)

		# Kalau index Level sekarang masih termasuk
		# Character aktif yang valid, pertahankan dia.
		if active_indices.has(
			active_character_index
		):
			chosen_index = (
				active_character_index
			)

		# PENTING:
		# activate_character_at() mematikan SEMUA dulu,
		# baru menyalakan satu Character.
		#
		# Jadi kalau bug membuat 2 Character aktif,
		# kondisi itu langsung dibersihkan.
		activate_character_at(
			chosen_index
		)

		return


	# ==================================================
	# NO ACTIVE CHARACTER
	# ==================================================

	# Misalnya Character aktif baru saja mati.
	# Cari Character hidup pertama.
	for i in range(
		characters.size()
	):
		var character := characters[i]

		if not is_instance_valid(
			character
		):
			continue

		if not character.is_alive:
			continue

		activate_character_at(
			i
		)

		return


	# ==================================================
	# EVERY CHARACTER IS DEAD
	# ==================================================

	active_character_index = -1

	

# ==================================================
# SWITCH CHARACTER
# ==================================================

func switch_character(
	direction: int
) -> void:
	if characters.is_empty():
		return

	if direction == 0:
		return

	# Jangan switch ketika Character aktif
	# sedang bergerak.
	if (
		active_character_index >= 0
		and active_character_index < characters.size()
	):
		var current := characters[
			active_character_index
		]

		if (
			is_instance_valid(current)
			and current.is_alive
			and current.is_moving()
		):
			return


	var start_index: int = (
		active_character_index
	)

	# Kalau semua sempat mati dan index = -1,
	# tentukan starting point berdasarkan arah.
	if start_index < 0:
		if direction > 0:
			start_index = -1
		else:
			start_index = 0


	# Cari Character hidup berikutnya.
	for step in range(
		1,
		characters.size() + 1
	):
		var candidate_index: int = posmod(
			start_index
			+ direction * step,
			characters.size()
		)

		var candidate := characters[
			candidate_index
		]

		if not is_instance_valid(
			candidate
		):
			continue

		# Character mati tidak termasuk slot Q/E.
		if not candidate.is_alive:
			continue

		activate_character_at(
			candidate_index
		)

		return

	# Tidak ada Character hidup.
	active_character_index = -1


# ==================================================
# RESET
# ==================================================

func reset_level() -> void:
	get_tree().reload_current_scene()


# ==================================================
# NECTAR VALIDATION
# ==================================================

func validate_nectar_count() -> void:
	var nectars := get_tree().get_nodes_in_group(
		"nectars"
	)

	print(
		"Nectar in level: ",
		nectars.size(),
		"/3"
	)

	if nectars.size() != 3:
		push_warning(
			"Level harus memiliki tepat 3 Nectar! Sekarang ada %d."
			% nectars.size()
		)


# ==================================================
# NECTAR UI
# ==================================================

func update_nectar_ui(
	current: int,
	maximum: int = ButterflyCharacter.MAX_NECTAR
) -> void:
	if nectar_label == null:
		return

	nectar_label.text = (
		"Nectar: %d/%d"
		% [
			current,
			maximum
		]
	)


# ==================================================
# COCOON
# ==================================================

func _on_cocoon_caterpillar_entered(
	caterpillar: CaterpillarCharacter,
	cocoon: Cocoon
) -> void:
	call_deferred(
		"transform_caterpillar",
		caterpillar,
		cocoon
	)


func transform_caterpillar(
	caterpillar: CaterpillarCharacter,
	cocoon: Cocoon
) -> void:
	if butterfly_scene == null:
		push_error(
			"Level belum memiliki Butterfly Scene!"
		)
		return

	if not is_instance_valid(
		caterpillar
	):
		return

	var character_index: int = (
		characters.find(
			caterpillar
		)
	)

	if character_index == -1:
		push_error(
			"Caterpillar tidak ditemukan dalam character list!"
		)
		return

	var character_board: Board = (
		caterpillar.board
	)

	var cell: Vector2i = (
		caterpillar.grid_position
	)

	var should_be_active: bool = (
		caterpillar.is_active
	)


	# ==================================================
	# CREATE BUTTERFLY
	# ==================================================

	var new_node := (
		butterfly_scene.instantiate()
	)

	if not (
		new_node is ButterflyCharacter
	):
		push_error(
			"Root butterfly.tscn bukan ButterflyCharacter!"
		)

		new_node.free()
		return

	var butterfly := (
		new_node as ButterflyCharacter
	)


	# ==================================================
	# REMOVE CATERPILLAR
	# ==================================================

	if not character_board.unregister_object(
		cell,
		caterpillar
	):
		push_error(
			"Gagal menghapus Caterpillar dari Board!"
		)

		butterfly.free()
		return

	caterpillar.set_active(
		false
	)

	caterpillar.remove_from_group(
		"characters"
	)

	caterpillar.visible = false

	var caterpillar_collision := (
		caterpillar.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
	)

	if caterpillar_collision:
		caterpillar_collision.disabled = true


	# ==================================================
	# CREATE BUTTERFLY
	# ==================================================

	butterfly.board = (
		character_board
	)

	butterfly.is_active = false

	butterfly.position = to_local(
		character_board.grid_to_world(
			cell
		)
	)

	add_child(
		butterfly
	)

	butterfly.nectar_changed.connect(
		_on_butterfly_nectar_changed
	)

	update_nectar_ui(
		butterfly.get_nectar_count()
	)

	update_hazard_nectar(
		butterfly.get_nectar_count()
	)

	cocoon.deactivate_cocoon()

	characters[
		character_index
	] = butterfly

	if should_be_active:
		activate_character_at(
			character_index
		)
	else:
		butterfly.set_active(
			false
		)

	print(
		"TRANSFORM: ",
		caterpillar.name,
		" -> ",
		butterfly.name,
		" | Cell: ",
		cell
	)


	# ==================================================
	# TRANSFORM UNDO
	# ==================================================

	character_board.append_action_to_last_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_transformation"
		),

		"data": {
			"caterpillar": caterpillar,
			"butterfly": butterfly,
			"cocoon": cocoon,
			"cell": cell,
			"character_index": character_index
		}
	})


# ==================================================
# UNDO TRANSFORMATION
# ==================================================

func _undo_transformation(
	data: Dictionary
) -> void:
	var caterpillar := (
		data["caterpillar"]
		as CaterpillarCharacter
	)

	var butterfly := (
		data["butterfly"]
		as ButterflyCharacter
	)

	var cocoon := (
		data["cocoon"]
		as Cocoon
	)

	var cell: Vector2i = (
		data["cell"]
	)

	var character_index: int = (
		data["character_index"]
	)

	if not is_instance_valid(
		caterpillar
	):
		return

	var character_board: Board = (
		caterpillar.board
	)

	var butterfly_was_active: bool = false

	if is_instance_valid(
		butterfly
	):
		butterfly_was_active = (
			butterfly.is_active
		)

		character_board.unregister_object(
			cell,
			butterfly
		)

		butterfly.set_active(
			false
		)

		butterfly.remove_from_group(
			"characters"
		)

		butterfly.queue_free()


	caterpillar.visible = true

	caterpillar.add_to_group(
		"characters"
	)

	var caterpillar_collision := (
		caterpillar.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
	)

	if caterpillar_collision:
		caterpillar_collision.disabled = false

	character_board.register_object(
		cell,
		caterpillar
	)

	if (
		character_index >= 0
		and character_index < characters.size()
	):
		characters[
			character_index
		] = caterpillar

	if butterfly_was_active:
		activate_character_at(
			character_index
		)
	else:
		caterpillar.set_active(
			false
		)

	if is_instance_valid(
		cocoon
	):
		cocoon.call_deferred(
			"activate_cocoon"
		)

	update_nectar_ui(
		0
	)

	update_hazard_nectar(
		0
	)

	print(
		"UNDO TRANSFORM: Butterfly -> Caterpillar"
	)


# ==================================================
# BUTTERFLY NECTAR
# ==================================================

func _on_butterfly_nectar_changed(
	current: int,
	maximum: int
) -> void:
	AudioManager.play_nectar()
	update_nectar_ui(
		current,
		maximum
	)

	update_hazard_nectar(
		current
	)


# ==================================================
# GOAL
# ==================================================

func _on_goal_puzzle_completed(
	butterfly: ButterflyCharacter
) -> void:
	complete_level(
		butterfly
	)


func complete_level(
	butterfly: ButterflyCharacter
) -> void:
	if is_level_complete:
		return

	is_level_complete = true
	AudioManager.play_win()

	for character in characters:
		if is_instance_valid(
			character
		):
			character.set_active(
				false
			)

	if level_complete_label != null:
		level_complete_label.text = (
			"LEVEL COMPLETE!"
		)

		level_complete_label.visible = true

	else:
		push_warning(
			"LevelCompleteLabel belum dihubungkan!"
		)

	print(
		"LEVEL COMPLETE | Butterfly Nectar: ",
		butterfly.get_nectar_count(),
		"/",
		ButterflyCharacter.MAX_NECTAR
	)
		# Tampilkan kemenangan sebentar.
	await get_tree().create_timer(
		1.0
	).timeout

	# Lanjut ke level berikutnya.
	LevelFlow.go_to_next_level()


# ==================================================
# OLD PLACEHOLDERS
# ==================================================

func _on_pressure_plate_activated() -> void:
	pass


func open_door() -> void:
	pass


# ==================================================
# HAZARDS
# ==================================================

func connect_hazards() -> void:
	for node in get_tree().get_nodes_in_group(
		"hazards"
	):
		if not node is BaseHazard:
			continue

		var hazard := (
			node as BaseHazard
		)

		if not hazard.triggered.is_connected(
			_on_hazard_triggered
		):
			hazard.triggered.connect(
				_on_hazard_triggered
			)


func update_hazard_nectar(
	current: int
) -> void:
	for node in get_tree().get_nodes_in_group(
		"hazards"
	):
		if node is BaseHazard:
			var hazard := (
				node as BaseHazard
			)

			hazard.set_nectar_count(
				current
			)


func _on_hazard_triggered(
	object: Node2D,
	hazard: BaseHazard
) -> void:
	if not is_instance_valid(
		object
	):
		return

	if not object.is_in_group(
		"hazard_vulnerable"
	):
		return

	# Flying Butterfly aman dari Pit.
	if (
		hazard.is_in_group("pit_hazard")
		and object is GridCharacter
	):
		var character := (
			object as GridCharacter
		)

		if character.can_cross_pit():
			return

	if not object.has_method(
		"defeat"
	):
		return

	print(
		"HAZARD HIT | ",
		object.name,
		" terkena ",
		hazard.name
	)

	object.call(
		"defeat"
	)

class_name LevelAuthoring
extends Node


# ==================================================
# SETTINGS
# ==================================================

@export var board_path: NodePath = NodePath("../Board")

@export var gameplay_folder_names: Array[StringName] = [
	&"Characters",
	&"Enemies",
	&"Objects",
	&"Hazards",
	&"Collectibles"
]

@export var auto_assign_board: bool = true
@export var auto_snap_to_grid: bool = true
@export var validate_level: bool = true


# ==================================================
# RUNTIME
# ==================================================

var board: Board


# ==================================================
# ENTER TREE
# ==================================================

func _enter_tree() -> void:
	board = get_node_or_null(
		board_path
	) as Board

	if board == null:
		push_error(
			"AUTHORING ERROR: Board tidak ditemukan!"
		)
		return


	# Auto isi Board semua gameplay object.
	if auto_assign_board:
		_assign_board_recursive(
			get_parent()
		)


	# Auto snap scene gameplay ke grid.
	if auto_snap_to_grid:
		_snap_gameplay_objects()


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	if validate_level:
		call_deferred(
			"_validate_level"
		)


# ==================================================
# AUTO BOARD
# ==================================================

func _assign_board_recursive(
	node: Node
) -> void:
	if node == null:
		return

	if (
		node != board
		and _has_property(
			node,
			&"board"
		)
	):
		node.set(
			&"board",
			board
		)

		print(
			"AUTO BOARD | ",
			node.name
		)

	for child in node.get_children():
		_assign_board_recursive(
			child
		)


# ==================================================
# PROPERTY CHECK
# ==================================================

func _has_property(
	object: Object,
	property_name: StringName
) -> bool:
	for property in object.get_property_list():

		var current_name := StringName(
			property.get(
				"name",
				""
			)
		)

		if current_name == property_name:
			return true

	return false


# ==================================================
# AUTO SNAP
# ==================================================

func _snap_gameplay_objects() -> void:
	if board == null:
		return

	var level := get_parent()

	if level == null:
		return


	for folder_name in gameplay_folder_names:

		var folder := level.get_node_or_null(
			NodePath(
				String(folder_name)
			)
		)

		if folder == null:
			continue


		for child in folder.get_children():

			if not (
				child is Node2D
			):
				continue


			var object := child as Node2D

			var old_position: Vector2 = (
				object.global_position
			)

			var cell: Vector2i = (
				board.world_to_grid(
					old_position
				)
			)

			var snapped_position: Vector2 = (
				board.grid_to_world(
					cell
				)
			)


			if (
				old_position.distance_to(
					snapped_position
				)
				> 0.1
			):
				push_warning(
					"AUTO SNAP | %s | %s -> %s"
					% [
						object.name,
						old_position,
						snapped_position
					]
				)


			object.global_position = (
				snapped_position
			)


# ==================================================
# VALIDATOR
# ==================================================

func _validate_level() -> void:
	if board == null:
		return

	print("")
	print("================================")
	print("LEVEL VALIDATION")
	print("================================")


	_validate_folders()
	_validate_characters()
	_validate_enemies()
	_validate_nectars()

	_validate_board_recursive(
		get_parent()
	)


	print("--------------------------------")
	print("VALIDATION FINISHED")
	print("================================")
	print("")


# ==================================================
# FOLDER VALIDATION
# ==================================================

func _validate_folders() -> void:
	var level := get_parent()

	if level == null:
		return


	for folder_name in gameplay_folder_names:

		if not level.has_node(
			NodePath(
				String(folder_name)
			)
		):
			push_warning(
				"MISSING FOLDER | "
				+ String(folder_name)
			)


# ==================================================
# CHARACTER VALIDATION
# ==================================================

func _validate_characters() -> void:
	var characters := (
		get_tree().get_nodes_in_group(
			"characters"
		)
	)

	print(
		"Characters placed: ",
		characters.size()
	)


	# Tidak ada Character = level tidak playable.
	if characters.is_empty():
		push_warning(
			"LEVEL WARNING: Tidak ada Character."
		)


	# Tidak ada Character Count manual.
	# Jumlah Character selalu berasal dari
	# Character yang benar-benar kamu drag.
	for character in characters:

		if not (
			character is GridCharacter
		):
			push_warning(
				"INVALID CHARACTER | "
				+ character.name
			)


# ==================================================
# ENEMY VALIDATION
# ==================================================

func _validate_enemies() -> void:
	var enemies := (
		get_tree().get_nodes_in_group(
			"enemies"
		)
	)

	print(
		"Enemies placed: ",
		enemies.size()
	)


	for enemy in enemies:

		if not (
			enemy is GridEnemy
		):
			push_warning(
				"INVALID ENEMY | "
				+ enemy.name
			)


# ==================================================
# NECTAR VALIDATION
# ==================================================

func _validate_nectars() -> void:
	var nectars := (
		get_tree().get_nodes_in_group(
			"nectars"
		)
	)

	print(
		"Nectars placed: ",
		nectars.size()
	)


	# Sistem objective kita sekarang memakai 3 Nectar.
	if nectars.size() != 3:
		push_warning(
			"NECTAR WARNING | Ada %d Nectar, seharusnya 3."
			% nectars.size()
		)


# ==================================================
# BOARD VALIDATION
# ==================================================

func _validate_board_recursive(
	node: Node
) -> void:
	if node == null:
		return


	if (
		node != board
		and _has_property(
			node,
			&"board"
		)
	):

		var assigned_board = node.get(
			&"board"
		)


		if assigned_board == null:
			push_warning(
				"BOARD MISSING | "
				+ node.name
			)

		elif assigned_board != board:
			push_warning(
				"WRONG BOARD | "
				+ node.name
			)


	for child in node.get_children():
		_validate_board_recursive(
			child
		)

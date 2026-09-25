class_name BaseHazard
extends Node2D


# ==================================================
# ACTIVATION MODE
# ==================================================

enum ActivationMode {
	ALWAYS,
	PRESSURE_PLATES,
	NECTAR
}


# Sekarang generic:
# Character maupun Enemy boleh dikirim.
signal triggered(
	object: Node2D,
	hazard: BaseHazard
)

signal activation_changed(
	active: bool
)


# ==================================================
# CORE
# ==================================================

@export_group("Core")

@export var board: Board


# ==================================================
# ACTIVATION
# ==================================================

@export_group("Activation")

@export var activation_mode: ActivationMode = (
	ActivationMode.ALWAYS
)

@export var invert_activation: bool = false

@export var hide_when_inactive: bool = true


# ==================================================
# PRESSURE PLATE
# ==================================================

@export_group("Pressure Plate Settings")

@export var trigger_plates: Array[PressurePlate] = []

@export_range(1, 16, 1)
var required_plates: int = 1


# ==================================================
# NECTAR
# ==================================================

@export_group("Nectar Settings")

@export_range(1, 3, 1)
var required_nectar: int = 1


# ==================================================
# RUNTIME
# ==================================================

var grid_position: Vector2i

var is_active: bool = false

var current_nectar: int = 0


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	add_to_group("hazards")

	if board == null:
		push_error(
			"%s belum terhubung ke Board!"
			% name
		)
		return

	grid_position = board.world_to_grid(
		global_position
	)

	global_position = board.grid_to_world(
		grid_position
	)

	connect_trigger_plates()

	validate_activation_setup()

	call_deferred(
		"evaluate_activation"
	)


# ==================================================
# PRESSURE PLATES
# ==================================================

func connect_trigger_plates() -> void:
	for plate in trigger_plates:
		if plate == null:
			continue

		if not plate.activated.is_connected(
			_on_activation_source_changed
		):
			plate.activated.connect(
				_on_activation_source_changed
			)

		if not plate.deactivated.is_connected(
			_on_activation_source_changed
		):
			plate.deactivated.connect(
				_on_activation_source_changed
			)


func _on_activation_source_changed() -> void:
	evaluate_activation()


func get_active_plate_count() -> int:
	var active_count: int = 0

	for plate in trigger_plates:
		if plate == null:
			continue

		if plate.is_pressed:
			active_count += 1

	return active_count


func plates_requirement_met() -> bool:
	if trigger_plates.is_empty():
		return false

	return (
		get_active_plate_count()
		>= required_plates
	)


# ==================================================
# NECTAR
# ==================================================

func set_nectar_count(
	value: int
) -> void:
	current_nectar = maxi(
		value,
		0
	)

	if activation_mode == ActivationMode.NECTAR:
		evaluate_activation()


# ==================================================
# ACTIVATION
# ==================================================

func evaluate_activation() -> void:
	var requirement_met: bool = false

	match activation_mode:
		ActivationMode.ALWAYS:
			requirement_met = true

		ActivationMode.PRESSURE_PLATES:
			requirement_met = (
				plates_requirement_met()
			)

		ActivationMode.NECTAR:
			requirement_met = (
				current_nectar
				>= required_nectar
			)

	var should_be_active: bool = (
		requirement_met
	)

	if invert_activation:
		should_be_active = (
			not requirement_met
		)

	set_hazard_active(
		should_be_active
	)


func set_hazard_active(
	value: bool
) -> void:
	var state_changed: bool = (
		is_active != value
	)

	is_active = value

	if hide_when_inactive:
		visible = is_active
	else:
		visible = true

	if not state_changed:
		return

	print(
		name,
		" | Hazard active = ",
		is_active
	)

	activation_changed.emit(
		is_active
	)

	_on_hazard_state_changed(
		is_active
	)


func _on_hazard_state_changed(
	_active: bool
) -> void:
	pass


# ==================================================
# HAZARD TRIGGER
# ==================================================

# Generic:
# Character dan Enemy sama-sama bisa terkena.
func trigger_object(
	object: Node2D
) -> void:
	if not is_active:
		return

	if object == null:
		return

	if not object.is_in_group(
		"hazard_vulnerable"
	):
		return

	if not object.has_method(
		"defeat"
	):
		return

	triggered.emit(
		object,
		self
	)


# Compatibility untuk Pit lama.
# Pit yang masih memanggil trigger_character()
# tetap bekerja.
func trigger_character(
	character: GridCharacter
) -> void:
	trigger_object(
		character
	)


# ==================================================
# VALIDATION
# ==================================================

func validate_activation_setup() -> void:
	if (
		activation_mode
		== ActivationMode.PRESSURE_PLATES
	):
		if trigger_plates.is_empty():
			push_warning(
				"%s memakai Pressure Plate tetapi "
				% name
				+ "Trigger Plates masih kosong."
			)

		elif (
			required_plates
			> trigger_plates.size()
		):
			push_warning(
				"%s membutuhkan %d Plate, "
				% [
					name,
					required_plates
				]
				+ "tetapi hanya memiliki %d Trigger Plate."
				% trigger_plates.size()
			)

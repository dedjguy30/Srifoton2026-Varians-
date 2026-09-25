@tool
extends EditorScript


func _run() -> void:
	var path := "res://levels/level_05.tscn"

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error("LEVEL05 | File tidak bisa dibuka.")
		return

	var text := file.get_as_text()
	file.close()

	var lines := text.split("\n")

	print("")
	print("====================================")
	print("DIAGNOSE LEVEL 05")
	print("====================================")

	var problem_found := false


	# ==================================================
	# 1. CEK MERGE CONFLICT
	# ==================================================

	for i in range(lines.size()):
		var line: String = lines[i]

		if (
			line.begins_with("<<<<<<<")
			or line.begins_with("=======")
			or line.begins_with(">>>>>>>")
		):
			problem_found = true

			print(
				"MERGE CONFLICT | Line ",
				i + 1,
				" | ",
				line
			)


	# ==================================================
	# 2. CEK EXT RESOURCE YANG HILANG
	# ==================================================

	for i in range(lines.size()):
		var line: String = lines[i]

		if not line.begins_with("[ext_resource"):
			continue

		var path_start := line.find('path="')

		if path_start == -1:
			continue

		path_start += 6

		var path_end := line.find(
			'"',
			path_start
		)

		if path_end == -1:
			continue

		var resource_path := line.substr(
			path_start,
			path_end - path_start
		)

		if not FileAccess.file_exists(
			resource_path
		):
			problem_found = true

			print(
				"MISSING FILE | Line ",
				i + 1,
				" | ",
				resource_path
			)


	# ==================================================
	# RESULT
	# ==================================================

	if problem_found:
		print("")
		print(
			"LEVEL05 MASIH PUNYA MASALAH. "
			+ "Lihat baris di atas."
		)
	else:
		print("")
		print(
			"Tidak ditemukan conflict marker "
			+ "atau ext_resource yang hilang."
		)

		print(
			"Kalau masih gagal load, "
			+ "kemungkinan ada syntax/resource ID rusak."
		)

	print("====================================")

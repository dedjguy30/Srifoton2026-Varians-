class_name BeetleCharacter
extends GridCharacter


# ==================================================
# BEETLE
# ==================================================

# Beetle adalah karakter kuat.
# Dia tidak punya active skill Right Click khusus.
#
# Kemampuannya bersifat pasif:
# push_strength minimal 2.
func _ready() -> void:
	# Designer masih boleh memberi nilai lebih tinggi
	# lewat Inspector kalau suatu level membutuhkannya.
	if push_strength < 2:
		push_strength = 2

	# Tetap jalankan setup GridCharacter:
	# - masuk group "characters"
	# - register ke Board
	# - snap ke grid
	super()

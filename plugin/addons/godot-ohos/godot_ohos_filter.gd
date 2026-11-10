@tool
extends EditorExportPlugin


func _get_name() -> String:
	return "godot-ohos"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	# The addon, its native templates, and exported OHOS projects under build/ohos/
	# must never end up inside the game PCK.
	if path.begins_with("res://addons/godot-ohos/") or path.begins_with("res://build/ohos/"):
		skip()

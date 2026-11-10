@tool
extends EditorPlugin

const GodotOhosExporter := preload("res://addons/godot-ohos/godot_ohos_exporter.gd")
const GodotOhosPlatform := preload("res://addons/godot-ohos/godot_ohos_platform.gd")
const GodotOhosFilter := preload("res://addons/godot-ohos/godot_ohos_filter.gd")

var _export_platform: EditorExportPlatform
var _export_filter: EditorExportPlugin


func _enter_tree() -> void:
	GodotOhosExporter.register_editor_settings(get_editor_interface())
	_export_platform = GodotOhosPlatform.new(get_editor_interface())
	add_export_platform(_export_platform)
	_export_filter = GodotOhosFilter.new()
	add_export_plugin(_export_filter)


func _exit_tree() -> void:
	if _export_filter != null:
		remove_export_plugin(_export_filter)
		_export_filter = null
	if _export_platform != null:
		remove_export_platform(_export_platform)
		_export_platform = null

@tool
extends EditorExportPlatformExtension

const GodotOhosExporter := preload("res://addons/godot-ohos/godot_ohos_exporter.gd")
const LOGO_PATH := "res://addons/godot-ohos/ohos-icon.png"
const LOGO_HEIGHT := 64

var _editor_interface: EditorInterface
var _logo: Texture2D


func _init(editor_interface: EditorInterface = null) -> void:
	_editor_interface = editor_interface


func _get_os_name() -> String:
	return "OpenHarmony"


func _get_name() -> String:
	return "OpenHarmony"


func _get_logo() -> Texture2D:
	if _logo == null:
		var image := Image.load_from_file(LOGO_PATH)
		if image != null and image.get_height() > 0:
			var logo_width := int(round(float(image.get_width()) * float(LOGO_HEIGHT) / float(image.get_height())))
			if logo_width < 1:
				logo_width = 1
			image.resize(logo_width, LOGO_HEIGHT, Image.INTERPOLATE_LANCZOS)
			_logo = ImageTexture.create_from_image(image)
	return _logo


func _get_binary_extensions(_preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray()


func _get_platform_features() -> PackedStringArray:
	return PackedStringArray(["openharmony", "ohos", "mobile"])


func _get_preset_features(preset: EditorExportPreset) -> PackedStringArray:
	var features := PackedStringArray(["openharmony", "ohos"])
	for abi in GodotOhosExporter.selected_abis(preset):
		features.append("arm64" if abi == "arm64-v8a" else "x86_64")
	return features


func _get_export_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{
			"name": GodotOhosExporter.OPTION_ARCHITECTURES,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "arm64-v8a,x86_64,arm64-v8a + x86_64",
			"default_value": GodotOhosExporter.DEFAULT_ARCHITECTURES,
		},
		{
			"name": GodotOhosExporter.OPTION_BUNDLE_ID,
			"type": TYPE_STRING,
			"default_value": GodotOhosExporter.default_bundle_id(),
			"required": true,
		},
		{
			"name": GodotOhosExporter.OPTION_SDK_VERSION,
			"type": TYPE_STRING,
			"default_value": GodotOhosExporter.DEFAULT_SDK_VERSION,
			"required": true,
		},
		{
			"name": GodotOhosExporter.OPTION_ORIENTATION,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "landscape,portrait,auto",
			"default_value": GodotOhosExporter.DEFAULT_ORIENTATION,
		},
	]
	for permission_option in GodotOhosExporter.PERMISSION_OPTIONS:
		options.append({
			"name": str(permission_option["option"]),
			"type": TYPE_BOOL,
			"default_value": bool(permission_option["default"]),
		})
	options.append({
		"name": GodotOhosExporter.OPTION_CUSTOM_PERMISSIONS,
		"type": TYPE_PACKED_STRING_ARRAY,
		"default_value": PackedStringArray(),
	})
	return options


func _can_export(preset: EditorExportPreset, debug: bool) -> bool:
	return _has_valid_export_configuration(preset, debug) and _has_valid_project_configuration(preset)


func _has_valid_export_configuration(preset: EditorExportPreset, debug: bool) -> bool:
	var exporter := GodotOhosExporter.new(_editor_interface)
	var error := exporter.get_export_environment_error(preset, debug)
	set_config_error(error)
	set_config_missing_templates(error.begins_with("Template not found:"))
	return error.is_empty()


func _has_valid_project_configuration(preset: EditorExportPreset) -> bool:
	var bundle_id := ""
	if preset.has(GodotOhosExporter.OPTION_BUNDLE_ID):
		bundle_id = str(preset.get(GodotOhosExporter.OPTION_BUNDLE_ID)).strip_edges()
	if bundle_id.is_empty():
		set_config_error("package/unique_name is empty.")
		return false
	if preset.has(GodotOhosExporter.OPTION_SDK_VERSION):
		var sdk_version := str(preset.get(GodotOhosExporter.OPTION_SDK_VERSION))
		var normalized_sdk_version := GodotOhosExporter.normalize_sdk_version(sdk_version)
		if sdk_version != normalized_sdk_version:
			preset.set(GodotOhosExporter.OPTION_SDK_VERSION, normalized_sdk_version)
	set_config_error("")
	return true


func _export_project(preset: EditorExportPreset, debug: bool, path: String, _flags: int) -> Error:
	var exporter := GodotOhosExporter.new(_editor_interface, self)
	var env_error := exporter.get_export_environment_error(preset, debug)
	if not env_error.is_empty():
		add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "OpenHarmony", env_error)
		push_error("[godot-ohos] " + env_error)
		return ERR_UNAVAILABLE

	var temp_dir := OS.get_temp_dir().path_join("godot-ohos-panel-export-%d" % Time.get_unix_time_from_system())
	var temp_pck := temp_dir.path_join("template.pck")
	_remove_dir(temp_dir)
	DirAccess.make_dir_recursive_absolute(temp_dir)

	var pack_result := save_pack(preset, debug, temp_pck)
	var err: Error = pack_result.get("result", FAILED)
	if err != OK:
		add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "OpenHarmony", "Failed to pack project PCK: %s" % error_string(err))
	else:
		err = exporter.export_project_from_preset(preset, debug, path, temp_pck)
	_remove_dir(temp_dir)
	return err


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	_remove_dir_contents(path)
	DirAccess.remove_absolute(path)


func _remove_dir_contents(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		var child_path := path.path_join(file_name)
		if dir.current_is_dir():
			_remove_dir(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()

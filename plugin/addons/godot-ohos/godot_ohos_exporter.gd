@tool
extends RefCounted

const TEMPLATE_DIR_RES := "res://addons/godot-ohos/bin"
const DEFAULT_SDK_VERSION := "6.0.2(22)"
const DEFAULT_SDK_API_LEVEL := 22
const DEFAULT_ORIENTATION := "landscape"
const DEFAULT_ARCHITECTURES := "arm64-v8a + x86_64"

const OPTION_ARCHITECTURES := "openharmony/architectures"
const OPTION_BUNDLE_ID := "package/unique_name"
const OPTION_SDK_VERSION := "openharmony/sdk_version"
const OPTION_ORIENTATION := "screen/orientation"
const OPTION_CUSTOM_PERMISSIONS := "permissions/custom_permissions"

const ARCHITECTURES := {
	"arm64-v8a": "arm64-v8a",
	"x86_64": "x86_64",
	"arm64-v8a + x86_64": "arm64-v8a + x86_64",
}

const PERMISSION_OPTIONS := [
	{"option": "permissions/internet", "permission": "ohos.permission.INTERNET", "default": true, "user_grant": false},
	{"option": "permissions/get_network_info", "permission": "ohos.permission.GET_NETWORK_INFO", "default": true, "user_grant": false},
	{"option": "permissions/camera", "permission": "ohos.permission.CAMERA", "default": false, "user_grant": true},
	{"option": "permissions/microphone", "permission": "ohos.permission.MICROPHONE", "default": false, "user_grant": true},
	{"option": "permissions/location", "permission": "ohos.permission.LOCATION", "default": false, "user_grant": true},
	{"option": "permissions/approximately_location", "permission": "ohos.permission.APPROXIMATELY_LOCATION", "default": false, "user_grant": true},
	{"option": "permissions/location_in_background", "permission": "ohos.permission.LOCATION_IN_BACKGROUND", "default": false, "user_grant": true},
	{"option": "permissions/media_location", "permission": "ohos.permission.MEDIA_LOCATION", "default": false, "user_grant": true},
	{"option": "permissions/read_image_video", "permission": "ohos.permission.READ_IMAGEVIDEO", "default": false, "user_grant": true},
	{"option": "permissions/write_image_video", "permission": "ohos.permission.WRITE_IMAGEVIDEO", "default": false, "user_grant": true},
	{"option": "permissions/read_audio", "permission": "ohos.permission.READ_AUDIO", "default": false, "user_grant": true},
	{"option": "permissions/write_audio", "permission": "ohos.permission.WRITE_AUDIO", "default": false, "user_grant": true},
	{"option": "permissions/read_document", "permission": "ohos.permission.READ_DOCUMENT", "default": false, "user_grant": true},
	{"option": "permissions/write_document", "permission": "ohos.permission.WRITE_DOCUMENT", "default": false, "user_grant": true},
	{"option": "permissions/read_contacts", "permission": "ohos.permission.READ_CONTACTS", "default": false, "user_grant": true},
	{"option": "permissions/write_contacts", "permission": "ohos.permission.WRITE_CONTACTS", "default": false, "user_grant": true},
	{"option": "permissions/read_calendar", "permission": "ohos.permission.READ_CALENDAR", "default": false, "user_grant": true},
	{"option": "permissions/write_calendar", "permission": "ohos.permission.WRITE_CALENDAR", "default": false, "user_grant": true},
	{"option": "permissions/activity_motion", "permission": "ohos.permission.ACTIVITY_MOTION", "default": false, "user_grant": true},
	{"option": "permissions/use_bluetooth", "permission": "ohos.permission.USE_BLUETOOTH", "default": false, "user_grant": false},
	{"option": "permissions/discover_bluetooth", "permission": "ohos.permission.DISCOVER_BLUETOOTH", "default": false, "user_grant": false},
	{"option": "permissions/access_bluetooth", "permission": "ohos.permission.ACCESS_BLUETOOTH", "default": false, "user_grant": true},
	{"option": "permissions/nfc_tag", "permission": "ohos.permission.NFC_TAG", "default": false, "user_grant": false},
	{"option": "permissions/vibrate", "permission": "ohos.permission.VIBRATE", "default": false, "user_grant": false},
	{"option": "permissions/modify_audio_settings", "permission": "ohos.permission.MODIFY_AUDIO_SETTINGS", "default": false, "user_grant": false},
	{"option": "permissions/running_lock", "permission": "ohos.permission.RUNNING_LOCK", "default": false, "user_grant": false},
]

const SETTING_DEVECO_HOME := "export/harmony/deveco_home"
const SETTING_EXPORT_PRESET := "export/harmony/export_preset"

var _editor_interface: EditorInterface
var _export_platform: EditorExportPlatform


func _init(editor_interface: EditorInterface = null, export_platform: EditorExportPlatform = null) -> void:
	_editor_interface = editor_interface
	_export_platform = export_platform


func _report_error(message: String) -> void:
	push_error("[godot-ohos] " + message)
	if _export_platform != null:
		_export_platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "OpenHarmony", message)


func _settings() -> EditorSettings:
	if _editor_interface != null:
		return _editor_interface.get_editor_settings()
	# Fallback for callers that did not pass an EditorInterface (for example a
	# platform created before the editor finished loading).
	var editor := Engine.get_singleton("EditorInterface") if Engine.has_singleton("EditorInterface") else null
	if editor != null and editor.has_method("get_editor_settings"):
		return editor.get_editor_settings()
	return null


static func register_editor_settings(editor_interface: EditorInterface) -> void:
	var settings := editor_interface.get_editor_settings()
	var template_dir := default_template_dir()
	if settings.has_setting(SETTING_EXPORT_PRESET):
		template_dir = str(settings.get_setting(SETTING_EXPORT_PRESET)).strip_edges()
	if template_dir.is_empty():
		template_dir = default_template_dir()

	_register_setting(settings, SETTING_DEVECO_HOME, "", PROPERTY_HINT_GLOBAL_DIR)
	_register_setting(settings, SETTING_EXPORT_PRESET, template_dir, PROPERTY_HINT_GLOBAL_DIR)
	settings.set_setting(SETTING_EXPORT_PRESET, template_dir)


static func _register_setting(settings: EditorSettings, name: String, default_value: Variant, hint: PropertyHint, hint_string: String = "") -> void:
	if not settings.has_setting(name):
		settings.set_setting(name, default_value)
	if settings.has_method("set_initial_value"):
		settings.set_initial_value(name, default_value, false)
	if settings.has_method("add_property_info"):
		settings.add_property_info({
			"name": name,
			"type": typeof(default_value),
			"hint": hint,
			"hint_string": hint_string,
		})


static func default_template_dir() -> String:
	return ProjectSettings.globalize_path(TEMPLATE_DIR_RES)


static func default_bundle_id() -> String:
	var app_name := str(ProjectSettings.get_setting("application/config/name", "Godot"))
	return "com.godothub.%s" % _slugify(app_name)


static func selected_architectures(preset: EditorExportPreset) -> String:
	if not preset.has(OPTION_ARCHITECTURES):
		return DEFAULT_ARCHITECTURES
	var value := str(preset.get(OPTION_ARCHITECTURES)).strip_edges()
	if not ARCHITECTURES.has(value):
		return DEFAULT_ARCHITECTURES
	return value


static func selected_abis(preset: EditorExportPreset) -> PackedStringArray:
	var abis := PackedStringArray()
	match selected_architectures(preset):
		"arm64-v8a":
			abis.append("arm64-v8a")
		"x86_64":
			abis.append("x86_64")
		_:
			abis.append("arm64-v8a")
			abis.append("x86_64")
	return abis


static func template_file_name(mode: String) -> String:
	return "openharmony_%s_dual.zip" % mode


static func template_dir(settings: EditorSettings) -> String:
	"""Resolve the template directory, falling back to the addon's own bin/.

	The editor setting is global, so it can point at a template directory left
	behind by another project or another plugin. Only honour it when it actually
	contains our template.
	"""
	var configured := str(settings.get_setting(SETTING_EXPORT_PRESET)).strip_edges()
	var own := default_template_dir()
	if configured.is_empty() or not FileAccess.file_exists(configured.path_join(template_file_name("release"))):
		if not configured.is_empty() and configured != own:
			print("[godot-ohos] Export preset directory '%s' has no template; using '%s'." % [configured, own])
		return own
	return configured


static func _template_zip_path(settings: EditorSettings, mode: String) -> String:
	return template_dir(settings).path_join(template_file_name(mode))


func get_export_environment_error(preset: EditorExportPreset, debug: bool) -> String:
	if debug:
		return "This plugin bundles Release native templates only. Uncheck \"Export With Debug\" (导出调试版本) in the export dialog, or use --export-release."
	var settings := _settings()
	if settings == null:
		return "Cannot access EditorSettings; the plugin must run inside the Godot editor."
	var template_zip := _template_zip_path(settings, "release")
	if not FileAccess.file_exists(template_zip):
		return "Template not found: %s" % template_zip
	var available := _available_abis(template_zip)
	var required := selected_abis(preset)
	for abi in required:
		if not available.has(abi):
			return "Template %s does not contain architecture: %s" % [template_zip, abi]
	return ""


static func _available_abis(template_zip: String) -> PackedStringArray:
	var abis := PackedStringArray()
	var reader := ZIPReader.new()
	if reader.open(template_zip) != OK:
		return abis
	for abi in ["arm64-v8a", "x86_64"]:
		if reader.file_exists("entry/libs/%s/libgodot.so" % abi):
			abis.append(abi)
	reader.close()
	return abis


func export_project_from_preset(preset: EditorExportPreset, debug: bool, output_path: String, pck_path: String) -> Error:
	return _export_project_from_pack(preset.get_preset_name(), debug, output_path, pck_path, _export_config_from_preset(preset))


func _export_project_from_pack(export_preset: String, debug: bool, output_path: String, pck_source_path: String, export_config: Dictionary) -> Error:
	var settings := _settings()
	if settings == null:
		_report_error("Cannot access EditorSettings; the plugin must run inside the Godot editor.")
		return ERR_UNAVAILABLE
	var project_dir := ProjectSettings.globalize_path("res://").simplify_path()
	var mode := "debug" if debug else "release"

	var template_zip := _template_zip_path(settings, mode)
	if not FileAccess.file_exists(template_zip):
		_report_error("Template not found: %s" % template_zip)
		return ERR_FILE_NOT_FOUND

	var app_name := _find_ini_value(_read_text(project_dir.path_join("project.godot")), "config/name", "Godot")
	var project_name := _slugify(app_name)
	var build_root := project_dir.path_join("build/ohos")
	var ohos_project := _resolve_project_dir(output_path, build_root.path_join(project_name))
	var pck_path := ohos_project.path_join("entry/src/main/resources/rawfile/template.pck")
	var bundle_id := str(export_config.get("bundle_id", default_bundle_id()))
	var abis := export_config.get("abis", PackedStringArray()) as PackedStringArray

	print("[godot-ohos] Preset: %s" % export_preset)
	print("[godot-ohos] OHOS project: %s" % ohos_project)
	print("[godot-ohos] Template: %s" % template_zip)
	print("[godot-ohos] Bundle ID: %s" % bundle_id)
	print("[godot-ohos] Architectures: %s" % ", ".join(abis))

	var preserved_signing := _read_preserved_signing(ohos_project)
	_remove_dir(ohos_project)
	var err := _extract_template(template_zip, ohos_project)
	if err != OK:
		return err

	_ensure_gdignore(ohos_project, project_dir)
	_prune_architectures(ohos_project, abis)
	_configure_project(ohos_project, app_name, export_config, preserved_signing)
	_write_cmdline_args(ohos_project)

	DirAccess.make_dir_recursive_absolute(pck_path.get_base_dir())
	err = DirAccess.copy_absolute(pck_source_path, pck_path)
	if err != OK:
		_report_error("Failed to copy PCK to %s" % pck_path)
		return err

	print("[godot-ohos] OHOS project exported: %s" % ohos_project)
	return OK


func _prune_architectures(project_dir: String, abis: PackedStringArray) -> void:
	var libs_dir := project_dir.path_join("entry/libs")
	if not DirAccess.dir_exists_absolute(libs_dir):
		return
	var dir := DirAccess.open(libs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not abis.has(entry):
			_remove_dir(libs_dir.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


func _extract_template(template_zip: String, project_dir: String) -> Error:
	var reader := ZIPReader.new()
	var err := reader.open(template_zip)
	if err != OK:
		_report_error("Failed to open template zip: %s" % template_zip)
		return err

	DirAccess.make_dir_recursive_absolute(project_dir)
	for file_path in reader.get_files():
		var dest := project_dir.path_join(file_path)
		if file_path.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(dest)
			continue
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var file := FileAccess.open(dest, FileAccess.WRITE)
		if file == null:
			reader.close()
			_report_error("Failed to write template file: %s" % dest)
			return ERR_FILE_CANT_WRITE
		file.store_buffer(reader.read_file(file_path))
	reader.close()
	return OK


func _configure_project(project_dir: String, app_name: String, export_config: Dictionary, preserved_signing: Dictionary) -> void:
	var bundle_id := str(export_config.get("bundle_id", default_bundle_id()))
	var sdk_version := str(export_config.get("sdk_version", DEFAULT_SDK_VERSION))
	var orientation := str(export_config.get("orientation", DEFAULT_ORIENTATION))
	var permissions: Array[String] = []
	for permission in export_config.get("permissions", []):
		permissions.append(str(permission))
	var user_permissions := str(export_config.get("user_permissions", ""))
	var abis: PackedStringArray = export_config.get("abis", PackedStringArray())

	var app_json := project_dir.path_join("AppScope/app.json5")
	if FileAccess.file_exists(app_json):
		var content := _read_text(app_json)
		content = _replace_json5_string_property(content, "bundleName", bundle_id)
		_write_text(app_json, content)

	var app_scope_strings := project_dir.path_join("AppScope/resources/base/element/string.json")
	if FileAccess.file_exists(app_scope_strings):
		var content := _read_text(app_scope_strings)
		content = _replace_resource_string(content, "app_name", app_name)
		_write_text(app_scope_strings, content)

	var entry_strings := project_dir.path_join("entry/src/main/resources/base/element/string.json")
	if FileAccess.file_exists(entry_strings):
		var content := _read_text(entry_strings)
		content = _replace_resource_string(content, "EntryAbility_label", app_name)
		content = _replace_resource_string(content, "user_permissions", user_permissions)
		content = _ensure_permission_reason_strings(content, permissions)
		_write_text(entry_strings, content)

	var module_json := project_dir.path_join("entry/src/main/module.json5")
	if FileAccess.file_exists(module_json):
		var content := _read_text(module_json)
		content = _replace_request_permissions(content, permissions)
		content = _replace_json5_string_property(content, "orientation", orientation)
		_write_text(module_json, content)

	var entry_profile := project_dir.path_join("entry/build-profile.json5")
	if FileAccess.file_exists(entry_profile):
		var content := _read_text(entry_profile)
		content = _replace_abi_filters(content, abis)
		_write_text(entry_profile, content)

	var build_profile := project_dir.path_join("build-profile.json5")
	if FileAccess.file_exists(build_profile):
		var content := _read_text(build_profile)
		var api_level := _sdk_api_level(sdk_version)
		if api_level >= 26:
			content = _replace_json5_string_property(content, "compileSdkVersion", "26.0.0")
			content = _replace_json5_string_property(content, "targetSdkVersion", "26.0.0")
			content = _replace_json5_string_property(content, "compatibleSdkVersion", "6.0.2(22)")
		else:
			content = _replace_json5_string_property(content, "targetSdkVersion", sdk_version)
			content = _replace_json5_string_property(content, "compatibleSdkVersion", sdk_version)
		if preserved_signing.has("signing_configs"):
			content = _replace_array_property(content, "signingConfigs", preserved_signing["signing_configs"])
		if preserved_signing.has("signing_config_name"):
			content = _replace_json5_string_property(content, "signingConfig", preserved_signing["signing_config_name"])
		_write_text(build_profile, content)

	_configure_icons(project_dir)


func _ensure_gdignore(ohos_project: String, project_dir: String) -> void:
	if ohos_project.begins_with(project_dir.path_join("build/ohos")):
		_write_text(project_dir.path_join("build/ohos/.gdignore"), "")
	if ohos_project.begins_with(project_dir):
		_write_text(ohos_project.path_join(".gdignore"), "")


func _write_cmdline_args(project_dir: String) -> void:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ProjectSettings.get_setting("rendering/renderer/rendering_method", "mobile"))).strip_edges()
	var driver := "vulkan"
	if method == "gl_compatibility":
		driver = "opengl3"
	elif method != "forward_plus":
		method = "mobile"
	var cl_path := project_dir.path_join("entry/src/main/resources/rawfile/_cl_")
	DirAccess.make_dir_recursive_absolute(cl_path.get_base_dir())
	_write_text(cl_path, "--rendering-method
%s
--rendering-driver
%s
" % [method, driver])


func _replace_abi_filters(content: String, abis: PackedStringArray) -> String:
	var re := RegEx.new()
	if re.compile("\"abiFilters\"\\s*:\\s*\\[[^\\]]*\\]") != OK:
		return content
	var entries := PackedStringArray()
	for abi in abis:
		entries.append("\"%s\"" % abi)
	return re.sub(content, "\"abiFilters\": [%s]" % ", ".join(entries), true)


func _configure_icons(project_dir: String) -> void:
	var icon_path := str(ProjectSettings.get_setting("application/config/icon", ""))
	if icon_path.is_empty():
		return
	var icon_global := ProjectSettings.globalize_path(icon_path)
	if not FileAccess.file_exists(icon_global):
		return
	var src_image := Image.load_from_file(icon_global)
	if src_image == null or src_image.is_empty():
		return
	src_image.convert(Image.FORMAT_RGBA8)

	var bg_color: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	var bg_image := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	bg_image.fill(bg_color)

	var fg_image := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	fg_image.fill(Color(0, 0, 0, 0))
	var fg_icon := Image.new()
	fg_icon.copy_from(src_image)
	fg_icon.resize(720, 720, Image.INTERPOLATE_LANCZOS)
	fg_image.blend_rect(fg_icon, Rect2i(0, 0, 720, 720), Vector2i(152, 152))

	var start_icon := Image.create(144, 144, false, Image.FORMAT_RGBA8)
	start_icon.fill(Color(0, 0, 0, 0))
	var start_inner := Image.new()
	start_inner.copy_from(src_image)
	start_inner.resize(120, 120, Image.INTERPOLATE_LANCZOS)
	start_icon.blend_rect(start_inner, Rect2i(0, 0, 120, 120), Vector2i(12, 12))

	var targets := [
		project_dir.path_join("AppScope/resources/base/media"),
		project_dir.path_join("entry/src/main/resources/base/media"),
	]
	for target: String in targets:
		if DirAccess.dir_exists_absolute(target):
			bg_image.save_png(target.path_join("background.png"))
			fg_image.save_png(target.path_join("foreground.png"))
	var start_path := project_dir.path_join("entry/src/main/resources/base/media/startIcon.png")
	if DirAccess.dir_exists_absolute(start_path.get_base_dir()):
		start_icon.save_png(start_path)


func _read_preserved_signing(project_dir: String) -> Dictionary:
	var build_profile := project_dir.path_join("build-profile.json5")
	if not FileAccess.file_exists(build_profile):
		return {}
	var content := _read_text(build_profile)
	var signing_configs := _extract_array_property(content, "signingConfigs")
	if signing_configs.is_empty():
		return {}
	var bracket_pos := signing_configs.find("[")
	if bracket_pos >= 0 and signing_configs.substr(bracket_pos).strip_edges() == "[]":
		return {}
	var result := {
		"signing_configs": signing_configs,
	}
	var signing_config_name := _find_json5_string_property(content, "signingConfig", "")
	if not signing_config_name.is_empty():
		result["signing_config_name"] = signing_config_name
	return result


func _export_config_from_preset(preset: EditorExportPreset) -> Dictionary:
	var enabled_options: Array[String] = []
	for permission_option in PERMISSION_OPTIONS:
		var option_name := str(permission_option["option"])
		if preset.has(option_name) and bool(preset.get(option_name)):
			enabled_options.append(option_name)
	var custom_permissions: Array[String] = []
	if preset.has(OPTION_CUSTOM_PERMISSIONS):
		for permission in preset.get(OPTION_CUSTOM_PERMISSIONS):
			custom_permissions.append(str(permission))
	return _make_export_config(
		str(preset.get(OPTION_BUNDLE_ID)) if preset.has(OPTION_BUNDLE_ID) else default_bundle_id(),
		str(preset.get(OPTION_SDK_VERSION)) if preset.has(OPTION_SDK_VERSION) else DEFAULT_SDK_VERSION,
		str(preset.get(OPTION_ORIENTATION)) if preset.has(OPTION_ORIENTATION) else DEFAULT_ORIENTATION,
		enabled_options,
		custom_permissions,
		selected_abis(preset)
	)


func _make_export_config(bundle_id: String, sdk_version: String, orientation: String, enabled_options: Array[String], custom_permissions: Array[String], abis: PackedStringArray) -> Dictionary:
	bundle_id = bundle_id.strip_edges()
	sdk_version = sdk_version.strip_edges()
	orientation = orientation.strip_edges()
	if bundle_id.is_empty():
		bundle_id = default_bundle_id()
	sdk_version = normalize_sdk_version(sdk_version)
	if orientation != "portrait" and orientation != "auto":
		orientation = DEFAULT_ORIENTATION

	var permissions: Array[String] = []
	var user_permissions: Array[String] = []
	for permission_option in PERMISSION_OPTIONS:
		var option_name := str(permission_option["option"])
		if not enabled_options.has(option_name):
			continue
		var permission := str(permission_option["permission"])
		_append_unique(permissions, permission)
		if bool(permission_option["user_grant"]):
			_append_unique(user_permissions, permission)
	for permission in custom_permissions:
		permission = permission.strip_edges()
		if permission.is_empty():
			continue
		_append_unique(permissions, permission)
	return {
		"bundle_id": bundle_id,
		"sdk_version": sdk_version,
		"orientation": orientation,
		"permissions": permissions,
		"user_permissions": ",".join(user_permissions),
		"abis": abis,
	}


static func _sdk_api_level(sdk_version: String) -> int:
	var start := sdk_version.find("(")
	var end := sdk_version.find(")", start + 1)
	if start != -1 and end != -1:
		return int(sdk_version.substr(start + 1, end - start - 1))
	var parts := sdk_version.split(".")
	if parts.size() > 0 and parts[0].is_valid_int():
		return int(parts[0])
	return 0


static func normalize_sdk_version(sdk_version: String) -> String:
	sdk_version = sdk_version.strip_edges()
	if sdk_version.is_empty() or _sdk_api_level(sdk_version) < DEFAULT_SDK_API_LEVEL:
		return DEFAULT_SDK_VERSION
	return sdk_version


func _append_unique(values: Array[String], value: String) -> void:
	if not values.has(value):
		values.append(value)


func _resolve_project_dir(output_path: String, default_path: String) -> String:
	output_path = output_path.strip_edges()
	if output_path.is_empty():
		return default_path
	if output_path.begins_with("res://") or output_path.begins_with("user://"):
		output_path = ProjectSettings.globalize_path(output_path)
	elif output_path.begins_with("./"):
		output_path = ProjectSettings.globalize_path("res://" + output_path.trim_prefix("./"))
	elif not output_path.is_absolute_path():
		output_path = ProjectSettings.globalize_path("res://" + output_path)
	return output_path


func _permissions_json(permissions: Array[String]) -> String:
	if permissions.is_empty():
		return "\"requestPermissions\": [],"
	var lines: Array[String] = ["\"requestPermissions\": ["]
	for i in range(permissions.size()):
		var permission := permissions[i]
		var comma := "," if i < permissions.size() - 1 else ""
		var reason := permission.trim_prefix("ohos.permission.")
		lines.append_array([
			"      {",
			"        \"name\": \"%s\"," % permission,
			"        \"reason\": \"$string:%s_reason\"," % reason,
			"        \"usedScene\": {",
			"          \"abilities\": [",
			"            \"EntryAbility\"",
			"          ],",
			"          \"when\": \"always\"",
			"        }",
			"      }%s" % comma,
		])
	lines.append("    ],")
	return "\n".join(lines)


func _replace_request_permissions(content: String, permissions: Array[String]) -> String:
	var re := RegEx.new()
	if re.compile("\"requestPermissions\"\\s*:\\s*\\[\\]\\s*,") != OK:
		return content
	return re.sub(content, _permissions_json(permissions).replace("$", "$$"), true)


func _replace_json5_string_property(content: String, key: String, value: String) -> String:
	var re := RegEx.new()
	if re.compile("([\"']?%s[\"']?\\s*:\\s*)[\"'][^\"']*[\"']" % key) != OK:
		return content
	return re.sub(content, "$1\"%s\"" % value, true)


func _replace_resource_string(content: String, name: String, value: String) -> String:
	var re := RegEx.new()
	if re.compile("(\"name\"\\s*:\\s*\"%s\"\\s*,\\s*\"value\"\\s*:\\s*)\"[^\"]*\"" % name) != OK:
		return content
	return re.sub(content, "$1\"%s\"" % value, true)


func _ensure_permission_reason_strings(content: String, permissions: Array[String]) -> String:
	for permission in permissions:
		var reason_name := _permission_reason_name(permission)
		if content.contains("\"name\": \"%s\"" % reason_name):
			continue
		var entry := ",\n    {\n      \"name\": \"%s\",\n      \"value\": \"Required by the application\"\n    }" % reason_name
		content = content.replace("\n  ]", entry + "\n  ]")
	return content


func _permission_reason_name(permission: String) -> String:
	return "%s_reason" % permission.trim_prefix("ohos.permission.")


func _find_json5_string_property(content: String, key: String, default_value: String) -> String:
	var re := RegEx.new()
	if re.compile("[\"']?%s[\"']?\\s*:\\s*[\"']([^\"']*)[\"']" % key) == OK:
		var m := re.search(content)
		if m != null:
			return m.get_string(1)
	return default_value


func _extract_array_property(content: String, key: String) -> String:
	var re := RegEx.new()
	if re.compile("[\"']?%s[\"']?\\s*:\\s*\\[" % key) != OK:
		return ""
	var m := re.search(content)
	if m == null:
		return ""
	var key_pos := m.get_start(0)
	var array_start := content.find("[", key_pos)
	if array_start < 0:
		return ""
	var depth := 0
	var quote_char := ""
	var escaped := false
	for i in range(array_start, content.length()):
		var c := content.substr(i, 1)
		if not quote_char.is_empty():
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == quote_char:
				quote_char = ""
		else:
			if c == "\"" or c == "'":
				quote_char = c
			elif c == "[":
				depth += 1
			elif c == "]":
				depth -= 1
				if depth == 0:
					return content.substr(key_pos, i - key_pos + 1)
	return ""


func _replace_array_property(content: String, key: String, replacement: String) -> String:
	var current := _extract_array_property(content, key)
	if current.is_empty():
		return content
	return content.replace(current, replacement)


func _find_ini_value(text: String, key: String, default_value: String) -> String:
	var prefix := "%s=\"" % key
	for line in text.split("\n"):
		if line.begins_with(prefix) and line.ends_with("\""):
			return line.substr(prefix.length(), line.length() - prefix.length() - 1)
	return default_value


static func _slugify(value: String) -> String:
	var result := ""
	var lower := value.to_lower()
	for i in range(lower.length()):
		var c := lower.substr(i, 1)
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			result += c
		else:
			result += "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	return result if not result.is_empty() else "godot_project"


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


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

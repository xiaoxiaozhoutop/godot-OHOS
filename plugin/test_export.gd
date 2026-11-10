@tool
extends SceneTree

const Platform := preload("res://addons/godot-ohos/godot_ohos_platform.gd")
const Exporter := preload("res://addons/godot-ohos/godot_ohos_exporter.gd")


func _initialize() -> void:
	_run.call_deferred()


func _export_to(preset: EditorExportPreset, output: String) -> Error:
	var fake_pck := ProjectSettings.globalize_path("user://ohos-test.pck")
	var fixture := FileAccess.open(fake_pck, FileAccess.WRITE)
	fixture.store_string("fake-pck-for-archive-test-only")
	fixture.close()
	var exporter := Exporter.new()
	var config: Dictionary = exporter._export_config_from_preset(preset)
	var error: Error = exporter._export_project_from_pack("OHOS Dual", false, output, fake_pck, config)
	DirAccess.remove_absolute(fake_pck)
	return error


func _run() -> void:
	await process_frame
	# Test this checkout, not another project's globally configured template.
	var settings := EditorInterface.get_editor_settings()
	var previous_template_dir: Variant = settings.get_setting(Exporter.SETTING_EXPORT_PRESET)
	settings.set_setting(Exporter.SETTING_EXPORT_PRESET, Exporter.default_template_dir())

	var platform := Platform.new()
	var preset := platform.create_preset()
	preset.set("package/unique_name", "com.example.ohosdual")
	preset.set("openharmony/architectures", "arm64-v8a + x86_64")
	preset.set("openharmony/sdk_version", "6.0.2(22)")
	preset.set("screen/orientation", "landscape")
	preset.set("permissions/internet", true)
	preset.set("permissions/microphone", false)

	assert(Exporter.selected_abis(preset) == PackedStringArray(["arm64-v8a", "x86_64"]))
	preset.set("openharmony/architectures", "x86_64")
	assert(Exporter.selected_abis(preset) == PackedStringArray(["x86_64"]))
	preset.set("openharmony/architectures", "arm64-v8a")
	assert(Exporter.selected_abis(preset) == PackedStringArray(["arm64-v8a"]))
	preset.set("openharmony/architectures", "arm64-v8a + x86_64")

	var exporter := Exporter.new(null, platform)
	assert(not exporter.get_export_environment_error(preset, true).is_empty(), "debug export must be rejected")
	assert(exporter.get_export_environment_error(preset, false).is_empty(), "release template was not found")

	platform.clear_messages()
	var debug_err := platform._export_project(preset, true, ProjectSettings.globalize_path("build/ohos/debug_should_fail"), 0)
	assert(debug_err == ERR_UNAVAILABLE, "debug export should fail fast before save_pack")
	assert(platform.get_message_count() == 1, "expected clear error message in export dialog")
	assert(platform.get_message_type(0) == EditorExportPlatform.EXPORT_MESSAGE_ERROR)
	assert(platform.get_message_text(0).contains("Export With Debug"))

	preset.set("openharmony/sdk_version", "26.0.0")

	var both := ProjectSettings.globalize_path("build/ohos/ohos_test_export")
	var error := _export_to(preset, both)
	if error != OK:
		push_error("Export failed: " + error_string(error))
		quit(1)
		return

	var libs := both.path_join("entry/libs")
	assert(FileAccess.file_exists(libs.path_join("arm64-v8a/libgodot.so")), "ARM64 library missing")
	assert(FileAccess.file_exists(libs.path_join("x86_64/libgodot.so")), "x86_64 library missing")
	assert(FileAccess.file_exists(both.path_join("entry/src/main/resources/rawfile/template.pck")), "PCK missing")
	var cl := FileAccess.open(both.path_join("entry/src/main/resources/rawfile/_cl_"), FileAccess.READ).get_as_text()
	assert(cl.contains("--rendering-driver
vulkan"), "_cl_ rendering-driver missing")

	var profile := FileAccess.open(both.path_join("entry/build-profile.json5"), FileAccess.READ).get_as_text()
	assert(profile.contains('"abiFilters": ["arm64-v8a", "x86_64"]'), "abiFilters not updated:\n" + profile)
	var app := FileAccess.open(both.path_join("AppScope/app.json5"), FileAccess.READ).get_as_text()
	assert(app.contains("com.example.ohosdual"), "bundle name not applied")
	var module_json := FileAccess.open(both.path_join("entry/src/main/module.json5"), FileAccess.READ).get_as_text()
	assert(module_json.contains("ohos.permission.INTERNET"), "internet permission missing")
	assert(not module_json.contains("ohos.permission.MICROPHONE"), "microphone permission should be absent")

	# Selecting one architecture must prune the other library directory.
	var single := ProjectSettings.globalize_path("build/ohos/ohos_test_export_x86")
	preset.set("openharmony/architectures", "x86_64")
	var error2 := _export_to(preset, single)
	if error2 != OK:
		push_error("Single architecture export failed: " + error_string(error2))
		quit(1)
		return
	assert(FileAccess.file_exists(single.path_join("entry/libs/x86_64/libgodot.so")))
	assert(not DirAccess.dir_exists_absolute(single.path_join("entry/libs/arm64-v8a")), "ARM64 directory should be pruned")
	var single_profile := FileAccess.open(single.path_join("entry/build-profile.json5"), FileAccess.READ).get_as_text()
	assert(single_profile.contains('"abiFilters": ["x86_64"]'), "single architecture abiFilters wrong")

	# Verify re-exporting preserves devecocli signature generate's unquoted JSON5 signingConfigs.
	var bp_path := single.path_join("build-profile.json5")
	var bp_writer := FileAccess.open(bp_path, FileAccess.WRITE)
	bp_writer.store_string("{\n  app: {\n    signingConfigs: [ { name: 'default', type: 'HarmonyOS' } ],\n    products: [ { name: 'default', signingConfig: 'default', targetSdkVersion: '6.0.2(22)', compatibleSdkVersion: '6.0.2(22)' } ]\n  }\n}\n")
	bp_writer.close()
	var error3 := _export_to(preset, single)
	assert(error3 == OK, "re-export should succeed")
	var bp_after := FileAccess.open(bp_path, FileAccess.READ).get_as_text()
	assert(bp_after.contains("signingConfigs: [ { name: 'default'"), "signingConfigs was lost on re-export")
	assert(bp_after.contains('"signingConfig": "default"'), "signingConfig name was not preserved")

	# Verify gl_compatibility writes opengl3 driver.
	var prev_mobile_method: Variant = ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", null)
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	exporter._write_cmdline_args(single)
	var cl_gles := FileAccess.open(single.path_join("entry/src/main/resources/rawfile/_cl_"), FileAccess.READ).get_as_text()
	assert(cl_gles.contains("--rendering-method\ngl_compatibility"), "gl_compatibility method missing:\n" + cl_gles)
	assert(cl_gles.contains("--rendering-driver\nopengl3"), "opengl3 driver missing:\n" + cl_gles)
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile", prev_mobile_method)

	settings.set_setting(Exporter.SETTING_EXPORT_PRESET, previous_template_dir)
	print("OHOS export smoke test passed")
	quit(0)

extends Control

# =========================================================
# MENU PAUSE — Échap pour ouvrir/fermer
# =========================================================

@onready var resume_btn = $Panel/VBoxContainer/ResumeButton
@onready var restart_btn = $Panel/VBoxContainer/RestartButton
@onready var settings_btn = $Panel/VBoxContainer/SettingsButton
@onready var quit_btn = $Panel/VBoxContainer/QuitButton

@onready var settings_panel = $SettingsPanel
@onready var brightness_slider = $SettingsPanel/VBoxContainer/BrightnessSlider
@onready var volume_slider = $SettingsPanel/VBoxContainer/VolumeSlider
@onready var back_btn = $SettingsPanel/VBoxContainer/BackButton

var is_paused := false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if settings_panel:
		settings_panel.visible = false
	
	resume_btn.pressed.connect(_on_resume)
	restart_btn.pressed.connect(_on_restart)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	
	if back_btn:
		back_btn.pressed.connect(_on_back_from_settings)
	if brightness_slider:
		brightness_slider.value_changed.connect(_on_brightness_changed)
		brightness_slider.value = 1.0
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		volume_slider.value = 1.0

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	is_paused = !is_paused
	visible = is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if settings_panel:
			settings_panel.visible = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume():
	toggle_pause()

func _on_restart():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()

func _on_settings():
	if settings_panel:
		settings_panel.visible = true

func _on_quit():
	get_tree().quit()

func _on_back_from_settings():
	if settings_panel:
		settings_panel.visible = false

func _on_brightness_changed(value: float):
	var env = get_viewport().get_camera_3d()
	if env:
		RenderingServer.global_shader_parameter_set("brightness", value)
	var canvas_modulate = get_tree().current_scene.get_node_or_null("CanvasModulate")
	if not canvas_modulate:
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		get_tree().current_scene.add_child(canvas_modulate)
	var brightness_color = Color(value, value, value, 1.0)
	canvas_modulate.color = brightness_color

func _on_volume_changed(value: float):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(0, db)

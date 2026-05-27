extends Control

# =========================================================
# SPLASH SCREEN — AKA_FPK
# =========================================================

var fade_timer := 0.0
var phase := 0  # 0=fade in title, 1=show menu, 2=fade out to game
var fade_out_timer := 0.0

var title_label: Label
var subtitle_label: Label
var player_label: Label
var play_button: Button
var bg: ColorRect
var fade_overlay: ColorRect

func _ready():
	# Fond noir
	bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Titre AKA_FPK
	title_label = Label.new()
	title_label.text = "AKA_FPK"
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(1, 0.75, 0.1, 0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.anchors_preset = Control.PRESET_CENTER_TOP
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-200, 120)
	title_label.size = Vector2(400, 100)
	add_child(title_label)
	
	# Sous-titre
	subtitle_label = Label.new()
	subtitle_label.text = "AKA FIRST PERSON KILLER"
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.anchors_preset = Control.PRESET_CENTER_TOP
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle_label.position = Vector2(-200, 210)
	subtitle_label.size = Vector2(400, 40)
	add_child(subtitle_label)
	
	# Nom du joueur
	player_label = Label.new()
	player_label.text = "JOUEUR: AKAZZA"
	player_label.add_theme_font_size_override("font_size", 18)
	player_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 0))
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.anchors_preset = Control.PRESET_CENTER_TOP
	player_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	player_label.position = Vector2(-200, 260)
	player_label.size = Vector2(400, 30)
	add_child(player_label)
	
	# Bouton JOUER
	play_button = Button.new()
	play_button.text = "► JOUER"
	play_button.add_theme_font_size_override("font_size", 32)
	play_button.custom_minimum_size = Vector2(250, 70)
	play_button.anchors_preset = Control.PRESET_CENTER
	play_button.set_anchors_preset(Control.PRESET_CENTER)
	play_button.position = Vector2(-125, 60)
	play_button.size = Vector2(250, 70)
	play_button.visible = false
	play_button.pressed.connect(_on_play_pressed)
	
	# Style du bouton
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.8, 0.5, 0.0, 0.9)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	play_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.65, 0.0, 1)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	play_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed_style = StyleBoxFlat.new()
	btn_pressed_style.bg_color = Color(0.6, 0.35, 0.0, 1)
	btn_pressed_style.corner_radius_top_left = 8
	btn_pressed_style.corner_radius_top_right = 8
	btn_pressed_style.corner_radius_bottom_left = 8
	btn_pressed_style.corner_radius_bottom_right = 8
	play_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	
	add_child(play_button)
	
	# Fade overlay pour transition
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.anchors_preset = Control.PRESET_FULL_RECT
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func _process(delta):
	if phase == 0:
		# Fade in du titre
		fade_timer += delta
		var alpha = clamp(fade_timer / 2.0, 0, 1)
		title_label.add_theme_color_override("font_color", Color(1, 0.75, 0.1, alpha))
		subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, alpha * 0.8))
		player_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, alpha * 0.7))
		if fade_timer >= 2.5:
			phase = 1
			play_button.visible = true
	
	elif phase == 2:
		# Fade out vers le jeu
		fade_out_timer += delta
		var alpha = clamp(fade_out_timer / 1.0, 0, 1)
		fade_overlay.color = Color(0, 0, 0, alpha)
		if fade_out_timer >= 1.2:
			get_tree().change_scene_to_file("res://nod1e_3d.tscn")

func _on_play_pressed():
	phase = 2
	fade_out_timer = 0.0

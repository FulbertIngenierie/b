extends Control

# =========================================================
# NODES
# =========================================================

@onready var restart_button = $Panel/RestartButton
@onready var quit_button = $Panel/QuitButton

# =========================================================
# READY
# =========================================================

func _ready():
	hide()
	
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

# =========================================================
# REDÉMARRER
# =========================================================

func _on_restart_pressed():
	get_tree().reload_current_scene()

# =========================================================
# QUITTER
# =========================================================

func _on_quit_pressed():
	get_tree().quit()

# =========================================================
# AFFICHER GAME OVER
# =========================================================

func show_game_over():
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

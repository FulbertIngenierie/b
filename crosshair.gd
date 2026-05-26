extends Control

# =========================================================
# VARIABLES
# =========================================================

var is_aiming := false
var normal_size := 1.0
var aim_size := 0.5
var current_size := 1.0

# =========================================================
# NODES
# =========================================================

@onready var center_dot = $CenterDot
@onready var top_line = $TopLine
@onready var bottom_line = $BottomLine
@onready var left_line = $LeftLine
@onready var right_line = $RightLine

# =========================================================
# READY
# =========================================================

func _ready():
	hide()

# =========================================================
# PROCESS
# =========================================================

func _process(_delta):
	if is_aiming:
		current_size = lerp(current_size, aim_size, 20.0 * _delta)
	else:
		current_size = lerp(current_size, normal_size, 20.0 * _delta)
	
	update_crosshair_size()

# =========================================================
# SET AIMING
# =========================================================

func set_aiming(aiming: bool):
	is_aiming = aiming

# =========================================================
# UPDATE CROSSHAIR SIZE
# =========================================================

func update_crosshair_size():
	var scale_factor = current_size
	
	center_dot.size = Vector2(4, 4) * scale_factor
	top_line.size = Vector2(2, 12) * scale_factor
	bottom_line.size = Vector2(2, 12) * scale_factor
	left_line.size = Vector2(12, 2) * scale_factor
	right_line.size = Vector2(12, 2) * scale_factor
	
	# Repositionner les lignes
	top_line.position = Vector2(-1, -15) * scale_factor
	bottom_line.position = Vector2(-1, 3) * scale_factor
	left_line.position = Vector2(-15, -1) * scale_factor
	right_line.position = Vector2(3, -1) * scale_factor

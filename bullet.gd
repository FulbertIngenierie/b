# =========================================================
# Bullet.gd
# =========================================================
extends Node3D

# =========================================================
# SPEED
# =========================================================
var speed := 300.0

# =========================================================
# DIRECTION
# =========================================================
var direction := Vector3.ZERO

# =========================================================
# DAMAGE
# =========================================================
var damage := 25.0

# =========================================================
# READY
# =========================================================
func _ready():
	
	# Connecter l'Area3D pour détecter les collisions
	var area = $Area3D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.area_entered.connect(_on_area_entered)

	await get_tree().create_timer(
		0.15
	).timeout

	queue_free()

# =========================================================
# MOVE
# =========================================================
func _physics_process(delta):

	global_position += (
		direction
		*
		speed
		*
		delta
	)

# =========================================================
# COLLISION WITH BODY
# =========================================================
func _on_body_entered(body):
	# Si c'est un ennemi, appliquer des dégâts
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

# =========================================================
# COLLISION WITH AREA
# =========================================================
func _on_area_entered(area):
	# Si l'area appartient à un ennemi, appliquer des dégâts
	var area_owner = area.owner
	if area_owner and area_owner.has_method("take_damage"):
		area_owner.take_damage(damage)
		queue_free()

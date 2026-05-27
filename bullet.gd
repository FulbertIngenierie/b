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
		3.0
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
	if not body or not is_instance_valid(body):
		queue_free()
		return
	if not body.is_inside_tree():
		queue_free()
		return
	# Vérifier si l'ennemi est déjà mort
	if "is_dead" in body and body.is_dead:
		queue_free()
		return
	# Si tirée par un ennemi, ne pas toucher les autres ennemis
	if has_meta("fired_by_enemy") and get_meta("fired_by_enemy"):
		if body.is_in_group("enemies") or body.is_in_group("enemy_target"):
			return
	# Si c'est une cible valide, appliquer des dégâts
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

# =========================================================
# COLLISION WITH AREA
# =========================================================
func _on_area_entered(area):
	if not area or not is_instance_valid(area):
		queue_free()
		return
	var area_owner = area.owner
	if area_owner and is_instance_valid(area_owner) and area_owner.is_inside_tree():
		if "is_dead" in area_owner and area_owner.is_dead:
			queue_free()
			return
		# Si tirée par un ennemi, ne pas toucher les autres ennemis
		if has_meta("fired_by_enemy") and get_meta("fired_by_enemy"):
			if area_owner.is_in_group("enemies") or area_owner.is_in_group("enemy_target"):
				return
		if area_owner.has_method("take_damage"):
			area_owner.take_damage(damage)
			queue_free()

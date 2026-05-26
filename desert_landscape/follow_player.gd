extends CharacterBody3D

# =========================================================
# VARIABLES
# =========================================================

@export var speed: float = 3.0
@export var detection_range: float = 50.0
@export var attack_range: float = 30.0
@export var damage: float = 25.0

var player: CharacterBody3D
var is_attacking: bool = false
var initial_position := Vector3.ZERO  # Position initiale pour défendre

@onready var gun_sound = $ShootSound

# =========================================================
# SCENES
# =========================================================

var bullet_scene = preload("res://Bullet.tscn")

# =========================================================
# READY
# =========================================================

func _ready() -> void:
	# Trouver le joueur dans la scène
	find_player()
	
	# Sauvegarder la position initiale pour défendre
	initial_position = global_position

# =========================================================
# PROCESS
# =========================================================

func _physics_process(delta: float) -> void:
	if not player:
		find_player()
		return
	
	# Calculer la distance vers le joueur
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Défendre la position initiale - ne pas bouger sauf pour attaquer
	var distance_from_initial = global_position.distance_to(initial_position)
	
	# Si trop loin de la position initiale, retourner
	if distance_from_initial > 2.0:
		var direction = (initial_position - global_position).normalized()
		direction.y = 0
		velocity = direction * speed
		move_and_slide()
		return
	
	# Si le joueur est dans la portée de détection
	if distance_to_player <= detection_range:
		# Attaquer si à portée
		if distance_to_player <= attack_range and not is_attacking:
			attack_player()

# =========================================================
# TROUVER LE JOUEUR
# =========================================================

func find_player():
	# Chercher le joueur par son type (CharacterBody3D avec le script du joueur)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		# Alternative: chercher le premier CharacterBody3D qui n'est pas l'ennemi
		for node in get_tree().get_nodes_in_group("enemies"):
			continue
		# Chercher dans la scène courante
		var root = get_tree().current_scene
		for child in root.get_children():
			if child is CharacterBody3D and child != self:
				player = child
				break

# =========================================================
# SE DÉPLACER VERS LE JOUEUR
# =========================================================

func move_towards_player(_delta: float):
	if not player:
		return
	
	# Direction vers le joueur
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0  # Garder le mouvement horizontal
	
	# Rotation pour faire face au joueur
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
	
	# Appliquer le mouvement
	velocity = direction * speed
	move_and_slide()

# =========================================================
# ATTAQUER LE JOUEUR
# =========================================================

func attack_player():
	if not player:
		return
	
	# Vérifier si l'ennemi est dans l'arbre
	if not is_inside_tree():
		return
	
	is_attacking = true
	
	# Tirer sur le joueur
	shoot()
	
	# Attendre avant la prochaine attaque
	if get_tree():
		await get_tree().create_timer(0.08).timeout
	is_attacking = false

func shoot():
	if not player or not bullet_scene:
		return
	
	# Son du tir
	if gun_sound:
		gun_sound.pitch_scale = randf_range(0.98, 1.02)
		if gun_sound.playing:
			gun_sound.stop()
		gun_sound.play()
	
	# Direction vers le joueur
	var direction = (player.global_position - global_position).normalized()
	var spawn_pos = global_position + Vector3(0, 1.5, 0)
	
	# Créer la balle
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	bullet.look_at_from_position(spawn_pos, spawn_pos + direction, Vector3.UP)
	bullet.global_position = spawn_pos
	
	get_tree().current_scene.add_child(bullet)

func respawn():
	# Respawn un peu plus loin de la position précédente
	var offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	global_position = initial_position + offset
	velocity = Vector3.ZERO
	is_attacking = false

extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var anim_player: AnimationPlayer = null
@onready var skeleton: Skeleton3D = null

# Animation names
const ANIM_IDLE = "Armature_003|mixamo_com|Layer0"
const ANIM_RUN = "run"
const ANIM_SHOOT = "crounch tirr"
const ANIM_DEAD = "dead"

# =========================================================
# VARIABLES
# =========================================================

var speed := 4.0
var detection_range := 60.0
var attack_range := 3.0
var shoot_range := 30.0
var damage := 15.0

var player: CharacterBody3D
var is_attacking := false
var can_attack := true
var attack_cooldown := 0.8
var health := 150
var is_dead := false

var current_anim := ""

# =========================================================
# READY
# =========================================================

func _ready():
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
	
	# Trouver l'AnimationPlayer
	anim_player = find_child("AnimationPlayer", true, false)
	
	# Trouver le Skeleton3D principal
	skeleton = find_child("Skeleton3D", true, false)
	
	if anim_player:
		print("AnimationPlayer found: ", anim_player.name)
		print("Available animations: ", anim_player.get_animation_list())
	
	# Jouer l'animation idle par défaut
	play_idle()

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return
	
	if not player:
		find_player()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Si le joueur est proche, le chasser
	if distance_to_player <= detection_range:
		# Si assez proche pour tirer
		if distance_to_player <= shoot_range:
			# Si très proche, attaquer au corps à corps
			if distance_to_player <= attack_range:
				attack_player()
			else:
				# Tirer sur le joueur
				shoot_at_player()
		else:
			# Se déplacer vers le joueur
			move_towards_player(delta)
			play_run()
	else:
		# Animation idle si le joueur est loin
		play_idle()
		velocity = Vector3.ZERO
	
	move_and_slide()

# =========================================================
# TROUVER LE JOUEUR
# =========================================================

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# =========================================================
# SE DÉPLACER VERS LE JOUEUR
# =========================================================

func move_towards_player(_delta):
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
	
	velocity = direction * speed

# =========================================================
# TIRER SUR LE JOUEUR
# =========================================================

func shoot_at_player():
	if not can_attack or is_dead:
		return
	
	can_attack = false
	is_attacking = true
	
	# Animation de tir
	play_shoot()
	
	# Appliquer des dégâts au joueur (réduits à distance)
	if player and player.has_method("take_damage"):
		player.take_damage(damage * 0.5)
	
	# Cooldown entre les tirs
	if get_tree():
		await get_tree().create_timer(attack_cooldown).timeout
	
	can_attack = true
	is_attacking = false

# =========================================================
# ATTAQUER LE JOUEUR
# =========================================================

func attack_player():
	if not can_attack or is_dead:
		return
	
	can_attack = false
	is_attacking = true
	
	# Animation d'attaque
	play_shoot()
	
	# Appliquer des dégâts au joueur (pleins dégâts au corps à corps)
	if player and player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Cooldown entre les attaques
	if get_tree():
		await get_tree().create_timer(attack_cooldown).timeout
	
	can_attack = true
	is_attacking = false

# =========================================================
# ANIMATIONS
# =========================================================

func play_idle():
	if anim_player and anim_player.has_animation(ANIM_IDLE):
		if current_anim != "idle":
			anim_player.play(ANIM_IDLE)
			anim_player.speed_scale = 0.5
			current_anim = "idle"
	elif anim_player and anim_player.get_animation_list().size() > 0:
		# Fallback: utiliser la première animation disponible
		var anim_name = anim_player.get_animation_list()[0]
		if current_anim != "idle":
			anim_player.play(anim_name)
			anim_player.speed_scale = 0.3
			current_anim = "idle"

func play_run():
	if anim_player and anim_player.has_animation(ANIM_RUN):
		if current_anim != "run":
			anim_player.play(ANIM_RUN)
			anim_player.speed_scale = 1.5
			current_anim = "run"
	else:
		# Fallback: utiliser l'animation idle avec vitesse augmentée
		play_idle()
		if anim_player:
			anim_player.speed_scale = 1.0

func play_shoot():
	if anim_player and anim_player.has_animation(ANIM_SHOOT):
		if current_anim != "shoot":
			anim_player.play(ANIM_SHOOT)
			anim_player.speed_scale = 1.0
			current_anim = "shoot"
	else:
		# Fallback: utiliser l'animation idle
		play_idle()

func play_dead():
	if anim_player and anim_player.has_animation(ANIM_DEAD):
		if current_anim != "dead":
			anim_player.play(ANIM_DEAD)
			anim_player.speed_scale = 1.0
			current_anim = "dead"
	else:
		# Fallback: utiliser l'animation idle
		play_idle()

# =========================================================
# DÉGÂTS
# =========================================================

func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	
	if health <= 0:
		die()

# =========================================================
# MOURIR
# =========================================================

func die():
	if is_dead:
		return
	
	is_dead = true
	
	# Animation de mort
	play_dead()
	
	if get_tree():
		await get_tree().create_timer(3.0).timeout
	queue_free()

# =========================================================
# GETTERS
# =========================================================

func get_health() -> int:
	return health

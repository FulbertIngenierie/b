extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var anim_player = $ZombieModel/AnimationPlayer

# =========================================================
# VARIABLES
# =========================================================

var speed := 3.0
var detection_range := 50.0
var attack_range := 2.0
var damage := 10.0

var player: CharacterBody3D
var is_attacking := false
var can_attack := true
var attack_cooldown := 1.0
var health := 100
var is_dead := false

var current_anim := ""

# =========================================================
# READY
# =========================================================

func _ready():
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
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
		move_towards_player(delta)
		
		# Si assez proche pour attaquer
		if distance_to_player <= attack_range:
			attack_player()
		else:
			# Animation de marche
			play_walk()
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
		# Rotation supplémentaire de 180 degrés pour corriger l'orientation du modèle
		rotation_degrees.y += 180
	
	velocity = direction * speed

# =========================================================
# ATTAQUER LE JOUEUR
# =========================================================

func attack_player():
	if not can_attack or is_dead:
		return
	
	can_attack = false
	is_attacking = true
	
	# Animation d'attaque
	play_attack()
	
	# Appliquer des dégâts au joueur
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
	if anim_player and anim_player.has_animation("slow_z4_qc_skeleton|slow_z4_qc_skeleton"):
		if current_anim != "idle":
			anim_player.play("slow_z4_qc_skeleton|slow_z4_qc_skeleton")
			current_anim = "idle"

func play_walk():
	if anim_player and anim_player.has_animation("slow_z4_qc_skeleton|slow_z4_qc_skeleton"):
		if current_anim != "walk":
			anim_player.play("slow_z4_qc_skeleton|slow_z4_qc_skeleton")
			anim_player.speed_scale = 1.5
			current_anim = "walk"

func play_attack():
	if anim_player and anim_player.has_animation("slow_z4_qc_skeleton|slow_z4_qc_skeleton"):
		if current_anim != "attack":
			anim_player.play("slow_z4_qc_skeleton|slow_z4_qc_skeleton")
			anim_player.speed_scale = 2.0
			current_anim = "attack"

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
	
	if anim_player:
		anim_player.stop()
	
	if get_tree():
		await get_tree().create_timer(2.0).timeout
	queue_free()

# =========================================================
# GETTERS
# =========================================================

func get_health() -> int:
	return health

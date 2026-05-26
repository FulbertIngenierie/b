extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var head = null
@onready var anim_player = $AnimationPlayer
@onready var gun_sound = null

# =========================================================
# GUN TIP
# =========================================================

@onready var gun_tip = $Armature/Skeleton3D

# =========================================================
# SCENES
# =========================================================

@export var bullet_scene: PackedScene = preload("res://Bullet.tscn")
@export var hit_effect_scene: PackedScene = preload("res://HitEffect.tscn")
@export var bullet_impact_scene: PackedScene = preload("res://BulletImpact.tscn")

# =========================================================
# VARIABLES DE COMBAT
# =========================================================

var health := 100
var max_health := 100
var ammo := 30
var max_ammo := 30
var fire_rate := 0.08
var reload_time := 2.5
var damage := 25.0
var speed := 6.0
var detection_range := 80.0
var attack_range := 20.0

var can_shoot := true
var is_reloading := false
var is_dead := false
var is_crouching := false
var is_prone := false

var current_state := CombatState.PATROL
var cover_position := Vector3.ZERO
var retreat_position := Vector3.ZERO
var last_seen_position := Vector3.ZERO
var time_since_last_seen := 0.0
var enemy_id := 0
var initial_position := Vector3.ZERO  # Position initiale pour défendre

var player: Node3D = null
var current_anim := ""

# =========================================================
# ÉTATS DE COMBAT
# =========================================================

enum CombatState {
	PATROL,
	CHASE,
	ATTACK,
	COVER,
	RETREAT
}

# =========================================================
# READY
# =========================================================

func _ready():
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
	play_idle()
	
	# Assign a unique ID based on position
	enemy_id = hash(str(global_position))
	
	# Sauvegarder la position initiale pour défendre
	initial_position = global_position

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Mise à jour du temps depuis la dernière vue
	if can_see_player():
		last_seen_position = player.global_position
		time_since_last_seen = 0.0
	
	time_since_last_seen += delta
	
	# Gestion des états
	match current_state:
		CombatState.PATROL:
			handle_patrol(delta, distance_to_player)
		CombatState.CHASE:
			handle_chase(delta, distance_to_player)
		CombatState.ATTACK:
			handle_attack(delta, distance_to_player)
		CombatState.COVER:
			handle_cover(delta, distance_to_player)
		CombatState.RETREAT:
			handle_retreat(delta, distance_to_player)

# =========================================================
# TROUVER LE JOUEUR
# =========================================================

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# =========================================================
# VOIR LE JOUEUR
# =========================================================

func can_see_player():
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	# Désactivé le raycast - vérifier seulement la distance
	return true

# =========================================================
# GESTION DES ÉTATS
# =========================================================

func handle_patrol(_delta, _distance_to_player):
	if can_see_player():
		current_state = CombatState.ATTACK
		return
	
	# Défendre la position initiale - ne pas bouger
	var distance_from_initial = global_position.distance_to(initial_position)
	
	# Si trop loin de la position initiale, retourner
	if distance_from_initial > 2.0:
		var direction = (initial_position - global_position).normalized()
		direction.y = 0
		velocity = direction * speed
		play_walk()
	else:
		velocity = Vector3.ZERO
		play_idle()
	
	move_and_slide()

func handle_chase(delta, distance_to_player):
	if not can_see_player() and time_since_last_seen > 5.0:
		current_state = CombatState.PATROL
		return
	
	if distance_to_player <= attack_range:
		current_state = CombatState.ATTACK
		return
	
	move_towards_player(delta)
	look_at_player()
	play_run()
	move_and_slide()

func handle_attack(_delta, distance_to_player):
	if not can_see_player():
		current_state = CombatState.COVER
		return
	
	if distance_to_player > attack_range * 1.5:
		current_state = CombatState.CHASE
		return
	
	# Tirer sur le joueur plus agressivement
	look_at_player()
	play_idle()
	if can_shoot:
		shoot_at_player()
	
	# Mouvement latéral pour esquiver les tirs du joueur
	var strafe_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	velocity = strafe_dir * speed * 0.3
	
	# Parfois se mettre à couvert
	if health < 50 and randf() < 0.02:
		current_state = CombatState.COVER
		find_cover_position()
	
	# Parfois reculer
	if randf() < 0.01:
		current_state = CombatState.RETREAT
	
	move_and_slide()

func handle_cover(_delta, _distance_to_player):
	# Si pas de position de couverture, retourner à l'attaque
	if cover_position == Vector3.ZERO:
		current_state = CombatState.ATTACK
		is_crouching = false
		return
	
	# Se déplacer vers la position de couverture
	var direction = (cover_position - global_position).normalized()
	direction.y = 0
	velocity = direction * speed * 1.5
	
	move_and_slide()
	play_run()
	
	# S'accroupir quand à couverture
	is_crouching = true
	is_prone = false
	
	# Vérifier si on est à couverture
	if global_position.distance_to(cover_position) < 2.0:
		play_idle()
		# Attendre un moment
		await get_tree().create_timer(2.0).timeout
		
		# Retourner à l'attaque
		if can_see_player():
			current_state = CombatState.ATTACK
			is_crouching = false
		else:
			current_state = CombatState.CHASE
			is_crouching = false

func handle_retreat(_delta, distance_to_player):
	# Reculer loin du joueur
	var direction = (global_position - player.global_position).normalized()
	direction.y = 0
	velocity = direction * speed * 1.5
	
	move_and_slide()
	play_run()
	
	# Après avoir reculé, retourner à l'attaque
	if distance_to_player > attack_range * 2.0:
		await get_tree().create_timer(1.0).timeout
		current_state = CombatState.ATTACK

# =========================================================
# TROUVER UNE POSITION DE COUVERTURE
# =========================================================

func find_cover_position():
	var random_offset = Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	cover_position = global_position + random_offset

# =========================================================
# SE DÉPLACER VERS LE JOUEUR
# =========================================================

func move_towards_player(delta):
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	velocity = direction * speed

# =========================================================
# REGARDER LE JOUEUR
# =========================================================

func look_at_player():
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
		# Rotation supplémentaire pour les modèles Mixamo (orientés vers -Z)
		rotate_y(PI)
	
	velocity = direction * speed

# =========================================================
# TIRER SUR LE JOUEUR
# =========================================================

func shoot_at_player():
	if not can_shoot or ammo <= 0 or is_dead:
		return
	
	# Vérifier si le joueur est toujours dans l'arbre
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
	
	# Vérifier si l'ennemi est dans l'arbre
	if not is_inside_tree():
		return
	
	can_shoot = false
	ammo -= 1
	
	# Son du tir
	if gun_sound:
		gun_sound.pitch_scale = randf_range(0.98, 1.02)
		if gun_sound.playing:
			gun_sound.stop()
		gun_sound.play()
	
	# Créer la balle
	shoot()
	
	# Recharger après avoir vidé le chargeur
	if ammo <= 0:
		reload()
	
	# Cooldown entre les tirs
	if get_tree():
		await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

# =========================================================
# TIRER
# =========================================================

func shoot():
	if gun_tip == null or bullet_scene == null:
		return
	
	# Vérifier si gun_tip est dans l'arbre
	if not gun_tip.is_inside_tree():
		return
	
	# Direction vers le joueur (pour que les tirs cadrent)
	var direction = (player.global_position - gun_tip.global_position).normalized()
	var spawn_pos = gun_tip.global_position
	
	# Petit offset devant le canon
	spawn_pos += direction * 0.5
	
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	
	# Utiliser look_at_from_position car la balle n'est pas encore dans l'arbre
	bullet.look_at_from_position(spawn_pos, spawn_pos + direction, Vector3.UP)
	bullet.global_position = spawn_pos
	
	get_tree().current_scene.add_child(bullet)

# =========================================================
# RECHARGER
# =========================================================

func reload():
	if is_dead:
		return
	
	await get_tree().create_timer(2.5).timeout
	ammo = max_ammo

# =========================================================
# PRENDRE DES DÉGÂTS
# =========================================================

func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	
	# Effet de particules rouge
	if hit_effect_scene:
		var hit_effect = hit_effect_scene.instantiate()
		add_child(hit_effect)
		hit_effect.global_position = global_position + Vector3(0, 1.5, 0)
		hit_effect.emitting = true
		hit_effect.one_shot = true
	
	if health <= 0:
		die()

# =========================================================
# MOURIR
# =========================================================

func die():
	if is_dead:
		return
	
	is_dead = true
	
	# Effet de mort
	if hit_effect_scene:
		var hit_effect = hit_effect_scene.instantiate()
		hit_effect.global_position = global_position + Vector3(0, 1.5, 0)
		get_tree().current_scene.add_child(hit_effect)
		hit_effect.emitting = true
	
	# Attendre un moment avant de respawn
	await get_tree().create_timer(3.0).timeout
	
	# Respawn dans une nouvelle position
	respawn()

func respawn():
	# Réinitialiser la santé et l'état
	is_dead = false
	health = max_health
	ammo = max_ammo
	current_state = CombatState.PATROL
	
	# Respawn un peu plus loin de la position précédente
	var offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	global_position = initial_position + offset
	
	# Réinitialiser la vélocité
	velocity = Vector3.ZERO
	
	# Jouer l'animation idle
	play_idle()

# =========================================================
# ANIMATIONS
# =========================================================

func play_idle():
	if anim_player:
		if anim_player.has_animation("mixamo_com_006"):
			anim_player.play("mixamo_com_006")
			anim_player.speed_scale = 1.0
			current_anim = "mixamo_com_006"

func play_walk():
	if anim_player:
		if anim_player.has_animation("mixamo_com"):
			anim_player.play("mixamo_com")
			anim_player.speed_scale = 1.2
			current_anim = "mixamo_com"

func play_run():
	if anim_player:
		if anim_player.has_animation("mixamo_com_004"):
			anim_player.play("mixamo_com_004")
			anim_player.speed_scale = 1.3
			current_anim = "mixamo_com_004"

func play_jump():
	if anim_player:
		if anim_player.has_animation("mixamo_com_005"):
			anim_player.play("mixamo_com_005")
			anim_player.speed_scale = 1.0
			current_anim = "mixamo_com_005"

# =========================================================
# GETTERS
# =========================================================

func get_health():
	return health

func get_ammo():
	return ammo

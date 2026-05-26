extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

@onready var head = $Head
@onready var anim_player = $SoldierModel/AnimationPlayer
@onready var gun_sound = $ShootSound

# =========================================================
# GUN TIP
# =========================================================

@onready var gun_tip = $Head

# =========================================================
# SCENES
# =========================================================

var bullet_scene = preload("res://Bullet.tscn")
var impact_scene = preload("res://Impact.tscn")
var hit_effect_scene = preload("res://HitEffect.tscn")
var bullet_impact_scene = preload("res://BulletImpact.tscn")

# =========================================================
# VARIABLES
# =========================================================

var speed := 6.0
var detection_range := 100.0
var attack_range := 50.0
var damage := 0.1

var player: CharacterBody3D
var is_attacking := true
var can_shoot := true
var fire_rate := 0.05
var ammo := 30
var max_ammo := 30
var health := 100
var is_dead := false

var current_anim := ""

# =========================================================
# POSTURE
# =========================================================

var is_crouching := false
var is_prone := false
var standing_height := 1.8
var crouch_height := 1.0
var prone_height := 0.5
var initial_head_height := 0.0

# =========================================================
# COMBAT STATE
# =========================================================

enum CombatState {
	PATROL,
	CHASE,
	ATTACK,
	COVER,
	RETREAT
}

var current_state := CombatState.PATROL
var cover_position := Vector3.ZERO
var retreat_position := Vector3.ZERO
var last_seen_position := Vector3.ZERO
var time_since_last_seen := 0.0
var enemy_id := 0
var initial_position := Vector3.ZERO  # Position initiale pour défendre

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
	
	# Initialiser la hauteur de la tête
	if head:
		initial_head_height = head.position.y

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return
	
	if not player:
		find_player()
		# Si pas de joueur, patrouille simple
		handle_patrol(delta, 0.0)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Mise à jour du temps depuis la dernière vue
	if can_see_player():
		last_seen_position = player.global_position
		time_since_last_seen = 0.0
	else:
		time_since_last_seen += delta
	
	# Machine à états de combat
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
	
	# Update height based on posture
	update_posture(delta)

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
# VOIR LE JOUEUR
# =========================================================

func can_see_player():
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	# Utiliser un raycast pour vérifier si l'ennemi peut vraiment voir le joueur
	var space_state = get_world_3d().direct_space_state
	var ray_end = player.global_position + Vector3(0, 1.5, 0)
	var ray_start = global_position + Vector3(0, 1.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	# Si le raycast touche le joueur, l'ennemi peut le voir
	if result and result.collider == player:
		return true
	
	# Sinon, vérifier si le joueur est proche (détection de proximité)
	if distance < 10.0:
		return true
	
	return false

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
	move_and_slide()

func handle_attack(_delta, distance_to_player):
	# Vérifier si self est dans l'arbre
	if not is_inside_tree():
		return
	
	if not can_see_player():
		current_state = CombatState.COVER
		return
	
	if distance_to_player > attack_range * 1.5:
		current_state = CombatState.CHASE
		return
	
	# Tirer sur le joueur plus agressivement
	look_at_player()
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
	
	# S'accroupir quand à couverture
	is_crouching = true
	is_prone = false
	
	# Vérifier si on est à couverture
	if global_position.distance_to(cover_position) < 2.0:
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
	
	# Après avoir reculé, retourner à l'attaque
	if distance_to_player > attack_range * 2.0:
		await get_tree().create_timer(1.0).timeout
		current_state = CombatState.ATTACK

# =========================================================
# TROUVER UNE POSITION DE COUVERTURE
# =========================================================

func find_cover_position():
	# Trouver une position derrière un obstacle
	var direction = (global_position - player.global_position).normalized()
	var cover_offset = direction * 10.0
	cover_position = global_position + cover_offset
	move_and_slide()

# =========================================================
# UPDATE POSTURE
# =========================================================

func update_posture(delta):
	var target_height := standing_height
	if is_prone:
		target_height = prone_height
	elif is_crouching:
		target_height = crouch_height
	
	# Smooth height transition - utiliser la hauteur initiale comme base
	if head:
		var current_height = head.position.y
		var new_height = lerp(current_height, target_height, 10.0 * delta)
		
		# Si c'est la première frame, utiliser la hauteur initiale
		if initial_head_height == 0.0:
			head.position.y = standing_height
		else:
			head.position.y = new_height

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

# =========================================================
# TIRER SUR LE JOUEUR
# =========================================================

func shoot_at_player():
	if not can_shoot or ammo <= 0 or is_dead:
		return
	
	# Vérifier si le joueur est toujours dans l'arbre
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
	
	can_shoot = false
	ammo -= 1
	
	# Son du tir
	if gun_sound:
		gun_sound.pitch_scale = randf_range(0.98, 1.02)
		if gun_sound.playing:
			gun_sound.stop()
		gun_sound.play()
	
	# Animation de tir
	if anim_player:
		if anim_player.has_animation("RIG_UE5_Comando_AK_Fire"):
			anim_player.speed_scale = 1.0
			anim_player.stop()
			anim_player.play("RIG_UE5_Comando_AK_Fire")
			current_anim = "RIG_UE5_Comando_AK_Fire"
		elif anim_player.has_animation("Shoot"):
			anim_player.speed_scale = 1.0
			anim_player.stop()
			anim_player.play("Shoot")
			current_anim = "Shoot"
	
	# Créer la balle
	shoot()
	
	# Recharger après avoir vidé le chargeur
	if ammo <= 0:
		reload()
	
	# Cooldown entre les tirs
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(fire_rate).timeout
		can_shoot = true
	else:
		can_shoot = true

# =========================================================
# TIR
# =========================================================

func shoot():
	if gun_tip == null or bullet_scene == null:
		return
	
	# Vérifier si gun_tip est dans l'arbre
	if not gun_tip.is_inside_tree():
		return
	
	# Vérifier si self est dans l'arbre
	if not is_inside_tree():
		return
	
	# Vérifier si get_tree() est valide
	if not get_tree():
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
	
	call_deferred("_add_bullet", bullet)
	
	# Raycast pour les impacts
	var space_state = get_world_3d().direct_space_state
	var ray_end = spawn_pos + direction * 1000.0
	var query = PhysicsRayQueryParameters3D.create(spawn_pos, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(damage)
		create_impact(result.position, result.normal)

# =========================================================
# AJOUTER BALLE
# =========================================================

func _add_bullet(bullet):
	if is_inside_tree() and get_tree():
		get_tree().current_scene.add_child(bullet)

# =========================================================
# IMPACT
# =========================================================

func create_impact(pos, normal):
	if impact_scene == null:
		return
	
	# Vérifier si get_tree() est valide
	if not get_tree():
		return
	
	var impact = impact_scene.instantiate()
	if impact:
		get_tree().current_scene.add_child(impact)
		impact.global_position = pos + normal * 0.02
		
		if normal != Vector3.ZERO:
			impact.look_at(pos + normal, Vector3.UP)
	
	# Ajouter des particules d'impact
	if bullet_impact_scene:
		var particles = bullet_impact_scene.instantiate()
		if particles:
			get_tree().current_scene.add_child(particles)
			particles.global_position = pos
			particles.look_at(pos + normal, Vector3.UP)
			particles.emitting = true
			particles.one_shot = true
	
	remove_impact_later(impact)

# =========================================================
# RETIRER IMPACT
# =========================================================

func remove_impact_later(impact):
	await get_tree().create_timer(2.0).timeout
	if impact:
		impact.queue_free()

# =========================================================
# RECHARGER
# =========================================================

func reload():
	if is_dead:
		return
	
	if anim_player:
		if anim_player.has_animation("RIG_UE5_Comando_AK_Reload"):
			anim_player.play("RIG_UE5_Comando_AK_Reload")
		elif anim_player.has_animation("Reload"):
			anim_player.play("Reload")
	
	await get_tree().create_timer(2.5).timeout
	ammo = max_ammo

# =========================================================
# IDLE
# =========================================================

func play_idle():
	if anim_player:
		if anim_player.has_animation("RIG_UE5_Comando_AK_Idle"):
			anim_player.play("RIG_UE5_Comando_AK_Idle")
			current_anim = "RIG_UE5_Comando_AK_Idle"
		elif anim_player.has_animation("Idle"):
			anim_player.play("Idle")
			current_anim = "Idle"

# =========================================================
# GETTERS
# =========================================================

func get_health():
	return health

func get_ammo():
	return ammo

# =========================================================
# DÉGÂTS
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
	health = 100
	ammo = max_ammo
	current_state = CombatState.PATROL
	
	# Respawn un peu plus loin de la position précédente
	var offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	global_position = initial_position + offset
	
	# Réinitialiser la vélocité
	velocity = Vector3.ZERO
	
	# Jouer l'animation idle
	play_idle()

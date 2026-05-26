extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

var anim_player: AnimationPlayer = null
@onready var gun_sound = $ShootSound

# =========================================================
# GUN TIP — position calculée au bout du fusil
# =========================================================

var gun_tip_offset := Vector3(0.3, 1.2, -0.8)

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

var speed := 4.0
var run_speed := 7.0
var detection_range := 80.0
var attack_range := 45.0
var damage := 10.0

var player: CharacterBody3D
var is_attacking := true
var can_shoot := true
var fire_rate := 0.15
var ammo := 30
var max_ammo := 30
var health := 100
var is_dead := false

var current_anim := ""

# =========================================================
# PATROL
# =========================================================

var patrol_points: Array[Vector3] = []
var current_patrol_index := 0
var patrol_wait_timer := 0.0
var patrol_wait_time := 3.0
var patrol_radius := 15.0

# =========================================================
# COMBAT STATE
# =========================================================

enum CombatState {
	PATROL,
	CHASE,
	ATTACK,
	COVER,
	RETREAT,
	REPOSITION
}

var current_state := CombatState.PATROL
var cover_position := Vector3.ZERO
var last_seen_position := Vector3.ZERO
var time_since_last_seen := 0.0
var enemy_id := 0
var initial_position := Vector3.ZERO

# =========================================================
# COORDINATION D'ÉQUIPE
# =========================================================

var reposition_timer := 0.0
var reposition_interval := 8.0
var reposition_target := Vector3.ZERO
var gravity := 9.8

# =========================================================
# ANIMATION NAMES CACHE
# =========================================================

var anim_idle := ""
var anim_walk := ""
var anim_run := ""
var anim_shoot := ""
var anim_shoot_walk := ""
var anim_reload := ""
var anim_die := ""
var all_anims: PackedStringArray = []

# =========================================================
# READY
# =========================================================

func _ready():
	_init_animation_player()
	_cache_animation_names()
	_generate_patrol_points()
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
	play_idle()
	
	enemy_id = hash(str(global_position))
	initial_position = global_position

func _init_animation_player():
	if has_node("AnimationPlayer"):
		anim_player = $AnimationPlayer
		if anim_player.get_animation_list().size() == 0 and has_node("Model"):
			var model_anim = $Model.find_child("AnimationPlayer", true, false)
			if model_anim and model_anim.get_animation_list().size() > 0:
				anim_player = model_anim
	elif has_node("Model"):
		var model_anim = $Model.find_child("AnimationPlayer", true, false)
		if model_anim:
			anim_player = model_anim
	else:
		anim_player = find_child("AnimationPlayer", true, false)

func _cache_animation_names():
	if not anim_player:
		return
	all_anims = anim_player.get_animation_list()
	anim_idle = _find_anim(["idle", "Idle", "IDLE", "Armature_002|mixamo"])
	anim_walk = _find_anim(["walk", "Walk", "WALK", "Armature_006|mixamo", "Armature_007|mixamo", "marche"])
	anim_run = _find_anim(["run", "Run", "RUN", "course"])
	anim_shoot = _find_anim(["tir ", "tir avant ", "shoot", "fire", "Shoot", "Fire"])
	anim_shoot_walk = _find_anim(["tir avant ", "tir ", "shoot_walk", "fire_walk"])
	anim_reload = _find_anim(["recharge", "reload", "Reload"])
	anim_die = _find_anim(["death", "die", "mort", "Death"])

func _find_anim(candidates: Array) -> String:
	for name in candidates:
		for a in all_anims:
			if a.to_lower().contains(name.to_lower()):
				return a
	return ""

func _generate_patrol_points():
	patrol_points.clear()
	for i in range(4):
		var angle = (PI * 2.0 / 4.0) * i
		var offset = Vector3(cos(angle) * patrol_radius, 0, sin(angle) * patrol_radius)
		patrol_points.append(initial_position + offset)

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if not player:
		find_player()
	
	var distance_to_player := 999.0
	if player and is_instance_valid(player):
		distance_to_player = global_position.distance_to(player.global_position)
	
	if can_see_player():
		last_seen_position = player.global_position
		time_since_last_seen = 0.0
	else:
		time_since_last_seen += delta
	
	reposition_timer += delta
	
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
		CombatState.REPOSITION:
			handle_reposition(delta, distance_to_player)
	
	move_and_slide()

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

func can_see_player() -> bool:
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + Vector3(0, 1.5, 0)
	var ray_end = player.global_position + Vector3(0, 1.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		return true
	
	if distance < 8.0:
		return true
	
	return false

# =========================================================
# GESTION DES ÉTATS
# =========================================================

func handle_patrol(delta, _distance_to_player):
	if can_see_player():
		current_state = CombatState.ATTACK
		return
	
	if time_since_last_seen < 5.0 and last_seen_position != Vector3.ZERO:
		current_state = CombatState.CHASE
		return
	
	if patrol_points.is_empty():
		play_idle()
		velocity.x = 0
		velocity.z = 0
		return
	
	var target = patrol_points[current_patrol_index]
	var dist = global_position.distance_to(target)
	
	if dist < 2.0:
		patrol_wait_timer += delta
		velocity.x = 0
		velocity.z = 0
		play_idle()
		
		if patrol_wait_timer >= patrol_wait_time:
			patrol_wait_timer = 0.0
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		var direction = (target - global_position).normalized()
		direction.y = 0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if direction.length() > 0:
			look_at(global_position + direction, Vector3.UP)
			rotate_y(PI)
		
		play_walk()

func handle_chase(delta, distance_to_player):
	if can_see_player():
		if distance_to_player <= attack_range:
			current_state = CombatState.ATTACK
			return
	elif time_since_last_seen > 8.0:
		current_state = CombatState.PATROL
		return
	
	var target = last_seen_position if last_seen_position != Vector3.ZERO else player.global_position
	var direction = (target - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * run_speed
	velocity.z = direction.z * run_speed
	
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
		rotate_y(PI)
	
	play_run()
	
	if can_shoot and can_see_player():
		shoot_at_player()

func handle_attack(_delta, distance_to_player):
	if not is_inside_tree():
		return
	
	if not can_see_player() and time_since_last_seen > 2.0:
		current_state = CombatState.CHASE
		return
	
	if distance_to_player > attack_range * 1.5:
		current_state = CombatState.CHASE
		return
	
	look_at_player()
	
	if can_shoot:
		shoot_at_player()
	
	var strafe_dir = Vector3.ZERO
	var strafe_rand = sin(Time.get_ticks_msec() * 0.001 + enemy_id * 0.1)
	strafe_dir = global_transform.basis.x * strafe_rand * speed * 0.4
	velocity.x = strafe_dir.x
	velocity.z = strafe_dir.z
	
	if health < 40 and randf() < 0.01:
		current_state = CombatState.COVER
		find_cover_position()
	
	if reposition_timer >= reposition_interval and randf() < 0.02:
		current_state = CombatState.REPOSITION
		_pick_reposition_target()
		reposition_timer = 0.0

func handle_cover(_delta, _distance_to_player):
	if cover_position == Vector3.ZERO:
		current_state = CombatState.ATTACK
		return
	
	var direction = (cover_position - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * run_speed
	velocity.z = direction.z * run_speed
	
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
		rotate_y(PI)
	
	play_run()
	
	if global_position.distance_to(cover_position) < 2.0:
		velocity.x = 0
		velocity.z = 0
		cover_position = Vector3.ZERO
		if is_inside_tree() and get_tree():
			await get_tree().create_timer(2.0).timeout
		current_state = CombatState.ATTACK

func handle_retreat(_delta, distance_to_player):
	if not player:
		current_state = CombatState.PATROL
		return
	
	var direction = (global_position - player.global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * run_speed
	velocity.z = direction.z * run_speed
	
	play_run()
	
	if distance_to_player > attack_range * 2.0:
		current_state = CombatState.ATTACK

func handle_reposition(_delta, _distance_to_player):
	if reposition_target == Vector3.ZERO:
		current_state = CombatState.ATTACK
		return
	
	var direction = (reposition_target - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * run_speed
	velocity.z = direction.z * run_speed
	
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
		rotate_y(PI)
	
	play_run()
	
	if global_position.distance_to(reposition_target) < 2.0:
		reposition_target = Vector3.ZERO
		current_state = CombatState.ATTACK

func _pick_reposition_target():
	if not player:
		return
	var allies = get_tree().get_nodes_in_group("enemies")
	var avg_pos := Vector3.ZERO
	var count := 0
	for ally in allies:
		if ally != self and is_instance_valid(ally) and not ally.is_dead:
			avg_pos += ally.global_position
			count += 1
	if count > 0:
		avg_pos /= count
	
	var to_player = (player.global_position - global_position).normalized()
	var flank_dir = Vector3(-to_player.z, 0, to_player.x)
	if randf() < 0.5:
		flank_dir = -flank_dir
	
	reposition_target = global_position + flank_dir * randf_range(5, 12) + to_player * randf_range(2, 6)

# =========================================================
# TROUVER UNE POSITION DE COUVERTURE
# =========================================================

func find_cover_position():
	if not player:
		return
	var direction = (global_position - player.global_position).normalized()
	var lateral = Vector3(-direction.z, 0, direction.x)
	if randf() < 0.5:
		lateral = -lateral
	cover_position = global_position + direction * 8.0 + lateral * randf_range(-5, 5)

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
		rotate_y(PI)

# =========================================================
# TIRER SUR LE JOUEUR
# =========================================================

func shoot_at_player():
	if not can_shoot or ammo <= 0 or is_dead:
		return
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
	
	can_shoot = false
	ammo -= 1
	
	if gun_sound and gun_sound.stream:
		gun_sound.pitch_scale = randf_range(0.95, 1.05)
		if gun_sound.playing:
			gun_sound.stop()
		gun_sound.play()
	
	if anim_player:
		if anim_shoot != "" and current_anim != anim_shoot:
			anim_player.speed_scale = 1.0
			anim_player.stop()
			anim_player.play(anim_shoot)
			current_anim = anim_shoot
	
	shoot()
	
	if ammo <= 0:
		reload()
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(fire_rate).timeout
		can_shoot = true
	else:
		can_shoot = true

# =========================================================
# CALCUL POSITION GUN TIP
# =========================================================

func get_gun_tip_position() -> Vector3:
	return global_position + global_transform.basis * gun_tip_offset

# =========================================================
# TIR
# =========================================================

func shoot():
	if bullet_scene == null:
		return
	if not is_inside_tree() or not get_tree():
		return
	if not player or not is_instance_valid(player):
		return
	
	var spawn_pos = get_gun_tip_position()
	var target_pos = player.global_position + Vector3(0, 1.2, 0)
	
	# Dispersion réaliste
	var spread := 0.03
	target_pos += Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		randf_range(-spread, spread)
	) * global_position.distance_to(target_pos)
	
	var direction = (target_pos - spawn_pos).normalized()
	
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	bullet.look_at_from_position(spawn_pos, spawn_pos + direction, Vector3.UP)
	bullet.global_position = spawn_pos
	
	call_deferred("_add_bullet", bullet)
	
	# Raycast pour impacts
	var space_state = get_world_3d().direct_space_state
	var ray_end = spawn_pos + direction * 500.0
	var query = PhysicsRayQueryParameters3D.create(spawn_pos, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(damage)
		create_impact(result.position, result.normal)

func _add_bullet(bullet):
	if is_inside_tree() and get_tree():
		get_tree().current_scene.add_child(bullet)

# =========================================================
# IMPACT
# =========================================================

func create_impact(pos, normal):
	if impact_scene == null or not get_tree():
		return
	
	var impact = impact_scene.instantiate()
	if impact:
		get_tree().current_scene.add_child(impact)
		impact.global_position = pos + normal * 0.02
		if normal != Vector3.ZERO:
			impact.look_at(pos + normal, Vector3.UP)
	
	if bullet_impact_scene:
		var particles = bullet_impact_scene.instantiate()
		if particles:
			get_tree().current_scene.add_child(particles)
			particles.global_position = pos
			particles.look_at(pos + normal, Vector3.UP)
			particles.emitting = true
			particles.one_shot = true

# =========================================================
# RECHARGER
# =========================================================

func reload():
	if is_dead:
		return
	if anim_player and anim_reload != "":
		anim_player.play(anim_reload)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(2.5).timeout
	ammo = max_ammo

# =========================================================
# ANIMATIONS
# =========================================================

func play_idle():
	if not anim_player:
		return
	if current_anim == "idle":
		return
	if anim_idle != "":
		anim_player.play(anim_idle)
		anim_player.speed_scale = 1.0
		current_anim = "idle"
	elif all_anims.size() > 0:
		anim_player.play(all_anims[0])
		anim_player.speed_scale = 0.3
		current_anim = "idle"

func play_walk():
	if not anim_player:
		return
	if current_anim == "walk":
		return
	if anim_walk != "":
		anim_player.play(anim_walk)
		anim_player.speed_scale = 1.0
		current_anim = "walk"
	elif anim_run != "":
		anim_player.play(anim_run)
		anim_player.speed_scale = 0.7
		current_anim = "walk"
	elif all_anims.size() > 0:
		anim_player.play(all_anims[0])
		anim_player.speed_scale = 1.5
		current_anim = "walk"

func play_run():
	if not anim_player:
		return
	if current_anim == "run":
		return
	if anim_run != "":
		anim_player.play(anim_run)
		anim_player.speed_scale = 1.2
		current_anim = "run"
	elif anim_walk != "":
		anim_player.play(anim_walk)
		anim_player.speed_scale = 2.0
		current_anim = "run"
	elif all_anims.size() > 0:
		anim_player.play(all_anims[0])
		anim_player.speed_scale = 2.0
		current_anim = "run"

func play_shoot():
	if not anim_player:
		return
	if anim_shoot != "":
		anim_player.play(anim_shoot)
		anim_player.speed_scale = 1.0
		current_anim = "shoot"

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
	
	if hit_effect_scene and is_inside_tree():
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
	velocity = Vector3.ZERO
	
	if anim_player and anim_die != "":
		anim_player.play(anim_die)
	
	if hit_effect_scene and is_inside_tree():
		var hit_effect = hit_effect_scene.instantiate()
		hit_effect.global_position = global_position + Vector3(0, 1.5, 0)
		get_tree().current_scene.add_child(hit_effect)
		hit_effect.emitting = true
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(5.0).timeout
	
	respawn()

func respawn():
	is_dead = false
	health = 100
	ammo = max_ammo
	current_state = CombatState.PATROL
	current_patrol_index = 0
	
	var offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	global_position = initial_position + offset
	velocity = Vector3.ZERO
	play_idle()

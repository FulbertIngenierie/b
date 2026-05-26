extends CharacterBody3D

# =========================================================
# NODES
# =========================================================

var anim_player: AnimationPlayer = null
@onready var gun_sound = $ShootSound

# =========================================================
# GUN TIP
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

var speed := 3.0
var run_speed := 5.0
var detection_range := 80.0
var attack_range := 45.0
var damage := 10.0
var velocity_smoothing := 10.0

var player: CharacterBody3D
var can_shoot := true
var fire_rate := 0.2
var ammo := 30
var max_ammo := 30
var health := 100
var is_dead := false

var current_anim := ""

# =========================================================
# GRAVITY
# =========================================================

var gravity := 20.0

# =========================================================
# COMBAT STATE — style Call of Duty
# =========================================================

enum CombatState {
	IDLE_PATROL,
	ADVANCE,
	HOLD_POSITION,
	COVER,
	FLANK
}

var current_state := CombatState.IDLE_PATROL
var hold_timer := 0.0
var hold_duration := 12.0
var flank_target := Vector3.ZERO
var cover_position := Vector3.ZERO
var last_seen_position := Vector3.ZERO
var time_since_last_seen := 0.0
var enemy_id := 0
var initial_position := Vector3.ZERO
var has_seen_player := false
var stop_distance := 15.0

# =========================================================
# PATROL — avant de voir le joueur
# =========================================================

var patrol_points: Array[Vector3] = []
var current_patrol_index := 0
var patrol_wait_timer := 0.0
var patrol_wait_time := 12.0
var patrol_radius := 15.0

# =========================================================
# OBSTACLES / COUVERTURE
# =========================================================

var nearby_obstacles: Array = []
var cover_check_timer := 0.0
var cover_check_interval := 1.5
var is_behind_cover := false

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
var anim_crouch := ""
var all_anims: PackedStringArray = []

# =========================================================
# SMOOTH ROTATION
# =========================================================

var rotation_speed := 5.0
var target_rotation_y := 0.0

# =========================================================
# READY
# =========================================================

func _ready():
	_init_animation_player()
	_cache_animation_names()
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
	
	enemy_id = hash(str(global_position))
	initial_position = global_position
	
	_snap_to_ground()
	_generate_patrol_points()
	
	if anim_player:
		_ensure_animations_loop()
	
	_play_anim_continuous(anim_idle, "idle")

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
	
	anim_idle = _find_anim(["idle", "Idle", "IDLE", "Armature_002|mixamo", "Armature|mixamo.com|Layer0"])
	anim_walk = _find_anim(["walk", "Walk", "WALK", "Armature_006|mixamo", "Armature_007|mixamo", "marche", "Armature|mixamo"])
	anim_run = _find_anim(["run", "Run", "RUN", "course", "sprint"])
	anim_shoot = _find_anim(["tir ", "tir avant", "shoot", "fire", "Shoot", "Fire", "attack"])
	anim_shoot_walk = _find_anim(["tir avant", "tir ", "shoot_walk", "fire_walk", "walk_shoot"])
	anim_reload = _find_anim(["recharge", "reload", "Reload"])
	anim_die = _find_anim(["death", "die", "mort", "Death"])
	anim_crouch = _find_anim(["crouch", "cover", "Crouch", "Cover", "accroupi"])

func _find_anim(candidates: Array) -> String:
	for anim_name in candidates:
		for a in all_anims:
			if a.to_lower().contains(anim_name.to_lower()):
				return a
	return ""

func _ensure_animations_loop():
	if not anim_player:
		return
	var loop_anims = [anim_idle, anim_walk, anim_run, anim_crouch, anim_shoot]
	for a_name in loop_anims:
		if a_name == "":
			continue
		var anim = _get_animation_resource(a_name)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR

func _get_animation_resource(a_name: String) -> Animation:
	if not anim_player:
		return null
	var libs = anim_player.get_animation_library_list()
	for lib_name in libs:
		var lib = anim_player.get_animation_library(lib_name)
		var prefix = lib_name + "/" if lib_name != "" else ""
		var local_name = a_name.replace(prefix, "")
		if lib.has_animation(local_name):
			return lib.get_animation(local_name)
	if anim_player.has_animation(a_name):
		return anim_player.get_animation(a_name)
	return null

func _snap_to_ground():
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + Vector3(0, 5.0, 0)
	var ray_end = global_position + Vector3(0, -50.0, 0)
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y

func _generate_patrol_points():
	patrol_points.clear()
	for i in range(4):
		var angle = (PI * 2.0 / 4.0) * i
		var offset = Vector3(cos(angle) * patrol_radius, 0, sin(angle) * patrol_radius)
		var point = initial_position + offset
		point.y = initial_position.y
		patrol_points.append(point)

# =========================================================
# PHYSICS PROCESS
# =========================================================

func _physics_process(delta):
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if not player:
		find_player()
	
	var distance_to_player := 999.0
	if player and is_instance_valid(player):
		distance_to_player = global_position.distance_to(player.global_position)
	
	var sees_player = can_see_player()
	if sees_player:
		last_seen_position = player.global_position
		time_since_last_seen = 0.0
		if not has_seen_player:
			has_seen_player = true
			current_state = CombatState.ADVANCE
	else:
		time_since_last_seen += delta
	
	cover_check_timer += delta
	if cover_check_timer >= cover_check_interval:
		cover_check_timer = 0.0
		_scan_nearby_obstacles()
	
	match current_state:
		CombatState.IDLE_PATROL:
			_handle_idle_patrol(delta)
		CombatState.ADVANCE:
			_handle_advance(delta, distance_to_player)
		CombatState.HOLD_POSITION:
			_handle_hold_position(delta, distance_to_player)
		CombatState.COVER:
			_handle_cover(delta)
		CombatState.FLANK:
			_handle_flank(delta, distance_to_player)
	
	_apply_smooth_rotation(delta)
	move_and_slide()

func _apply_smooth_rotation(delta):
	var current_y = rotation.y
	var diff = wrapf(target_rotation_y - current_y, -PI, PI)
	rotation.y += diff * rotation_speed * delta

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
# SCAN OBSTACLES
# =========================================================

func _scan_nearby_obstacles():
	nearby_obstacles.clear()
	if not player:
		return
	var space_state = get_world_3d().direct_space_state
	var directions = [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(),
		Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized()
	]
	for dir in directions:
		var ray_start = global_position + Vector3(0, 1.0, 0)
		var ray_end = ray_start + dir * 12.0
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [self]
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		if result and result.collider is StaticBody3D:
			nearby_obstacles.append({
				"position": result.position,
				"normal": result.normal,
				"collider": result.collider,
				"distance": global_position.distance_to(result.position)
			})

func _find_best_cover() -> Vector3:
	if nearby_obstacles.is_empty() or not player:
		return Vector3.ZERO
	var best_pos := Vector3.ZERO
	var best_score := -999.0
	for obs in nearby_obstacles:
		var obs_pos: Vector3 = obs["position"]
		var obs_normal: Vector3 = obs["normal"]
		var behind_cover = obs_pos + obs_normal * 1.5
		behind_cover.y = global_position.y
		var to_player = (player.global_position - behind_cover).normalized()
		var cover_dot = obs_normal.dot(to_player)
		var dist_from_me = global_position.distance_to(behind_cover)
		var dist_from_player = player.global_position.distance_to(behind_cover)
		var score = cover_dot * 10.0 - dist_from_me * 0.5
		if dist_from_player > 5.0 and dist_from_player < 30.0:
			score += 5.0
		if score > best_score:
			best_score = score
			best_pos = behind_cover
	return best_pos

# =========================================================
# ÉTAT 1: PATROUILLE — avant d'avoir vu le joueur
# =========================================================

func _handle_idle_patrol(delta):
	if has_seen_player:
		current_state = CombatState.ADVANCE
		velocity.x = 0
		velocity.z = 0
		return
	
	if patrol_points.is_empty():
		_play_anim_continuous(anim_idle, "idle")
		velocity.x = lerp(velocity.x, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		return
	
	var target = patrol_points[current_patrol_index]
	target.y = global_position.y
	var dist = Vector2(global_position.x, global_position.z).distance_to(Vector2(target.x, target.z))
	
	if dist < 2.0:
		patrol_wait_timer += delta
		velocity.x = lerp(velocity.x, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		_play_anim_continuous(anim_idle, "idle")
		if anim_player:
			anim_player.speed_scale = 1.0
		if patrol_wait_timer >= patrol_wait_time:
			patrol_wait_timer = 0.0
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		var direction = (target - global_position)
		direction.y = 0
		direction = direction.normalized()
		var target_vx = direction.x * speed
		var target_vz = direction.z * speed
		velocity.x = lerp(velocity.x, target_vx, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, target_vz, clamp(velocity_smoothing * delta, 0.0, 1.0))
		_face_direction(direction)
		_play_anim_continuous(anim_walk, "walk")
		if anim_player:
			anim_player.speed_scale = clamp(velocity.length() / speed, 0.5, 1.5)

# =========================================================
# ÉTAT 2: AVANCER — directement vers le joueur
# =========================================================

func _handle_advance(delta, distance_to_player):
	if not player:
		return
	
	_face_player()
	
	if can_see_player() and can_shoot:
		shoot_at_player()
	
	# Arrivé à portée de tir → s'arrêter et tenir la position
	if distance_to_player <= stop_distance:
		current_state = CombatState.HOLD_POSITION
		hold_timer = 0.0
		hold_duration = randf_range(10.0, 15.0)
		return
	
	# Perdu de vue depuis longtemps → continuer vers la dernière position connue
	# Ne PAS arrêter d'avancer — aller à last_seen_position puis tenir
	if time_since_last_seen > 15.0 and not can_see_player():
		var dist_to_last = global_position.distance_to(last_seen_position)
		if dist_to_last < 5.0:
			current_state = CombatState.HOLD_POSITION
			hold_timer = 0.0
			hold_duration = randf_range(5.0, 8.0)
			return
	
	# Avancer DIRECTEMENT vers le joueur (pas de point intermédiaire)
	var target_pos = player.global_position if can_see_player() else last_seen_position
	var direction = (target_pos - global_position)
	direction.y = 0
	if direction.length() > 0.5:
		direction = direction.normalized()
		var target_vx = direction.x * run_speed
		var target_vz = direction.z * run_speed
		velocity.x = lerp(velocity.x, target_vx, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, target_vz, clamp(velocity_smoothing * delta, 0.0, 1.0))
		_play_anim_continuous(anim_run, "run")
		if anim_player:
			anim_player.speed_scale = clamp(velocity.length() / run_speed, 0.5, 1.5)
	else:
		velocity.x = lerp(velocity.x, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		_play_anim_continuous(anim_idle, "idle")
		if anim_player:
			anim_player.speed_scale = 1.0

# =========================================================
# ÉTAT 3: TENIR POSITION — rester et tirer 10-15s
# =========================================================

func _handle_hold_position(delta, distance_to_player):
	if not player:
		return
	
	_face_player()
	velocity.x = lerp(velocity.x, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
	velocity.z = lerp(velocity.z, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
	
	if can_see_player() and can_shoot:
		shoot_at_player()
		_play_anim_continuous(anim_shoot, "shoot")
	else:
		_play_anim_continuous(anim_idle, "idle")
	if anim_player:
		anim_player.speed_scale = 1.0
	
	hold_timer += delta
	
	if health < 40 and not nearby_obstacles.is_empty():
		var cover_pos = _find_best_cover()
		if cover_pos != Vector3.ZERO:
			cover_position = cover_pos
			current_state = CombatState.COVER
			return
	
	if hold_timer >= hold_duration:
		if distance_to_player > stop_distance:
			# Trop loin → avancer encore
			current_state = CombatState.ADVANCE
		else:
			# À portée → flanquer pour changer de position
			current_state = CombatState.FLANK
			_pick_flank_target()

# =========================================================
# ÉTAT 4: COUVERTURE — se cacher derrière un obstacle
# =========================================================

func _handle_cover(delta):
	if cover_position == Vector3.ZERO:
		current_state = CombatState.HOLD_POSITION
		hold_timer = 0.0
		hold_duration = randf_range(10.0, 15.0)
		return
	
	var dist_to_cover = global_position.distance_to(cover_position)
	
	if dist_to_cover > 2.0:
		var direction = (cover_position - global_position)
		direction.y = 0
		direction = direction.normalized()
		var target_vx = direction.x * run_speed
		var target_vz = direction.z * run_speed
		velocity.x = lerp(velocity.x, target_vx, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, target_vz, clamp(velocity_smoothing * delta, 0.0, 1.0))
		_face_player()
		_play_anim_continuous(anim_run, "run")
		if anim_player:
			anim_player.speed_scale = clamp(velocity.length() / run_speed, 0.5, 1.5)
	else:
		velocity.x = lerp(velocity.x, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, 0.0, clamp(velocity_smoothing * delta, 0.0, 1.0))
		is_behind_cover = true
		_face_player()
		
		if anim_crouch != "":
			_play_anim_continuous(anim_crouch, "crouch")
		else:
			_play_anim_continuous(anim_idle, "idle")
		
		if can_see_player() and can_shoot:
			shoot_at_player()
		
		if is_inside_tree() and get_tree():
			await get_tree().create_timer(4.0).timeout
		
		is_behind_cover = false
		cover_position = Vector3.ZERO
		current_state = CombatState.ADVANCE

# =========================================================
# ÉTAT 5: FLANQUER — changer de position latérale
# =========================================================

func _pick_flank_target():
	if not player:
		return
	var to_player = (player.global_position - global_position).normalized()
	# Direction latérale (perpendiculaire au joueur)
	var flank_dir = Vector3(-to_player.z, 0, to_player.x)
	if randf() < 0.5:
		flank_dir = -flank_dir
	# Toujours avancer un peu vers le joueur, jamais reculer
	flank_target = global_position + flank_dir * randf_range(5, 10) + to_player * randf_range(2, 5)
	flank_target.y = global_position.y

func _handle_flank(delta, _distance_to_player):
	var _delta = delta
	if not player:
		return
	
	_face_player()
	
	if can_see_player() and can_shoot:
		shoot_at_player()
	
	if flank_target == Vector3.ZERO:
		_pick_flank_target()
	
	var dist_to_target = Vector2(global_position.x, global_position.z).distance_to(Vector2(flank_target.x, flank_target.z))
	
	if dist_to_target < 2.5:
		flank_target = Vector3.ZERO
		current_state = CombatState.HOLD_POSITION
		hold_timer = 0.0
		hold_duration = randf_range(10.0, 15.0)
		return
	
	var direction = (flank_target - global_position)
	direction.y = 0
	if direction.length() > 0.5:
		direction = direction.normalized()
		var target_vx = direction.x * run_speed
		var target_vz = direction.z * run_speed
		velocity.x = lerp(velocity.x, target_vx, clamp(velocity_smoothing * _delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, target_vz, clamp(velocity_smoothing * _delta, 0.0, 1.0))
		_play_anim_continuous(anim_run, "run")
		if anim_player:
			anim_player.speed_scale = clamp(velocity.length() / run_speed, 0.5, 1.5)
	else:
		velocity.x = lerp(velocity.x, 0.0, clamp(velocity_smoothing * _delta, 0.0, 1.0))
		velocity.z = lerp(velocity.z, 0.0, clamp(velocity_smoothing * _delta, 0.0, 1.0))

# =========================================================
# ROTATION
# =========================================================

func _face_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		return
	target_rotation_y = atan2(direction.x, direction.z)

func _face_player():
	if not player:
		return
	var direction = (player.global_position - global_position)
	direction.y = 0
	if direction.length_squared() > 0.001:
		target_rotation_y = atan2(direction.x, direction.z)

func find_cover_position():
	var cover_pos = _find_best_cover()
	if cover_pos != Vector3.ZERO:
		cover_position = cover_pos

func look_at_player():
	_face_player()

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
	
	_play_anim_shoot()
	shoot()
	
	if ammo <= 0:
		reload()
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(fire_rate).timeout
		can_shoot = true
	else:
		can_shoot = true

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
	
	var spread := 0.03
	target_pos += Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		randf_range(-spread, spread)
	) * global_position.distance_to(target_pos)
	
	var direction = (target_pos - spawn_pos).normalized()
	
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	
	call_deferred("_add_bullet", bullet, spawn_pos, direction)
	
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

func _add_bullet(bullet, spawn_pos: Vector3, direction: Vector3):
	if is_inside_tree() and get_tree():
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = spawn_pos
		bullet.look_at(spawn_pos + direction, Vector3.UP)

# =========================================================
# IMPACT
# =========================================================

func create_impact(pos, normal_vec):
	if impact_scene == null or not get_tree():
		return
	var impact = impact_scene.instantiate()
	if impact:
		get_tree().current_scene.add_child(impact)
		impact.global_position = pos + normal_vec * 0.02
		if normal_vec != Vector3.ZERO:
			impact.look_at(pos + normal_vec, Vector3.UP)
	if bullet_impact_scene:
		var particles = bullet_impact_scene.instantiate()
		if particles:
			get_tree().current_scene.add_child(particles)
			particles.global_position = pos
			particles.look_at(pos + normal_vec, Vector3.UP)
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
# ANIMATIONS — boucle continue
# =========================================================

func _play_anim_continuous(a_name: String, tag: String):
	if not anim_player:
		return
	if a_name == "":
		if all_anims.size() > 0:
			a_name = all_anims[0]
		else:
			return
	if not anim_player.has_animation(a_name):
		return
	if current_anim == tag and anim_player.is_playing():
		return
	anim_player.play(a_name)
	anim_player.speed_scale = 1.0
	current_anim = tag

func _play_anim_shoot():
	if not anim_player:
		return
	var moving = velocity.length() > 0.5
	if moving and anim_shoot_walk != "":
		_play_anim_continuous(anim_shoot_walk, "shoot_walk")
	elif anim_shoot != "":
		_play_anim_continuous(anim_shoot, "shoot")

func play_idle():
	_play_anim_continuous(anim_idle, "idle")

func play_walk():
	if anim_walk != "":
		_play_anim_continuous(anim_walk, "walk")
	elif anim_run != "":
		_play_anim_continuous(anim_run, "walk")

func play_run():
	if anim_run != "":
		_play_anim_continuous(anim_run, "run")
	elif anim_walk != "":
		_play_anim_continuous(anim_walk, "run")

func play_shoot():
	_play_anim_continuous(anim_shoot, "shoot")

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
	# Attendre 8 secondes avant de respawn (plus réaliste)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(8.0).timeout
	respawn()

func respawn():
	is_dead = false
	health = 100
	ammo = max_ammo
	has_seen_player = true
	current_state = CombatState.ADVANCE
	hold_timer = 0.0
	
	# Respawn à une position aléatoire AUTOUR de la position initiale (pas au même endroit)
	var angle = randf() * PI * 2.0
	var dist = randf_range(10.0, 25.0)
	var offset = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	global_position = initial_position + offset
	_snap_to_ground()
	velocity = Vector3.ZERO
	
	# Regénérer les points de patrouille autour de la nouvelle position
	initial_position = global_position
	_generate_patrol_points()
	_play_anim_continuous(anim_idle, "idle")

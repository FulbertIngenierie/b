extends CharacterBody3D

# =========================================================
# ENEMY_BAD — IA réaliste avec Behavior Tree
# =========================================================
# Basé sur edo_kpessé.gd mais avec animations diversifiées
# Chaque instance reçoit un variant_id pour des animations uniques

# =========================================================
# NODES
# =========================================================

var anim_player: AnimationPlayer = null
var anim_tree: AnimationTree = null
@onready var gun_sound = $ShootSound if has_node("ShootSound") else null

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
# STATS
# =========================================================

var speed := 2.5
var run_speed := 4.5
var detection_range := 80.0
var attack_range := 45.0
var damage := 12.0
var gravity := 20.0

# =========================================================
# ÉTAT INTERNE
# =========================================================

var player: CharacterBody3D
var health := 120
var max_health := 120
var ammo := 30
var max_ammo := 30
var fire_rate := 0.3
var is_dead := false
var current_anim := ""
var enemy_id := 0
var initial_position := Vector3.ZERO

# =========================================================
# VARIANT — pour diversifier les animations
# =========================================================

@export var variant_id := 0  # 0-3, défini dans la scène pour chaque instance

# =========================================================
# TIMERS (AUCUN await)
# =========================================================

var can_shoot := true
var fire_cooldown := 0.0
var reload_timer := 0.0
var is_reloading := false

# =========================================================
# AI DIRECTOR LINK
# =========================================================

var ai_director = null
var reaction_timer := 0.0
var reaction_delay := 0.8

# =========================================================
# PERCEPTION
# =========================================================

var can_see_target := false
var last_known_position := Vector3.ZERO
var time_since_seen := 999.0
var distance_to_target := 999.0
var has_ever_seen_player := false

# =========================================================
# BEHAVIOR TREE — états
# =========================================================

enum BTState {
	PATROL,
	INVESTIGATE,
	ENGAGE_ADVANCE,
	ENGAGE_HOLD,
	ENGAGE_FLANK,
	TAKE_COVER,
	DEAD
}

var bt_state := BTState.PATROL
var state_timer := 0.0
var state_change_cooldown := 0.0

# =========================================================
# PATROL
# =========================================================

var patrol_points: Array[Vector3] = []
var current_patrol_index := 0
var patrol_wait_timer := 0.0
var patrol_wait_time := 8.0
var patrol_radius := 12.0

# =========================================================
# ENGAGE
# =========================================================

var hold_duration := 0.0
var flank_target := Vector3.ZERO
var stop_distance := 12.0

# =========================================================
# COVER
# =========================================================

var nearby_obstacles: Array = []
var cover_position := Vector3.ZERO
var cover_timer := 0.0
var cover_duration := 4.0
var is_behind_cover := false

# =========================================================
# SMOOTH MOVEMENT
# =========================================================

var velocity_smoothing := 8.0
var rotation_speed := 4.0
var target_rotation_y := 0.0

# =========================================================
# ANIMATION MAPPING — par variant
# =========================================================

# Animations disponibles dans Enemy_bad.glb:
# [0] recharge
# [1] Armature.006|mixamo.com|Layer0  (idle/walk)
# [2] Armature.008|mixamo.com|Layer0  (idle/walk2)
# [3] corps à corps
# [4] die
# [5] die1
# [6] effet de balle marche  (tir en marchant)
# [7] effet de balles  (tir debout)
# [8] grenade
# [9] recharge run
# [10] tir avancé
# [11] tir debout
# [12] tir+cover

var anim_idle := ""
var anim_walk := ""
var anim_run := ""
var anim_shoot := ""
var anim_shoot_walk := ""
var anim_reload := ""
var anim_die := ""
var anim_crouch := ""
var anim_melee := ""
var anim_grenade := ""
var all_anims: PackedStringArray = []

# =========================================================
# READY
# =========================================================

func _ready():
	_init_animation_player()
	_setup_animation_tree()
	_assign_variant_animations()
	find_player()
	add_to_group("enemies")
	add_to_group("enemy_target")
	
	enemy_id = hash(str(global_position) + str(variant_id))
	initial_position = global_position
	
	_snap_to_ground()
	_generate_patrol_points()
	_find_ai_director()
	
	if anim_player:
		_ensure_animations_loop()
		print("[", name, "] (variant ", variant_id, ") AnimationPlayer avec ", anim_player.get_animation_list().size(), " animations")
	else:
		print("[", name, "] ATTENTION: Aucun AnimationPlayer trouvé!")
	
	_play_anim("idle", anim_idle)

# =========================================================
# VARIANT ANIMATIONS — chaque ennemi a des anims uniques
# =========================================================

func _assign_variant_animations():
	if not anim_player:
		return
	all_anims = anim_player.get_animation_list()
	
	# Distribution des animations selon le variant_id
	match variant_id:
		0:
			# Variant 0 : Standard — tir debout, die classique
			anim_idle = _find_anim(["Armature.006|mixamo"])
			anim_walk = _find_anim(["Armature.006|mixamo"])
			anim_run = _find_anim(["Armature.008|mixamo"])
			anim_shoot = _find_anim(["tir debout"])
			anim_shoot_walk = _find_anim(["effet de balle marche"])
			anim_reload = _find_anim(["recharge"])
			anim_die = _find_anim(["die1"])
			anim_crouch = _find_anim(["tir+cover"])
			anim_melee = _find_anim(["corps"])
			anim_grenade = _find_anim(["grenade"])
		1:
			# Variant 1 : Agressif — tir avancé, die rapide
			anim_idle = _find_anim(["Armature.008|mixamo"])
			anim_walk = _find_anim(["Armature.008|mixamo"])
			anim_run = _find_anim(["Armature.006|mixamo"])
			anim_shoot = _find_anim(["tir avanc"])
			anim_shoot_walk = _find_anim(["effet de balle marche"])
			anim_reload = _find_anim(["recharge run"])
			anim_die = _find_anim(["die"])
			anim_crouch = _find_anim(["tir+cover"])
			anim_melee = _find_anim(["corps"])
			anim_grenade = _find_anim(["grenade"])
		2:
			# Variant 2 : Couverture — tir+cover, effet de balles
			anim_idle = _find_anim(["Armature.006|mixamo"])
			anim_walk = _find_anim(["Armature.008|mixamo"])
			anim_run = _find_anim(["Armature.006|mixamo"])
			anim_shoot = _find_anim(["effet de balles"])
			anim_shoot_walk = _find_anim(["tir avanc"])
			anim_reload = _find_anim(["recharge"])
			anim_die = _find_anim(["die1"])
			anim_crouch = _find_anim(["tir+cover"])
			anim_melee = _find_anim(["corps"])
			anim_grenade = _find_anim(["grenade"])
		3, _:
			# Variant 3 : Grenadier — utilise grenades, die dramatique
			anim_idle = _find_anim(["Armature.008|mixamo"])
			anim_walk = _find_anim(["Armature.006|mixamo"])
			anim_run = _find_anim(["Armature.008|mixamo"])
			anim_shoot = _find_anim(["tir debout"])
			anim_shoot_walk = _find_anim(["tir avanc"])
			anim_reload = _find_anim(["recharge run"])
			anim_die = _find_anim(["die"])
			anim_crouch = _find_anim(["tir+cover"])
			anim_melee = _find_anim(["corps"])
			anim_grenade = _find_anim(["grenade"])

# =========================================================
# ANIMATION TREE — transitions fluides
# =========================================================

func _setup_animation_tree():
	if not anim_player:
		return
	
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	
	var state_machine = AnimationNodeStateMachine.new()
	
	# Ajouter les nœuds pour chaque animation
	var anims_to_add = {}
	for a_name in anim_player.get_animation_list():
		var node = AnimationNodeAnimation.new()
		node.animation = a_name
		var safe_name = a_name.replace("|", "_").replace(".", "_").replace(" ", "_").replace("+", "_")
		state_machine.add_node(safe_name, node, Vector2(0, 0))
		anims_to_add[a_name] = safe_name
	
	anim_tree.tree_root = state_machine
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	add_child(anim_tree)

# =========================================================
# PHYSICS PROCESS — BEHAVIOR TREE TICK
# =========================================================

func _physics_process(delta):
	_update_timers(delta)
	
	if is_dead:
		velocity = Vector3.ZERO
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if not player:
		find_player()
	
	_perceive(delta)
	_decide()
	_act(delta)
	_apply_smooth_rotation(delta)
	move_and_slide()

# =========================================================
# TIMERS
# =========================================================

func _update_timers(delta):
	if fire_cooldown > 0:
		fire_cooldown -= delta
		if fire_cooldown <= 0:
			can_shoot = true
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			ammo = max_ammo
	
	state_timer += delta
	
	if state_change_cooldown > 0:
		state_change_cooldown -= delta
	
	if can_see_target and reaction_timer < reaction_delay + 1.0:
		reaction_timer += delta
	if not can_see_target:
		reaction_timer = 0.0

# =========================================================
# PERCEVOIR
# =========================================================

func _perceive(delta):
	if not player or not is_instance_valid(player):
		can_see_target = false
		distance_to_target = 999.0
		return
	
	distance_to_target = global_position.distance_to(player.global_position)
	var sees_now = _check_line_of_sight()
	
	# Perception son
	if not sees_now and distance_to_target < 35.0:
		if player and "shooting" in player and player.shooting:
			last_known_position = player.global_position
			has_ever_seen_player = true
			if bt_state == BTState.PATROL:
				_transition_to(BTState.INVESTIGATE)
				if ai_director:
					ai_director.alert_squad(player.global_position, self)
	
	if sees_now:
		can_see_target = true
		last_known_position = player.global_position
		time_since_seen = 0.0
		has_ever_seen_player = true
		if ai_director:
			ai_director.alert_squad(player.global_position, self)
	else:
		can_see_target = false
		time_since_seen += delta

# =========================================================
# DÉCIDER
# =========================================================

func _decide():
	match bt_state:
		BTState.DEAD:
			return
		BTState.PATROL:
			if can_see_target:
				_transition_to(BTState.ENGAGE_ADVANCE)
		BTState.INVESTIGATE:
			if can_see_target:
				_transition_to(BTState.ENGAGE_ADVANCE)
			elif _arrived_at(last_known_position, 3.0):
				_transition_to(BTState.PATROL)
		BTState.ENGAGE_ADVANCE:
			if not can_see_target and time_since_seen > 10.0:
				_transition_to(BTState.INVESTIGATE)
			elif distance_to_target <= stop_distance:
				_transition_to(BTState.ENGAGE_HOLD)
			elif health < 30 and _has_nearby_cover():
				_transition_to(BTState.TAKE_COVER)
		BTState.ENGAGE_HOLD:
			if not can_see_target and time_since_seen > 8.0:
				_transition_to(BTState.INVESTIGATE)
			elif health < 30 and _has_nearby_cover():
				_transition_to(BTState.TAKE_COVER)
			elif state_timer >= hold_duration:
				if distance_to_target > stop_distance:
					_transition_to(BTState.ENGAGE_ADVANCE)
				else:
					_transition_to(BTState.ENGAGE_FLANK)
		BTState.ENGAGE_FLANK:
			if _arrived_at(flank_target, 2.5):
				_transition_to(BTState.ENGAGE_HOLD)
			elif not can_see_target and time_since_seen > 10.0:
				_transition_to(BTState.INVESTIGATE)
		BTState.TAKE_COVER:
			if cover_position == Vector3.ZERO:
				_transition_to(BTState.ENGAGE_HOLD)
			elif is_behind_cover and cover_timer >= cover_duration:
				cover_timer = 0.0
				is_behind_cover = false
				cover_position = Vector3.ZERO
				_transition_to(BTState.ENGAGE_ADVANCE)

func _transition_to(new_state: BTState):
	if state_change_cooldown > 0:
		return
	state_change_cooldown = 1.0
	bt_state = new_state
	state_timer = 0.0
	
	match new_state:
		BTState.ENGAGE_HOLD:
			hold_duration = randf_range(8.0, 14.0)
		BTState.ENGAGE_FLANK:
			_pick_flank_target()
		BTState.TAKE_COVER:
			var pos = _find_best_cover()
			if pos != Vector3.ZERO:
				cover_position = pos
				cover_timer = 0.0
				is_behind_cover = false
			else:
				bt_state = BTState.ENGAGE_HOLD
				hold_duration = randf_range(8.0, 14.0)

# =========================================================
# AGIR
# =========================================================

func _act(delta):
	match bt_state:
		BTState.PATROL:
			_act_patrol(delta)
		BTState.INVESTIGATE:
			_act_investigate(delta)
		BTState.ENGAGE_ADVANCE:
			_act_advance(delta)
		BTState.ENGAGE_HOLD:
			_act_hold(delta)
		BTState.ENGAGE_FLANK:
			_act_flank(delta)
		BTState.TAKE_COVER:
			_act_cover(delta)

func _act_patrol(delta):
	if patrol_points.is_empty():
		_smooth_stop(delta)
		_play_anim("idle", anim_idle)
		return
	var target = patrol_points[current_patrol_index]
	target.y = global_position.y
	if _arrived_at(target, 2.0):
		_smooth_stop(delta)
		_play_anim("idle", anim_idle)
		patrol_wait_timer += delta
		if patrol_wait_timer >= patrol_wait_time:
			patrol_wait_timer = 0.0
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		_move_toward(target, speed, delta)
		_face_direction_of_movement()
		_play_anim("walk", anim_walk)
		_sync_anim_speed(speed)

func _act_investigate(delta):
	if last_known_position == Vector3.ZERO:
		_smooth_stop(delta)
		_play_anim("idle", anim_idle)
		return
	_move_toward(last_known_position, run_speed, delta)
	_face_movement_direction()
	_play_anim("run", anim_run)
	_sync_anim_speed(run_speed)

func _act_advance(delta):
	_face_player()
	if can_see_target and can_shoot and not is_reloading:
		_try_shoot()
	var target_pos = player.global_position if can_see_target else last_known_position
	_move_toward(target_pos, run_speed, delta)
	_play_anim("run", anim_run)
	_sync_anim_speed(run_speed)

func _act_hold(delta):
	_face_player()
	_smooth_stop(delta)
	if can_see_target and can_shoot and not is_reloading:
		_try_shoot()
		_play_anim("shoot", anim_shoot)
	else:
		_play_anim("idle", anim_idle)
	if anim_player:
		anim_player.speed_scale = 1.0

func _act_flank(delta):
	_face_player()
	if can_see_target and can_shoot and not is_reloading:
		_try_shoot()
	if flank_target != Vector3.ZERO:
		_move_toward(flank_target, run_speed, delta)
		_play_anim("run", anim_run)
		_sync_anim_speed(run_speed)
	else:
		_smooth_stop(delta)

func _act_cover(delta):
	if not is_behind_cover:
		if cover_position != Vector3.ZERO:
			_move_toward(cover_position, run_speed, delta)
			_face_player()
			_play_anim("run", anim_run)
			_sync_anim_speed(run_speed)
			if _arrived_at(cover_position, 2.0):
				is_behind_cover = true
				cover_timer = 0.0
	else:
		_smooth_stop(delta)
		_face_player()
		cover_timer += delta
		if anim_crouch != "":
			_play_anim("crouch", anim_crouch)
		else:
			_play_anim("idle", anim_idle)
		if can_see_target and can_shoot and not is_reloading:
			_try_shoot()

# =========================================================
# MOUVEMENT
# =========================================================

func _move_toward(target: Vector3, spd: float, delta: float):
	var direction = (target - global_position)
	direction.y = 0
	if direction.length() < 0.3:
		_smooth_stop(delta)
		return
	direction = direction.normalized()
	var target_vx = direction.x * spd
	var target_vz = direction.z * spd
	var t = clamp(velocity_smoothing * delta, 0.0, 1.0)
	velocity.x = lerp(velocity.x, target_vx, t)
	velocity.z = lerp(velocity.z, target_vz, t)

func _smooth_stop(delta):
	var t = clamp(velocity_smoothing * delta, 0.0, 1.0)
	velocity.x = lerp(velocity.x, 0.0, t)
	velocity.z = lerp(velocity.z, 0.0, t)

func _arrived_at(pos: Vector3, threshold: float) -> bool:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(pos.x, pos.z)) < threshold

# =========================================================
# ROTATION
# =========================================================

func _apply_smooth_rotation(delta):
	var current_y = rotation.y
	var diff = wrapf(target_rotation_y - current_y, -PI, PI)
	rotation.y += diff * rotation_speed * delta

func _face_player():
	if not player or not is_instance_valid(player):
		return
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length_squared() > 0.001:
		target_rotation_y = atan2(dir.x, dir.z)

func _face_direction_of_movement():
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	if horizontal.length_squared() > 0.1:
		target_rotation_y = atan2(horizontal.x, horizontal.z)

func _face_movement_direction():
	_face_direction_of_movement()

# =========================================================
# PERCEPTION
# =========================================================

func _check_line_of_sight() -> bool:
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var dist = global_position.distance_to(player.global_position)
	if dist > detection_range:
		return false
	if dist < 8.0:
		return true
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + Vector3(0, 1.5, 0)
	var ray_end = player.global_position + Vector3(0, 1.5, 0)
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result and result.collider == player

# =========================================================
# TIR
# =========================================================

func _try_shoot():
	if not can_shoot or ammo <= 0 or is_dead or is_reloading:
		return
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return
	if reaction_timer < reaction_delay:
		return
	
	can_shoot = false
	var actual_fire_rate = fire_rate
	if ai_director:
		actual_fire_rate = ai_director.get_enemy_fire_rate()
	fire_cooldown = actual_fire_rate
	ammo -= 1
	
	if gun_sound and gun_sound.stream:
		gun_sound.pitch_scale = randf_range(0.95, 1.05)
		if gun_sound.playing:
			gun_sound.stop()
		gun_sound.play()
	
	_play_anim_shoot()
	_fire_bullet()
	
	if ammo <= 0:
		is_reloading = true
		reload_timer = 2.5
		if anim_player and anim_reload != "":
			anim_player.play(anim_reload)

func get_gun_tip_position() -> Vector3:
	return global_position + global_transform.basis * gun_tip_offset

func _fire_bullet():
	if bullet_scene == null or not is_inside_tree() or not get_tree():
		return
	if not player or not is_instance_valid(player):
		return
	
	var spawn_pos = get_gun_tip_position()
	var target_pos = player.global_position + Vector3(0, 1.2, 0)
	
	var spread := 0.03
	if ai_director:
		var accuracy = ai_director.get_enemy_accuracy()
		spread = 0.06 * (1.0 - accuracy)
	target_pos += Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		randf_range(-spread, spread)
	) * global_position.distance_to(target_pos)
	
	var direction = (target_pos - spawn_pos).normalized()
	
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	bullet.set_meta("fired_by_enemy", true)
	call_deferred("_add_bullet", bullet, spawn_pos, direction)
	
	# Hitscan — SEULEMENT sur le joueur
	var space_state = get_world_3d().direct_space_state
	var ray_end = spawn_pos + direction * 500.0
	var query = PhysicsRayQueryParameters3D.create(spawn_pos, ray_end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider != null and collider == player and collider.has_method("take_damage"):
			var actual_damage = damage
			if ai_director:
				actual_damage = ai_director.get_enemy_damage()
			collider.take_damage(actual_damage)
			if ai_director:
				ai_director.register_player_damage()
		_create_impact(result.position, result.normal)

func _add_bullet(bullet, spawn_pos: Vector3, direction: Vector3):
	if is_inside_tree() and get_tree():
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = spawn_pos
		bullet.look_at(spawn_pos + direction, Vector3.UP)

func _create_impact(pos, normal_vec):
	if impact_scene == null or not get_tree():
		return
	var safe_normal = normal_vec
	if safe_normal.is_equal_approx(Vector3.UP) or safe_normal.is_equal_approx(Vector3.DOWN) or safe_normal.length() < 0.001:
		safe_normal = Vector3(0.01, normal_vec.y if normal_vec.length() > 0 else 1.0, 0.01).normalized()
	var impact = impact_scene.instantiate()
	if impact:
		get_tree().current_scene.add_child(impact)
		impact.global_position = pos + normal_vec * 0.02
		if safe_normal != Vector3.ZERO:
			impact.look_at(pos + safe_normal, Vector3.UP)
	if bullet_impact_scene:
		var particles = bullet_impact_scene.instantiate()
		if particles:
			get_tree().current_scene.add_child(particles)
			particles.global_position = pos
			if safe_normal != Vector3.ZERO:
				particles.look_at(pos + safe_normal, Vector3.UP)
			particles.emitting = true
			particles.one_shot = true

# =========================================================
# FLANK
# =========================================================

func _pick_flank_target():
	if not player:
		return
	var to_player = (player.global_position - global_position).normalized()
	var flank_dir = Vector3(-to_player.z, 0, to_player.x)
	if randf() < 0.5:
		flank_dir = -flank_dir
	flank_target = global_position + flank_dir * randf_range(5, 10) + to_player * randf_range(2, 5)
	flank_target.y = global_position.y

# =========================================================
# COUVERTURE
# =========================================================

func _has_nearby_cover() -> bool:
	_scan_nearby_obstacles()
	return not nearby_obstacles.is_empty()

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
		var to_player_dir = (player.global_position - behind_cover).normalized()
		var cover_dot = obs_normal.dot(to_player_dir)
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
# ANIMATIONS
# =========================================================

func _play_anim(tag: String, a_name: String):
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
		_play_anim("shoot_walk", anim_shoot_walk)
	elif anim_shoot != "":
		_play_anim("shoot", anim_shoot)

func _sync_anim_speed(target_speed: float):
	if anim_player and target_speed > 0:
		anim_player.speed_scale = clamp(velocity.length() / target_speed, 0.4, 1.5)

# =========================================================
# DÉGÂTS ET MORT
# =========================================================

func take_damage(amount):
	if is_dead:
		return
	health -= amount
	if ai_director:
		ai_director.register_hit()
	# Effet sang
	if is_inside_tree() and get_tree():
		_spawn_blood_splatter()
	if hit_effect_scene and is_inside_tree():
		var hit_effect = hit_effect_scene.instantiate()
		add_child(hit_effect)
		hit_effect.global_position = global_position + Vector3(0, 1.5, 0)
		hit_effect.emitting = true
		hit_effect.one_shot = true
	# Réaction aux dégâts
	if not is_dead and health > 0:
		if bt_state == BTState.PATROL:
			_transition_to(BTState.INVESTIGATE)
		elif bt_state == BTState.INVESTIGATE:
			_transition_to(BTState.ENGAGE_ADVANCE)
	if health <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	bt_state = BTState.DEAD
	if ai_director:
		ai_director.register_kill()
	velocity = Vector3.ZERO
	if anim_player and anim_die != "":
		anim_player.play(anim_die)
	if hit_effect_scene and is_inside_tree() and get_tree():
		var hit_effect = hit_effect_scene.instantiate()
		if hit_effect:
			get_tree().current_scene.add_child(hit_effect)
			hit_effect.global_position = global_position + Vector3(0, 1.5, 0)
			hit_effect.emitting = true

# =========================================================
# BLOOD SPLATTER
# =========================================================

func _spawn_blood_splatter():
	if not is_inside_tree() or not get_tree():
		return
	for i in range(4):
		var blood = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(0.2, 0.2)
		blood.mesh = quad
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.0, 0.0, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.0, 0.0, 1)
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		blood.material_override = mat
		get_tree().current_scene.add_child(blood)
		blood.global_position = global_position + Vector3(
			randf_range(-0.4, 0.4),
			randf_range(0.8, 1.8),
			randf_range(-0.4, 0.4)
		)
		var tween = get_tree().create_tween()
		tween.tween_property(blood, "scale", Vector3.ZERO, 1.2).set_delay(0.3)
		tween.tween_callback(blood.queue_free)

# =========================================================
# UTILITAIRES
# =========================================================

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _find_ai_director():
	var directors = get_tree().get_nodes_in_group("ai_director")
	if directors.size() > 0:
		ai_director = directors[0]
		reaction_delay = ai_director.get_enemy_reaction_time()

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

func _init_animation_player():
	var best_anim_player: AnimationPlayer = null
	var best_count := 0
	var all_players = _find_all_animation_players(self)
	for ap in all_players:
		var count = ap.get_animation_list().size()
		if count > best_count:
			best_count = count
			best_anim_player = ap
	if best_anim_player:
		anim_player = best_anim_player
	elif has_node("AnimationPlayer"):
		anim_player = $AnimationPlayer

func _find_all_animation_players(node: Node) -> Array:
	var result := []
	if node is AnimationPlayer:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_animation_players(child))
	return result

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

# Compatibilité
func get_health():
	return health

func get_ammo():
	return ammo

func shoot_at_player():
	_try_shoot()

func shoot():
	_fire_bullet()

func reload():
	if is_dead:
		return
	is_reloading = true
	reload_timer = 2.5
	if anim_player and anim_reload != "":
		anim_player.play(anim_reload)

func look_at_player():
	_face_player()

func find_cover_position():
	var pos = _find_best_cover()
	if pos != Vector3.ZERO:
		cover_position = pos

extends Node

# =========================================================
# AI DIRECTOR — Contrôle la difficulté et la tension
# =========================================================
# Analyse la performance du joueur en temps réel
# Ajuste la difficulté dynamiquement
# Gère le spawn et la coordination des ennemis (Squad AI)

# =========================================================
# RÉFÉRENCES
# =========================================================

var player: CharacterBody3D = null
var enemies: Array = []

# =========================================================
# ANALYSE PERFORMANCE JOUEUR
# =========================================================

var player_accuracy := 0.0
var player_kills_per_minute := 0.0
var player_damage_taken_per_minute := 0.0
var player_deaths := 0
var session_time := 0.0
var total_shots := 0
var total_hits := 0
var total_kills := 0
var analysis_timer := 0.0
var analysis_interval := 5.0

# =========================================================
# DIFFICULTÉ ADAPTATIVE
# =========================================================

enum Difficulty { EASY, NORMAL, HARD, VETERAN }
var current_difficulty := Difficulty.NORMAL
var difficulty_score := 50.0
var target_difficulty := 50.0

# Paramètres par difficulté
var diff_enemy_accuracy := {
	Difficulty.EASY: 0.15,
	Difficulty.NORMAL: 0.3,
	Difficulty.HARD: 0.5,
	Difficulty.VETERAN: 0.7
}
var diff_enemy_fire_rate := {
	Difficulty.EASY: 0.5,
	Difficulty.NORMAL: 0.25,
	Difficulty.HARD: 0.18,
	Difficulty.VETERAN: 0.12
}
var diff_enemy_damage := {
	Difficulty.EASY: 6,
	Difficulty.NORMAL: 10,
	Difficulty.HARD: 15,
	Difficulty.VETERAN: 20
}
var diff_enemy_reaction_time := {
	Difficulty.EASY: 1.5,
	Difficulty.NORMAL: 0.8,
	Difficulty.HARD: 0.4,
	Difficulty.VETERAN: 0.2
}

# =========================================================
# TENSION — gestion du rythme de jeu
# =========================================================

var tension := 0.0
var max_tension := 100.0
var tension_decay := 5.0
var tension_from_combat := 15.0
var tension_from_damage := 25.0
var tension_from_kill := -10.0
var is_in_combat := false
var combat_timer := 0.0

# =========================================================
# SQUAD AI — coordination d'équipe
# =========================================================

var squad_roles := {}
var squad_update_timer := 0.0
var squad_update_interval := 2.0
var suppressor_count := 0
var flanker_count := 0

enum SquadRole {
	ASSAULT,
	FLANKER,
	SUPPRESSOR,
	COVER_GUARD
}

# =========================================================
# READY
# =========================================================

func _ready():
	add_to_group("ai_director")

# =========================================================
# PROCESS
# =========================================================

func _process(delta):
	session_time += delta
	
	# Trouver le joueur
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Mettre à jour la liste des ennemis
	enemies = get_tree().get_nodes_in_group("enemies")
	
	# Analyse périodique
	analysis_timer += delta
	if analysis_timer >= analysis_interval:
		analysis_timer = 0.0
		_analyze_player_performance()
		_adjust_difficulty()
	
	# Tension management
	_update_tension(delta)
	
	# Squad AI coordination
	squad_update_timer += delta
	if squad_update_timer >= squad_update_interval:
		squad_update_timer = 0.0
		_update_squad_coordination()
	
	# Combat state
	if is_in_combat:
		combat_timer += delta
		if combat_timer > 8.0:
			is_in_combat = false
			combat_timer = 0.0

# =========================================================
# ANALYSE PERFORMANCE
# =========================================================

func _analyze_player_performance():
	if session_time < 1.0:
		return
	
	# Précision
	if total_shots > 0:
		player_accuracy = float(total_hits) / float(total_shots)
	
	# Kills par minute
	var minutes = session_time / 60.0
	if minutes > 0:
		player_kills_per_minute = float(total_kills) / minutes

func register_shot():
	total_shots += 1

func register_hit():
	total_hits += 1
	is_in_combat = true
	combat_timer = 0.0
	tension += tension_from_combat * 0.5

func register_kill():
	total_kills += 1
	tension += tension_from_kill

func register_player_damage():
	tension += tension_from_damage
	is_in_combat = true
	combat_timer = 0.0

func register_player_death():
	player_deaths += 1
	difficulty_score = max(0, difficulty_score - 15.0)

# =========================================================
# DIFFICULTÉ ADAPTATIVE
# =========================================================

func _adjust_difficulty():
	# Joueur trop bon → augmenter la difficulté
	if player_accuracy > 0.5 and player_kills_per_minute > 2.0:
		target_difficulty = min(100, target_difficulty + 5.0)
	# Joueur en difficulté → baisser
	elif player_accuracy < 0.15 or player_deaths > total_kills:
		target_difficulty = max(0, target_difficulty - 8.0)
	# Joueur moyen → ajuster légèrement
	else:
		target_difficulty = lerp(target_difficulty, 50.0, 0.1)
	
	difficulty_score = lerp(difficulty_score, target_difficulty, 0.2)
	
	# Mapper le score à la difficulté
	if difficulty_score < 25:
		current_difficulty = Difficulty.EASY
	elif difficulty_score < 50:
		current_difficulty = Difficulty.NORMAL
	elif difficulty_score < 75:
		current_difficulty = Difficulty.HARD
	else:
		current_difficulty = Difficulty.VETERAN

func get_enemy_accuracy() -> float:
	return diff_enemy_accuracy[current_difficulty]

func get_enemy_fire_rate() -> float:
	return diff_enemy_fire_rate[current_difficulty]

func get_enemy_damage() -> int:
	return diff_enemy_damage[current_difficulty]

func get_enemy_reaction_time() -> float:
	return diff_enemy_reaction_time[current_difficulty]

# =========================================================
# TENSION — gestion du rythme
# =========================================================

func _update_tension(delta):
	# Decay naturel
	if not is_in_combat:
		tension -= tension_decay * delta
	else:
		tension += delta * 2.0
	
	tension = clamp(tension, 0, max_tension)

func get_tension() -> float:
	return tension

func is_high_tension() -> bool:
	return tension > 60.0

# =========================================================
# SQUAD AI — coordination d'équipe
# =========================================================

func _update_squad_coordination():
	if not player or not is_instance_valid(player):
		return
	
	var alive_enemies := []
	for e in enemies:
		if is_instance_valid(e) and not ("is_dead" in e and e.is_dead):
			alive_enemies.append(e)
	
	if alive_enemies.is_empty():
		return
	
	# Répartir les rôles de squad
	squad_roles.clear()
	suppressor_count = 0
	flanker_count = 0
	
	var player_pos = player.global_position
	
	# Trier par distance au joueur
	alive_enemies.sort_custom(func(a, b):
		return a.global_position.distance_to(player_pos) < b.global_position.distance_to(player_pos)
	)
	
	for i in range(alive_enemies.size()):
		var enemy = alive_enemies[i]
		var enemy_id = enemy.get_instance_id()
		
		if i == 0:
			# Le plus proche = ASSAULT
			squad_roles[enemy_id] = SquadRole.ASSAULT
		elif i == 1 and alive_enemies.size() >= 3:
			# Le 2ème = FLANKER
			squad_roles[enemy_id] = SquadRole.FLANKER
			flanker_count += 1
		elif suppressor_count < 1:
			# Un SUPPRESSOR (tir de couverture)
			squad_roles[enemy_id] = SquadRole.SUPPRESSOR
			suppressor_count += 1
		else:
			# Les autres = COVER_GUARD
			squad_roles[enemy_id] = SquadRole.COVER_GUARD
	
	# Communiquer les rôles aux ennemis
	for enemy in alive_enemies:
		var enemy_id = enemy.get_instance_id()
		if enemy_id in squad_roles:
			_assign_squad_role(enemy, squad_roles[enemy_id])

func _assign_squad_role(enemy, role: SquadRole):
	if not is_instance_valid(enemy):
		return
	
	match role:
		SquadRole.ASSAULT:
			# Avancer agressivement
			if "stop_distance" in enemy:
				enemy.stop_distance = 8.0
			if "speed" in enemy:
				enemy.speed = 3.0
			if "run_speed" in enemy:
				enemy.run_speed = 5.5
		SquadRole.FLANKER:
			# Flanquer
			if "bt_state" in enemy and enemy.bt_state != enemy.BTState.DEAD:
				if enemy.bt_state == enemy.BTState.ENGAGE_HOLD or enemy.bt_state == enemy.BTState.ENGAGE_ADVANCE:
					enemy.bt_state = enemy.BTState.ENGAGE_FLANK
					enemy._pick_flank_target()
			if "stop_distance" in enemy:
				enemy.stop_distance = 10.0
		SquadRole.SUPPRESSOR:
			# Tenir position et tirer beaucoup
			if "fire_rate" in enemy:
				enemy.fire_rate = get_enemy_fire_rate() * 0.7
			if "stop_distance" in enemy:
				enemy.stop_distance = 20.0
		SquadRole.COVER_GUARD:
			# Se mettre à couvert
			if "stop_distance" in enemy:
				enemy.stop_distance = 15.0

# =========================================================
# API POUR LES ENNEMIS
# =========================================================

func get_squad_role(enemy) -> int:
	if not is_instance_valid(enemy):
		return SquadRole.ASSAULT
	var eid = enemy.get_instance_id()
	if eid in squad_roles:
		return squad_roles[eid]
	return SquadRole.ASSAULT

func should_enemy_attack() -> bool:
	# En haute tension, les ennemis attaquent plus
	return tension > 30.0

func get_player_last_position() -> Vector3:
	if player and is_instance_valid(player):
		return player.global_position
	return Vector3.ZERO

func request_suppression_fire(requester_pos: Vector3):
	for e in enemies:
		if not is_instance_valid(e) or ("is_dead" in e and e.is_dead):
			continue
		var eid = e.get_instance_id()
		if eid in squad_roles and squad_roles[eid] == SquadRole.SUPPRESSOR:
			if "can_shoot" in e:
				e.can_shoot = true

func alert_squad(alert_pos: Vector3, alerter):
	for e in enemies:
		if e == alerter or not is_instance_valid(e):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		var dist = e.global_position.distance_to(alert_pos)
		if dist < 40.0:
			if "last_known_position" in e:
				e.last_known_position = alert_pos
			if "has_ever_seen_player" in e:
				e.has_ever_seen_player = true
			if "bt_state" in e and e.bt_state == e.BTState.PATROL:
				e.bt_state = e.BTState.INVESTIGATE

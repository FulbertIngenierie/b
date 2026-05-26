extends Control

# =========================================================
# RADAR FPS — AKA_FPK — radar moderne
# =========================================================

@onready var player_dot = $PlayerDot
@onready var player_dot_glow = $PlayerDotGlow

var map_size := 200.0
var radar_range := 80.0
var player: CharacterBody3D

var enemy_dots: Array = []
var enemy_dot_glows: Array = []
var sweep_angle := 0.0
var sweep_speed := 2.0

func _ready():
	find_player()
	_remove_old_dots()

func _remove_old_dots():
	if has_node("EnemyDot"):
		$EnemyDot.queue_free()
	if has_node("EnemyDotGlow"):
		$EnemyDotGlow.queue_free()

func _process(delta):
	if not player or not is_instance_valid(player):
		find_player()
		return
	
	sweep_angle += sweep_speed * delta
	if sweep_angle > TAU:
		sweep_angle -= TAU
	
	update_radar()

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func update_radar():
	if not player:
		return
	
	var center = size / 2.0
	player_dot.position = center - player_dot.size / 2.0
	player_dot_glow.position = center - player_dot_glow.size / 2.0
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	_sync_dot_count(enemies.size())
	
	var player_yaw = player.rotation.y
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if not is_instance_valid(enemy):
			enemy_dots[i].visible = false
			enemy_dot_glows[i].visible = false
			continue
		
		var is_dead_enemy = false
		if "is_dead" in enemy:
			is_dead_enemy = enemy.is_dead
		
		if is_dead_enemy:
			enemy_dots[i].visible = false
			enemy_dot_glows[i].visible = false
			continue
		
		var offset_3d = enemy.global_position - player.global_position
		var distance = offset_3d.length()
		
		if distance > radar_range:
			enemy_dots[i].visible = false
			enemy_dot_glows[i].visible = false
			continue
		
		var rel_x = offset_3d.x * cos(player_yaw) + offset_3d.z * sin(player_yaw)
		var rel_z = -offset_3d.x * sin(player_yaw) + offset_3d.z * cos(player_yaw)
		
		var scale_factor = (map_size * 0.4) / radar_range
		var dot_pos = center + Vector2(rel_x * scale_factor, rel_z * scale_factor)
		
		dot_pos.x = clamp(dot_pos.x, 5, size.x - 5)
		dot_pos.y = clamp(dot_pos.y, 5, size.y - 5)
		
		enemy_dots[i].position = dot_pos - enemy_dots[i].size / 2.0
		enemy_dot_glows[i].position = dot_pos - enemy_dot_glows[i].size / 2.0
		enemy_dots[i].visible = true
		enemy_dot_glows[i].visible = true
		
		# Pulse effect for close enemies
		var pulse = (sin(sweep_angle * 3.0) + 1.0) / 2.0
		if distance < 20.0:
			enemy_dots[i].color = Color(1, 0.1, 0.1, 0.8 + pulse * 0.2)
			enemy_dot_glows[i].color = Color(1, 0.1, 0.1, 0.3 + pulse * 0.2)
		else:
			enemy_dots[i].color = Color(1, 0.3, 0.1, 0.9)
			enemy_dot_glows[i].color = Color(1, 0.3, 0.1, 0.3)

func _sync_dot_count(count: int):
	while enemy_dots.size() < count:
		var dot = ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color(1, 0.2, 0.2, 1)
		add_child(dot)
		enemy_dots.append(dot)
		
		var glow = ColorRect.new()
		glow.size = Vector2(10, 10)
		glow.color = Color(1, 0.2, 0.2, 0.3)
		add_child(glow)
		enemy_dot_glows.append(glow)
	
	for i in range(count, enemy_dots.size()):
		enemy_dots[i].visible = false
		enemy_dot_glows[i].visible = false

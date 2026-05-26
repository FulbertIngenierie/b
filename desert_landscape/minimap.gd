extends Control

# =========================================================
# NODES
# =========================================================

@onready var player_dot = $PlayerDot
@onready var player_dot_glow = $PlayerDotGlow
@onready var enemy_dot = $EnemyDot
@onready var enemy_dot_glow = $EnemyDotGlow

# =========================================================
# VARIABLES
# =========================================================

var map_size := 200.0
var world_size := 100.0
var player: CharacterBody3D
var enemy: CharacterBody3D

# =========================================================
# READY
# =========================================================

func _ready():
	find_player_and_enemy()

# =========================================================
# PROCESS
# =========================================================

func _process(_delta):
	if not player or not enemy:
		find_player_and_enemy()
	
	update_minimap()

# =========================================================
# TROUVER JOUEUR ET ENNEMI
# =========================================================

func find_player_and_enemy():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	var enemies = get_tree().get_nodes_in_group("enemy_target")
	if enemies.size() > 0:
		enemy = enemies[0]

# =========================================================
# UPDATE MINIMAP
# =========================================================

func update_minimap():
	if not player or not enemy:
		return
	
	# Position du joueur sur la carte
	var player_pos = player.global_position
	var player_x = (player_pos.x / world_size) * map_size
	var player_z = (player_pos.z / world_size) * map_size
	
	player_dot.position = Vector2(
		size.x / 2 + player_x,
		size.y / 2 + player_z
	)
	
	player_dot_glow.position = Vector2(
		size.x / 2 + player_x,
		size.y / 2 + player_z
	)
	
	# Position de l'ennemi sur la carte
	var enemy_pos = enemy.global_position
	var enemy_x = (enemy_pos.x / world_size) * map_size
	var enemy_z = (enemy_pos.z / world_size) * map_size
	
	enemy_dot.position = Vector2(
		size.x / 2 + enemy_x,
		size.y / 2 + enemy_z
	)
	
	enemy_dot_glow.position = Vector2(
		size.x / 2 + enemy_x,
		size.y / 2 + enemy_z
	)

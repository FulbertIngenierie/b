extends Control

# =========================================================
# HUD FPS — AKA_FPK — Joueur: AKAZZA
# =========================================================

@onready var player_health_label = $PlayerPanel/PlayerHealthLabel
@onready var player_health_bar = $PlayerPanel/PlayerHealthBar
@onready var player_ammo_label = $PlayerPanel/PlayerAmmoLabel

@onready var enemy_health_label = $EnemyPanel/EnemyHealthLabel
@onready var enemy_health_bar = $EnemyPanel/EnemyHealthBar
@onready var enemy_ammo_label = $EnemyPanel/EnemyAmmoLabel

var player: CharacterBody3D
var player_name_label: Label = null
var enemy_health_bar_3d: Control = null

func _ready():
	find_player()
	_create_player_name_label()
	update_hud()

func _process(_delta):
	if not player or not is_instance_valid(player):
		find_player()
	update_hud()
	_update_enemy_health_bar_3d()

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _create_player_name_label():
	player_name_label = Label.new()
	player_name_label.text = "AKAZZA"
	player_name_label.add_theme_font_size_override("font_size", 16)
	player_name_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1))
	player_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	player_name_label.add_theme_constant_override("shadow_offset_x", 1)
	player_name_label.add_theme_constant_override("shadow_offset_y", 1)
	
	var panel = get_node_or_null("PlayerPanel")
	if panel:
		player_name_label.position = Vector2(10, -20)
		panel.add_child(player_name_label)

func update_hud():
	if player and is_instance_valid(player):
		var hp = 100
		if player.has_method("get_health"):
			hp = player.get_health()
		elif "health" in player:
			hp = player.health
		player_health_label.text = "VIE: " + str(hp)
		player_health_bar.value = hp
		
		# Couleur de la barre de vie selon le niveau
		if hp > 60:
			player_health_bar.modulate = Color(0.2, 1, 0.2, 1)
		elif hp > 30:
			player_health_bar.modulate = Color(1, 0.8, 0, 1)
		else:
			player_health_bar.modulate = Color(1, 0.2, 0.2, 1)
		
		var am = 30
		if player.has_method("get_ammo"):
			am = player.get_ammo()
		elif "ammo" in player:
			am = player.ammo
		player_ammo_label.text = "MUNITIONS: " + str(am)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_count := 0
	var total_hp := 0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dead = false
		if "is_dead" in e:
			dead = e.is_dead
		if not dead:
			alive_count += 1
			if "health" in e:
				total_hp += e.health
	
	enemy_health_label.text = "ENNEMIS: " + str(alive_count)
	if alive_count > 0:
		enemy_health_bar.value = float(total_hp) / float(alive_count)
	else:
		enemy_health_bar.value = 0
	enemy_ammo_label.text = "RESTANTS: " + str(alive_count) + "/4"

func _update_enemy_health_bar_3d():
	if not player or not is_instance_valid(player):
		return
	
	var camera = player.get_node_or_null("Head/Camera3D")
	if not camera:
		return
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var cam_dir = -camera.global_transform.basis.z.normalized()
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			_hide_enemy_bar(enemy)
			continue
		
		var to_enemy = (enemy.global_position - camera.global_position).normalized()
		var dot = to_enemy.dot(cam_dir)
		var dist = camera.global_position.distance_to(enemy.global_position)
		
		if dot > 0.95 and dist < 50.0:
			_show_enemy_bar(enemy, camera)
		else:
			_hide_enemy_bar(enemy)

func _show_enemy_bar(enemy, camera):
	var bar = enemy.get_node_or_null("EnemyHealthBar3D")
	if not bar:
		bar = _create_enemy_bar(enemy)
	
	if "health" in enemy:
		var fill = bar.get_node_or_null("Fill")
		if fill:
			var hp_ratio = float(enemy.health) / 100.0
			fill.scale.x = hp_ratio
			if hp_ratio > 0.5:
				fill.color = Color(0.2, 1, 0.2, 0.8)
			elif hp_ratio > 0.25:
				fill.color = Color(1, 0.8, 0, 0.8)
			else:
				fill.color = Color(1, 0.2, 0.2, 0.8)
	
	bar.visible = true

func _hide_enemy_bar(enemy):
	var bar = enemy.get_node_or_null("EnemyHealthBar3D")
	if bar:
		bar.visible = false

func _create_enemy_bar(enemy) -> Node3D:
	var bar_root = Node3D.new()
	bar_root.name = "EnemyHealthBar3D"
	bar_root.position = Vector3(0, 2.5, 0)
	enemy.add_child(bar_root)
	
	var bg_mesh = MeshInstance3D.new()
	bg_mesh.name = "BG"
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(1.0, 0.1)
	bg_mesh.mesh = bg_quad
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.2, 0.2, 0.6)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mesh.material_override = bg_mat
	bar_root.add_child(bg_mesh)
	
	var fill_mesh = MeshInstance3D.new()
	fill_mesh.name = "Fill"
	var fill_quad = QuadMesh.new()
	fill_quad.size = Vector2(0.96, 0.06)
	fill_mesh.mesh = fill_quad
	var fill_mat = StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 1, 0.2, 0.8)
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mesh.material_override = fill_mat
	fill_mesh.position.z = -0.01
	bar_root.add_child(fill_mesh)
	
	return bar_root

extends BeehaveAction
class_name ShootAtPlayer

@export var bullet_scene : PackedScene   # À assigner dans l'inspecteur
@export var cooldown : float = 1.0        # secondes entre deux tirs

var last_shot_time : float = 0.0

func tick(actor: Node, blackboard: Blackboard) -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or bullet_scene == null:
		return FAILURE
	
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_shot_time >= cooldown:
		# Instancier la balle
		var bullet = bullet_scene.instantiate()
		bullet.global_position = actor.global_position
		bullet.direction = (player.global_position - actor.global_position).normalized()
		get_tree().root.add_child(bullet)
		last_shot_time = now
		return SUCCESS
	
	return RUNNING   # attend la fin du cooldown

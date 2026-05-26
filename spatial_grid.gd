extends Node
class_name SpatialGrid

@export var cell_size := 12.0

var grid := {}

func _cell(pos: Vector3) -> Vector3i:
	return Vector3i(
		floor(pos.x / cell_size),
		floor(pos.y / cell_size),
		floor(pos.z / cell_size)
	)

func add_object(obj: Node3D):

	var c = _cell(obj.global_position)

	if !grid.has(c):
		grid[c] = []

	grid[c].append(obj)

func remove_object(obj: Node3D):

	var c = _cell(obj.global_position)

	if grid.has(c):
		grid[c].erase(obj)

func update_object(obj: Node3D, old_pos: Vector3):

	var old_cell = _cell(old_pos)
	var new_cell = _cell(obj.global_position)

	if old_cell == new_cell:
		return

	if grid.has(old_cell):
		grid[old_cell].erase(obj)

	if !grid.has(new_cell):
		grid[new_cell] = []

	grid[new_cell].append(obj)

func get_nearby(pos: Vector3) -> Array:

	var result := []
	var center = _cell(pos)
"res://HitEffect.tscn"
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):

				var c = Vector3i(
					center.x + x,
					center.y + y,
					center.z + z
				)

				if grid.has(c):
					result += grid[c]

	return result

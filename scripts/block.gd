@tool
extends CharacterBody2D
class_name Block

enum Direction {
	LEFT, RIGHT, UP, DOWN
}

const dir_map = [
	Vector2i(-1, 0), 
	Vector2i(1, 0), 
	Vector2i(0, -1), 
	Vector2i(0, 1)
]

@export var is_gravity_enabled := true:
	set(value):
		is_gravity_enabled = value
		if value:
			static_block = false
		_update_sprite()

@export var static_block := false:
	set(value):
		static_block = value
		if value:
			is_gravity_enabled = false
		_update_sprite()

@export var is_main_character := false:
	set(value):
		is_main_character = value
		_update_sprite()

@export var rotatable: bool = false
@export_range(-360, 360) var angle: float = 0:
	set(value):
		angle = value
		#$CollisionShape.rotation_degrees = value
		#$Sprite.rotation_degrees = value

@export var scale_max_speed : float = 1.5

@export_group("Up Extandable")
@export var up_extendable: bool = false
@export var up_extend_range: Vector2i = Vector2i(8, 100)
@export var up_extend_value: float = 8:
	set(value):
		up_extend_value = clamp(value, up_extend_range.x, up_extend_range.y)
		update_dimensions()

@export_group("Down Extandable")
@export var down_extendable: bool = false
@export var down_extend_range: Vector2i = Vector2i(8, 100)
@export var down_extend_value: float = 8:
	set(value):
		down_extend_value = clamp(value, down_extend_range.x, down_extend_range.y)
		update_dimensions()

@export_group("Left Extandable")
@export var left_extendable: bool = false
@export var left_extend_range: Vector2i = Vector2i(8, 100)
@export var left_extend_value: float = 8:
	set(value):
		left_extend_value = clamp(value, left_extend_range.x, left_extend_range.y)
		update_dimensions()

@export_group("Right Extandable")
@export var right_extendable: bool = false
@export var right_extend_range: Vector2i = Vector2i(8, 100)
@export var right_extend_value: float = 8:
	set(value):
		right_extend_value = clamp(value, right_extend_range.x, right_extend_range.y)
		update_dimensions()

################################################

@onready var main := get_node("/root/Main")
@onready var sleep_particles: CPUParticles2D = $Sleep/SleepParticles

var is_hovered := false
var is_selected := false
var handles: Array = []
var direction_indicators: Array[Sprite2D] = []
var scale_handle: PackedScene = load("res://scenes/scale_handle.tscn")
var direction_indicator: PackedScene = load("res://scenes/direction_indicator.tscn")

var animation = "o_face"
var is_asleep := false

################################################

func expand(direction: Direction, amount: int):
	if direction == Direction.RIGHT:
		right_extend_value += amount
	if direction == Direction.LEFT:
		left_extend_value += amount
	if direction == Direction.UP:
		up_extend_value += amount
	if direction == Direction.DOWN:
		down_extend_value += amount

func update_dimensions():
	var dim: Vector2 = Vector2(left_extend_value + right_extend_value, 
							   up_extend_value + down_extend_value)
	var collision_shape = $CollisionShape
	var click_area = $ClickArea
	var click_area_collision_shape = $ClickArea/ClickAreaCollisionShape
	var unclick_area_collision_shape = $UnClickArea/ClickAreaCollisionShape
	var shape = collision_shape.shape
	var light_occ : LightOccluder2D = $BlockOccluder

	if shape is not RectangleShape2D:
		print("$CollisionShape.shape is not a RectangleShape2D")
		return
	
	# Update size
	shape.size = dim
	click_area_collision_shape.shape.size = dim
	if light_occ != null:
		light_occ.occluder.polygon = [Vector2(-dim.x/2, -dim.y/2), Vector2(dim.x/2, -dim.y/2), Vector2(dim.x/2, dim.y/2), Vector2(-dim.x/2, dim.y/2)]
	unclick_area_collision_shape.shape.size = dim + Vector2(8, 8)
	
	# Update position
	var child_pos: Vector2 = Vector2(-left_extend_value + right_extend_value,
									 -up_extend_value   + down_extend_value) / 2
	if light_occ != null:
		light_occ.position = child_pos
	collision_shape.position = child_pos
	unclick_area_collision_shape.position = child_pos
	click_area.position = child_pos
	update_sprite_size(child_pos, dim)

func update_sprite_size(_pos, dimensions):
	var nine_patch: NinePatchRect = $NinePatch
	nine_patch.position = round(get_center() - dimensions/2)
	nine_patch.size = round(dimensions)

func select():
	if is_selected:
		return
	
	is_selected = true
	_show_scale_handles()
	extend_direction_indicator()
	BlockManagerAutoload.on_select_block(self)

func unselect():
	if not is_selected:
		return
	
	is_selected = false
	_hide_scale_handles()
	retract_direction_indicator()
	BlockManagerAutoload.on_unselect_block(self)

func get_dimensions():
	return Vector2(left_extend_value + right_extend_value, up_extend_value + down_extend_value)

func get_rect() -> Rect2i:
	return Rect2i(int(position.x - left_extend_value), int(position.y - up_extend_value), 
				int(left_extend_value + right_extend_value), int(up_extend_value + down_extend_value))

func get_grid_rect() -> Rect2i:
	var rect = get_rect()
	return Rect2i((rect.position.x + 8) / 16, (rect.position.y + 8) / 16, rect.size.x / 16, rect.size.y / 16)

func get_center():
	return $CollisionShape.position

func get_all_tree_nodes(node = get_tree().get_root(), list = []):
	list.append(node)
	for childNode in node.get_children():
		get_all_tree_nodes(childNode, list)
	return list

func print_grid(grid):
	for line in grid:
		var l = ""
		for row in line:
			var c = "D"
			if row == -2:
				c = " "
			if row == -1:
				c = "S"
			l += c
		print(l)

func get_grid():
	var grid := []
	var block_id = 0
	
	for node in get_all_tree_nodes():
		if node is TileMapLayer:
			if not node.collision_enabled:
				continue
			var cells = node.get_used_cells()
			var xmax = 0
			var ymax = 0
			for cell in cells:
				if cell.x > xmax:
					xmax = cell.x
				if cell.y > ymax:
					ymax = cell.y
			for y in range(ymax + 1):
				grid.append([])
				for x in range(xmax + 1):
					grid[y].append(-2) # empty
			
			for cell in cells:
				if cell.x < 0 or cell.y < 0:
					continue
				grid[cell.y][cell.x] = -1 # static
		if node is Block:
			var id = -1
			if not node.static_block:
				id = block_id
				block_id += 1
			var rect = node.get_grid_rect()
			var ymin = rect.position.y
			var ymax = rect.position.y + rect.size.y
			var xmin = rect.position.x
			var xmax = rect.position.x + rect.size.x
			
			for y in range(ymin, ymax):
				for x in range(xmin, xmax):
					if y < 0 or y >= len(grid) or x < 0 or y >= len(grid[y]):
						continue
					grid[y][x] = id
	return grid

func left(direction):
	return Vector2i(direction.y, -direction.x)

func right(direction):
	return Vector2i(-direction.y, direction.x)

func can_move(grid: Array, x: int, y: int, direction: Vector2i) -> bool:
	if y < 0 or y >= len(grid) or x < 0 or x >= len(grid[y]):
		return false
	
	if grid[y][x] == -2:
		return true
	if grid[y][x] == -1:
		return false

	var val = grid[y][x]
	grid[y][x] = -2
	
	var left_dir = left(direction)
	if grid[y + left_dir.y][x + left_dir.x] == val and not can_move(grid, x + left_dir.x, y + left_dir.y, direction):
		return false
	
	var right_dir = right(direction)
	if grid[y + right_dir.y][x + right_dir.x] == val and not can_move(grid, x + right_dir.x, y + right_dir.y, direction):
		return false
	
	return can_move(grid, x + direction.x, y + direction.y, direction)

func get_pos(direction: Direction) -> Vector2i:
	var rect = get_grid_rect()
	if direction == Direction.LEFT or direction == Direction.UP:
		return Vector2i(rect.position.x, rect.position.y)
	if direction == Direction.RIGHT:
		return Vector2i(rect.position.x + (rect.size.x - 1), rect.position.y)
	return Vector2i(rect.position.x, rect.position.y + (rect.size.y - 1))

func get_opposite_direction(direction: Direction) -> Direction:
	if direction == Direction.LEFT:
		return Direction.RIGHT
	if direction == Direction.RIGHT:
		return Direction.LEFT
	if direction == Direction.UP:
		return Direction.DOWN
	return Direction.UP

func check_move_block(grid: Array, dir: Direction) -> bool:
	var direction = dir_map[dir]
	var rect = get_grid_rect()
	var pos = get_pos(dir)

	if dir == Direction.DOWN or dir == Direction.UP:
		for x in range(rect.size.x):
			if not can_move(grid, pos.x + x + direction.x, pos.y + direction.y, direction):
				return false
	if dir == Direction.LEFT or dir == Direction.RIGHT:
		for y in range(rect.size.y):
			if not can_move(grid, pos.x + direction.x, pos.y + y + direction.y, direction):
				return false
	return true


func check_movements(dir: Direction) -> bool:
	var grid = get_grid()
	if check_move_block(grid, dir):
		return true
	
	if not static_block and check_move_block(grid, get_opposite_direction(dir)):
		return true

	return false

func is_moving(dir: Direction) -> bool:
	var val = left_extend_value
	if dir == Direction.RIGHT:
		val = right_extend_value
	if dir == Direction.UP:
		val = up_extend_value
	if dir == Direction.DOWN:
		val = down_extend_value
	
	return fmod(val + 8, 16) != 0

func get_variation(dir: Direction) -> float:
	var pos_diff = get_global_mouse_position() - global_position
	if dir == Direction.LEFT:
		return pos_diff.x + left_extend_value
	if dir == Direction.RIGHT:
		return pos_diff.x - right_extend_value
	if dir == Direction.UP:
		return pos_diff.y + up_extend_value
	if dir == Direction.DOWN:
		return pos_diff.y - down_extend_value
	return -1

################################################

func _update_sprite():
	# Update animation
	_update_animation()
	
	# Change 9-patch sprite
	var ninepatch: NinePatchRect = $NinePatch
	if is_main_character: # Normal
		ninepatch.region_rect.position = Vector2(0, 96)
	elif static_block: # Normal
		ninepatch.region_rect.position = Vector2(16, 80)
	elif is_gravity_enabled: # Gravity
		ninepatch.region_rect.position = Vector2(32, 80)
	#else: # bleu
		#ninepatch.region_rect.position.x = 0
		#ninepatch.region_rect.position.y = 32

func _update_animation():
	var dim = get_dimensions()
	var size = dim.x * dim.y
	var old_animation = animation
	
	if not is_selected:
		animation = "sleeping"
	elif size <= 4*16*16:
		animation = "poker"
	elif size <= 6*16*16:
		animation = "fat"
	else:
		animation = "scared"
	
	if sleep_particles:
		sleep_particles.emitting = (animation == "sleeping")

func _create_scale_handle(direction: Direction, handle_name: String):
	var new_scale_handle: ScaleHandle = scale_handle.instantiate()
	new_scale_handle.block = self
	new_scale_handle.name = handle_name
	new_scale_handle.direction = direction
	new_scale_handle.z_index = 10
	
	new_scale_handle.start_drag.connect(func():
		_on_scale_handle_start_drag(new_scale_handle, direction)
	)
	new_scale_handle.end_drag.connect(func():
		_on_scale_handle_end_drag(new_scale_handle, direction)
	)
	new_scale_handle.dragging.connect(func():
		_on_scale_handle_dragged(new_scale_handle, direction)
	)
	add_child(new_scale_handle)
	new_scale_handle.initialize()
	
	var new_direction_indicator = direction_indicator.instantiate()
	new_direction_indicator.block = self
	new_direction_indicator.direction = direction
	add_child(new_direction_indicator)
	new_direction_indicator.initialize()
	
	handles.append({
		handle = new_scale_handle,
		direction_indicator = new_direction_indicator,
	})

func _create_scale_handles():
	if left_extendable:
		_create_scale_handle(Direction.LEFT, "LeftHandle")
	if right_extendable:
		_create_scale_handle(Direction.RIGHT, "RightHandle")
	if up_extendable:
		_create_scale_handle(Direction.UP, "UpHandle")
	if down_extendable:
		_create_scale_handle(Direction.DOWN, "DownHandle")
	
	_update_scale_handles()

func _update_scale_handles():
	var center = get_center()
	var dimensions = get_dimensions()
	for handle_info in handles:
		var handle = handle_info["handle"]
		var direction = handle.direction
		var handle_position = center + Util.direction_to_vector(direction) * (dimensions/2)
		handle.position = round(handle_position) 
		
		var indicator = handle_info["direction_indicator"]
		indicator.is_held = handle.is_held

func _hide_scale_handles():
	for handle in handles:
		handle["handle"].hide_handle()

func _show_scale_handles():
	for handle in handles:
		handle["handle"].show_handle()

func retract_direction_indicator():
	for handle in handles:
		handle["direction_indicator"].retract_indicator()

func extend_direction_indicator():
	for handle in handles:
		handle["direction_indicator"].extend_indicator()

func hide_direction_indicator():
	for handle in handles:
		handle["direction_indicator"].hide_indicator()

func show_direction_indicator():
	for handle in handles:
		handle["direction_indicator"].show_indicator()


################################################

func _ready():
	$CollisionShape.shape = $CollisionShape.shape.duplicate()
	$ClickArea/ClickAreaCollisionShape.shape = $ClickArea/ClickAreaCollisionShape.shape.duplicate()
	
	if Engine.is_editor_hint():
		return
	
	_update_sprite()
	
	up_extend_value = up_extend_value
	down_extend_value = down_extend_value
	left_extend_value = left_extend_value
	right_extend_value = right_extend_value
	_create_scale_handles()
	_hide_scale_handles()
	
	update_dimensions()
	BlockManagerAutoload.register_block(self)

func _process(delta):
	if Engine.is_editor_hint():
		return
	
	$CenterIndicator.play(animation)

func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	
	velocity.x /= 2
	if is_gravity_enabled:
		if not is_on_floor():
			velocity += get_gravity() * delta
		
		const rot_speed = 0.1
		var alpha = fmod(fmod(angle, 90) + 90, 90)
		
		if is_on_floor() and alpha != 0:
			if alpha < 45:
				angle -= alpha * rot_speed
			else:
				angle += alpha * rot_speed
	else:
		velocity.y /= 2
	
	if not static_block:
		move_and_slide()
	
	_update_scale_handles()
	_update_sprite()

func _on_click_area_clicked():
	if BlockManagerAutoload.can_select(self):
		BlockManagerAutoload.new_selection_candidate(self)

func _on_un_click_area_clicked_outside_area():
	unselect()

func _on_scale_handle_start_drag(handle: ScaleHandle, direction: Direction):
	BlockManagerAutoload.start_drag()

func _on_scale_handle_end_drag(handle: ScaleHandle, direction: Direction):
	BlockManagerAutoload.end_drag()

func _on_scale_handle_dragged(handle: ScaleHandle, direction: Direction):
	if is_moving(direction):
		return

	var variation = get_variation(direction)
	if abs(variation) < 8:
		return

	if variation > 0:
		variation = 16
	else:
		variation = -16
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC)
	
	if direction == Direction.LEFT:
		if variation < 0 && not check_movements(direction):
			return
		tween.tween_property(self, "left_extend_value", left_extend_value - variation, 0.3).set_ease(Tween.EASE_OUT)
	elif direction == Direction.RIGHT:
		if variation > 0 && not check_movements(direction):
			return
		tween.tween_property(self, "right_extend_value", right_extend_value + variation, 0.3).set_ease(Tween.EASE_OUT)
	elif direction == Direction.UP:
		if variation < 0 && not check_movements(direction):
			return
		tween.tween_property(self, "up_extend_value", up_extend_value - variation, 0.3).set_ease(Tween.EASE_OUT)
	elif direction == Direction.DOWN:
		if variation > 0 && not check_movements(direction):
			return
		tween.tween_property(self, "down_extend_value", down_extend_value + variation, 0.3).set_ease(Tween.EASE_OUT)
	
	_update_scale_handles()

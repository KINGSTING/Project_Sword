extends Node2D

@onready var tilemap = $TileMapLayer  # Ensure this is a TileMap node
@onready var orc_scene = preload("res://Scenes/characters/orc_enemy.tscn")  # Preload the orc scene
@onready var door_scene = preload("res://Scenes/components/door.tscn")

var platform_atlas = Vector2i(0, 0)  # Ground tile in the atlas
var wall_atlas = Vector2i(0, 1)      # Wall tile in the atlas

const WIDTH = 130   # Grid width (horizontal)
const HEIGHT = 150 # Grid height (vertical)
const ROW_SPACING = 5  # Distance between rows
const WALK_HEIGHT = 5  # Limit height variation per walker
const WALK_LENGTH = 20 # Max steps per walker
const GAP_SIZE = 3  # Ensure at least one 3-cell wide gap
const TILE_SIZE = 16  # Change this to your actual tile size


func _ready():
	generate_terrain()
	generate_walls()  # Add walls at the edges
	spawn_orc_enemies()
	spawn_door()

func generate_terrain():
	var start_y = 2  # Initial row height
	while start_y + WALK_HEIGHT < HEIGHT - 3:
		place_random_walker(start_y)
		start_y += ROW_SPACING + WALK_HEIGHT  # Ensure spacing

func generate_walls():
	# Place walls along the left (x = 0) and right (x = WIDTH - 1) edges
	for y in range(HEIGHT):
		set_tile(0, y, wall_atlas)  # Left wall
		set_tile(WIDTH - 1, y, wall_atlas)  # Right wall

func place_random_walker(start_y):
	var x = 1  # Start from left wall
	var y = start_y  # Controlled vertical movement
	
	var placed_positions = []
	while x < WIDTH - 1:  # Stop before the right wall
		# Random height variation within 5-cell range
		if randi() % 6 == 0:
			y -= 1
		elif randi() % 6 == 0:
			y += 1
		
		# Clamp within assigned height range
		y = clamp(y, start_y, start_y + WALK_HEIGHT)  
		
		# **Make the row thicker**
		var thickness = randi() % 3 + 2  # Random thickness between 2-4
		for i in range(thickness):
			var tile_pos = Vector2i(x, y + i)
			set_tile(tile_pos.x, tile_pos.y, platform_atlas)
			placed_positions.append(tile_pos)

		x += 1  # Move right

	# **Create gaps properly**
	create_vertical_gap(placed_positions)

func create_vertical_gap(positions):
	var row_groups = {}

	# Group tiles by row
	for pos in positions:
		if pos.y not in row_groups:
			row_groups[pos.y] = []
		row_groups[pos.y].append(pos)

	print("Total rows detected: ", row_groups.keys().size())

	for row in row_groups.keys():
		var row_positions = row_groups[row]
		row_positions.sort_custom(func(a, b): return a.x < b.x)  # Sort by x position

		if row_positions.size() > 2:  # Ensure we have enough tiles to remove
			var gap_x_index = randi() % (row_positions.size() - 2)
			var gap_x = row_positions[gap_x_index].x

			# Randomly determine how many rows downward to cut
			var vertical_cut_depth = randi() % 4 + 2  # Cut between 2 to 5 rows

			for i in range(3):  # Remove tiles in a 3-cell wide vertical cut
				for j in range(vertical_cut_depth):
					var target_row = row + j
					if target_row in row_groups:
						for pos in row_groups[target_row]:
							if pos.x == gap_x + i:
								clear_tile(pos.x, target_row)
								print("Cleared tile at: (", pos.x, ",", target_row, ")")

	print("Vertical gaps created.")

func spawn_orc_enemies():
	var valid_positions = []
	
	# Scan all tiles to find valid spawn points
	for x in range(1, WIDTH - 1):  # Avoid walls
		for y in range(HEIGHT - 1):  # Avoid top edge
			if is_valid_spawn(x, y):
				valid_positions.append(Vector2(x, y))
	
	# Sort positions by row (Y-axis) for better control
	valid_positions.sort_custom(func(a, b): return a.y < b.y)
	
	var used_rows = {}  # Track spawned orcs per row

	for pos in valid_positions:
		var row = int(pos.y)
		if row in used_rows:
			continue  # Skip if an orc is already placed in this row

		place_orc(pos)
		used_rows[row] = true  # Mark row as used

func is_valid_spawn(x, y):
	# Must be on a platform tile
	if tilemap.get_cell_atlas_coords(Vector2i(x, y)) != platform_atlas:
		return false

	# Ensure no tile above (checking one cell higher)
	if tilemap.get_cell_atlas_coords(Vector2i(x, y - 1)) != Vector2i(-1, -1):
		return false

	return true

func place_orc(position):
	var orc = orc_scene.instantiate()
	orc.position = position * 16  # Adjust according to tile size
	add_child(orc)

func find_lowest_platform_row():
	for y in range(HEIGHT - 2, 0, -1):  # Start from bottom, move up
		for x in range(1, WIDTH - 1):
			if tilemap.get_cell_atlas_coords(Vector2i(x, y)) == platform_atlas:
				return y  # Found lowest platform row
	return 1  # Default fallback

func spawn_door():
	var bottom_y = find_lowest_platform_row()
	print("Lowest platform row:", bottom_y)

	var valid_positions = []

	# Collect valid positions for the door **above** the lowest row
	for y in range(bottom_y - 1, 0, -1):  # Start from just above the lowest row, move up
		for x in range(1, WIDTH - 1):  # Avoid walls
			if is_valid_door_position(x, y):
				valid_positions.append(Vector2i(x, y))
				print("✅ Valid door position found at:", x, y)

		# Stop checking once at least one valid position is found
		if valid_positions.size() > 0:
			break

	# Randomly place the door at one of the valid positions
	if valid_positions.size() > 0:
		var door_pos = valid_positions[randi() % valid_positions.size()]
		var door = door_scene.instantiate()

		# Ensure the door is placed **on** the platform correctly
		door.position = Vector2(door_pos.x * TILE_SIZE, door_pos.y * TILE_SIZE)
		add_child(door)
		print("🚪 Door placed at:", door.position)
	else:
		print("⚠ No valid position found for the door!")

# Function to check if a position is valid for the door
func is_valid_door_position(x, y):
	if tilemap.get_cell_atlas_coords(Vector2i(x, y)) != platform_atlas:
		return false  # Must be on a platform tile

	var above_tile = tilemap.get_cell_atlas_coords(Vector2i(x, y - 1))
	var left_tile = tilemap.get_cell_atlas_coords(Vector2i(x - 1, y))
	var right_tile = tilemap.get_cell_atlas_coords(Vector2i(x + 1, y))

	# Ensure space above and on the sides
	var above_empty = above_tile == Vector2i(-1, -1)
	var left_empty = left_tile == Vector2i(-1, -1)
	var right_empty = right_tile == Vector2i(-1, -1)

	return above_empty and left_empty and right_empty


		
func set_tile(x, y, atlas_coords):
	tilemap.set_cell(Vector2i(x, y), 0, atlas_coords)  # Corrected parameters

func clear_tile(x, y):
	tilemap.set_cell(Vector2i(x, y), -1)  # Corrected parameters

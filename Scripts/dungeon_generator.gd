extends Node2D

@export var noise_height_text: NoiseTexture2D
var noise: Noise

@onready var tile_map = $TileMapLayer

var width = 100
var height = 150

var source_id = 0
var platform_atlas = Vector2i(0, 1)  # Ground tile
var wall_atlas = Vector2i(1, 1)      # Wall tile

func _ready() -> void:
	noise = noise_height_text.noise
	generate_world()

func generate_world():
	# First pass: Generate terrain directly from noise
	for x in range(width):
		for y in range(height):
			var noise_val: float = noise.get_noise_2d(x * 0.1, y * 0.1)  # Use scaled noise
			
			# Threshold for ground placement
			if noise_val > 0.0:
				tile_map.set_cell(Vector2i(x, y), source_id, platform_atlas)

	# Second pass: Generate walls around the terrain
	for x in range(width):
		for y in range(height):
			var is_edge = x == 0 or x == width - 1 or y == 0 or y == height - 1  # Check if it's the border
			if is_edge:
				tile_map.set_cell(Vector2i(x, y), source_id, wall_atlas)  # Place walls at the edges

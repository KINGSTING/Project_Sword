extends CharacterBody2D

@onready var animation_player = $AnimatedSprite2D
@onready var detection_area = $vision/vision_collision

const SPEED = 150.0
const ACCELERATION = 500.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 1000.0
const ATTACK_RANGE = 30.0  # Distance to attack

var player: CharacterBody2D = null
var current_state = "IDLE"

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Handle enemy states
	match current_state:
		"IDLE":
			idle_behavior()
		"CHASE":
			chase_behavior(delta)
		"ATTACK":
			attack_behavior()

	move_and_slide()

# ---------------------- IDLE STATE ----------------------
func idle_behavior():
	velocity.x = 0
	animation_player.play("fire_knight_idle")

# ---------------------- CHASE STATE ----------------------
func chase_behavior(delta):
	if player:
		var direction = (player.global_position - global_position).normalized()
		print("Direction to player: ", direction)

		# Check if within attack range
		if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
			current_state = "ATTACK"
			print("Player in attack range at position: ", player.global_position)
			return

		# Move towards the player
		velocity.x = lerp(velocity.x, direction.x * SPEED, ACCELERATION * delta)

		# Flip sprite based on movement direction
		if direction.x != 0:
			animation_player.flip_h = direction.x < 0

		animation_player.play("fire_knight_run")
		print("Chasing player, velocity: ", velocity)

# ---------------------- ATTACK STATE ----------------------
func attack_behavior():
	velocity.x = 0
	animation_player.play("fire_knight_atk1")
	await animation_player.animation_finished
	current_state = "CHASE"

# ---------------------- DETECTION & CHASING ----------------------
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		print("Player detected at position: ", player.global_position)
		current_state = "CHASE"

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		print("Player left detection area")
		player = null
		current_state = "IDLE"

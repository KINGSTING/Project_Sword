extends CharacterBody2D

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var detection_area = $vision/detection_area

@export var speed: float = 50.0
@export var acceleration: float = 200.0
@export var gravity: float = 1200.0
@export var attack_range: float = 30.0  # Distance to attack

var player: CharacterBody2D = null
var current_state = "IDLE"

func _physics_process(delta):
	apply_gravity(delta)

	match current_state:
		"IDLE":
			idle_behavior()
		"CHASE":
			chase_behavior(delta)
		"ATTACK":
			attack_behavior()

	move_and_slide()

# ---------------------- GRAVITY ----------------------
func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta  # Apply gravity when not on the floor
	else:
		velocity.y = 0  # Reset velocity when grounded

# ---------------------- IDLE STATE ----------------------
func idle_behavior():
	velocity.x = 0
	animation_player.play("idle")

# ---------------------- CHASE STATE ----------------------
func chase_behavior(delta):
	if player:
		var direction = (player.global_position - global_position).normalized()
		print("📌 Direction to player:", direction)

		if global_position.distance_to(player.global_position) <= attack_range:
			current_state = "ATTACK"
			print("🎯 Player in attack range!")
			return

		velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta) 
		print("🚀 Chasing player | Velocity:", velocity.x)

		# Flip sprite
		if direction.x != 0:
			sprite.flip_h = direction.x < 0

		animation_player.play("walk")
		
# ---------------------- ATTACK STATE ----------------------
func attack_behavior():
	velocity.x = 0
	animation_player.play("attack")
	await animation_player.animation_finished
	current_state = "CHASE"

# ---------------------- DETECTION & CHASING ----------------------
func _on_vision_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		player = area.get_parent()
		print("✅ Player detected at position: ", player.global_position)
		print("Switching to CHASE state")
		current_state = "CHASE"
	else:
		print("❌ Something else entered: ", area.name)

func _on_vision_area_exited(area: Area2D) -> void:
	if area.is_in_group("player"):
		print("Player left detection area")
		player = null
		current_state = "IDLE"

# ---------------------- LINE OF SIGHT CHECK ----------------------
func is_player_visible() -> bool:
	if not player:
		return false
	
	var direction = (player.global_position - global_position).normalized()

	# Ensure we are checking in the correct direction
	detection_area.look_at(player.global_position)

	# Check if there are obstacles blocking vision
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collide_with_areas = true  # Include areas in the check
	query.collide_with_bodies = true # Include physics bodies

	var result = space_state.intersect_ray(query)

	# If there's no collision OR the first collision is the player, the player is visible
	if not result or result["collider"] == player:
		return true

	return false

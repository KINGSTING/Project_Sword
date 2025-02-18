extends CharacterBody2D

# Constants for movement
const SPEED = 150.0
const JUMP_VELOCITY = -350.0
const GRAVITY = 1000.0  # Custom gravity
const FALL_GRAVITY = 1300
const DASH_SPEED = 600.0  # Dash speed (higher than regular speed)
const DASH_DURATION = 0.2  # Dash duration in seconds
const DASH_COOLDOWN = 1.0  # Dash cooldown time

# Reference to nodes
@onready var sprite = $AnimatedSprite2D
@onready var attack_collision = $attack_collision  # Attack Area2D
@onready var attack_shape = attack_collision.get_node("attack_area")  # CollisionShape2D
@onready var hurt_collision: CollisionShape2D = $hurt_collison/hurt_area
@onready var attack_enemy_detector: RayCast2D = $attack_player_detector # Ensure this exists in the scene
@onready var health_bar = $HealthBar

@export var coyote_time: float = 0.2

# Attack cooldowns
var attack_cooldown = 0.5
var attack_timer = 0.0

# Health points
var max_hp = 10
var hp = max_hp
var attack_in_progress = false  # True when an attack animation is playing

# Coyote Jumptime
var jump_available: bool = true
var coyote_timer = 0.0

# Dash variables
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector2.ZERO

var player_in_range = false  # Track if the player is inside the attack zone
var is_knocked_back = false

func _ready() -> void:
	# Set initial animation to idle
	sprite.play("idle")
	sprite.animation_finished.connect(_on_animation_finished)
	hurt_collision.connect("area_entered", _on_attack_area_entered)  # Correct collision
	health_bar.init_health(hp)

func _physics_process(delta: float) -> void:
	# Handle dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if is_knocked_back:
		return  # Prevent player from controlling movement
	
	# Handle dash duration
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
		velocity = dash_direction * DASH_SPEED  # Ensure movement is applied during dashing

	# Apply gravity
	if not is_on_floor() and not is_dashing:
		if jump_available and coyote_timer <= 0:
			coyote_timer = coyote_time
		velocity.y += calculate_gravity(velocity) * delta
	else:
		if velocity.y > 0 and not is_dashing:
			velocity.y = 0  # Stop downward velocity when hitting the floor	
		jump_available = true 
		coyote_timer = 0  # Reset coyote timer when landing
	
	# Coyote time countdown
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y = JUMP_VELOCITY / 4
	
	# Handle jump input
	if Input.is_action_just_pressed("ui_accept") and (jump_available or coyote_timer > 0) and not is_dashing:
		velocity.y = JUMP_VELOCITY
		jump_available = false
	
	# Handle movement input
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0 and not is_dashing and not attack_in_progress:
		velocity.x = direction * SPEED
		if sprite.animation != "run":
			sprite.play("run")  # Play "run" animation when moving

		# Flip sprite and attack hitbox
		var is_facing_left = direction < 0
		sprite.flip_h = is_facing_left
		dash_direction = Vector2.LEFT if is_facing_left else Vector2.RIGHT

		# Flip the attack area
		attack_collision.scale.x = -1 if is_facing_left else 1
	else:
		# Apply deceleration
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Attack input handling
	attack_timer -= delta
	if attack_timer <= 0 and not attack_in_progress:
		if Input.is_action_just_pressed("attack_1"):
			_start_attack("attack_1")
		elif Input.is_action_just_pressed("attack_2"):
			_start_attack("attack_2")
		elif Input.is_action_just_pressed("attack_3"):
			_start_attack("attack_3")

	# Handle dash input
	if dash_cooldown_timer <= 0 and Input.is_action_just_pressed("dash") and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

	# Default to idle if no movement, no attack, and no dash
	if velocity.x == 0 and is_on_floor() and not attack_in_progress and not is_dashing:
		if sprite.animation != "idle": 
			sprite.play("idle")

	# Move the character
	move_and_slide()

# Helper function to handle attack animations
func _start_attack(attack_name: String) -> void:
	sprite.play(attack_name)
	attack_in_progress = true
	attack_timer = attack_cooldown
	attack_shape.disabled = false  # Enable hitbox

# Function to handle when an animation finishes
func _on_animation_finished() -> void:
	if sprite.animation.begins_with("attack_"):
		attack_shape.disabled = true  # Disable hitbox
		attack_in_progress = false
		# Return to idle if not moving
		if velocity.x == 0 and is_on_floor() and not is_dashing:
			sprite.play("idle")
	elif sprite.animation == "hurt" and hp <= 0:
		sprite.play("death")  # Play death animation

func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation == "death":
		queue_free()  # Remove player from scene

func take_damage(amount: int):
	hp -= amount
	print("Player HP:", hp)
	
	# Update health bar
	health_bar.value = hp
	
	if hp <= 0:
		die()
	else:
		sprite.play("hurt")  
		
		# Apply knockback
		var knockback_force = -500 if sprite.flip_h else 500
		velocity.x = knockback_force
		move_and_slide()

		# Disable movement for 0.3 seconds (stun effect)
		is_knocked_back = true
		await get_tree().create_timer(0.3).timeout
		is_knocked_back = false
		
		# Move immediately so knockback is applied instantly
		move_and_slide()

func _on_attack_area_entered(area: Area2D):
	print("Collision detected with:", area.name)  # Debugging
	if area.is_in_group("enemy"):
		print("Enemy hit!")
		var enemy = area.get_parent()  # Get the enemy node
		enemy.take_damage(1, sprite.flip_h)  # Pass damage + attack direction

func die():
	print("Player died!")
	sprite.play("death")  # Play death animation if available
	set_physics_process(false)  # Disable movement
	await sprite.animation_finished
	queue_free()  # Remove the player

func calculate_gravity(velocity: Vector2) -> float:
	return GRAVITY if velocity.y <= 0 else FALL_GRAVITY

func _on_attack_area_exited(area: Area2D):
	if area.is_in_group("player"):
		player_in_range = false
		_stop_attack()

func _stop_attack():
	if not player_in_range:  # Only stop if player is not in range
		sprite.play("idle")  # Return to idle or wandering state


func _on_hurt_collison_area_entered(area: Area2D) -> void:
	take_damage(1)

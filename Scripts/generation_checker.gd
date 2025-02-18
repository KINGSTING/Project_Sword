extends CharacterBody2D

@export var speed: float = 500.0

func _physics_process(delta):
	var direction = Vector2.ZERO

	# Get input for movement
	if Input.is_action_pressed("ui_up"):
		direction.y -= 10
	if Input.is_action_pressed("ui_down"):
		direction.y += 10
	if Input.is_action_pressed("ui_left"):
		direction.x -= 10
	if Input.is_action_pressed("ui_right"):
		direction.x += 10

	# Normalize to avoid diagonal speed boost
	if direction.length() > 0:
		direction = direction.normalized()

	# Apply movement
	velocity = direction * speed
	move_and_slide()

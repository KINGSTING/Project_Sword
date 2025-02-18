extends CharacterBody2D

@onready var animation_player  = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var raycast: RayCast2D = $player_detector
@onready var raycast2: RayCast2D = $player_detector2
@onready var raycast3: RayCast2D = $player_detector3
@onready var timer  = $StateTimer
@onready var attack_player_detector: RayCast2D = $attack_player_detector
@onready var enemy_attack_box: Area2D = $enemy_attack_box
@onready var enemy_attack_box_collision: CollisionShape2D = $enemy_attack_box/enemy_attack_box_collision
@onready var health_bar: ProgressBar = $HealthBar  # Adjust the node path if necessary

var player = null  
var speed = 70
var dead = false
var attacking = false  
var hp = 4

@export var chase_speed: int = 90
@export var acceleration: int = 30

enum States {
	WANDER,
	CHASE,
	ATTACKING
}
var current_state = States.WANDER

const GRAVITY = 1200.0
var left_bounds: Vector2
var right_bounds: Vector2
var direction: Vector2 = Vector2(1, 0)  

var default_attack_detector_target: Vector2
var default_raycast_target: Vector2

var is_knocked_back = false  # To track knockback state

func _ready():
	left_bounds = self.position + Vector2(-125, 0)
	right_bounds = self.position + Vector2(125, 0)
	timer.start()
	
	default_attack_detector_target = attack_player_detector.target_position
	default_raycast_target = raycast.target_position
	
	# Set initial health bar value
	health_bar.max_value = hp
	health_bar.value = hp

func _physics_process(delta: float) -> void:
	if dead or attacking or is_knocked_back:
		return  # Prevent movement during knockback

	handle_gravity(delta)
	look_for_player()
	attack_player_detect()  
	handle_movement(delta)
	change_direction()
	move_and_slide()

	update_animation()

func update_animation():
	if attacking:
		return  # Don't override attack animations

	if current_state == States.WANDER:
		if animation_player.current_animation != "walk":
			animation_player.play("walk")
	elif current_state == States.CHASE:
		if animation_player.current_animation != "walk":
			animation_player.play("walk")
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("sword"):
		hp -= 1
		health_bar.value = hp

		# Determine the knockback direction
		var knockback_force = 300  
		var knockback_direction = sign(global_position.x - area.global_position.x)

		# Apply knockback and disable movement temporarily
		is_knocked_back = true
		velocity.x = knockback_direction * knockback_force
		velocity.y = -200  
		timer.start()  # Start timer to reset knockback

		if hp <= 0:
			dead = true
			attacking = false  
			animation_player.play("death")
			velocity = Vector2.ZERO  

func _on_enemy_attack_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and not attacking and is_on_floor():    
		attacking = true  
		velocity = Vector2.ZERO  
		animation_player.play("attack")  

func _on_animation_player_animation_finished(anim_name):
	if anim_name in ["attack", "attack1"]:
		attacking = false
		enemy_attack_box_collision.set_deferred("disabled", true)
		if attack_player_detector.is_colliding():
			print("Player still in attack range, delaying next attack")
			await get_tree().create_timer(0.5).timeout  # Small delay before checking again
			attack_player_detect()
		else:
			print("Attack finished, returning to chase or wander")
			if player:
				current_state = States.CHASE
				chase_player()
			else:
				current_state = States.WANDER
				stop_chase()
	elif anim_name == "death":
		queue_free()

func _on_timer_timeout() -> void:
	if current_state == States.WANDER:
		direction = -direction  

func look_for_player():
	if raycast.is_colliding() or raycast2.is_colliding():
		var collider = null
		
		if raycast.is_colliding():
			collider = raycast.get_collider()
		elif raycast2.is_colliding():
			collider = raycast2.get_collider()
		elif raycast3.is_colliding():
			collider = raycast3.get_collider()

		if collider and collider.is_in_group("player"):
			player = collider
			print("Player detected! Switching to CHASE mode.")
			current_state = States.CHASE  
			chase_player()
		elif collider and collider.is_in_group("platforms") and velocity.x == 0:
			jump()
	elif current_state == States.CHASE:  # This triggers when player is lost
		print("Lost player, switching to WANDER mode.")
		current_state = States.WANDER  
		stop_chase()
		direction = Vector2(1, 0) if sprite.flip_h else Vector2(-1, 0)  # Resume movement

func jump():
	if is_on_floor():
		velocity.y = -250  # Adjust this value if needed

func attack_player_detect():
	if attacking or not is_on_floor():
		return  # Prevent re-entering attack state or attacking mid-air
		
	if attack_player_detector.is_colliding():
		var collider = attack_player_detector.get_collider()
		if collider and collider.is_in_group("player"):
			current_state = States.ATTACKING
			attacking = true
			print("ENEMY IS ATTACKING")
			enemy_attack_box_collision.set_deferred("disabled", false)
			velocity = Vector2.ZERO
			animation_player.play("attack")
			await get_tree().create_timer(0.5).timeout
			enemy_attack_box_collision.set_deferred("disabled", true)
			attacking = false  # Reset attacking here
			print("Attack cooldown finished, hitbox disabled")

func chase_player():
	timer.stop()
	current_state = States.CHASE  
	print("Chasing player!")

func stop_chase():
	if timer.time_left <= 0:
		print("Lost player, returning to WANDER mode.")
		timer.start()
		current_state = States.WANDER
		direction = Vector2(1, 0) if sprite.flip_h else Vector2(-1, 0)  # Ensure movement resumes
		velocity.x = direction.x * speed  

func handle_movement(delta: float) -> void:
	if current_state == States.WANDER:
		velocity.x = direction.x * speed  
	elif current_state == States.CHASE and player:
		var dir = (player.global_position - global_position).normalized().x
		velocity.x = dir * chase_speed  

	# If the enemy is stuck (velocity.x is 0 for a while), attempt to jump out
	if velocity.x == 0 and is_on_floor():
		print("Orc is stuck! Trying to jump out...")
		jump() 

func change_direction():
	if current_state == States.WANDER:
		if position.x <= left_bounds.x:
			direction = Vector2(1, 0)
		elif position.x >= right_bounds.x:
			direction = Vector2(-1, 0)
	elif current_state == States.CHASE and player:
		var dir = sign((player.global_position - position).x)
		direction = Vector2(dir, 0)

	# Flip  based on direction
	sprite.flip_h = direction.x < 0

	# Flip attack hitbox
	enemy_attack_box.scale.x = direction.x  

	# Flip RayCasts by modifying target_position directly
	attack_player_detector.target_position.x = direction.x * 26  
	raycast.target_position.x = direction.x * 75  
	raycast2.target_position.x = direction.x * -50  # Adjust for second raycast

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta


func _on_knockback_timer_timeout() -> void:
	is_knocked_back = false  # Allow movement again

extends CharacterMovementComponent

@export var networking_path : NodePath
@onready var networking = get_node(networking_path) 
#####################################
#Controls Settings
@export var OnePressJump := false
@export var UsingSprintToggle := false
@export var UsingCrouchToggle := false
#####################################

var h_rotation :float
#var v_rotation :float

var direction := Vector3.FORWARD

var previous_rotation_mode 

func _physics_process(delta):
	super._physics_process(delta)
#	Debug()
	if !networking.is_local_authority():
		if input_is_moving:
			if gait == Global.gait.sprinting:
				add_movement_input(direction, current_movement_data.sprint_speed,current_movement_data.sprint_acceleration)
			elif gait == Global.gait.running:
				add_movement_input(direction, current_movement_data.run_speed,current_movement_data.run_acceleration)
			else:
				add_movement_input(direction, current_movement_data.walk_speed,current_movement_data.walk_acceleration)
		else:
			add_movement_input(direction,0,deacceleration)
			
		return

	
	#------------------ Input Movement ------------------#
	h_rotation = camera_root.HObject.transform.basis.get_euler().y
	var v_rotation = camera_root.VObject.transform.basis.get_euler().x
	
	if Input.is_action_pressed("forward") || Input.is_action_pressed("back") || Input.is_action_pressed("right") || Input.is_action_pressed("left") :
		direction = Vector3(Input.get_action_strength("right") - Input.get_action_strength("left"),
			remap(v_rotation,-PI/2,PI/2,-1.0,1.0) if is_flying == true else 0.0,
			Input.get_action_strength("back") - Input.get_action_strength("forward"))
		direction = direction.rotated(Vector3.UP,h_rotation).normalized()
		if gait == Global.gait.sprinting :
			add_movement_input(direction, current_movement_data.sprint_speed,current_movement_data.sprint_acceleration)
		elif gait == Global.gait.running:
			add_movement_input(direction, current_movement_data.run_speed,current_movement_data.run_acceleration)
		else:
			add_movement_input(direction, current_movement_data.walk_speed,current_movement_data.walk_acceleration)
	else:
		direction = Vector3.ZERO
		add_movement_input()
		
	
	#------------------ Input Crouch ------------------#
	if UsingCrouchToggle == false:
		if Input.is_action_pressed("crouch"):
			if stance != Global.stance.crouching:
				stance = Global.stance.crouching
		else:
			if stance != Global.stance.standing:
				stance = Global.stance.standing
	else:
		if Input.is_action_just_pressed("crouch"):
			stance = Global.stance.standing if stance == Global.stance.crouching else Global.stance.crouching
	#------------------ Sprint ------------------#
	if UsingSprintToggle:
		if Input.is_action_just_pressed("sprint"):
			if gait == Global.gait.walking:
				gait = Global.gait.running  
			elif gait == Global.gait.running:
				gait = Global.gait.sprinting
			elif gait == Global.gait.sprinting:
				gait = Global.gait.walking
	else:
		if Input.is_action_just_pressed("sprint"):
			if gait == Global.gait.walking:
				gait = Global.gait.running
			elif gait == Global.gait.running:
				gait = Global.gait.sprinting
		if Input.is_action_just_released("sprint"):
			if gait == Global.gait.sprinting or gait == Global.gait.walking:
				gait = Global.gait.walking
			elif gait == Global.gait.running:
				await get_tree().create_timer(0.4).timeout
				if gait == Global.gait.running:
					gait = Global.gait.walking
	#------------------ Input Aim ------------------#
	if Input.is_action_pressed("aim"):
		if rotation_mode != Global.rotation_mode.aiming:
			previous_rotation_mode = rotation_mode
			rotation_mode = Global.rotation_mode.aiming
	else:
		if rotation_mode == Global.rotation_mode.aiming:
			rotation_mode = previous_rotation_mode
	#------------------ Jump ------------------#=
	if OnePressJump == true:
		if Input.is_action_just_pressed("jump"):
			if stance != Global.stance.standing:
				stance = Global.stance.standing
			else:
				jump()
	else:
		if Input.is_action_pressed("jump"):
			if stance != Global.stance.standing:
				stance = Global.stance.standing
			else:
				jump()
	#------------------ Look At ------------------#
	match rotation_mode:
		Global.rotation_mode.velocity_direction:
			if input_is_moving:
				ik_look_at(actual_velocity + Vector3(0.0,1.0,0.0))
		Global.rotation_mode.looking_direction:
			ik_look_at(camera_root.SpringArm.transform.basis.z * 2.0 + Vector3(0.0,1.5,0.0))
		Global.rotation_mode.aiming:
			ik_look_at(camera_root.SpringArm.transform.basis.z * 2.0 + Vector3(0.0,1.5,0.0))
	#------------------ Interaction ------------------#
	if Input.is_action_just_pressed("interaction"):
		camera_root.Camera.get_node("InteractionRaycast").Interact()




var view_changed_recently = false
func _input(event):
	#------------------ Motion Warping test------------------#
	if event.is_action_pressed("fire"):
		anim_ref.active = false
		get_node("../MotionWarping").add_sync_position(Vector3(4.762,1.574,-1.709),Vector3(0,PI,0),"kick_target",self,mesh_ref)
		get_node("../AnimationPlayer").play("Kick")
		await get_tree().create_timer(2.6).timeout
		anim_ref.active = true
		
	#------------------ Change Camera View ------------------#
	if Input.is_action_just_released("switch_camera_view"):
		if view_changed_recently == false:
			view_changed_recently = true
			camera_root.view_angle = camera_root.view_angle + 1 if camera_root.view_angle < 2 else 0
			await get_tree().create_timer(0.3).timeout
			view_changed_recently = false
		else:
			view_changed_recently = false
	if Input.is_action_just_pressed("switch_camera_view"):
		await get_tree().create_timer(0.2).timeout
		if view_changed_recently == false:
			camera_root.view_mode = camera_root.view_mode + 1 if camera_root.view_mode < 1 else 0
			view_changed_recently = true
	if networking.is_local_authority():
		if event.is_action_pressed("EnableSDFGI"):
			var postprocess = preload("res://AMSG_Examples/Maps/default_env.tres")
			postprocess.sdfgi_enabled = not postprocess.sdfgi_enabled
			postprocess.ssil_enabled = not postprocess.ssil_enabled
			postprocess.ssao_enabled = not postprocess.ssao_enabled
			postprocess.ssr_enabled = not postprocess.ssr_enabled
			postprocess.glow_enabled = not postprocess.glow_enabled
	if event.is_action_pressed("ragdoll"):
		ragdoll = true


		if rotation_mode == Global.rotation_mode.velocity_direction:
			if camera_root != null:
				if camera_root.view_mode == Global.view_mode.first_person:
					camera_root.view_mode = Global.view_mode.third_person
					

#func Debug():
#	$Status/Label.text = "InputSpeed : %s" % input_velocity.length()
#	$Status/Label2.text = "ActualSpeed : %s" % get_velocity().length()

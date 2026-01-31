extends CharacterBody3D
class_name FirstPersonCharacter

var local_client_id = 0
var is_local_player = false

@export_category("Objects")
@export var _body: Node3D = null
@onready var nickname: Label3D = $PlayerNick/Nickname
var players_container = null
var player_inventory: PlayerInventory

@export_category("Mouvements")
var locked_cursor = false
@export var SENSITIVITY = 0.3
const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 10
var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_double_jump = true
var has_double_jumped = false

@export_category("Skin Colors")
enum SkinColor { BLUE, YELLOW, GREEN, RED }
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D
@onready var _bottom_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
@onready var _chest_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
@onready var _face_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
@onready var _limbs_head_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")

@export_group("Holding Objects")
@export var throw_force = 7.5
@export var follow_speed = 5.0
@export var follow_distance = 2.5
@export var max_distance_from_camera = 5.0
@export var drop_below_player = true
@onready var interact_raycast: RayCast3D = $Camera3D/InteractRayCast
@onready var ground_raycast: RayCast3D = $GroundRayCast
@export var held_object: RigidBody3D = null

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$Camera3D.current = is_multiplayer_authority()

func _make_invisible_but_keep_shadow():
	if is_multiplayer_authority():
		var meshes = [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]
		for mesh in meshes:
			if mesh:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	locked_cursor = true
	
	_make_invisible_but_keep_shadow()
	
	if multiplayer.multiplayer_peer == null:
		return
	
	is_local_player = is_multiplayer_authority()
	local_client_id = multiplayer.get_unique_id()

"""
	if is_local_player:
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	elif multiplayer.is_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	else:
		if get_multiplayer_authority() == local_client_id:
			request_inventory_sync.rpc_id(1)
"""

func _input(event):
	if not is_multiplayer_authority(): return

	if Input.is_action_just_pressed("unlock_cursor"):
		if locked_cursor :
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			locked_cursor = false
		else :
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			locked_cursor = true

	if event is InputEventMouseMotion:
		$Camera3D.rotation_degrees.x -= event.relative.y * SENSITIVITY
		$Camera3D.rotation_degrees.x = clamp($Camera3D.rotation_degrees.x, -90, 90)
		rotation_degrees.y -= event.relative.x * SENSITIVITY

	## HOLDING OBJECTS
	if not is_multiplayer_authority(): return
	if Input.is_action_just_pressed("interact"):
		request_interact.rpc()
	if Input.is_action_just_pressed("throw"):
		request_throw.rpc()

func _physics_process(delta):
	if multiplayer.multiplayer_peer == null: return
	if not is_multiplayer_authority(): return

	var current_scene = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		var should_freeze = false
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true

		if should_freeze:
			freeze()
			return

	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_body.play_jump_animation("Jump")
	else:
		velocity.y -= gravity * delta

		if can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			_body.play_jump_animation("Jump2")

	velocity.y -= gravity * delta

	_move()
	move_and_slide()
	_body.animate(velocity)


	
	## HOLDING OBJECTS
	#if multiplayer.is_server():
	#	if held_object != null:
	_apply_holding_physics.rpc()

func _process(_delta):
	if multiplayer.multiplayer_peer == null: return
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()
	
	# SHOW HIDE BUTTONS
	if interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		if collider is RigidBody3D and held_object == null :
			$Control/CenterContainer/VBoxContainer/ButtonUp.visible = true
			$Control/CenterContainer/VBoxContainer/ButtonDown.visible = true
		else :
			$Control/CenterContainer/VBoxContainer/ButtonUp.visible = false
			$Control/CenterContainer/VBoxContainer/ButtonDown.visible = false
	else :
		$Control/CenterContainer/VBoxContainer/ButtonUp.visible = false
		$Control/CenterContainer/VBoxContainer/ButtonDown.visible = false


func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_body.animate(Vector3.ZERO)

func _move() -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		_input_direction = Input.get_vector(
			"move_right", "move_left",
			"move_backward", "move_forward",
			)

	var _direction: Vector3 = transform.basis * Vector3(_input_direction.x, 0, _input_direction.y).normalized()

	is_running()

	if _direction:
		velocity.x = _direction.x * _current_speed
		velocity.z = _direction.z * _current_speed
		return

	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)

func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false

func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()

func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture = get_texture_from_name(skin_name)

	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)

func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)

####################################################################################################
####################################################################################################
#### INVENTORY

"""
# Inventory Network Functions
@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync():
	if not multiplayer.is_server():
		return
	var requesting_client = multiplayer.get_remote_sender_id()
	if player_inventory:
		sync_inventory_to_owner.rpc_id(requesting_client, player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	if multiplayer.get_remote_sender_id() != 1:
		return
	if not is_multiplayer_authority():
		return
	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)
	var level_scene = get_tree().get_current_scene()
	if level_scene:
		if is_multiplayer_authority():
			if level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
			if level_scene.has_node("InventoryUI"):
				var inventory_ui = level_scene.get_node("InventoryUI")
				if inventory_ui.visible and inventory_ui.has_method("refresh_display"):
					inventory_ui.refresh_display()

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	if not multiplayer.is_server(): return
	if not player_inventory: return
	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot) or player_inventory.swap_items(from_slot, to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)
	if success:
		sync_inventory_to_owner.rpc_id(get_multiplayer_authority(), player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	if not multiplayer.is_server(): return
	if not player_inventory: return
	var item = ItemDatabase.get_item(item_id)
	if item:
		player_inventory.add_item(item, quantity)
		sync_inventory_to_owner.rpc_id(get_multiplayer_authority(), player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	if not multiplayer.is_server(): return
	if not player_inventory: return
	if player_inventory.remove_item(item_id, quantity) > 0:
		sync_inventory_to_owner.rpc_id(get_multiplayer_authority(), player_inventory.to_dict())

func get_inventory() -> PlayerInventory:
	return player_inventory

func _add_starting_items():
	if not player_inventory: return
	var sword = ItemDatabase.get_item("iron_sword")
	var potion = ItemDatabase.get_item("health_potion")
	if sword: player_inventory.add_item(sword, 1)
	if potion: player_inventory.add_item(potion, 3)
"""

####################################################################################################
####################################################################################################
#### HOLDING OBJECTS

## --- RPCs (Client calling Server) ---

@rpc("any_peer", "call_local", "reliable")
func request_interact() -> void:
	#if not multiplayer.is_server(): return
	
	if held_object != null:
		_server_drop_object()
		return

	if interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		if collider is RigidBody3D:
			if not _is_object_held_by_anyone(collider):
				_server_pickup_object(collider)

@rpc("any_peer", "call_local", "reliable")
func request_throw() -> void:
	#if not multiplayer.is_server(): return
	
	if held_object != null:
		var force = -$Camera3D.global_basis.z * throw_force * 10.0
		held_object.apply_central_impulse(force)
		_server_drop_object()

## --- Internal Server Logic ---

func _server_pickup_object(obj: RigidBody3D) -> void:
	held_object = obj
	held_object.set("held_by_id", multiplayer.get_remote_sender_id())
	held_object.sleeping = false
	held_object.add_collision_exception_with(players_container.get_player(held_object.get("held_by_id")))

func _server_drop_object() -> void:
	if held_object:
		held_object.remove_collision_exception_with(players_container.get_player(held_object.get("held_by_id")))
		held_object.set("held_by_id", -1)
		held_object = null

@rpc("any_peer", "call_local", "reliable")
func _apply_holding_physics() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return
	
	var target_pos = $Camera3D.global_position + (-$Camera3D.global_basis.z * follow_distance)
	var current_pos = held_object.global_position
	
	var target_velocity = (target_pos - current_pos) * follow_speed
	var velocity_change = target_velocity - held_object.linear_velocity
	held_object.apply_central_impulse(velocity_change * held_object.mass)

	var current_ang_vel = held_object.angular_velocity
	var angular_change = (current_ang_vel * 0.9) - current_ang_vel
	held_object.apply_torque_impulse(angular_change * held_object.inertia)
	
	if current_pos.distance_to($Camera3D.global_position) > max_distance_from_camera:
		_server_drop_object()

func _is_object_held_by_anyone(obj: RigidBody3D) -> bool:
	if obj.get("held_by_id") >= 0 :
		return true
	
	for player in get_tree().get_nodes_in_group("players"):
		if player.held_object == obj:
			return true
	return false

func _exit_tree() -> void:
	if multiplayer.is_server():
		_server_drop_object()

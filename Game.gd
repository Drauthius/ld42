extends Node

var Beam = preload("res://scenes/Beam.tscn")
var BeamSprite = preload("res://scenes/BeamSprite.tscn")
var CostText = preload("res://scenes/CostText.tscn")
var Apartment1x1 = preload("res://scenes/Apartment1x1.tscn")
var Apartment2x1 = preload("res://scenes/Apartment2x1.tscn")

export(int, 1000000) var money
var min_beam_length = 16
var max_beam_length = 128
var min_beam_cost = 25
var max_beam_cost = 100

var from = null
var placing = null
var cost_text = null

var beams = []
var joints = []
var apartments = [
	Apartment1x1,
	Apartment2x1
]
var current_mode

enum MODES {
	BEAM_MODE,
	APARTMENT_MODE,
	PHYSICS_MODE
}

func _ready():
	current_mode = MODES.BEAM_MODE
	
	# Add the ground joints that are available in the level (identified as RigidBody2D).
	for node in get_children():
		if node is RigidBody2D:
			joints.append(node)
			# Connect the click event for the joint
			node.connect("clicked", self, "_on_Joint_clicked")
	
	$GUI.set_money(money)

func _process(delta):
	if placing and current_mode == MODES.BEAM_MODE:
		_update_placing_beam()
	if placing and current_mode == MODES.APARTMENT_MODE:
		_update_placing_apartment()
		pass
	
	if current_mode != MODES.PHYSICS_MODE and Input.is_action_just_pressed("ui_accept"):
		current_mode = MODES.PHYSICS_MODE
		print("PHYSICS!")
		play()
	elif current_mode == MODES.PHYSICS_MODE and Input.is_action_just_pressed("ui_cancel"):
		current_mode = MODES.BEAM_MODE
		print("no physics")
		pause()
	elif current_mode != MODES.PHYSICS_MODE and Input.is_action_just_pressed("ui_tab") and not placing:
		if current_mode == MODES.BEAM_MODE:
			current_mode = MODES.APARTMENT_MODE
		elif current_mode == MODES.APARTMENT_MODE:
			current_mode = MODES.BEAM_MODE
		print("current_mode ", current_mode)
	elif not placing and current_mode == MODES.APARTMENT_MODE and Input.is_key_pressed(KEY_1):
		instanciate_apartment(0)
	elif not placing and current_mode == MODES.APARTMENT_MODE and Input.is_key_pressed(KEY_2):
		instanciate_apartment(1)
	else:
#		print("unhandled stuff")
		pass

func instanciate_apartment( array_index ):
	if placing != apartments[array_index]:
		placing = apartments[array_index].instance()
		add_child(placing)
		placing.set_position(get_viewport().get_mouse_position())

# Start physics.
func play():
	for beam in beams:
		beam.get_node("Mid").mode = RigidBody2D.MODE_RIGID
		beam.get_node("Left").mode = RigidBody2D.MODE_RIGID
		beam.get_node("Right").mode = RigidBody2D.MODE_RIGID
		beam.get_node("Mid").set_sleeping(false)
		beam.get_node("Left").set_sleeping(false)
		beam.get_node("Right").set_sleeping(false)

# Stop physics
func pause():
	for beam in beams:
		beam.get_node("Mid").mode = RigidBody2D.MODE_STATIC
		beam.get_node("Left").mode = RigidBody2D.MODE_STATIC
		beam.get_node("Right").mode = RigidBody2D.MODE_STATIC
		beam.get_node("Mid").set_sleeping(true)
		beam.get_node("Left").set_sleeping(true)
		beam.get_node("Right").set_sleeping(true)

# Stretch and rotate the beam sprite that is currently being placed.
# Force will ignore (or exagerate) the maximum beam length, to avoid connections that are juuuust short.
func _update_placing_beam(position = null, force = false):
	if not position:
		position = get_viewport().get_mouse_position()
	placing.look_at(position)
	var length = min(max_beam_length if not force else max_beam_length * 100, (position - from.position).length())
	placing.get_node("Sprite").rect_size.x = length
	
	var cost = 0
	if length >= min_beam_length:
		cost = (length - min_beam_length) / (max_beam_length - min_beam_length) * (max_beam_cost - min_beam_cost) + min_beam_cost
	
	cost_text.set_cost(round(cost), cost > money)
	$GUI.set_insufficient(cost > money)
	
	return placing.to_global(Vector2(length, 0))

# Just changing the position of the apartment to be placed
func _update_placing_apartment():
	placing.set_position(get_viewport().get_mouse_position())

# Called when clicked on things that aren't a joint.
# This function recieves the input event before the joint for some reason (when placing), so just handle it here I guess.
func _unhandled_input(event):
	if current_mode == MODES.PHYSICS_MODE or not placing or not event is InputEventMouseButton or not event.button_index == BUTTON_LEFT or event.pressed:
		return
		
	#handling beams
	if current_mode == MODES.BEAM_MODE:
		#print("unhandled input")
		get_tree().set_input_as_handled() # Marked as handled.
		
		# Get the position of the beam's end.
		var position = _update_placing_beam(event.position)
		
		# Create a shape + transform for checking if a click connects to an existing joint.
		var shape = CircleShape2D.new()
		shape.radius = 10
		var transform = Transform2D(0.0, position)
		
		for joint in joints:
			if joint.get_node("CollisionShape2D").shape.collide(joint.get_global_transform(), shape, transform):
				# Update the placing node, so that _place_beam puts the end at the right place.
				position = _update_placing_beam(joint.get_global_transform().origin, true)
				
				_place_beam(position, joint)
				return
				
		_place_beam(position)
	#handling apartments
	elif current_mode == MODES.APARTMENT_MODE:
		# Update the placing node, so that _place_beam puts the end at the right place.
		_update_placing_apartment()
		if placing:
			print("apartment input")
			get_tree().set_input_as_handled() # Marked as handled.
		# Create a shape + transform for checking if a click connects to an existing joint.
			var transform = Transform2D(0.0, event.position)
			var connecting_joints = []
			_place_apartment(event.position)
			#conditional stuff for when to place an apartment?
			if false:
				pass

# Called when a joint (ground or from a beam) is clicked.
func _on_Joint_clicked(joint):
	if current_mode == MODES.PHYSICS_MODE:
		return
	
	var position = joint.get_global_transform().origin
	
	if not placing:
		#print("attaching to ", joint)
		from = { "joint": joint, "position": position }
		placing = BeamSprite.instance()
		add_child(placing)
		placing.position = from.position
		cost_text = CostText.instance()
		add_child(cost_text)
		cost_text.position = from.position - Vector2(20, 40)
	#else:
		# The above _unhandled_event gets the event before the click event on the joint.

# Called when trying to place a beam.
func _place_beam(position, other_joint = null):
	# How much softness to allow for the pin joints.
	# This needs to be greater than zero, to avoid having too rigid structures that start to vibrate.
	var slackness = 0.5
	
	# Minimum length requirement for placing beam.
	if placing.get_node("Sprite").rect_size.x >= min_beam_length and cost_text.cost <= money:
		# Reduce the amount of money
		money -= cost_text.cost
		$GUI.set_money(money)
		
		# Create a new beam
		var beam = Beam.instance()
		beam.set_position(placing.get_position())
		beam.set_rotation(placing.get_rotation())
		add_child(beam)
		
		# Set the length of the beam (texture sprite) and the position of the right joint.
		var length = (position - from.position).length()
		beam.get_node("Mid/TextureRect").rect_size.x = length
		beam.get_node("Right").position = Vector2(length, 0)
		# The mass has to be updated to correspond with the length
		beam.get_node("Mid").mass = length / 320.0
		
		# This is utter shit. The joint connecting the right ball to the beam has to be added here, or it will snap back to the original position
		# once the mode is changed to rigid (if it was added in the editor). The left joint is handled the same way for consistency.
		yield(get_tree(), "idle_frame") # Wait a frame, because why not (probably needed for the rigid body to "update").
		var left_joint = PinJoint2D.new()
		left_joint.softness = slackness
		left_joint.position = beam.get_node("Left").position - Vector2(30, 0)
		left_joint.node_a = beam.get_node("Mid").get_path()
		left_joint.node_b = beam.get_node("Left").get_path()
		beam.get_node("Mid").add_child(left_joint)
		
		var right_joint = PinJoint2D.new()
		right_joint.softness = slackness
		right_joint.position = beam.get_node("Right").position - Vector2(30, 0)
		right_joint.node_a = beam.get_node("Mid").get_path()
		right_joint.node_b = beam.get_node("Right").get_path()
		beam.get_node("Mid").add_child(right_joint)
		
		# Recreate the collision shape, since it is shared among all beams, but they need to be unique (since the length might be different).
		beam.get_node("Mid/CollisionShape2D").set_shape(beam.get_node("Mid/CollisionShape2D").get_shape().duplicate(true))
		# Set the length of the collision shape (minus a small offset)
		beam.get_node("Mid/CollisionShape2D").shape.extents.x = length / 2 - 10
		# Set the position of the collision shape (needs to be in the middle of the beam)
		beam.get_node("Mid/CollisionShape2D").position.x = length / 2 - 30
		
		# Connect the click events for the left and right joints
		beam.get_node("Left").connect("clicked", self, "_on_Joint_clicked")
		beam.get_node("Right").connect("clicked", self, "_on_Joint_clicked")
		
		# Add the beam and joints to the lists
		beams.append(beam)
		joints.append(beam.get_node("Left"))
		joints.append(beam.get_node("Right"))
		
		# Add the pin joints connecting the beam with the joints it was placed upon.
		# Have to yield here, or the thing goes haywire once the body is set to rigid.
		yield(get_tree(), "idle_frame")
		var joint = PinJoint2D.new()
		beam.get_node("Mid").add_child(joint)
		joint.softness = slackness
		joint.position = left_joint.position
		joint.node_a = from.joint.get_path()
		joint.node_b = beam.get_node("Left").get_path()
		
		# Add a pin joint for the right joint if it is connected to anything.
		if other_joint:
			joint = PinJoint2D.new()
			beam.get_node("Mid").add_child(joint)
			joint.softness = slackness
			joint.position = right_joint.position
			joint.node_a = other_joint.get_path()
			joint.node_b = beam.get_node("Right").get_path()

	# Clear the placing stuff.
	placing.queue_free()
	placing = null
	from = null
	cost_text.queue_free()
	cost_text = null
	# Reset GUI
	$GUI.set_insufficient(false)

func _place_apartment(position):
	placing.set_position(position)
	apartments.append(placing)
	placing = null
	from = null #just to be safe

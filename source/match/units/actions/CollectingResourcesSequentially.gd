extends "res://source/match/units/actions/Action.gd"

enum State { NULL, MOVING_TO_RESOURCE, COLLECTING, MOVING_TO_CC }

const CommandCenter = preload("res://source/match/units/CommandCenter.gd")
const CollectingResourcesWhileInRange = preload(
	"res://source/match/units/actions/CollectingResourcesWhileInRange.gd"
)
const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")

var _state := State.NULL
var _state_locked = false
var _resource_unit = null
var _cc_unit = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(source_unit, target_unit):
	# TODO: handle starting from CC as well
	return source_unit is Worker and target_unit is ResourceUnit


func _init(resource_unit):
	_resource_unit = resource_unit


func _ready():
	_change_state_to(State.MOVING_TO_RESOURCE)


func _to_string():
	return "{0}({1})".format([super(), str(_sub_action) if _sub_action != null else ""])


func _change_state_to(new_state):
	assert(not _state_locked)
	_state_locked = true
	_exit_state(_state)
	_enter_state(new_state)
	_state = new_state
	_state_locked = false


func _exit_state(_a_state):
	pass


func _enter_state(state):
	match state:
		State.MOVING_TO_RESOURCE:
			_sub_action = MovingToUnit.new(_resource_unit)
			_sub_action.tree_exited.connect(_on_sub_action_finished)
			add_child(_sub_action)
			_unit.action_updated.emit()
		State.COLLECTING:
			assert(CollectingResourcesWhileInRange.is_applicable(_unit, _resource_unit))
			_sub_action = CollectingResourcesWhileInRange.new(_resource_unit)
			_sub_action.tree_exited.connect(_on_sub_action_finished)
			add_child(_sub_action)
			_unit.action_updated.emit()
		State.MOVING_TO_CC:
			_sub_action = MovingToUnit.new(_cc_unit)
			_sub_action.tree_exited.connect(_on_sub_action_finished)
			add_child(_sub_action)
			_unit.action_updated.emit()


func _transfer_collected_resources_to_player():
	_unit.player.resource_a += _unit.resource_a
	_unit.player.resource_b += _unit.resource_b
	_unit.resource_a = 0
	_unit.resource_b = 0


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_unit.action_updated.emit()
	match _state:
		State.MOVING_TO_RESOURCE:
			# TODO: handle resource 'death' i.e. check if it's still in tree at this point
			# TODO: if worker full then go back
			_change_state_to(State.COLLECTING)
		State.COLLECTING:
			# TODO: handle resource 'death' i.e. check if it's still in tree at this point
			# TODO: handle being not in range
			_cc_unit = _find_cc_closest_to_unit(_unit)
			if _cc_unit == null:
				queue_free()
			else:
				_change_state_to(State.MOVING_TO_CC)
		State.MOVING_TO_CC:
			# TODO: handle being not in range
			# TODO: handle cc 'death'
			_transfer_collected_resources_to_player()
			# TODO: find new resource unit if current is null
			_change_state_to(State.MOVING_TO_RESOURCE)


static func _find_cc_closest_to_unit(unit):
	var ccs_of_the_same_player = (
		unit
		. get_tree()
		. get_nodes_in_group(
			"player_{0}_units".format([unit.find_parent("Match").players.find(unit.player)])
		)
		. filter(func(a_unit): return a_unit is CommandCenter)
	)
	# TODO: calc distances
	# TODO: sort
	# TODO: pick closest
	return ccs_of_the_same_player[0] if not ccs_of_the_same_player.is_empty() else null

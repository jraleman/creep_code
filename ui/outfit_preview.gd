extends Control

## A close-up of the exact keeper mesh worn in play. The shelf supplies an item,
## not permission to buy it; previewing never changes ownership or equipment.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Models = preload("res://games/creep_code/art/toy_models.gd")
const Palette = preload("res://games/creep_code/art/palette.gd")
const REST_YAW := -0.35
const STAND_TOP := 0.19

var _viewport: SubViewport
var _container: SubViewportContainer
var _keeper: MeshInstance3D
var _camera: Camera3D
var _outfit_id: StringName = Options.DEFAULT_OUTFIT
var _angle := 0.0
var _preview_requested := true
var _reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := get_tree().root.get_node("Settings")
	_reduced_motion = bool(settings.call("reduced_motion_enabled"))
	settings.connect("changed", _on_setting_changed)
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_container.add_child(_viewport)
	_build_stage()
	_container.resized.connect(_frame_camera)
	_frame_camera()
	_sync_motion()


func _process(delta: float) -> void:
	if not _preview_requested or _reduced_motion:
		return
	_angle = fmod(_angle + delta * 0.4, TAU)
	_keeper.rotation.y = REST_YAW + _angle


## Accepts a Store.describe() item, including before the card enters the tree.
func configure(item: Dictionary) -> void:
	var id := StringName(str(item.get("id", "")))
	var mesh := Models.keeper_outfit(id)
	if mesh == null:
		return
	_outfit_id = id
	tooltip_text = "%s outfit preview" % str(item.get("title", id))
	accessibility_description = tooltip_text
	if is_instance_valid(_keeper):
		_keeper.mesh = mesh
		_frame_camera()


## Both the shelf and the saved accessibility setting must allow idle rotation.
func set_preview_running(running: bool) -> void:
	_preview_requested = running
	if is_instance_valid(_keeper):
		_sync_motion()


func _sync_motion() -> void:
	var running := _preview_requested and not _reduced_motion
	set_process(running)
	if not running:
		_angle = 0.0
		_keeper.rotation.y = REST_YAW


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == Settings.REDUCED_MOTION_KEY:
		_reduced_motion = bool(value)
		_sync_motion()


func _build_stage() -> void:
	var world := Node3D.new()
	_viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Palette.BACKDROP
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Palette.FILL_LIGHT
	lighting.ambient_light_energy = 0.6
	environment.environment = lighting
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -28, 0)
	key.light_color = Palette.SUNLIGHT
	key.light_energy = 0.85
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 10
	world.add_child(key)
	var material := Palette.painted_material()
	var stand := MeshInstance3D.new()
	stand.mesh = Models.mesh(&"pedestal")
	stand.material_override = material
	stand.scale = Vector3(0.8, 0.16, 0.8)
	world.add_child(stand)
	_keeper = MeshInstance3D.new()
	_keeper.name = "Keeper"
	_keeper.mesh = Models.keeper_outfit(_outfit_id)
	_keeper.material_override = material
	_keeper.position.y = STAND_TOP
	_keeper.rotation.y = REST_YAW
	world.add_child(_keeper)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	world.add_child(_camera)


func _frame_camera() -> void:
	if not is_instance_valid(_keeper):
		return
	var bounds := _keeper.mesh.get_aabb()
	var reach := bounds.position.abs().max(bounds.end.abs())
	var radius := maxf(Vector2(reach.x, reach.z).length(), 0.9)
	var height := bounds.end.y + STAND_TOP
	var center := Vector3(0, height * 0.5, 0)
	_camera.position = center + Vector3(0, 1.5, 5)
	_camera.look_at(center)
	var framing := AABB(Vector3(-radius, 0, -radius), Vector3(radius * 2, height, radius * 2))
	var inverse := _camera.global_transform.affine_inverse()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for index in range(8):
		var point: Vector3 = inverse * framing.get_endpoint(index)
		minimum = minimum.min(Vector2(point.x, point.y))
		maximum = maximum.max(Vector2(point.x, point.y))
	var span := maximum - minimum
	var aspect := maxf(0.1, _container.size.x / maxf(1.0, _container.size.y))
	_camera.size = maxf(span.y, span.x / aspect) * 1.08

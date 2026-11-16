extends Control

# Background behind the phone: night sky shader + slow pixel clouds

@export var sky: ColorRect
@export var cloud_count: int = 9

const CLOUD_DIR = "res://Assets/cloud_single/"
const CLOUD_TEXTURES = 30

var clouds: Array = [] # [{ node, speed }]
var dawn_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_on_resized()

	for i in cloud_count:
		var tex = load(CLOUD_DIR + "cloud%d.png" % randi_range(1, CLOUD_TEXTURES))
		var cloud = TextureRect.new()
		cloud.texture = tex
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s = randf_range(3.0, 6.5)
		cloud.size = tex.get_size() * s
		cloud.position = Vector2(randf() * size.x, randf_range(0.04, 0.62) * size.y)
		cloud.modulate = Color(0.62, 0.58, 0.9, randf_range(0.08, 0.2))
		add_child(cloud)
		# Bigger clouds feel closer, so they move faster
		clouds.append({ "node": cloud, "speed": s * randf_range(1.5, 3.0) })

func _process(delta: float) -> void:
	for c in clouds:
		var node: TextureRect = c.node
		node.position.x += c.speed * delta
		if node.position.x > size.x:
			node.position.x = -node.size.x
			node.position.y = randf_range(0.04, 0.62) * size.y

func _on_resized() -> void:
	if sky and sky.material and size.y > 0:
		sky.material.set_shader_parameter("aspect", size.x / size.y)

# Called as the story advances: the sky slowly turns to dawn
func set_dawn(value: float) -> void:
	if not sky or not sky.material:
		return
	var current = sky.material.get_shader_parameter("dawn")
	if dawn_tween and dawn_tween.is_valid():
		dawn_tween.kill()
	dawn_tween = create_tween()
	dawn_tween.tween_method(func(v): sky.material.set_shader_parameter("dawn", v), current if current != null else 0.0, clampf(value, 0.0, 1.0), 4.0)
	# Clouds catch the warm light
	for c in clouds:
		dawn_tween.parallel().tween_property(c.node, "self_modulate", Color(1.0, 0.85, 0.8).lerp(Color.WHITE, 1.0 - value), 4.0)

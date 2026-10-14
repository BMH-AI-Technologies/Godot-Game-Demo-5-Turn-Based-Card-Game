class_name DemoMap
extends RunScreen
const ENCOUNTER_NODE = preload("res://scenes/components/map_encounter.tscn")
var nodes: Array[Button] = []
var links: Array[HSeparator] = []

func setup(game) -> void:
	app = game
	for index in range(app.demo_run.campaign.encounters.size()):
		if index > 0:
			var link := HSeparator.new()
			link.custom_minimum_size.x = 24
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			%Route.add_child(link)
			links.append(link)
		var node: Button = ENCOUNTER_NODE.instantiate()
		%Route.add_child(node)
		nodes.append(node)
		node.pressed.connect(func(): app.start_demo_battle(index))
		for scene in app.demo_run.campaign.encounters[index].enemies:
			var actor: EnemyActor = scene.instantiate()
			var portrait := TextureRect.new()
			portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.texture = actor.artwork
			node.get_node("Layout/Portraits").add_child(portrait)
			actor.free()
	refresh_text()
	_focus_current.call_deferred()

func _focus_current() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		%RouteScroll.ensure_control_visible(nodes[app.demo_run.stage])

func refresh_text() -> void:
	super.refresh_text()
	if app == null:
		return
	%Title.text = I18n.t(app.demo_run.campaign.title)
	for index in range(links.size()):
		var line := StyleBoxLine.new()
		line.color = GameUI.TEAL if index < app.demo_run.stage else Color("#647569")
		line.thickness = 4
		links[index].add_theme_stylebox_override("separator", line)
	for index in range(nodes.size()):
		var node := nodes[index]
		var current: bool = index == app.demo_run.stage
		var complete: bool = index < app.demo_run.stage
		node.disabled = not current
		node.modulate = Color.WHITE if current or complete else Color(0.6, 0.65, 0.63, 1.0)
		var style: StyleBoxFlat = node.get_theme_stylebox("normal").duplicate()
		style.border_color = GameUI.GOLD if current else (GameUI.TEAL if complete else Color("#69746a"))
		style.shadow_color = Color(0.5, 0.75, 0.5, 0.22) if current else Color.TRANSPARENT
		style.shadow_size = 14 if current else 0
		node.add_theme_stylebox_override("normal", style)
		node.add_theme_stylebox_override("disabled", style)
		node.get_node("Layout/Number").text = "%02d" % (index + 1)
		var names: Array[String] = []
		for foe in app.content.encounter_enemies(index):
			names.append(I18n.t(app.content.enemies[foe].title))
		node.get_node("Layout/Name").text = I18n.t(app.demo_run.campaign.encounters[index].title)
		node.tooltip_text = " + ".join(names)
		node.get_node("Layout/Status").text = I18n.t("RUN_CURRENT" if current else ("RUN_CLEARED" if complete else "RUN_LOCKED"))

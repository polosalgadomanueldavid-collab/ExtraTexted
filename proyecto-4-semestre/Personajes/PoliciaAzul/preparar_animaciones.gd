@tool
extends EditorScenePostImport
## glTF no conserva el modo de repetición de las acciones de Blender.
## Se aplica al importar para que los ciclos funcionen también fuera del controlador.

const CYCLES: Array[String] = ["idle", "walk", "run", "fall"]


func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for clip_name: StringName in player.get_animation_list():
			var animation := player.get_animation(clip_name)
			animation.loop_mode = Animation.LOOP_LINEAR if String(clip_name) in CYCLES else Animation.LOOP_NONE
	return scene

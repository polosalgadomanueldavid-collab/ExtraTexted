extends SceneTree
## Diagnóstico del motor, sin instanciar la oficina ni iniciar una partida.
## Comparar -- --sincrona con -- --threaded y la salida --verbose.
var recurso: PackedScene

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ruta := "res://Mundo/Oficina.tscn"
	if "--threaded" in OS.get_cmdline_user_args():
		var error := ResourceLoader.load_threaded_request(ruta)
		if error != OK:
			quit(error)
			return
		var limite := Time.get_ticks_msec() + 60000
		while ResourceLoader.load_threaded_get_status(ruta) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if Time.get_ticks_msec() >= limite:
				push_error("La carga en segundo plano no terminó en 60 segundos.")
				quit(1)
				return
			await process_frame
		recurso = ResourceLoader.load_threaded_get(ruta)
	else:
		recurso = load(ruta)
	var correcto := recurso != null
	recurso = null
	await create_timer(0.3).timeout
	print("[AISLAMIENTO] recurso cargado y liberado, sin instanciar: ", correcto)
	quit(0 if correcto else 1)

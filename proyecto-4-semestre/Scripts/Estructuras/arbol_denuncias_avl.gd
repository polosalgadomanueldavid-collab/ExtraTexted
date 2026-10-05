class_name ArbolDenunciasAVL
extends RefCounted

var raiz: NodoAVL = null


func insertar(denuncia: Denuncia) -> void:
	if denuncia == null:
		push_warning("No se puede insertar una denuncia vacía.")
		return

	raiz = _insertar_recursivo(raiz, denuncia)


func _insertar_recursivo(nodo: NodoAVL, denuncia: Denuncia) -> NodoAVL:
	if nodo == null:
		return NodoAVL.new(denuncia)

	# No permitimos dos denuncias con el mismo ID.
	if denuncia.id == nodo.denuncia.id:
		push_warning("Ya existe una denuncia con el ID: " + denuncia.id)
		return nodo

	# Izquierda = más prioritaria; derecha = menos prioritaria.
	if denuncia.va_antes_que(nodo.denuncia):
		nodo.izquierda = _insertar_recursivo(nodo.izquierda, denuncia)
	else:
		nodo.derecha = _insertar_recursivo(nodo.derecha, denuncia)

	_actualizar_altura(nodo)
	return _balancear(nodo)


func _altura(nodo: NodoAVL) -> int:
	if nodo == null:
		return 0
	return nodo.altura


func _actualizar_altura(nodo: NodoAVL) -> void:
	nodo.altura = 1 + max(_altura(nodo.izquierda), _altura(nodo.derecha))


func _factor_balance(nodo: NodoAVL) -> int:
	if nodo == null:
		return 0
	return _altura(nodo.izquierda) - _altura(nodo.derecha)


func _balancear(nodo: NodoAVL) -> NodoAVL:
	var balance: int = _factor_balance(nodo)

	# Casos izquierda-izquierda e izquierda-derecha.
	if balance > 1:
		if _factor_balance(nodo.izquierda) < 0:
			nodo.izquierda = _rotar_izquierda(nodo.izquierda)
		return _rotar_derecha(nodo)

	# Casos derecha-derecha y derecha-izquierda.
	if balance < -1:
		if _factor_balance(nodo.derecha) > 0:
			nodo.derecha = _rotar_derecha(nodo.derecha)
		return _rotar_izquierda(nodo)

	return nodo


func _rotar_derecha(nodo_y: NodoAVL) -> NodoAVL:
	var nodo_x: NodoAVL = nodo_y.izquierda
	var subarbol_t2: NodoAVL = nodo_x.derecha

	nodo_x.derecha = nodo_y
	nodo_y.izquierda = subarbol_t2

	_actualizar_altura(nodo_y)
	_actualizar_altura(nodo_x)

	return nodo_x


func _rotar_izquierda(nodo_x: NodoAVL) -> NodoAVL:
	var nodo_y: NodoAVL = nodo_x.derecha
	var subarbol_t2: NodoAVL = nodo_y.izquierda

	nodo_y.izquierda = nodo_x
	nodo_x.derecha = subarbol_t2

	_actualizar_altura(nodo_x)
	_actualizar_altura(nodo_y)

	return nodo_y

func obtener_prioritaria() -> Denuncia:
	if raiz == null:
		return null

	var actual: NodoAVL = raiz

	# Como izquierda significa "más prioritaria",
	# el caso prioritario es el nodo más a la izquierda.
	while actual.izquierda != null:
		actual = actual.izquierda

	return actual.denuncia


func recorrido_inorden() -> Array[Denuncia]:
	var denuncias_ordenadas: Array[Denuncia] = []
	_recorrer_inorden(raiz, denuncias_ordenadas)
	return denuncias_ordenadas


func _recorrer_inorden(nodo: NodoAVL, resultado: Array[Denuncia]) -> void:
	if nodo == null:
		return

	_recorrer_inorden(nodo.izquierda, resultado)
	resultado.append(nodo.denuncia)
	_recorrer_inorden(nodo.derecha, resultado)

func buscar_por_id(id: String) -> Denuncia:
	return _buscar_por_id_recursivo(raiz, id)


func _buscar_por_id_recursivo(nodo: NodoAVL, id: String) -> Denuncia:
	if nodo == null:
		return null

	if nodo.denuncia.id == id:
		return nodo.denuncia

	var encontrada_izquierda: Denuncia = _buscar_por_id_recursivo(nodo.izquierda, id)

	if encontrada_izquierda != null:
		return encontrada_izquierda

	return _buscar_por_id_recursivo(nodo.derecha, id)


func eliminar_por_id(id: String) -> bool:
	var denuncia: Denuncia = buscar_por_id(id)

	if denuncia == null:
		push_warning("No existe una denuncia con el ID: " + id)
		return false

	raiz = _eliminar_recursivo(raiz, denuncia)
	return true


func _eliminar_recursivo(nodo: NodoAVL, denuncia: Denuncia) -> NodoAVL:
	if nodo == null:
		return null

	if denuncia.id == nodo.denuncia.id:
		# Caso 1: no tiene hijo izquierdo.
		if nodo.izquierda == null:
			return nodo.derecha

		# Caso 2: no tiene hijo derecho.
		if nodo.derecha == null:
			return nodo.izquierda

		# Caso 3: tiene ambos hijos.
		# Se toma el primer nodo del subárbol derecho.
		var sucesor: NodoAVL = _nodo_mas_izquierdo(nodo.derecha)
		nodo.denuncia = sucesor.denuncia
		nodo.derecha = _eliminar_recursivo(nodo.derecha, sucesor.denuncia)

	elif denuncia.va_antes_que(nodo.denuncia):
		nodo.izquierda = _eliminar_recursivo(nodo.izquierda, denuncia)

	else:
		nodo.derecha = _eliminar_recursivo(nodo.derecha, denuncia)

	_actualizar_altura(nodo)
	return _balancear(nodo)


func _nodo_mas_izquierdo(nodo: NodoAVL) -> NodoAVL:
	var actual: NodoAVL = nodo

	while actual.izquierda != null:
		actual = actual.izquierda

	return actual

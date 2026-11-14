extends RefCounted
## Guías del despacho. Cada paso utiliza una captura de la oficina o de su minijuego.

const GUIAS := {
	&"terremoto": {
		"nombre": "TERREMOTO", "titulo": "PROTEGE LA DENUNCIA",
		"pista": "¡Descanso también se rompe! Rodea la grieta gigante.",
		"pasos": [
			["Reconoce el aviso", "Cuando empiece el temblor, busca suelo firme antes de que se abran las grietas.", preload("res://UI/Menus/ArtePiloto/Eventos/sismo_aviso.webp")],
			["Busca otro paso", "Caen más escombros en la oficina. Sal de las marcas rayadas: el borde se consume y se vuelve rojo antes del impacto. Salta solo las grietas estrechas con Espacio.", preload("res://UI/Menus/ArtePiloto/Eventos/sismo_grieta.webp")],
			["Cuida la hoja", "Si la hoja cae en una grieta, sola o contigo, pierdes ese caso. Espera al cierre para volver a cruzar.", preload("res://UI/Menus/ArtePiloto/Eventos/sismo_hoja.webp")],
		],
	},
	&"incendio": {
		"nombre": "INCENDIO", "titulo": "APAGA LAS MESAS",
		"pista": "Tras 24 s pierdes cordura. Abajo no cruza el hueco ni gira a los laterales.",
		"pasos": [
			["Recoge el extintor", "Sigue el marcador hasta la zona de descanso. Acércate al extintor y pulsa E.", preload("res://UI/Menus/ArtePiloto/Eventos/fuego_extintor.webp")],
			["Apaga hasta tres", "Mira una mesa cercana y mantén E. Al completar su arco, las vecinas del mismo tramo se apagan suavemente.", preload("res://UI/Menus/ArtePiloto/Eventos/fuego_mesa.webp")],
			["Recorre el perímetro", "Apaga todos los fuegos para detener la pérdida de cordura. Las estaciones apagadas vuelven a funcionar; los cajones se vuelven ceniza solos.", preload("res://UI/Menus/ArtePiloto/Eventos/fuego_oficina.webp")],
		],
	},
	&"inundacion": {
		"nombre": "INUNDACIÓN", "titulo": "REPARA LA FUGA DE AGUA",
		"pista": "Puedes seguir atendiendo casos mientras nadas.",
		"pasos": [
			["Nada hasta descanso", "El agua te ralentiza. Usa las teclas de movimiento para llegar a la zona de descanso.", preload("res://UI/Menus/ArtePiloto/Eventos/agua_nado.webp")],
			["Busca las tuberías", "Sigue el marcador hasta la tubería con la válvula. Mírala de cerca y pulsa E.", preload("res://UI/Menus/ArtePiloto/Eventos/agua_tuberia.webp")],
			["Conecta el desagüe", "Gira las piezas con clic, o elígelas con las flechas y pulsa E. Une la entrada con el desagüe.", preload("res://UI/Menus/ArtePiloto/Eventos/agua_red.webp")],
		],
	},
	&"lava": {
		"nombre": "LAVA", "titulo": "MANTENTE SOBRE LOS CAJONES",
		"pista": "Las mesas laterales no sirven de refugio.",
		"pasos": [
			["Sal del suelo", "El piso caliente te quita calma. Los charcos de magma aceleran la pérdida.", preload("res://UI/Menus/ArtePiloto/Eventos/lava_suelo.webp")],
			["Salta a un cajón", "Pulsa Espacio mientras avanzas hacia un cajón temporal. Sobre él estás a salvo.", preload("res://UI/Menus/ArtePiloto/Eventos/lava_cajon.webp")],
			["Mira el reloj", "Los cajones cambian cada cuatro segundos. Prepara el siguiente salto hasta que termine el minuto.", preload("res://UI/Menus/ArtePiloto/Eventos/lava_reloj.webp")],
		],
	},
	&"hielo": {
		"nombre": "HIELO", "titulo": "SELLA LA FUGA DE NITRÓGENO",
		"pista": "Al congelarte conservas la velocidad que llevabas.",
		"pasos": [
			["Anticipa el giro", "El piso resbala. Cada cuatro segundos te congelas un instante, así que gira antes de llegar a la pared.", preload("res://UI/Menus/ArtePiloto/Eventos/hielo_cristal.webp")],
			["Localiza la fuga", "Sigue el indicador de nitrógeno hasta la zona de descanso. Mira la tubería y pulsa E.", preload("res://UI/Menus/ArtePiloto/Eventos/hielo_tuberia.webp")],
			["Aprieta en cruz", "Sigue el orden del panel. Haz clic en las cuatro tuercas y repite la secuencia tres veces en total.", preload("res://UI/Menus/ArtePiloto/Eventos/hielo_tuercas.webp")],
		],
	},
}

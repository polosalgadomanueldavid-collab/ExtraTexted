extends RefCounted
## Dibujos de objetos y gestos. No contienen nombres ni instrucciones escritas.
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const VERDE := Color("507b65")

static func caja(c: CanvasItem, r: Rect2, color: Color, radio := 4.0) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(roundi(radio))
	c.draw_style_box(s, r)

static func marca(c: CanvasItem, p: Vector2, lado: float, correcta := true) -> void:
	var color := VERDE if correcta else CORAL
	c.draw_circle(p, lado * .5, color, true, -1, true)
	if correcta:
		c.draw_polyline(PackedVector2Array([p+Vector2(-.25,0)*lado,p+Vector2(-.06,.19)*lado,p+Vector2(.27,-.20)*lado]), CREMA, lado*.09, true)
	else:
		c.draw_line(p-Vector2.ONE*lado*.20,p+Vector2.ONE*lado*.20,CREMA,lado*.09,true)
		c.draw_line(p+Vector2(-1,1)*lado*.20,p+Vector2(1,-1)*lado*.20,CREMA,lado*.09,true)

static func flecha(c: CanvasItem, a: Vector2, b: Vector2, color := TINTA, grosor := 3.0) -> void:
	var d := (b-a).normalized()
	var n := Vector2(-d.y,d.x)
	c.draw_line(a,b,color,grosor,true)
	c.draw_polyline(PackedVector2Array([b-d*8+n*6,b,b-d*8-n*6]),color,grosor,true)

# Se dibuja dentro de la transformación de cada papel, también si está inclinado.
static func archivo(c: CanvasItem, tipo: int, p: Vector2, lado: float) -> void:
	var u := lado / 80.0
	match tipo:
		0:
			caja(c,Rect2(p+Vector2(-38,-28)*u,Vector2(76,56)*u),TINTA,5)
			caja(c,Rect2(p+Vector2(-34,-24)*u,Vector2(68,48)*u),CREMA,4)
			c.draw_circle(p+Vector2(-17,-8)*u,9*u,TINTA,true,-1,true)
			caja(c,Rect2(p+Vector2(-29,5)*u,Vector2(24,15)*u),TINTA,6)
			for y in [-10,0,10]: c.draw_line(p+Vector2(2,y)*u,p+Vector2(27,y)*u,TINTA,3*u,true)
		1:
			caja(c,Rect2(p+Vector2(-35,-25)*u,Vector2(53,31)*u),TINTA,8)
			c.draw_colored_polygon(PackedVector2Array([p+Vector2(-26,3)*u,p+Vector2(-26,17)*u,p+Vector2(-11,3)*u]),TINTA)
			caja(c,Rect2(p+Vector2(-8,1)*u,Vector2(44,25)*u),CORAL,8)
			c.draw_colored_polygon(PackedVector2Array([p+Vector2(15,23)*u,p+Vector2(29,34)*u,p+Vector2(29,23)*u]),CORAL)
			for x in [-22,-9,4]: c.draw_circle(p+Vector2(x,-10)*u,3*u,CREMA,true,-1,true)
		2:
			for x in [-16,16]:
				c.draw_arc(p+Vector2(x,0)*u,21*u,0,TAU,32,TINTA,7*u,true)
			c.draw_line(p+Vector2(-13,0)*u,p+Vector2(13,0)*u,CORAL,7*u,true)

static func objeto(c: CanvasItem, id: String, p: Vector2, lado: float, fase := 0.0) -> void:
	c.draw_set_transform(p-Vector2.ONE*lado*.5,0,Vector2.ONE*lado/64.0)
	match id:
		"archivo":
			caja(c,Rect2(9,2,46,60),TINTA,3)
			caja(c,Rect2(12,5,40,54),CREMA,1)
			archivo(c,0,Vector2(32,24),34)
			for y in [43,49,55]: c.draw_line(Vector2(18,y),Vector2(46,y),TINTA,2,true)
		"evidencias":
			caja(c,Rect2(5,18,54,39),TINTA)
			caja(c,Rect2(10,4,32,36),CREMA,2)
			archivo(c,0,Vector2(26,19),22)
			caja(c,Rect2(5,29,54,28),Color("d7ac69"))
			caja(c,Rect2(8,24,22,10),Color("d7ac69"),2)
			c.draw_line(Vector2(17,43),Vector2(47,43),TINTA,3,true)
		"verificacion":
			caja(c,Rect2(3,19,58,39),TINTA,5)
			caja(c,Rect2(7,23,50,25),Color("82c9d6"),2)
			caja(c,Rect2(14,26,36,18),CREMA,1)
			c.draw_line(Vector2(7,30+fase*12),Vector2(57,30+fase*12),CORAL,4,true)
			c.draw_circle(Vector2(51,53),2,VERDE)
			c.draw_polyline(PackedVector2Array([Vector2(5,16),Vector2(12,5),Vector2(55,5),Vector2(60,16)]),TINTA,4,true)
		"privacidad", "pc":
			caja(c,Rect2(5,5,54,37),TINTA)
			caja(c,Rect2(9,9,46,29),Color("82c9d6"),2)
			if id == "privacidad":
				c.draw_arc(Vector2(32,21),8,PI,TAU,20,TINTA,3,true)
				caja(c,Rect2(22,21,20,13),TINTA,2)
				c.draw_circle(Vector2(32,26),2,CREMA)
			else:
				caja(c,Rect2(21,13,22,21),CREMA,1)
				c.draw_line(Vector2(25,19),Vector2(39,19),TINTA,2,true)
			caja(c,Rect2(28,42,8,7),TINTA,1)
			caja(c,Rect2(4,50,56,9),TINTA,2)
			for x in range(10,56,8): c.draw_line(Vector2(x,53),Vector2(x,56),CREMA,2,true)
		"reporte":
			caja(c,Rect2(16,3,32,23),CREMA,1)
			caja(c,Rect2(4,20,56,30),TINTA,5)
			caja(c,Rect2(13,33,38,8),Color("82c9d6"),1)
			caja(c,Rect2(17,37,30,23),CREMA,1)
			for y in [43,49,55]: c.draw_line(Vector2(22,y),Vector2(42,y),TINTA,2,true)
			c.draw_circle(Vector2(51,27),3,CORAL)
		"bienestar":
			caja(c,Rect2(4,14,56,42),CREMA,8)
			caja(c,Rect2(20,5,24,13),TINTA,3)
			caja(c,Rect2(27,23,10,25),CORAL,1)
			caja(c,Rect2(19,31,26,9),CORAL,1)
		"moneda":
			c.draw_circle(Vector2(32,32),26,Color("bf893c"),true,-1,true)
			c.draw_circle(Vector2(32,29),23,Color("ffdc78"),true,-1,true)
			c.draw_arc(Vector2(32,29),18,0,TAU,40,Color("bf893c"),2,true)
			c.draw_colored_polygon(PackedVector2Array([Vector2(32,15),Vector2(36,25),Vector2(47,26),Vector2(39,33),Vector2(41,44),Vector2(32,38),Vector2(23,44),Vector2(25,33),Vector2(17,26),Vector2(28,25)]),Color("bf893c"))
		"chocolate":
			caja(c,Rect2(15,4,34,54),TINTA,3)
			caja(c,Rect2(18,7,28,48),Color("75452c"),2)
			for x in [20,33]:
				for y in [9,23]: caja(c,Rect2(x,y,11,12),Color("b2784b"),2)
			caja(c,Rect2(13,36,38,24),CORAL,2)
			c.draw_circle(Vector2(32,48),7,CREMA,true,-1,true)
		"tienda":
			caja(c,Rect2(7,2,50,60),TINTA,5)
			caja(c,Rect2(12,7,31,34),Color("82c9d6"),2)
			for x in [16,29]:
				for y in [12,27]: caja(c,Rect2(x,y,9,11),CORAL,2)
			c.draw_circle(Vector2(50,20),3,CREMA)
			caja(c,Rect2(16,47,32,9),CREMA,2)
		"plazo":
			for y in [5,59]: c.draw_line(Vector2(13,y),Vector2(51,y),TINTA,5,true)
			c.draw_polyline(PackedVector2Array([Vector2(17,9),Vector2(17,16),Vector2(30,31),Vector2(17,48),Vector2(17,55)]),TINTA,3,true)
			c.draw_polyline(PackedVector2Array([Vector2(47,9),Vector2(47,16),Vector2(34,31),Vector2(47,48),Vector2(47,55)]),TINTA,3,true)
			c.draw_colored_polygon(PackedVector2Array([Vector2(21,52),Vector2(43,52),Vector2(32,39)]),CORAL)
		"perdido":
			caja(c,Rect2(13,5,38,54),TINTA,2)
			caja(c,Rect2(16,8,32,48),CREMA,1)
			marca(c,Vector2(39,43),31,false)
		"grieta":
			c.draw_polyline(PackedVector2Array([Vector2(40,4),Vector2(24,21),Vector2(38,30),Vector2(19,47),Vector2(26,61)]),TINTA,9,true)
		"llave":
			c.draw_line(Vector2(16,53),Vector2(42,24),TINTA,12,true)
			c.draw_line(Vector2(16,53),Vector2(30,37),CORAL,8,true)
			c.draw_arc(Vector2(43,20),13,-.4,PI+1.6,28,TINTA,7,true)
			c.draw_circle(Vector2(16,53),3,CREMA)
		"soltar":
			caja(c,Rect2(8,5,24,29),CREMA,2)
			flecha(c,Vector2(43,17),Vector2(43,47),CORAL)
			c.draw_line(Vector2(7,57),Vector2(57,57),TINTA,3,true)
		"usar":
			c.draw_circle(Vector2(38,26),17,CREMA,true,-1,true)
			c.draw_circle(Vector2(43,21),2,TINTA)
			c.draw_arc(Vector2(36,30),6,0,PI,16,TINTA,3,true)
			caja(c,Rect2(5,35,13,21),Color("75452c"),2)
			flecha(c,Vector2(17,43),Vector2(29,34),CORAL,2.5)
	c.draw_set_transform(Vector2.ZERO)

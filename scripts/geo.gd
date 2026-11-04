extends RefCounted
## Hjälpfunktioner för att bygga meshar för hand.


## En triangel. Vänds automatiskt så att framsidan pekar åt hint-hållet.
static func tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, hint: Vector3,
		u0 := Vector2.ZERO, u1 := Vector2.ZERO, u2 := Vector2.ZERO) -> void:
	var n := (p2 - p0).cross(p1 - p0)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
		var tp := p1
		p1 = p2
		p2 = tp
		var tu := u1
		u1 = u2
		u2 = tu
	st.set_normal(n)
	st.set_uv(u0)
	st.add_vertex(p0)
	st.set_normal(n)
	st.set_uv(u1)
	st.add_vertex(p1)
	st.set_normal(n)
	st.set_uv(u2)
	st.add_vertex(p2)


## En fyrhörning a-b-c-d (i ordning runt kanten).
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3,
		ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1), ud := Vector2(0, 1)) -> void:
	tri(st, a, b, c, hint, ua, ub, uc)
	tri(st, a, c, d, hint, ua, uc, ud)

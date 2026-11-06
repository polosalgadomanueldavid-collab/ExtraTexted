"""Policía trazado sobre las vistas ortográficas de referencia.

Ejecutar: blender --background --python herramientas/generar_policia_azul.py
Genera un GLB con skin y seis clips; Blender solo es necesario para editarlo.
Coordenadas de autoría: Z arriba, -Y delante. En Godot: Y arriba, +Z delante.
Las cotas trasladan 650 px de altura a 2,66 unidades de malla.
"""
import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "proyecto-4-semestre/Personajes/PoliciaAzul"
SOURCE = ROOT / "arte-fuente/PoliciaAzul"
DEST.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
for block in bpy.data.actions:
    bpy.data.actions.remove(block)


def material(name, color, roughness=.4, metallic=0):
    # Artist-facing colours are sRGB; Blender shader inputs are scene-linear.
    color = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in color)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


BLUE = material("Uniforme · azul cobalto", (.075, .40, .83), .46)
PANTS = material("Pantalón · azul", (.065, .37, .81), .47)
COLLAR = material("Cuello · azul vivo", (.105, .46, .87), .45)
NAVY = material("Gorra · banda y visera", (.045, .115, .31), .40)
GOLD = material("Insignias y botones · oro", (1, .80, .055), .34, .18)
BLACK = material("Cinturón · cuero grafito", (.132, .135, .147), .54)
FLAP = material("Bolsillos · solapas", (.168, .17, .182), .48)
parts = []


def finish(obj, name, mat, bind):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    parts.append((obj, bind))
    return obj


def apply(obj, modifier):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def outward_normals(mesh):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def sphere(name, center, radii, mat, bind, segments=40, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bind)


def rounded_box(name, center, size, bevel, mat, bind):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Bordes redondeados", "BEVEL")
    mod.width = bevel
    mod.segments = 4
    apply(obj, mod)
    mod = obj.modifiers.new("Normales suaves", "WEIGHTED_NORMAL")
    apply(obj, mod)
    return finish(obj, name, mat, bind)


def ring_mesh(name, rings, mat, bind, segments=48, subdiv=2):
    # Rings: center Z, radius X, radius Y, center Y. Closed smoothly at poles.
    verts = []
    for z, rx, ry, cy in rings:
        for j in range(segments):
            a = j * math.tau / segments
            verts.append((rx * math.cos(a), cy + ry * math.sin(a), z))
    faces = []
    for i in range(len(rings) - 1):
        for j in range(segments):
            nj = (j + 1) % segments
            a, b = i * segments + j, i * segments + nj
            faces.append((a, b, b + segments, a + segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(rings) - 1) * segments + j for j in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if subdiv:
        mod = obj.modifiers.new("Superficie suave", "SUBSURF")
        mod.levels = subdiv
        apply(obj, mod)
    return finish(obj, name, mat, bind)


def fitted_panel(name, outline, center, depth, mat, bind, slope_x=0, slope_z=0):
    """Loft a rounded panel across its depth, following the host surface."""
    contour = []
    for i in range(len(outline)):
        a, b, c, d = (Vector(outline[j % len(outline)]) for j in range(i - 1, i + 3))
        for j in range(4):
            t = j / 4
            contour.append(.5 * (2 * b + (c - a) * t
                                 + (2 * a - 5 * b + 4 * c - d) * t ** 2
                                 + (d - a + 3 * b - 3 * c) * t ** 3))
    profiles = [(.06, -.66), (.72, -.62), (.94, -.44), (1, -.08),
                (.96, .32), (.75, .48), (.06, .50)]
    verts = [(x * scale, depth * offset + scale * (slope_x * x + slope_z * z), z * scale)
             for scale, offset in profiles for x, z in contour]
    n = len(contour)
    faces = [tuple(reversed(range(n)))]
    for i in range(len(profiles) - 1):
        for j in range(n):
            a, b = i * n + j, i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    faces.append(tuple(range(len(verts) - n, len(verts))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    outward_normals(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    mod = obj.modifiers.new("Relieve redondeado", "SUBSURF")
    mod.levels = 1
    apply(obj, mod)
    return finish(obj, name, mat, bind)


def shield(name, center, width, height, depth, bind, slope_x=0, slope_z=0):
    contour = [(-.49, .38), (-.24, .36), (0, .51), (.24, .36), (.49, .38),
               (.43, .10), (.46, -.16), (.34, -.33), (0, -.53),
               (-.34, -.33), (-.46, -.16), (-.43, .10)]
    return fitted_panel(name, [(x * width, z * height) for x, z in contour],
                        center, depth, GOLD, bind, slope_x, slope_z)


def lapel(name, side):
    x_center, z_center = side * .172, 1.611
    outline = [(side * x - x_center, z - z_center) for x, z in
               [(.016, 1.635), (.142, 1.676), (.324, 1.714), (.354, 1.682),
                (.296, 1.604), (.184, 1.52), (.126, 1.502), (.078, 1.546)]]
    lapel_mesh = fitted_panel(name, outline, (x_center, -.310, z_center), .049,
                              COLLAR, "chest", slope_z=.24)
    for v in lapel_mesh.data.vertices:
        x, z = x_center + v.co.x, z_center + v.co.z
        # Follow the curved neckline from the front notch to the outer tip.
        v.co.y += 1.55 * x ** 2 + .70 * max(z - 1.64, 0) + .24 * (z_center - 1.60)
    return lapel_mesh


# Lower body is one continuous organic surface, including the crotch arch.
lower = [ring_mesh("Pelvis temporal", [(.350, .050, .115, -.007),
    (.377, .23, .245, -.010), (.438, .390, .328, -.008),
    (.530, .469, .390, -.003), (.655, .480, .425, -.012),
    (.784, .483, .443, -.024), (.865, .462, .425, -.023),
    (.918, .36, .33, -.02)], PANTS, "lower", segments=40, subdiv=1)]
for side in (-1, 1):
    leg = ring_mesh("Pierna temporal", [(.001, .020, .031, .015),
        (.022, .090, .096, .021), (.074, .127, .134, .025),
        (.161, .149, .153, .029), (.283, .166, .173, .033),
        (.396, .182, .209, .029), (.525, .207, .262, .023),
        (.645, .203, .295, .012), (.737, .167, .235, .002)],
        PANTS, "lower", segments=32, subdiv=1)
    for v in leg.data.vertices:
        v.co.x += side * (.303 - .071 * min(v.co.z / .70, 1))
    lower.append(leg)
bpy.ops.object.select_all(action="DESELECT")
for obj in lower:
    obj.select_set(True)
bpy.context.view_layer.objects.active = lower[0]
bpy.ops.object.join()
pelvis = bpy.context.object
parts[:] = [(o, b) for o, b in parts if o not in lower]
mod = pelvis.modifiers.new("Unión orgánica", "REMESH")
mod.mode = "VOXEL"
mod.voxel_size = .013
mod.use_smooth_shade = True
apply(pelvis, mod)
mod = pelvis.modifiers.new("Suavizado", "SMOOTH")
mod.factor, mod.iterations = .8, 7
apply(pelvis, mod)
mod = pelvis.modifiers.new("Acabado orgánico", "SUBSURF")
mod.levels = 1
apply(pelvis, mod)
triangles = sum(len(face.vertices) - 2 for face in pelvis.data.polygons)
mod = pelvis.modifiers.new("Malla de juego", "DECIMATE")
mod.ratio = min(1.0, 26000 / triangles)
apply(pelvis, mod)
finish(pelvis, "Pantalón continuo", PANTS, "lower")

ring_mesh("Chaqueta", [(.73, .404, .375, -.015), (.80, .475, .441, -.020),
    (.90, .482, .449, -.023), (1.10, .460, .436, -.013), (1.29, .437, .408, -.003),
    (1.46, .424, .354, .023), (1.56, .382, .303, .037),
    (1.63, .324, .254, .041), (1.69, .229, .233, .020),
    (1.72, .135, .156, .015)], BLUE, "torso")
sphere("Cabeza sin rostro", (0, -.012, 1.982), (.433, .416, .391), BLUE, "head",
       segments=64, rings=40)
# Collar behind the two front lapels.
collar_band = ring_mesh("Cuello trasero", [(1.642, .290, .282, .011), (1.652, .341, .325, .012),
    (1.702, .358, .335, .016), (1.731, .332, .299, .018),
    (1.737, .285, .268, .018)], COLLAR, "chest", subdiv=1)
for v in collar_band.data.vertices:
    v.co.z += .075 * (v.co.y - .08)
lapel("Cuello izquierdo", 1)
lapel("Cuello derecho", -1)

for side, suffix in ((1, "L"), (-1, "R")):
    sleeve = ring_mesh("Manga " + suffix, [(.816, .146, .154, .038),
        (.831, .171, .177, .038), (.885, .170, .181, .038),
        (1.078, .158, .184, .038), (1.25, .156, .193, .038),
        (1.415, .163, .203, .038), (1.535, .146, .185, .038),
        (1.606, .090, .113, .038), (1.63, .028, .043, .038)], BLUE, "arm." + suffix,
        segments=40, subdiv=2)
    for v in sleeve.data.vertices:
        z = v.co.z
        shoulder = max(0, min(1, (z - 1.36) / .26))
        shoulder = shoulder * shoulder * (3 - 2 * shoulder)
        v.co.z += v.co.x * .28 * max(0, min(1, (1.04 - z) / .21))
        v.co.z += .025 * shoulder
        v.co.x = side * (v.co.x + .695 - (z - .836) * .395 - .041 * shoulder)
    outward_normals(sleeve.data)
    hand = sphere("Mano " + suffix, (side * .744, .042, .724), (.120, .170, .147),
                  BLUE, "hand." + suffix, segments=48, rings=28)
    hand.rotation_euler.y = -side * .30

# The crown is lofted front to back from the profile outline. Each section
# controls both the depth silhouette and the flared outline seen from front.
band = ring_mesh("Banda de la gorra", [(2.104, .381, .387, .014),
    (2.120, .424, .424, .012), (2.195, .436, .433, .015),
    (2.237, .423, .418, .019), (2.250, .381, .374, .021)], NAVY, "head")
for v in band.data.vertices:
    v.co.z -= .263 * v.co.y
sections = [(-.422, .026, 2.496, 2.662), (-.401, .195, 2.304, 2.671),
    (-.344, .315, 2.261, 2.662), (-.239, .461, 2.224, 2.637),
    (-.095, .545, 2.187, 2.594), (.045, .582, 2.173, 2.552),
    (.185, .551, 2.154, 2.494), (.319, .459, 2.130, 2.415),
    (.425, .321, 2.126, 2.338), (.509, .164, 2.141, 2.268),
    (.545, .022, 2.167, 2.225)]
crown = ring_mesh("Gorra de plato", [(y, rx, (hi - lo) / 2, (hi + lo) / 2)
                  for y, rx, lo, hi in sections], BLUE, "head")
for v in crown.data.vertices:
    v.co.y, v.co.z = v.co.z, v.co.y
outward_normals(crown.data)
visor = sphere("Visera", (0, -.391, 2.171), (.407, .248, .044), NAVY, "head",
               segments=64, rings=32)
for v in visor.data.vertices:
    v.co.z += .035 * v.co.y + .09 * max(v.co.y, 0) - .09 * v.co.x ** 2
shield("Placa de la gorra", (0, -.412, 2.432), .213, .229, .046, "head", slope_z=-.16)
for side in (-1, 1):
    sphere("Botón lateral de gorra", (side * .428, -.081, 2.194), (.028, .038, .039),
           GOLD, "head", segments=24, rings=12)

for i, (z, y) in enumerate(((1.387, -.394), (1.195, -.435), (.999, -.461))):
    sphere("Botón dorado %s" % (i + 1), (0, y, z), (.053, .029, .053),
           GOLD, "torso", segments=24, rings=12)
shield("Placa del pecho", (.236, -.349, 1.321), .217, .254, .056,
       "chest", slope_x=.57, slope_z=.24)

# Belt is a closed rounded elliptical band (not a cylinder across the torso).
ring_mesh("Cinturón", [(.694, .474, .447, -.018), (.708, .501, .478, -.018),
    (.850, .502, .479, -.018), (.864, .499, .477, -.018),
    (.876, .488, .464, -.018)], BLACK, "pelvis", subdiv=1)
rounded_box("Hebilla", (0, -.496, .771), (.267, .085, .174), .033, FLAP, "pelvis")
for side, suffix in ((-1, "R"), (1, "L")):
    pouch = rounded_box("Cartuchera " + suffix, (side * .329, -.378, .757),
                        (.252, .224, .335), .077, BLACK, "pelvis")
    pouch.rotation_euler.z = side * .30
    flap_outline = [(-.115, .055), (-.091, .085), (.083, .085), (.113, .056),
                    (.095, -.030), (.054, -.084), (0, -.103),
                    (-.055, -.084), (-.095, -.029)]
    fitted_panel("Solapa " + suffix, flap_outline, (side * .335, -.488, .842),
                 .071, FLAP, "pelvis", slope_x=side * .31)
    sphere("Broche " + suffix, (side * .340, -.533, .793), (.044, .018, .044),
           BLACK, "pelvis", segments=24, rings=12)
    # The left edge of the front image carries the taller utility case.
    case_z, case_height = (.702, .411) if side < 0 else (.748, .319)
    rounded_box("Funda lateral " + suffix, (side * .539, .009, case_z),
                (.158, .289, case_height), .071, BLACK, "pelvis")

# A genuine skin: the whole model is deformed by this armature on import.
armature = bpy.data.armatures.new("EsqueletoPoliciaAzul")
rig = bpy.data.objects.new("Rig", armature)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, head, tail, parent=None):
    b = armature.edit_bones.new(name)
    b.head, b.tail = head, tail
    if name.startswith(("upper_arm.", "forearm.", "hand.", "thigh.", "shin.")):
        # Keep the side-to-side rotation axis consistent on both arms.
        b.align_roll(Vector((0, 1, 0)))
    if parent:
        b.parent = armature.edit_bones[parent]


bone("root", (0, 0, 0), (0, 0, .25))
bone("pelvis", (0, 0, .68), (0, 0, .90), "root")
bone("spine", (0, 0, .90), (0, 0, 1.30), "pelvis")
bone("chest", (0, 0, 1.30), (0, 0, 1.62), "spine")
bone("head", (0, 0, 1.62), (0, 0, 2.20), "chest")
for side, suffix in ((1, "L"), (-1, "R")):
    shoulder = (side * .424, .038, 1.535)
    elbow = (side * .558, .038, 1.192)
    wrist = (side * .695, .041, .837)
    hip = (side * .242, .020, .647)
    knee = (side * .268, .023, .352)
    ankle = (side * .292, .021, .122)
    bone("upper_arm." + suffix, shoulder, elbow, "chest")
    bone("forearm." + suffix, elbow, wrist, "upper_arm." + suffix)
    bone("hand." + suffix, wrist, (side * .755, .042, .633), "forearm." + suffix)
    bone("thigh." + suffix, hip, knee, "pelvis")
    bone("shin." + suffix, knee, ankle, "thigh." + suffix)
    bone("foot." + suffix, ankle, (side * .297, -.145, .090), "shin." + suffix)
bpy.ops.object.mode_set(mode="OBJECT")


def blend_height(z, stops):
    if z <= stops[0][0]:
        return {stops[0][1]: 1.0}
    for (lo, a), (hi, b) in zip(stops, stops[1:]):
        if z <= hi:
            t = (z - lo) / (hi - lo)
            t = t * t * (3 - 2 * t)
            return {a: 1 - t, b: t}
    return {stops[-1][1]: 1.0}


def smoothstep(value, low, high):
    t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)


for obj, binding in parts:
    obj.parent = rig
    groups = {}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if binding == "lower":
            suffix = "L" if p.x >= 0 else "R"
            weights = blend_height(p.z, [(.11, "foot." + suffix), (.22, "shin." + suffix),
                (.40, "thigh." + suffix), (.72, "pelvis")])
            # The centre of the crotch moves with the pelvis so the weld
            # never snaps directly from one leg to the other as they swing.
            centre = (1 - smoothstep(abs(p.x), .052, .166)) * smoothstep(p.z, .266, .338)
            weights = {name: weight * (1 - centre) for name, weight in weights.items()}
            weights["pelvis"] = weights.get("pelvis", 0) + centre
        elif binding == "torso":
            weights = blend_height(p.z, [(.80, "pelvis"), (1.13, "spine"), (1.47, "chest")])
        elif binding.startswith("arm."):
            suffix = binding[-1]
            weights = blend_height(p.z, [(.98, "forearm." + suffix), (1.37, "upper_arm." + suffix)])
        else:
            weights = {binding: 1}
        for name, weight in weights.items():
            if weight <= 0:
                continue
            if name not in groups:
                groups[name] = obj.vertex_groups.new(name=name)
            groups[name].add([v.index], weight, "REPLACE")
    mod = obj.modifiers.new("Deformación del esqueleto", "ARMATURE")
    mod.object = rig

scene = bpy.context.scene
scene.render.fps = 30
for b in rig.pose.bones:
    b.rotation_mode = "XYZ"


def clip(name, seconds, motion):
    action = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = action
    count = round(seconds * 30)
    for frame in range(count + 1):
        t = frame / count
        for b in rig.pose.bones:
            b.location = (0, 0, 0)
            b.rotation_euler = (0, 0, 0)
            b.scale = (1, 1, 1)
        motion(t)
        for b in rig.pose.bones:
            b.keyframe_insert(data_path="rotation_euler", frame=frame)
            if b.name == "root":
                b.keyframe_insert(data_path="location", frame=frame)
    # One named NLA track per animation is reliably imported as one Godot clip.
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, action)
    strip.action_frame_start, strip.action_frame_end = 0, count
    track.mute = True
    return action


pose = rig.pose.bones


def idle(t):
    s = math.sin(t * math.tau)
    pose["root"].location.y = .007 * (1 + s)
    pose["chest"].rotation_euler.x = .014 * s
    pose["head"].rotation_euler.z = .022 * s
    for side in ("L", "R"):
        pose["upper_arm." + side].rotation_euler.x = .018 * s


def gait(t, running=False):
    a = t * math.tau
    stride = .68 if running else .42
    pose["root"].location.y = (.055 if running else .025) * (1 - math.cos(2 * a))
    pose["spine"].rotation_euler.x = -.10 if running else -.025
    pose["chest"].rotation_euler.z = .055 * math.sin(a)
    pose["head"].rotation_euler.z = -.035 * math.sin(a)
    for side, phase in (("L", a), ("R", a + math.pi)):
        s = math.sin(phase)
        pose["thigh." + side].rotation_euler.x = stride * s
        pose["shin." + side].rotation_euler.x = max(0, -s) * (.85 if running else .40)
        pose["foot." + side].rotation_euler.x = -.14 * s
        pose["upper_arm." + side].rotation_euler.x = -stride * .85 * s
        pose["forearm." + side].rotation_euler.x = -.38 if running else -.08 - .10 * max(0, s)


def jump(t):
    s = math.sin(t * math.pi)
    for side in ("L", "R"):
        pose["thigh." + side].rotation_euler.x = -.38 * s
        pose["shin." + side].rotation_euler.x = .48 * s
        pose["upper_arm." + side].rotation_euler.x = -.60 * s
        pose["forearm." + side].rotation_euler.x = -.18 * s
    pose["chest"].rotation_euler.x = -.08 * s


def fall(t):
    s = .03 * math.sin(t * math.tau)
    pose["upper_arm.L"].rotation_euler.z = -.30 + s
    pose["upper_arm.R"].rotation_euler.z = .30 - s
    for side in ("L", "R"):
        pose["thigh." + side].rotation_euler.x = -.12
        pose["shin." + side].rotation_euler.x = .20


def wave(t):
    ramp = min(1, t * 6, (1 - t) * 6)
    ramp = ramp * ramp * (3 - 2 * ramp)
    pose["upper_arm.R"].rotation_euler.z = 2.25 * ramp
    pose["upper_arm.R"].rotation_euler.x = -.15 * ramp
    pose["forearm.R"].rotation_euler.x = -.25 * ramp
    pose["forearm.R"].rotation_euler.z = .25 * ramp * math.sin(t * math.tau * 3)
    pose["hand.R"].rotation_euler.z = .20 * ramp * math.sin(t * math.tau * 3)
    pose["head"].rotation_euler.z = -.055 * ramp


clip("idle", 2.4, idle)
clip("walk", .9, gait)
clip("run", .6, lambda t: gait(t, True))
clip("jump", .65, jump)
clip("fall", .8, fall)
clip("wave", 1.8, wave)
for b in pose:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
scene.frame_set(0)

# Export only game geometry and armature. No lights or camera in the GLB.
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
for obj, _ in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(DEST / "policia_azul.glb"), export_format="GLB",
    use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS",
    export_skins=True, export_yup=True, export_force_sampling=True, export_frame_range=False)

# Keep the editable source outside the Godot project, avoiding a Blender dependency on import.
rig.show_in_front = True
armature.display_type = "STICK"
scene.world.color = (.16, .18, .23)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "policia_azul.blend"), compress=True)

# Studio render for visual verification; optional review image, not a game texture.
bpy.ops.object.camera_add(location=(3.5, -6.4, 3.15))
camera = bpy.context.object
direction = Vector((0, 0, 1.35)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type, camera.data.ortho_scale = "ORTHO", 3.5
scene.camera = camera
for location, energy, size in [((3, -4, 6), 550, 4), ((-4, -2, 3), 400, 4), ((1, 3, 5), 650, 3)]:
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy, light.data.shape, light.data.size = energy, "DISK", size
    light.rotation_euler = (Vector((0, 0, 1.3)) - light.location).to_track_quat("-Z", "Y").to_euler()
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 900
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = True
scene.view_settings.view_transform = "AgX"
scene.render.filepath = str(SOURCE / "vista_previa.png")
bpy.ops.render.render(write_still=True)
print("POLICIA_AZUL_OK", len(parts), "meshes", len(armature.bones), "bones", flush=True)

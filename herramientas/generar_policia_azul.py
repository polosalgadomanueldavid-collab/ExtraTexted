"""Modelo original basado en las referencias del proyecto.

Ejecutar: blender --background --python herramientas/generar_policia_azul.py
Genera un GLB con skin y seis clips; Blender solo es necesario para editarlo.
Coordenadas de autoría: Z arriba, -Y delante. En Godot: Y arriba, +Z delante.
"""
import math
from pathlib import Path

import bpy
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


BLUE = material("Uniforme · azul cobalto", (.055, .37, .84), .42)
PANTS = material("Pantalón · azul", (.045, .31, .73), .46)
COLLAR = material("Cuello y puños · azul vivo", (.075, .43, .92), .41)
NAVY = material("Gorra · banda y visera", (.035, .105, .35), .38)
GOLD = material("Insignias y botones · oro", (1, .79, .035), .32, .25)
BLACK = material("Cinturón · cuero grafito", (.115, .13, .16), .55)
FLAP = material("Bolsillos · solapas", (.16, .175, .20), .49)
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


def ring_mesh(name, rings, mat, bind, segments=64, subdiv=2):
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


def shield(name, center, width, height, depth, mat, bind):
    # Original shield contour, softened bevel: crown notch, shoulders and point.
    contour = [(-.48, .43), (-.23, .40), (0, .52), (.23, .40), (.48, .43),
               (.43, .13), (.46, -.16), (.34, -.33), (0, -.54),
               (-.34, -.33), (-.46, -.16), (-.43, .13)]
    verts = [(x * width, y, z * height) for y in (-depth / 2, depth / 2)
             for x, z in contour]
    n = len(contour)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, j + n, i + n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    mod = obj.modifiers.new("Relieve redondeado", "BEVEL")
    mod.width = min(width, height) * .065
    mod.segments = 4
    apply(obj, mod)
    mod = obj.modifiers.new("Normales", "WEIGHTED_NORMAL")
    apply(obj, mod)
    return finish(obj, name, mat, bind)


def lapel(name, side):
    verts = [(side * .018, -.205, 1.625), (side * .29, -.195, 1.60),
             (side * .20, -.295, 1.45), (side * .075, -.28, 1.49)]
    verts += [(x, y + .045, z + .008) for x, y, z in verts]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
                                (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mod = obj.modifiers.new("Cuello redondeado", "BEVEL")
    mod.width, mod.segments = .028, 4
    apply(obj, mod)
    mod = obj.modifiers.new("Normales", "WEIGHTED_NORMAL")
    apply(obj, mod)
    return finish(obj, name, COLLAR, "chest")


# Lower body is one continuous organic surface, including the crotch arch.
lower = [sphere("Pelvis temporal", (0, 0, .63), (.445, .285, .29), PANTS, "lower")]
for side in (-1, 1):
    lower.append(sphere("Pierna temporal", (side * .235, -.005, .32),
                        (.196, .225, .32), PANTS, "lower"))
bpy.ops.object.select_all(action="DESELECT")
for obj in lower:
    obj.select_set(True)
bpy.context.view_layer.objects.active = lower[0]
bpy.ops.object.join()
pelvis = bpy.context.object
parts[:] = [(o, b) for o, b in parts if o not in lower]
mod = pelvis.modifiers.new("Unión orgánica", "REMESH")
mod.mode = "VOXEL"
mod.voxel_size = .017
mod.use_smooth_shade = True
apply(pelvis, mod)
mod = pelvis.modifiers.new("Suavizado", "SMOOTH")
mod.factor, mod.iterations = 1.15, 5
apply(pelvis, mod)
mod = pelvis.modifiers.new("Malla de juego", "DECIMATE")
mod.ratio = .40
apply(pelvis, mod)
mod = pelvis.modifiers.new("Acabado orgánico", "SUBSURF")
mod.levels = 1
apply(pelvis, mod)
finish(pelvis, "Pantalón continuo", PANTS, "lower")

ring_mesh("Chaqueta", [(.70, .29, .20, 0), (.73, .39, .26, 0),
    (.80, .445, .285, 0), (1.02, .448, .29, 0), (1.27, .423, .275, 0),
    (1.43, .37, .25, 0), (1.54, .29, .205, 0),
    (1.61, .19, .155, 0), (1.63, .12, .10, 0)], BLUE, "torso")
sphere("Cabeza sin rostro", (0, -.012, 1.965), (.425, .355, .405), BLUE, "head")
# Collar behind the two front lapels.
ring_mesh("Cuello trasero", [(1.565, .20, .16, 0), (1.59, .255, .198, 0),
    (1.635, .24, .19, 0), (1.66, .18, .145, 0)], COLLAR, "chest", subdiv=1)
lapel("Cuello izquierdo", 1)
lapel("Cuello derecho", -1)

for side, suffix in ((1, "L"), (-1, "R")):
    # A continuous sleeve with elbow weighting; flattened cuffs and mitten hands.
    sleeve = ring_mesh("Manga " + suffix, [(.765, .124, .125, -.005),
        (.78, .15, .15, -.005), (.88, .151, .153, 0),
        (1.10, .155, .158, 0), (1.32, .17, .163, 0),
        (1.45, .145, .14, 0), (1.48, .09, .09, 0)], BLUE, "arm." + suffix,
        segments=40, subdiv=2)
    # The ring centres sweep outward towards the wrist.
    for v in sleeve.data.vertices:
        z = v.co.z
        v.co.x += side * (.70 - (z - .78) * .44)
    sphere("Mano " + suffix, (side * .719, -.012, .663), (.13, .14, .169), BLUE,
           "hand." + suffix)
    cuff = sphere("Puño " + suffix, (side * .70, -.004, .795), (.151, .153, .045),
                  COLLAR, "forearm." + suffix)
    cuff.rotation_euler.y = side * -.25

# Cap band and a broad, softly peaked crown with a rising front profile.
ring_mesh("Banda de la gorra", [(2.22, .39, .325, -.005),
    (2.235, .433, .36, -.005), (2.32, .437, .363, -.005),
    (2.35, .42, .345, -.005)], NAVY, "head", subdiv=1)
crown = ring_mesh("Gorra de plato", [(2.315, .416, .35, 0),
    (2.34, .51, .415, .005), (2.39, .568, .455, .008),
    (2.45, .565, .45, .01), (2.54, .43, .36, .012),
    (2.64, .20, .21, .005), (2.66, .015, .02, 0)], BLUE, "head", subdiv=2)
for v in crown.data.vertices:
    # Front of the crown sits higher, as in the reference side view.
    v.co.z += -v.co.y * .12
sphere("Visera", (0, -.346, 2.242), (.449, .278, .041), NAVY, "head")
sphere("Ribete de visera", (0, -.358, 2.262), (.425, .25, .017), BLUE, "head")
shield("Placa de la gorra", (0, -.423, 2.476), .18, .205, .048, GOLD, "head")
for side in (-1, 1):
    sphere("Botón lateral de gorra", (side * .425, -.14, 2.29), (.027, .030, .036),
           GOLD, "head", segments=24, rings=12)

for i, z in enumerate((1.375, 1.19, 1.005)):
    sphere("Botón dorado %s" % (i + 1), (0, -.286, z), (.049, .025, .049),
           GOLD, "torso", segments=24, rings=12)
shield("Placa del pecho", (-.225, -.257, 1.312), .19, .235, .052, GOLD, "chest")

# Belt is a closed rounded elliptical band (not a cylinder across the torso).
ring_mesh("Cinturón", [(.715, .444, .293, 0), (.735, .474, .322, 0),
    (.845, .474, .322, 0), (.865, .444, .293, 0)], BLACK, "pelvis", subdiv=1)
rounded_box("Hebilla", (0, -.340, .79), (.24, .085, .155), .035, FLAP, "pelvis")
for side, suffix in ((-1, "R"), (1, "L")):
    pouch = rounded_box("Cartuchera " + suffix, (side * .329, -.286, .755),
                        (.225, .16, .29), .065, BLACK, "pelvis")
    pouch.rotation_euler.z = side * -.10
    flap = rounded_box("Solapa " + suffix, (side * .329, -.383, .823),
                       (.208, .048, .157), .052, FLAP, "pelvis")
    sphere("Broche " + suffix, (side * .329, -.415, .798), (.042, .019, .043),
           BLACK, "pelvis", segments=24, rings=12)
    rounded_box("Funda lateral " + suffix, (side * .464, -.018, .718),
                (.14, .225, .34), .060, BLACK, "pelvis")

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
    bone("upper_arm." + suffix, (side * .39, 0, 1.45), (side * .55, 0, 1.12), "chest")
    bone("forearm." + suffix, (side * .55, 0, 1.12), (side * .70, 0, .79), "upper_arm." + suffix)
    bone("hand." + suffix, (side * .70, 0, .79), (side * .73, 0, .60), "forearm." + suffix)
    bone("thigh." + suffix, (side * .235, 0, .63), (side * .235, 0, .34), "pelvis")
    bone("shin." + suffix, (side * .235, 0, .34), (side * .235, 0, .12), "thigh." + suffix)
    bone("foot." + suffix, (side * .235, 0, .12), (side * .235, -.17, .09), "shin." + suffix)
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


for obj, binding in parts:
    obj.parent = rig
    groups = {}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if binding == "lower":
            suffix = "L" if p.x >= 0 else "R"
            weights = blend_height(p.z, [(.11, "foot." + suffix), (.22, "shin." + suffix),
                (.39, "thigh." + suffix), (.69, "pelvis")])
        elif binding == "torso":
            weights = blend_height(p.z, [(.80, "pelvis"), (1.13, "spine"), (1.47, "chest")])
        elif binding.startswith("arm."):
            suffix = binding[-1]
            weights = blend_height(p.z, [(.90, "forearm." + suffix), (1.29, "upper_arm." + suffix)])
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

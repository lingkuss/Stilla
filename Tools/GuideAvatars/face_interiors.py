"""Shared low-cost oral anatomy. Eight curved incisors/canines, one mesh."""
import bpy
import math
from mathutils import Vector


def refine_dental_arch(portrait, parent, name='Upper dental arch'):
    old = bpy.data.objects[name]
    # Work in the head's coordinates for both source rigs.
    transform = parent.matrix_world.inverted() @ old.matrix_world
    points = [transform @ v.co for v in old.data.vertices]
    left, right = min(p.x for p in points), max(p.x for p in points)
    center = (left + right) / 2
    half_width = (right - left) * .46
    front = min(p.y for p in points) + .001
    top = max(p.z for p in points)
    bpy.data.objects.remove(old, do_unlink=True)
    widths = [.19, .23, .27, .31, .31, .27, .23, .19]
    total = sum(widths)
    verts, faces, slots = [], [], []
    start = center - half_width
    for tooth, proportion in enumerate(widths):
        width = half_width * 2 * proportion / total
        offset = len(verts)
        for row in range(4):
            vertical = row / 3
            for column in range(7):
                horizontal = column / 6
                x = start + width * horizontal
                # Almost-touching boundaries, rounded incisal edge and convex
                # enamel: never a row of detached cubes or one white strip.
                x += .00006 * (1 - 2 * horizontal)
                scallop = .00045 * abs(2 * horizontal - 1) ** 4
                height = .0041 if tooth in [3, 4] else .0038
                z = top + .001 - vertical * (height + .001 - scallop)
                y = front + .025 * ((x - center) / half_width) ** 2
                y += .00055 * (2 * horizontal - 1) ** 2 + .0002 * vertical
                verts.append((x, y, z))
        for row in range(3):
            for column in range(6):
                a = offset + row * 7 + column
                faces.append((a, a+7, a+8, a+1))
                slots.append(row)
        start += width
    data = bpy.data.meshes.new('Individual curved dental crowns')
    data.from_pydata(verts, [], faces); data.update()
    teeth = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(teeth); teeth.parent = parent
    # Upper-lip occlusion softens the roots. Ivory is intentionally subdued.
    for label, color in [('root', (.16,.135,.105)), ('enamel', (.31,.275,.22)), ('edge', (.27,.245,.205))]:
        data.materials.append(portrait.material('Natural teeth '+label, color, roughness=.58))
    for polygon, slot in zip(data.polygons, slots):
        polygon.material_index = slot; polygon.use_smooth = True

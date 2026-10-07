"""A guide-specific facial surface registered to its own portrait landmarks.

No inference at build/runtime: coordinates are baked in the source JSON. The
face has a shaped nose, cheeks, lips, jaw and a closed back, not a portrait quad.
"""
import bpy
import bmesh
import json
import math
from mathutils import Vector


def create_reference_face(portrait_mesh, parent, source):
    data = json.loads(source.read_text())
    points = data['landmarks']
    vertices = [portrait_mesh.point(x * 1024, y * 1024, .22 - z * 1024 / 560)
                for x, y, z in points]
    triangles = data['triangles']
    topology = bpy.data.meshes.new('Serene reference anatomy')
    topology.from_pydata(vertices, [], triangles)
    topology.update()
    bm = bmesh.new()
    bm.from_mesh(topology)
    # Preserve the three anatomical apertures. Filling them makes speech only
    # stretch painted lips and makes it impossible for the eyelids to open.
    # Only the outer face boundary is extended into the rear skull below.
    rim_ids = {10,338,297,332,284,251,389,356,454,323,361,288,397,
               365,379,378,400,377,152,148,176,149,150,136,172,58,
               132,93,234,127,162,21,54,103,67,109}
    bm.verts.ensure_lookup_table()
    rim = {bm.verts[i] for i in rim_ids}
    # The detector stops below the hairline. Extend a painted forehead/temple
    # ring under the hair so the crown cannot reveal an empty black band.
    outline = [e for e in bm.edges if e.is_boundary and all(v in rim for v in e.verts)]
    extension = bmesh.ops.extrude_edge_only(bm, edges=outline)
    for vertex in extension['geom']:
        if not isinstance(vertex, bmesh.types.BMVert):
            continue
        py = portrait_mesh.origin_y - vertex.co.z * portrait_mesh.scale_z
        upper = max(0, min(1, (260 - py) / 65))
        vertex.co.x *= 1 + .14 * upper
        vertex.co.z += .047 * max(0, min(1, (186 - py) / 62))
    # Connect to a shallow skull behind the hair; no painted rear face.
    outer = {v for v in extension['geom'] if isinstance(v, bmesh.types.BMVert)}
    outline = [e for e in bm.edges if e.is_boundary and all(v in outer for v in e.verts)]
    result = bmesh.ops.extrude_edge_only(bm, edges=outline)
    rear = [v for v in result['geom'] if isinstance(v, bmesh.types.BMVert)]
    for vertex in rear:
        vertex.co.y = .035
        vertex.co.x *= .86
    back = set(rear)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary and all(v in back for v in e.verts)], sides=0)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(topology)
    bm.free()
    obj = bpy.data.objects.new('AnatomicalHead', topology)
    bpy.context.collection.objects.link(obj)
    topology.materials.append(portrait_mesh.paint)
    topology.materials.append(portrait_mesh.material('Serene skin rear', (.46, .28, .18)))
    topology.update()
    for polygon in topology.polygons:
        polygon.use_smooth = True
        if polygon.center.y > -.07:
            polygon.material_index = 1
    # Store two independent expressions in standard displayColor, which survives
    # USDZ import. R/G = eyelid Z/Y delta; B = jaw Z delta. Each has its own
    # anatomical support, interpolated by subdivision along with the skin.
    motion = topology.color_attributes.new(name='displayColor', type='FLOAT_COLOR', domain='POINT')
    topology.color_attributes.active_color = motion
    eye_sets = [([33,246,161,160,159,158,157,173,133], [33,7,163,144,145,153,154,155,133]),
                ([362,398,384,385,386,387,388,466,263], [362,382,381,380,374,373,390,249,263])]
    lower_lip = {78,95,88,178,87,14,317,402,318,324,308}
    upper_lip = {78,191,80,81,82,13,312,311,310,415,308}
    lip_y = (points[13][1] + points[14][1]) * 512
    original_indices = {tuple(round(c, 6) for c in v): i for i, v in enumerate(vertices)}
    mouth_left, mouth_right = sorted(points[i][0]*1024 for i in [78,308])
    for vertex, color in zip(topology.vertices, motion.data):
        source_index = original_indices.get(tuple(round(c, 6) for c in vertex.co), -1)
        x = vertex.co.x * portrait_mesh.scale_x + 512
        y = portrait_mesh.origin_y - vertex.co.z * portrait_mesh.scale_z
        eye_z = eye_y = 0
        if vertex.co.y < -.10:
            for upper, lower in eye_sets:
                corners = [points[upper[0]], points[upper[-1]]]
                left, right = sorted(p[0]*1024 for p in corners)
                t = max(0, min(1, (x-left)/(right-left)))
                seam = sum(points[i][1]*1024 for i in [upper[4], lower[4]])/2
                above = source_index in set(upper)-set(lower) or (source_index not in lower and y < seam)
                vertical = math.exp(-((y-seam)/(15 if above else 10))**2)
                weight = math.sin(t*math.pi)**0.8 * vertical
                eye_z += (0.0115 if above else -0.0022) * weight
                eye_y += 0.0015 * weight
            below = source_index in lower_lip-upper_lip or (source_index not in upper_lip and y >= lip_y)
            t = max(0, min(1, (x-mouth_left)/(mouth_right-mouth_left)))
            width = math.sin(t*math.pi)**.6
            weight = width * math.exp(-((y-lip_y)/(32 if below else 9))**2)
            # The lower lip opens with a small distributed chin/cheek response,
            # not an isolated elastic slit. Keep the upper face independent.
            jaw = math.exp(-((x-(mouth_left+mouth_right)/2)/65)**2 - ((y-lip_y)/52)**2)
            jaw_z = (-.0105*weight-.0025*jaw) if below else .0015*weight
        else:
            jaw_z = 0
        color.color = (.5+eye_z/.08, .5+eye_y/.08, .5+jaw_z/.08, 1)
    bpy.context.view_layer.objects.active = obj
    # Two levels give smooth cheek/nose silhouettes; reprojection below keeps
    # every feature attached to its measured position after subdivision.
    smooth = obj.modifiers.new('Facial surface refinement', 'SUBSURF')
    smooth.levels = 2
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    obj.parent = parent
    inverse = parent.matrix_world.inverted()
    for vertex in obj.data.vertices:
        vertex.co = inverse @ vertex.co
    bpy.context.view_layer.update()
    portrait_mesh.project(obj)

    colors=obj.data.color_attributes['displayColor']
    for color in colors.data:
        color.color=tuple(max(0,min(1,v)) for v in color.color)
    samples=[]
    for name,index,channel,sign in [('upperLidLeft',159,0,1),('lowerLidLeft',145,0,-1),
                                    ('upperLidRight',386,0,1),('lowerLidRight',374,0,-1),
                                    ('lowerLip',14,2,-1),('upperLip',13,2,1),('forehead',10,0,0)]:
        expected=inverse @ Vector(vertices[index])
        candidates=[v for v in obj.data.vertices if sign==0 or (colors.data[v.index].color[channel]-.5)*sign>.001]
        v=min(candidates,key=lambda v:(v.co-expected).length_squared)
        samples.append(dict(name=name,position=list(v.co),encoded=list(colors.data[v.index].color[:3])))
    (source.parent/'motion-samples.json').write_text(json.dumps(samples,indent=2)+'\n')

    add_face_interiors(portrait_mesh, parent, points)
    return obj


def add_face_interiors(mesh, parent, points):
    """Recessed curved eyes and oral cavity, revealed by the actual lid/lip rims."""
    sclera = mesh.material('Serene warm sclera', (.28,.245,.21), roughness=.45)
    iris = mesh.material('Serene hazel iris', (.052,.035,.019), roughness=.35)
    pupil = mesh.material('Serene pupil', (.005,.004,.003), roughness=.28)
    limbus = mesh.material('Serene limbus', (.025,.023,.014), roughness=.40)
    inverse = parent.matrix_world.inverted()
    for label, indices in [('Left',(159,145)), ('Right',(386,374))]:
        a,b = (points[i] for i in indices)
        x,y,z = ((a[i]+b[i])/2 for i in range(3))
        center = Vector(mesh.point(x*1024,y*1024,.22-z*1024/560-.031))
        pivot = bpy.data.objects.new('Eye'+label+'Pivot', None)
        bpy.context.collection.objects.link(pivot); pivot.parent=parent
        pivot.location=inverse @ center
        angles = [0,.07,.14,.20,.26,.32,.38,.44,.48,.54,.65,.8,1,1.3,1.6,2,2.5,math.pi]
        vertices=[];faces=[];slots=[];n=48
        for theta in angles:
            for j in range(n):
                phi=j/n*math.tau
                direction=Vector((math.sin(theta)*math.cos(phi),-math.cos(theta),math.sin(theta)*math.sin(phi)))
                # Soft forward gaze aligned with the opened aperture, not the
                # lower resting eyelash line in the closed-eye photograph.
                direction.y,direction.z=(math.cos(-.11)*direction.y-math.sin(-.11)*direction.z,
                                          math.sin(-.11)*direction.y+math.cos(-.11)*direction.z)
                vertices.append((.031*direction.x,.027*direction.y,.025*direction.z))
        for i in range(len(angles)-1):
            for j in range(n):
                faces.append(((i+1)*n+j,(i+1)*n+(j+1)%n,i*n+(j+1)%n,i*n+j))
                theta=(angles[i]+angles[i+1])/2
                slots.append(2 if theta<.20 else 1 if theta<.44 else 3 if theta<.48 else 0)
        data=bpy.data.meshes.new('Serene eyeball '+label);data.from_pydata(vertices,[],faces);data.update()
        eye=bpy.data.objects.new('Eyeball'+label,data);bpy.context.collection.objects.link(eye);eye.parent=pivot
        for mat in [sclera,iris,pupil,limbus]:data.materials.append(mat)
        for poly,slot in zip(data.polygons,slots):poly.material_index=slot;poly.use_smooth=True
    a,b=points[13],points[14]
    center=Vector(mesh.point((a[0]+b[0])*512,(a[1]+b[1])*512+4,.225))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12)
    cavity=bpy.context.object;cavity.name='Mouth inset';cavity.parent=parent;cavity.location=inverse@center
    for vertex in cavity.data.vertices:
        vertex.co.x*=.037;vertex.co.y=vertex.co.y*.006+.045*(vertex.co.x/.037)**2;vertex.co.z*=.028
    cavity.data.materials.append(mesh.material('Serene mouth interior',(.024,.009,.008),roughness=.9))
    # Recessed upper dental arch, visible only through parted lips. Curving the
    # depth with the cheek prevents a dark/white patch piercing a mouth corner.
    top=Vector(mesh.point((a[0]+b[0])*512,(a[1]+b[1])*512,.234))
    verts=[];faces=[]
    for i in range(33):
        x=(i/32*2-1)*.030
        for z in [0,-.004]:
            verts.append(inverse @ (top+Vector((x,.035*(x/.037)**2,z-.001*(x/.030)**2))))
    for i in range(32):faces.append((i*2,i*2+1,i*2+3,i*2+2))
    data=bpy.data.meshes.new('Serene dental arch');data.from_pydata(verts,[],faces);data.update()
    teeth=bpy.data.objects.new('Upper dental arch',data);bpy.context.collection.objects.link(teeth);teeth.parent=parent
    data.materials.append(mesh.material('Serene natural ivory teeth',(.43,.37,.30),roughness=.6))
    from face_interiors import refine_dental_arch
    bpy.context.view_layer.update()
    refine_dental_arch(mesh, parent)

"""Layered, reference-directed hair with fitted roots and tapered loose strands.

All geometry is baked into one mesh. No physics, alpha sorting or extra runtime
animation is required; the whole groom follows the existing HeadPivot.
"""
import bpy
import bmesh
import math
import random
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
from avatar_mesh import bell, inside


def spline(points, steps):
    points = [Vector(p) for p in points]
    result = []
    for i in range(steps + 1):
        t = i / steps * (len(points) - 1)
        j = min(int(t), len(points) - 2)
        u = t - j
        a, b, c, d = points[max(0, j - 1)], points[j], points[j + 1], points[min(len(points) - 1, j + 2)]
        result.append(.5 * ((2*b) + (-a+c)*u + (2*a-5*b+4*c-d)*u*u + (-a+3*b-3*c+d)*u*u*u))
    return result


def build_hair(mesh, head, outline):
    # The crown roots lie against this woman's scalp, rather than floating
    # several centimetres in front of the forehead as a rigid cut-out.
    paths = [
        [(509,66),(481,53),(447,78),(426,119),(422,171),(403,214),(414,263),(395,310),(406,351)],
        [(501,77),(475,67),(451,91),(440,133),(427,179),(417,221),(431,264),(413,303),(423,342)],
        [(506,91),(482,89),(467,119),(467,156),(449,196),(456,230),(442,264),(451,299),(430,347)],
        [(488,60),(457,60),(430,93),(416,139),(407,180),(403,213),(413,246),(402,280),(398,326)],
        [(465,72),(444,102),(439,141),(424,181),(433,215),(421,252),(433,291),(417,323)],
        [(514,57),(544,52),(577,75),(594,108),(590,148),(610,187),(601,225),(618,267),(612,308)],
        [(518,73),(544,68),(563,91),(575,130),(569,161),(587,198),(578,237),(599,277),(589,317),(611,360),(602,401),(625,448),(634,496)],
        [(521,93),(541,99),(550,128),(549,157),(564,185),(558,218),(574,249),(568,283),(584,320),(577,349),(596,386),(590,415)],
        [(548,55),(576,72),(603,117),(603,153),(620,188),(614,228),(630,266),(621,304),(640,344),(634,380),(650,421),(637,460),(646,493)],
        [(564,83),(585,112),(581,149),(601,186),(588,224),(610,263),(599,303),(622,344),(610,378),(633,414),(623,450),(638,506)],
        [(588,175),(603,209),(591,244),(611,283),(601,319),(623,357),(615,389),(638,430),(628,471)],
        [(431,153),(416,192),(425,225),(410,263),(422,301),(409,343)],
    ]
    paths = [path for i,path in enumerate(paths) if i not in (2,7)]
    flow=[p for path in paths for p in spline(path,72)]
    flow_tree=KDTree(len(flow))
    for i,p in enumerate(flow):flow_tree.insert(Vector((p.x,p.y,0)),i)
    flow_tree.balance()
    def depth(x, y):
        # Continuous curvature is essential: sampling discrete skin triangles
        # here produces abrupt steps and dark creases along otherwise smooth locks.
        _,_,distance=flow_tree.find(Vector((x,y,0)))
        ridge=.0018*math.exp(-(distance/8)**2)
        return (.158 + .078 * bell(x,y,512,170,155,210)
                - .031 * bell(x,y,510,112,76,46) + ridge)

    # Smooth the hand-traced silhouette, and keep its opaque foundation inside
    # the warm hair colour. Separate wisps provide the irregular outer edge.
    pixels = np.array(mesh.image.pixels[:],dtype=np.float32).reshape(1024,1024,4)[::-1]
    warm = (pixels[:,:,0] >= pixels[:,:,1]) & (pixels[:,:,0] >= pixels[:,:,2]*1.03)
    neighbours = sum(np.roll(np.roll(warm,dy,axis=0),dx,axis=1).astype(np.uint8)
                     for dy in (-1,0,1) for dx in (-1,0,1))
    safe = warm & (neighbours >= 8)
    rows, columns = np.where(safe[35:535,365:685])
    tree=KDTree(len(rows))
    for i,(y,x) in enumerate(zip(rows,columns)):
        tree.insert(Vector((float(x+365),float(y+35),0)),i)
    tree.balance()
    contour=[]
    for a,b in zip(outline,outline[1:]+outline[:1]):
        a,b=Vector(a),Vector(b)
        for i in range(max(1,math.ceil((b-a).length/2))):
            p=a.lerp(b,i/max(1,math.ceil((b-a).length/2)))
            nearest,_,_=tree.find(Vector((p.x,p.y,0)))
            q=(nearest.x,nearest.y)
            if not contour or (Vector(q)-Vector(contour[-1])).length>1:
                contour.append(q)
    if (Vector(contour[0])-Vector(contour[-1])).length<1:
        contour.pop()
    previous_back = mesh.back
    mesh.back = mesh.paint
    foundation = mesh.shell('Hair', contour, depth, head, grid=11, back=.14)
    mesh.back = previous_back
    # Collapse the sidewall into a thin rounded edge instead of a visible shelf.
    for vertex in foundation.data.vertices:
        if abs(vertex.co.y + .14) < 1e-5:
            x = vertex.co.x * mesh.scale_x + 512
            y = mesh.origin_y - vertex.co.z * mesh.scale_z
            vertex.co.y = -min(.14, depth(x,y)-.004)
            vertex.co.x *= .98
    mesh.project(foundation)

    # Centre-part flow, unequal waves and lengths follow the reference. These
    # paths define real lock volume; the existing colour texture provides fibres.
    vertices, faces, uv_coords, material_ids = [], [], [], []

    def flyaway(path, width):
        samples = spline(path, 40)
        outside = [not inside(tuple(p),contour) for p in samples]
        # Ignore tiny isolated segments; let each longer wisp emerge from
        # a point within the foundation so it never floats beside the head.
        for i in range(len(outside)):
            if outside[i] and sum(outside[max(0,i-2):i+3])<3:
                outside[i]=False
        sides = 3
        start = len(vertices)
        for i, p in enumerate(samples):
            t = i / (len(samples)-1)
            tangent = samples[min(i+1,len(samples)-1)]-samples[max(i-1,0)]
            across = Vector((-tangent.y, tangent.x)).normalized()
            taper = max(.005, math.sin(math.pi*t) ** .55)
            half_width = width * taper
            for side in range(sides):
                angle = side / sides * math.tau
                q = p + across * half_width * math.cos(angle)
                thickness = width / 560
                d = depth(p.x, p.y) + (.001 if outside[i] else -.002) * taper + thickness * math.sin(angle) * taper
                vertices.append(mesh.point(q.x, q.y, d))
                # Sample the same fibre section around the back of each lock.
                uv_coords.append((q.x/1024, 1-q.y/1024))
            if i and (outside[i] or outside[i-1]):
                for side in range(sides):
                    a=start+(i-1)*sides+side;b=start+(i-1)*sides+(side+1)%sides
                    faces.append((a,b,b+sides,a+sides));material_ids.append(1)

    # Broad locks are blended into the foundation as continuous shallow ridges.
    # Separate raised tubes cast dark seams and resemble cables in closeups.
    # Airy, tapered flyaways are actual fine geometry with warm fibre material,
    # never the green background baked into a coarse outline.
    rng = random.Random(92417)
    for i in range(24):
        path = paths[i % len(paths)]
        outward = -1 if path[-1][0] < 512 else 1
        shift = rng.uniform(3, 8)*outward
        strand = [(x+shift+math.sin(j*1.8+i)*1.4, y+rng.uniform(-2,2)) for j,(x,y) in enumerate(path)]
        flyaway(strand, width=rng.uniform(.09,.16))

    data = bpy.data.meshes.new('Layered hair locks')
    data.from_pydata(vertices, [], faces)
    data.materials.append(mesh.paint)
    fibre = mesh.material('Champagne blonde fibres', (.65,.51,.36), roughness=.76)
    fibre.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value=.18
    data.materials.append(fibre)
    uv = data.uv_layers.new(name='PortraitProjection')
    for loop in data.loops:
        uv.data[loop.index].uv = uv_coords[loop.vertex_index]
    for polygon, material in zip(data.polygons, material_ids):
        polygon.use_smooth = True
        polygon.material_index = material
    bm=bmesh.new();bm.from_mesh(data)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data);bm.free()
    groom = bpy.data.objects.new('Hair locks', data)
    bpy.context.collection.objects.link(groom)
    groom.parent=head;groom.matrix_parent_inverse=head.matrix_world.inverted()
    # One mesh/one controller node, even though the hair contains many locks.
    bpy.ops.object.select_all(action='DESELECT')
    foundation.select_set(True);groom.select_set(True)
    bpy.context.view_layer.objects.active=foundation
    bpy.ops.object.join()
    foundation['groom_version']=2
    foundation['lock_count']=len(paths)
    foundation['flyaway_count']=24
    return foundation

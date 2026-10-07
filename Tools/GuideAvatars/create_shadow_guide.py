"""Build a seated Shadow Guide from the shared Zen anatomy, motion data and pivots."""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from avatar_mesh import PortraitMesh,bell,studio
SOURCE=ROOT/'Tools/GuideAvatars/ShadowGuide';OUT=ROOT/'Stilla/Resources'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Tools/ZenAvatar/ZenMinimalist.blend'))
head=bpy.data.objects['HeadPivot'];body=bpy.data.objects['BreathPivot'];root=bpy.data.objects['ZenMinimalist']
keep={root,body,head,*head.children_recursive}
for obj in list(bpy.data.objects):
    if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
root.name='ShadowGuide'
image=bpy.data.images.load(str(SOURCE/'portrait.png'));image.scale(1024,1024)
mesh=PortraitMesh(image)
bpy.context.view_layer.update()
face=bpy.data.objects['AnatomicalHead']
face.data.materials.clear();face.data.materials.append(mesh.paint);face.data.materials.append(mesh.back)
mesh.project(face)
# Face landmarks share the Zen coordinate contract; UV registration preserves
# the new identity without changing the eyelid atlas or anatomical speech data.
for loop in face.data.loops:
    v=face.data.vertices[loop.vertex_index].co
    if v.y<-.10:
        w=math.exp(-((abs(v.x)-.0545)/.034)**4-((v.z-.054)/.025)**4)
        face.data.uv_layers['PortraitProjection'].data[loop.index].uv.y+=.010*w

# Recess the oral cavity and dental corners behind this portrait's narrower
# lip opening. The old uncurved inset pierced the cheeks during speech.
cavity=bpy.data.objects['Mouth inset']
for vertex in cavity.data.vertices:
    vertex.co.y+=.038*(vertex.co.x/.043)**2
teeth=bpy.data.objects['Upper dental arch']
for vertex in teeth.data.vertices:
    vertex.co.y+=.025*(vertex.co.x/.031)**2
    vertex.co.x*=.88
for name in ['EyeLeftPivot','EyeRightPivot']:
    bpy.data.objects[name].location.y+=.003
from face_interiors import refine_dental_arch
bpy.context.view_layer.update()
refine_dental_arch(mesh, head)

outline=[(349,294),(305,329),(284,368),(265,429),(239,489),(214,526),(209,566),(199,606),(174,642),
(122,668),(100,695),(91,738),(74,793),(65,835),(31,864),(39,880),(56,883),(40,909),(73,925),
(162,910),(302,909),(409,913),(513,911),(615,917),(746,913),(867,914),(946,926),(984,909),
(967,889),(995,878),(965,850),(951,811),(936,751),(927,710),(900,684),(866,661),(827,641),
(817,591),(821,550),(812,519),(790,480),(771,432),(753,392),(735,351),(697,318),(665,294),
(602,326),(552,381),(512,433),(472,383),(418,327)]
def depth(x,y):
    return .06+.13*bell(x,y,512,477,176,190)+.19*bell(x,y,275,755,142,118)+.19*bell(x,y,748,755,142,118)+.12*bell(x,y,302,533,80,125)+.12*bell(x,y,723,533,80,125)+.008*math.sin(x*.12+y*.05)
mesh.shell('Robe',outline,depth,body,grid=12)
hood=[(350,306),(354,271),(364,229),(373,176),(383,129),(401,84),(432,49),(470,27),(504,20),
(543,26),(581,47),(609,75),(630,123),(648,178),(656,221),(666,268),(665,309),(646,345),
(610,374),(568,407),(523,443),(512,449),(483,413),(437,377),(397,350),(366,333)]
opening=[(458,122),(480,111),(509,106),(544,113),(570,130),(585,155),(586,196),(574,234),
(556,266),(522,285),(485,268),(457,242),(443,208),(438,164)]
mesh.shell('Hood',hood,lambda x,y:.16+.095*bell(x,y,512,215,155,225),head,grid=9,holes=[opening])
beard=[(469,223),(482,228),(494,236),(511,247),(530,240),(549,226),(564,225),(576,251),
(582,278),(578,313),(564,342),(547,361),(529,383),(513,396),(496,378),(477,365),(465,338),
(451,315),(444,280),(451,247)]
beard_object=mesh.shell('Beard',beard,lambda x,y:.235+.055*bell(x,y,512,293,60,115),head,grid=4,back=.13)
# Bury the mouth-side shell edge into the actual jaw and bind it to the same
# speech displacement. A thick rigid shell here exposed an angular dark flange
# when the lips moved, even though the head's speech animation was running.
from mathutils.bvhtree import BVHTree
tree=BVHTree.FromObject(face,bpy.context.evaluated_depsgraph_get())
top_edge=beard[:7]
motion=beard_object.data.color_attributes.new(name='displayColor',type='FLOAT_COLOR',domain='POINT')
beard_object.data.color_attributes.active_color=motion
for vertex,color in zip(beard_object.data.vertices,motion.data):
    p=vertex.co;x=p.x*560+512;y=997-p.z*580
    upper=top_edge[0][1] if x<top_edge[0][0] else top_edge[-1][1]
    for (ax,ay),(bx,by) in zip(top_edge,top_edge[1:]):
        if ax<=x<=bx:upper=ay+(by-ay)*(x-ax)/(bx-ax);break
    t=max(0,min(1,(y-upper)/45));t=t*t*(3-2*t)
    origin=face.matrix_world.inverted() @ Vector((p.x,-1,p.z))
    hit,normal,index,_=tree.ray_cast(origin,Vector((0,1,0)))
    delta=Vector((0,-.001,-.012))*bell(x,y,512,260,45,75)
    if hit is not None:
        depth=-(face.matrix_world @ hit).y
        attachment=depth+(.0008 if p.y<-.18 else -.0008)
        vertex.co.y=-(attachment+(-p.y-attachment)*t)
        indices=face.data.polygons[index].vertices
        weights=[1/max(1e-6,(face.data.vertices[i].co-hit).length_squared) for i in indices]
        skin=sum((Vector([(v-.5)*.08 for v in face.data.color_attributes['displayColor'].data[i].color[:3]])*w for i,w in zip(indices,weights)),Vector())/sum(weights)
        delta=skin*(1-t)+delta*t
    color.color=(*(0.5+d/.08 for d in delta),1)
# The shared anatomical mouth stays visible above the beard. Hands and sphere
# are independent of the chest's breathing deformation.
hands=[(391,635),(414,627),(439,636),(457,655),(478,674),(503,685),(521,686),(546,674),
(567,653),(584,636),(609,628),(632,637),(643,655),(632,679),(607,697),(576,711),
(542,718),(506,718),(475,713),(448,705),(416,692),(397,671)]
mesh.shell('Hands',hands,lambda x,y:.39+.04*bell(x,y,512,689,112,39),body,grid=7,back=.25)
feet=[(336,811),(391,795),(449,804),(493,823),(527,835),(570,811),(607,798),(655,807),
(687,833),(721,866),(728,895),(708,912),(675,908),(618,891),(556,876),(513,866),
(463,883),(409,900),(351,913),(306,910),(290,893),(299,868)]
mesh.shell('Lotus feet',feet,lambda x,y:.28+.065*bell(x,y,512,866,222,72),body,grid=9,back=.12)
cushion=[(90,900),(171,890),(277,913),(508,923),(716,916),(844,893),(932,902),(960,927),
(956,960),(932,983),(817,994),(215,994),(116,986),(78,968),(72,936)]
mesh.shell('Cushion',cushion,lambda x,y:.15+.18*bell(x,y,512,948,475,70),root,grid=11,back=-.26)
# An actual sphere with native PBR highlights, held between the cupped hands.
bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,location=mesh.point(512,629,.35))
orb=bpy.context.object;orb.name='CrystalOrb';orb.parent=body
for v in orb.data.vertices:v.co*=.110
orb.data.materials.append(mesh.material('Crystal • polished blue',(.12,.19,.36),texture=True,roughness=.20,metallic=.22))
bpy.context.view_layer.update();mesh.project(orb)
for poly in orb.data.polygons:poly.use_smooth=True
# USD projection texture is shared; no refraction pass, physics or dynamic lights.
# Carry the exact eyelid vectors on the vertices, as for Serene. Sampling a
# low-resolution atlas beside the nearly closed seam caused jagged open lids.
# Beard binding above deliberately reads the original full speech vectors.
eye_delta=face.data.uv_layers['EyelidDelta']
by_vertex={loop.vertex_index:eye_delta.data[loop.index].uv.copy() for loop in face.data.loops}
colors=face.data.color_attributes['displayColor']
for vertex,color in zip(face.data.vertices,colors.data):
    d=by_vertex.get(vertex.index,Vector((0,0)))
    color.color=(.5+d.y/.08,.5+d.x/.08,color.color[2],1)
face.data.color_attributes.active_color=colors
bpy.ops.object.select_all(action='DESELECT');triangles=0
for obj in bpy.data.objects:
    if obj.type in {'MESH','EMPTY'}:obj.select_set(True)
    if obj.type=='MESH':obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
bpy.ops.wm.usd_export(filepath=str(OUT/'ShadowGuide.usdz'),selected_objects_only=True,
 export_animation=False,export_materials=True,generate_preview_surface=True,
 export_subdivision='TESSELLATE',export_cameras=False,export_lights=False,convert_world_material=False,
 convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',root_prim_path='/GuideAvatar')
report={'triangles':triangles,'mesh_objects':len([o for o in bpy.data.objects if o.type=='MESH']),
 'texture_dimensions':list(image.size),'usdz_bytes':(OUT/'ShadowGuide.usdz').stat().st_size,
 'shared_anatomy':'Tools/ZenAvatar/ZenMinimalist.blend','eyelid_motion':'per-vertex, independent from jaw'}
(SOURCE/'asset-metrics.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
studio(SOURCE,root,image,'ShadowGuide')

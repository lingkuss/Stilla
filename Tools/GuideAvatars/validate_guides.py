"""Validate shared avatar anatomy, assets, physical props and mobile budgets."""
from pathlib import Path
import bpy
from pxr import Usd,UsdGeom,UsdUtils
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Tools/GuideAvatars/ShadowGuide/ShadowGuide.blend'))
for name in ['BreathPivot','HeadPivot','Robe','Hood','Beard','Hands','CrystalOrb','Lotus feet','Cushion','AnatomicalHead','EyeLeftPivot','EyeRightPivot']:
    assert name in bpy.data.objects,name
face=bpy.data.objects['AnatomicalHead']
assert face.parent.name=='HeadPivot'
assert 'EyelidDelta' in face.data.uv_layers
assert len(face.data.color_attributes['displayColor'].data)==len(face.data.vertices)
colors=face.data.color_attributes['displayColor']
assert max((color.color[0]-.5)*.08 for color in colors.data)>.006,'Shadow eyelids must open'
assert min((color.color[2]-.5)*.08 for color in colors.data)<-.008,'Shadow jaw must open'
assert 'displayColor' in bpy.data.objects['Beard'].data.color_attributes,'Beard must follow anatomical jaw'
assert bpy.data.objects['Hands'].parent.name=='BreathPivot'
assert bpy.data.objects['CrystalOrb'].parent.name=='BreathPivot'
assert bpy.data.objects['Cushion'].parent.name=='ShadowGuide'
assert bpy.data.objects['Hood'].parent.name=='HeadPivot'
orb=bpy.data.objects['CrystalOrb'];assert len(orb.data.vertices)>1000
for v in orb.data.vertices: assert abs(v.co.length-.110)<1e-5,'Sphere must have real depth'
# Separate physical surfaces rather than a circular portrait or flat billboard.
for name in ['Robe','Hood','Beard','Hands','Cushion']:
    obj=bpy.data.objects[name]
    assert max(v.co.y for v in obj.data.vertices)-min(v.co.y for v in obj.data.vertices)>.05,name
triangles=0
for obj in bpy.data.objects:
    if obj.type=='MESH':obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
assert triangles<70000,triangles
asset=ROOT/'Stilla/Resources/ShadowGuide.usdz';assert asset.stat().st_size<7_000_000
checker=UsdUtils.ComplianceChecker(arkit=True);checker.CheckCompliance(str(asset))
assert not checker.GetErrors(),checker.GetErrors()
assert not checker.GetFailedChecks(),checker.GetFailedChecks()
stage=Usd.Stage.Open(str(asset))
assert UsdGeom.GetStageUpAxis(stage)=='Y'
mesh=next(p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh) and 'AnatomicalHead' in str(p.GetPath()))
assert UsdGeom.Mesh(mesh).GetDisplayColorPrimvar().HasValue()
assert any('CrystalOrb' in str(p.GetPath()) for p in stage.Traverse())
# The legacy model and its imported coordinate/deformation contract stay intact.
with bpy.data.libraries.load(str(ROOT/'Tools/ZenAvatar/ZenMinimalist.blend'),link=False) as (src,dst):
    dst.meshes=[face.data.name]
original=dst.meshes[0]
assert original is not None and len(original.vertices)==len(face.data.vertices)
assert all((a.co-b.co).length<1e-6 for a,b in zip(original.vertices,face.data.vertices))
print(f'PASS: shared anatomical rig and speech data, volumetric robe, held spherical prop, Y-up USDZ compliance; {triangles} triangles.')

# This face is measured from her portrait, never an imported male head.
import bmesh, hashlib, json
from mathutils import Vector
from mathutils.kdtree import KDTree
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Tools/GuideAvatars/SereneGuide/SereneGuide.blend'))
for name in ['SereneGuide','BreathPivot','HeadPivot','Robe','Hair','HandLeft','HandRight','Cushion','Mala','AnatomicalHead']:
    assert name in bpy.data.objects,name
face=bpy.data.objects['AnatomicalHead']
assert face.parent.name=='HeadPivot'
assert face.data.name=='Serene reference anatomy'
for name in ['EyeLeftPivot','EyeRightPivot','Mouth inset','Upper dental arch']:
    assert name in bpy.data.objects,name
source=ROOT/'Tools/GuideAvatars/SereneGuide'
landmarks=json.loads((source/'face-landmarks.json').read_text())
assert landmarks['portrait_sha256']==hashlib.sha256((source/'portrait.png').read_bytes()).hexdigest()
# Nose, chin and lips must remain registered to the source after refinement.
points=KDTree(len(face.data.vertices))
for vertex in face.data.vertices: points.insert(face.matrix_world@vertex.co,vertex.index)
points.balance()
for index in [1,4,13,14,152]:
    x,y,z=landmarks['landmarks'][index]
    expected=Vector(((x*1024-512)/560,-.22+z*1024/560,(984-y*1024)/572))
    _,_,distance=points.find(expected)
    assert distance<.012,(index,distance)
bm=bmesh.new();bm.from_mesh(face.data)
assert all(edge.is_manifold or edge.is_boundary for edge in bm.edges),'No broken/intersecting topology'
boundary={v for e in bm.edges if e.is_boundary for v in e.verts}
apertures=[]
while boundary:
    group={boundary.pop()};todo=list(group)
    while todo:
        for edge in todo.pop().link_edges:
            if not edge.is_boundary:continue
            for v in edge.verts:
                if v in boundary:boundary.remove(v);group.add(v);todo.append(v)
    apertures.append(group)
assert len(apertures)==3,'Exactly two eyelid rims and one lip rim; skull must be closed'
bm.free()
colors=face.data.color_attributes['displayColor']
assert len(colors.data)==len(face.data.vertices)
assert all(0<=value<=1 for color in colors.data for value in color.color)
assert max(abs((value-.5)*.08) for color in colors.data for value in color.color[:3])<=.018
samples=json.loads((source/'motion-samples.json').read_text())
for sample in samples:
    eye_z,eye_y,jaw_z=[(v-.5)*.08 for v in sample['encoded']]
    if sample['name'].startswith('upperLid'):assert eye_z>.003 and abs(jaw_z)<1e-5,sample
    if sample['name'].startswith('lowerLid'):assert eye_z<-.0005 and abs(jaw_z)<1e-5,sample
    if sample['name']=='lowerLip':assert jaw_z<-.005 and abs(eye_z)<1e-5,sample
for side in ['Left','Right']:
    assert bpy.data.objects['Hand'+side].parent.name=='BreathPivot'
assert bpy.data.objects['Hair'].parent.name=='HeadPivot'
triangles=0
for obj in bpy.data.objects:
    if obj.type=='MESH':obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
assert triangles<70000,triangles
asset=ROOT/'Stilla/Resources/SereneGuide.usdz';assert asset.stat().st_size<7_000_000
checker=UsdUtils.ComplianceChecker(arkit=True);checker.CheckCompliance(str(asset))
assert not checker.GetErrors(),checker.GetErrors()
assert not checker.GetFailedChecks(),checker.GetFailedChecks()
stage=Usd.Stage.Open(str(asset));assert UsdGeom.GetStageUpAxis(stage)=='Y'
assert any('Hair' in str(p.GetPath()) for p in stage.Traverse())
print(f'PASS: portrait-registered female face, three anatomical apertures, independent eye/jaw motion, separate hair/hands, Y-up USDZ compliance; {triangles} triangles.')

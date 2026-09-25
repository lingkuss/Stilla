"""Validate generated mobile avatar geometry and USDZ contracts in Blender."""
from pathlib import Path
import bpy
from mathutils import Vector
from pxr import UsdUtils

root=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root/'Tools/ZenAvatar/ZenMinimalist.blend'))
for side in ['Left','Right']:
    eye=bpy.data.objects['Eyeball'+side]
    assert eye.parent.name=='Eye'+side+'Pivot'
    assert len(eye.data.materials)==4
    # Native RealityKit culls the back side, so inward spheres render as empty
    # sockets even when Blender's double-sided preview appears correct.
    outward=[p.center.dot(p.normal) for p in eye.data.polygons if p.area>1e-10]
    assert outward and min(outward)>0, 'Eyeball normals must point outwards'
    # Iris registration must stay on the original ellipsoid, inside the lids.
    for v in eye.data.vertices:
        radius=sum((v.co[i]/r)**2 for i,r in enumerate((.031,.027,.025)))
        assert abs(radius-1)<1e-5, 'Eye surface no longer fits the socket'
assert not any('aperture' in o.name.lower() for o in bpy.data.objects)
head=bpy.data.objects['AnatomicalHead']
assert 'JawPivot' not in bpy.data.objects
assert 'Lower lip and chin' not in bpy.data.objects
motion=head.data.color_attributes['displayColor']
displacements=[Vector(tuple((x-.5)*.08 for x in c.color[:3])) for c in motion.data]
assert len(displacements)==len(head.data.vertices)
assert all(0<=x<=1 for c in motion.data for x in c.color)
assert max(d.length for d in displacements)<.04
assert any(d.z<-.005 for d in displacements), 'Speech pose must actually open the jaw'
assert all(d.length<1e-6 for v,d in zip(head.data.vertices,displacements) if v.co.z>.035), 'Speech must leave the eyes and brow still'
# Lower lip, chin and both cheeks belong to one connected anatomical surface.
adjacency=[set() for _ in head.data.vertices]
for edge in head.data.edges:
    a,b=edge.vertices;adjacency[a].add(b);adjacency[b].add(a)
landmarks=[(0,-.214,-.073),(0,-.204,-.12),(-.065,-.185,-.08),(.065,-.185,-.08)]
ids=[min(range(len(head.data.vertices)),key=lambda i:(head.data.vertices[i].co-Vector(p)).length) for p in landmarks]
visited={ids[0]};pending=[ids[0]]
while pending:
    for neighbor in adjacency[pending.pop()]-visited:
        visited.add(neighbor);pending.append(neighbor)
assert set(ids)<=visited, 'Detached lip, cheek or chin geometry'
assert 'EyelidDelta' in head.data.uv_layers
assert max(abs(v.uv.y) for v in head.data.uv_layers['EyelidDelta'].data)>.01
assert list(bpy.data.images['Zen eyelid displacement'].size)==[256,128]
triangles=0
for o in bpy.data.objects:
    if o.type=='MESH':
        o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
assert triangles<70000
asset=root/'Stilla/Resources/ZenMinimalist.usdz'
assert asset.stat().st_size<6_000_000
checker=UsdUtils.ComplianceChecker(arkit=True);checker.CheckCompliance(str(asset))
assert not checker.GetErrors(), checker.GetErrors()
assert not checker.GetFailedChecks(), checker.GetFailedChecks()
from pxr import Usd, UsdGeom
stage=Usd.Stage.Open(str(asset))
face=next(p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh) and 'AnatomicalHead' in str(p.GetPath()))
colors=UsdGeom.Mesh(face).GetDisplayColorPrimvar()
assert colors.HasValue() and len(colors.Get())==len(head.data.vertices), 'Missing native vertex speech data'
print('PASS: fitted outward eyes, connected lips/cheeks/chin, bounded anatomical speech data, fixed upper face, eyelids, mobile budgets and USDZ compliance')

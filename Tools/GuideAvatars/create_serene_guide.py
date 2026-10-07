"""Seated female guide with a fitted face, wavy hair and the shared animation contract."""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from avatar_mesh import PortraitMesh,bell,studio
from reference_face import create_reference_face
from serene_hair import build_hair
SOURCE=ROOT/'Tools/GuideAvatars/SereneGuide';OUT=ROOT/'Stilla/Resources'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Tools/ZenAvatar/ZenMinimalist.blend'))
head=bpy.data.objects['HeadPivot'];body=bpy.data.objects['BreathPivot'];root=bpy.data.objects['ZenMinimalist']
keep={root,body,head}
for obj in list(bpy.data.objects):
    if obj not in keep:bpy.data.objects.remove(obj,do_unlink=True)
root.name='SereneGuide'
image=bpy.data.images.load(str(SOURCE/'portrait.png'));image.scale(1024,1024)
mesh=PortraitMesh(image,origin_y=984,scale_x=560,scale_z=572,background=lambda rgb: rgb[1]>rgb[0]*1.02 or rgb[2]>rgb[0]*1.02)
mesh.back=mesh.material('Ivory linen back',(.56,.43,.31))
# Her own measured facial surface replaces the unrelated Zen anatomy.
face=create_reference_face(mesh,head,SOURCE/'face-landmarks.json')
# Skin/linen torso and bent legs share the same low-cost breath modifier. Hands
# are separate, so the knee mudras remain still through an inhale.
outline=[(437,224),(441,275),(443,306),(443,327),(403,330),(349,337),(327,348),(311,369),(304,415),
(303,472),(297,516),(292,535),(283,556),(268,597),(244,630),(217,657),(191,682),
(188,717),(151,736),(124,764),(107,811),(99,858),(109,881),(86,899),(130,914),
(275,918),(424,914),(512,915),(672,920),(860,917),(931,902),(931,873),(924,822),
(919,784),(900,754),(880,735),(836,719),(813,684),(794,655),(769,626),(747,596),
(732,552),(717,526),(715,478),(710,423),(704,378),(686,355),(654,337),(613,329),
(581,315),(581,275),(585,224),(529,224),(508,224),(490,224)]
holes=[[(380,516),(378,559),(384,590),(393,617),(402,643),(402,603),(397,556)],
       [(625,537),(622,578),(620,609),(623,643),(633,617),(635,584),(632,553)]]
def depth(x,y):
    chest=.145*bell(x,y,512,453,128,175)
    arms=.095*bell(x,y,321,472,76,134)+.095*bell(x,y,703,472,76,134)
    knees=.20*bell(x,y,264,812,149,103)+.20*bell(x,y,762,812,149,103)
    folds=.006*math.sin(x*.15+y*.045)*bell(x,y,512,621,295,200)
    feet=.19*bell(x,y,512,778,205,54)
    neck=.11*bell(x,y,510,287,54,58)
    return .065+chest+arms+knees+folds+feet+neck
mesh.shell('Robe',outline,depth,body,grid=8,back=-.13,holes=holes)
# Hair is a closed crown with a face opening, plus two tapered wavy locks.
hair=[(449,49),(478,44),(509,43),(546,44),(578,58),(599,81),(613,112),(619,143),
(625,163),(622,188),(628,206),(633,240),(625,268),(635,293),(641,319),(644,349),
(659,380),(665,408),(655,431),(666,463),(658,490),(650,514),(631,524),(613,501),
(600,467),(580,432),(567,399),(553,364),(557,321),(563,293),(567,267),(559,252),
(544,263),(518,273),(492,263),(477,253),(458,265),(455,295),(451,327),(430,349),
(407,364),(381,348),(382,324),(388,296),(388,269),(395,240),(391,209),(397,185),
(397,151),(405,125),(411,95),(428,68)]
# An open U-shaped hairline leaves the face and neck entirely to the anatomy,
# avoiding a second painted chin on the hair shell.
hair=hair[:hair.index((563,293))+1]+[(567,267),(565,208),(566,173),(560,141),
(550,114),(533,102),(511,99),(490,103),(471,112),(461,139),(452,173),(452,208),
(452,265),(450,295),(444,327),(430,349),(407,364),(381,348),(382,324),(388,296),
(388,269),(395,240),(391,209),(397,185),(397,151),(405,125),(411,95),(428,68)]
hair_object=build_hair(mesh,head,hair)
# Connected individual fingers are traced into each closed hand, including the
# thumb/index opening. Bare wrists taper into the draped sleeves.
left=[(220,655),(209,670),(189,685),(177,691),(162,680),(146,677),
(138,671),(127,662),(121,662),(118,668),(118,674),(115,687),(113,700),
(112,709),(110,708),(109,697),(109,685),(106,682),(101,682),(98,685),
(96,699),(94,697),(90,693),(86,693),(84,695),(84,711),(87,722),
(89,731),(96,735),(104,740),(112,744),(122,747),(139,738),(178,724),
(213,708),(241,689)]
right=[(795,657),(808,673),(816,680),(841,692),(846,690),(858,682),
(870,679),(879,675),(884,673),(895,665),(901,664),(905,668),(905,675),
(907,685),(909,690),(910,709),(912,708),(912,700),(911,697),(911,685),
(915,681),(919,680),(922,682),(924,692),(926,703),(928,699),(931,694),
(934,692),(938,692),(940,694),(940,709),(937,717),(934,731),(927,736),
(919,740),(911,743),(903,747),(886,738),(846,725),(810,708),(785,689)]
for name,contour in [('HandLeft',left),('HandRight',right)]:
    mesh.shell(name,contour,lambda x,y:.22+.025*bell(x,y,512,711,455,50),body,grid=3,back=.18)
# Crossed feet belong to the same continuous surface as the legs: no floating
# cut-out, dark undercut or doubled linen edge at the ankles.
cushion=[(104,890),(227,913),(491,918),(751,913),(921,890),(956,909),(984,938),(978,960),
(947,976),(836,980),(191,980),(67,972),(39,959),(31,938),(54,914)]
mesh.shell('Cushion',cushion,lambda x,y:.12+.22*bell(x,y,512,946,475,70),root,grid=12,back=-.26)
# Low-poly mala beads add shallow depth but follow the existing reference chain.
bead_material=mesh.material('Mala wood',(.15,.075,.028),roughness=.48)
beads=[]
for i in range(32):
    t=i/31
    if t<.5: x=448+(508-448)*t*2;y=310+(527-310)*t*2
    else: x=508+(579-508)*(t-.5)*2;y=527+(321-527)*(t-.5)*2
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,location=mesh.point(x,y,depth(x,y)+.01))
    obj=bpy.context.object;obj.parent=body;obj.name='MalaBead'
    for v in obj.data.vertices:v.co*=.0045
    obj.data.materials.append(bead_material);beads.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in beads:obj.select_set(True)
bpy.context.view_layer.objects.active=beads[0];bpy.ops.object.join();bpy.context.object.name='Mala'
bpy.ops.object.select_all(action='DESELECT');triangles=0
for obj in bpy.data.objects:
    if obj.type in {'MESH','EMPTY'}:obj.select_set(True)
    if obj.type=='MESH':obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
bpy.ops.wm.usd_export(filepath=str(OUT/'SereneGuide.usdz'),selected_objects_only=True,
 export_animation=False,export_materials=True,generate_preview_surface=True,
 export_subdivision='TESSELLATE',export_cameras=False,export_lights=False,convert_world_material=False,
 convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',root_prim_path='/GuideAvatar')
report={'triangles':triangles,'mesh_objects':len([o for o in bpy.data.objects if o.type=='MESH']),
 'texture_dimensions':list(image.size),'usdz_bytes':(OUT/'SereneGuide.usdz').stat().st_size,
 'anatomy':'portrait-measured facial surface; closed resting eyelids',
 'face_fit':'468 portrait landmarks; independent geometry and speech displacement',
 'hair':'flow-shaped crown, colour-traced silhouette, tapered edge wisps; groom v2'}
(SOURCE/'asset-metrics.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
studio(SOURCE,root,image,'SereneGuide')

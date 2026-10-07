"""Reference-textured, seated Zen Minimalist, built with free Blender.

The face uses CC0 MakeHuman anatomy; the robe silhouette, proportions and
projected 1K color texture come from Vindla's existing illustration. Designed
for the app's frontal camera and small natural movements, not arbitrary orbit.
No inference, online generator or runtime service is involved.
"""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector, Euler
from mathutils.geometry import delaunay_2d_cdt

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'Tools/ZenAvatar'
OUT=ROOT/'Stilla/Resources'
REFERENCE=ROOT/'Stilla/Assets.xcassets/kai_zen_minimalist.imageset/image.png'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
    o.location=loc;o.parent=parent;return o
root=empty('ZenMinimalist')
body=empty('BreathPivot',parent=root)
head=empty('HeadPivot',(0,0,1.37),body)

image=bpy.data.images.load(str(REFERENCE),check_existing=True)
def material(name,color,texture=False,roughness=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=roughness
    p.inputs['Specular IOR Level'].default_value=.22
    if texture:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=image;t.interpolation='Linear'
        m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
    return m
paint=material('Original portrait • 1024px color',(.6,.6,.6),True)
skin=material('Skin • side and back',(.40,.30,.22),False,.63)
cloth=material('Linen • side and back',(.135,.16,.175))
dark=material('Mouth interior',(.012,.007,.006))
beads=material('Walnut prayer beads',(.07,.045,.03),False,.4)

# The reference is registered in a shared frontal plane. Texture detail carries
# folds and wrinkles; geometry carries anatomy and depth at a low polygon cost.
def world(px,py,depth): return ((px-512)/500,-depth,(955-py)/500)
def uv_for(v): return ((v.x*500+512)/1024,1-(955-v.z*500)/1024)
def project_uv(o):
    for previous in list(o.data.uv_layers): o.data.uv_layers.remove(previous)
    uv=o.data.uv_layers.new(name='PortraitProjection')
    uv.active_render=True
    for p in o.data.polygons:
        for li in p.loop_indices:
            uv.data[li].uv=uv_for(o.matrix_world @ o.data.vertices[o.data.loops[li].vertex_index].co)
    o.data.uv_layers.active=uv

def inside(p,poly):
    x,y=p;yes=False;j=len(poly)-1
    for i,(xi,yi) in enumerate(poly):
        xj,yj=poly[j]
        if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi:yes=not yes
        j=i
    return yes

def shell(name,outline,depth_func,parent=body,grid=11,back_depth=-.12):
    """Closed volumetric shell, triangulated with the hand-traced silhouette."""
    points=[Vector(p) for p in outline]
    count=len(points)
    for y in range(int(min(p[1] for p in outline))+grid,int(max(p[1] for p in outline)),grid):
        for x in range(int(min(p[0] for p in outline))+grid,int(max(p[0] for p in outline)),grid):
            if inside((x,y),outline):points.append(Vector((x,y)))
    vs,edges,faces,*_=delaunay_2d_cdt(points,[(i,(i+1)%count) for i in range(count)],[list(range(count))],1,.0001)
    # CDT output may reorder vertices, so derive the silhouette boundary from faces.
    frontfaces=[list(f) for f in faces if inside(tuple(sum((vs[i] for i in f),Vector((0,0)))/len(f)),outline)]
    verts=[world(p.x,p.y,depth_func(p.x,p.y)) for p in vs]
    n=len(verts)
    verts += [world(p.x,p.y,back_depth) for p in vs]
    boundary={}
    for f in frontfaces:
        for a,b in zip(f,f[1:]+f[:1]):
            key=tuple(sorted((a,b)));boundary[key]=boundary.get(key,0)+1
    allfaces=frontfaces+[[i+n for i in reversed(f)] for f in frontfaces]
    allfaces += [[a,b,b+n,a+n] for (a,b),num in boundary.items() if num==1]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],allfaces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    o.data.materials.append(paint);o.data.materials.append(cloth)
    for i,p in enumerate(mesh.polygons):p.material_index=0 if i<len(frontfaces) else 1;p.use_smooth=True
    # Recalculate outward normals on this closed mesh.
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    project_uv(o);o.parent=parent
    return o

def g(x,y,cx,cy,wx,wy): return math.exp(-((x-cx)/wx)**2-((y-cy)/wy)**2)

def robe_depth(x,y):
    # Chest, relaxed arms and bent knees form one continuous robe, with shallow
    # folds following the garment instead of tubes placed on top of it.
    d=.09+.11*g(x,y,512,530,150,210)
    d+=.15*g(x,y,329,773,105,83)+.15*g(x,y,709,779,109,84)
    d+=.13*g(x,y,339,613,57,112)+.12*g(x,y,694,612,55,110)
    d+=.085*g(x,y,514,705,160,51)
    # Folds are kept subtle because the reference already contains soft shading.
    d+=.007*math.sin(x*.14+y*.029)*g(x,y,512,619,300,260)
    d+=.009*math.sin((x-512)*.10+y*.07)*g(x,y,510,821,190,75)
    return d

robe_outline=[(456,323),(426,352),(351,381),(318,419),(299,465),(285,516),(265,575),
 (253,629),(241,672),(211,705),(197,749),(181,792),(160,817),(130,828),(103,847),
 (54,869),(86,876),(137,879),(176,850),(192,869),(256,878),(368,883),(371,897),
 (471,889),(563,887),(661,895),(651,879),(770,875),(812,858),(853,881),
 (977,878),(941,862),(901,842),(856,828),(842,783),(818,739),(791,700),(772,661),
 (755,618),(746,571),(728,534),(718,484),(687,424),(667,395),(628,372),(589,352),(562,323)]
shell('Layered linen robe',robe_outline,robe_depth,grid=9)
# The hands have a separate shallow anatomical surface; the original finger
# creases, skin and nails stay crisp at this small, phone-sized presentation.
hand_outline=[(391,692),(414,682),(443,683),(474,680),(498,687),(513,687),(534,683),
 (568,681),(593,688),(614,700),(610,725),(592,738),(565,748),(537,755),(511,755),
 (489,748),(468,743),(449,736),(431,732),(411,720),(400,709)]
shell('Resting hands',hand_outline,lambda x,y:robe_depth(x,y)+.016+.025*g(x,y,508,709,110,35),grid=5,back_depth=.19)
# Rectangular linen cushion rather than the first prototype's round pad.
cushion_outline=[(185,875),(206,864),(360,878),(493,891),(650,879),(790,866),(833,874),
 (856,889),(880,917),(875,933),(850,945),(784,951),(252,950),(185,942),(165,929),(153,915),(164,895)]
shell('Linen cushion',cushion_outline,lambda x,y:.13+.24*g(x,y,516,915,358,56),root,grid=11,back_depth=-.21)

# Matched closed/open anatomical eyelids. The skin itself moves, including its
# portrait UVs; eyes are actual spheres behind the lids, never overlaid decals.
def anatomical_head(name):
    with bpy.data.libraries.load(str(SOURCE/('Source/'+name+'.blend')),link=False) as (src,dst):
        dst.objects=[name]
    mesh=dst.objects[0];bpy.context.collection.objects.link(mesh)
    for v in mesh.data.vertices:
        v.co=Vector((v.co.x*1.92,v.co.y*1.65,(v.co.z-1.60726273)*2.0+1.65))
    bm=bmesh.new();bm.from_mesh(mesh.data)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<1.11 or (v.co.z<1.22 and abs(v.co.x)>.115)],context='VERTS')
    bm.to_mesh(mesh.data);bm.free()
    bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True)
    bpy.context.view_layer.objects.active=mesh
    sub=mesh.modifiers.new('Anatomical surface','SUBSURF');sub.levels=1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    return mesh

o=anatomical_head('ZenHeadAnatomy');o.name='AnatomicalHead'
opened=anatomical_head('ZenHeadOpenAnatomy')
assert len(o.data.vertices)==len(opened.data.vertices)
deltas=[(b.co-a.co)*.90 for a,b in zip(o.data.vertices,opened.data.vertices)]
bpy.data.objects.remove(opened,do_unlink=True)
speaking=anatomical_head('ZenHeadSpeechAnatomy')
assert len(o.data.vertices)==len(speaking.data.vertices)
speech_deltas=[]
for a,b in zip(o.data.vertices,speaking.data.vertices):
    # Expression data includes tiny nose/temple motions. Fade those out below
    # the eyes so speech never changes the approved eyelid animation.
    t=max(0,min(1,(a.co.z-1.37)/.035))
    speech_deltas.append((b.co-a.co)*(1-t*t*(3-2*t)))
bpy.data.objects.remove(speaking,do_unlink=True)
# Align the actual lip contact seam with the portrait before projecting color.
# The same continuous warp carries the surrounding chin and cheeks with it.
for v in o.data.vertices:
    if v.co.y<-.10:
        v.co.z+=.021*math.exp(-(v.co.x/.072)**4-((v.co.z-1.278)/.048)**4)
o.data.materials.clear();o.data.materials.append(paint);o.data.materials.append(skin)
for p in o.data.polygons:
    p.material_index=0 if p.center.y<.025 else 1;p.use_smooth=True
project_uv(o)
# Register the painted closed-lid crease to the anatomical lid seam (the source
# portrait and the CC0 skull differ by a few pixels around the eyes).
for loop in o.data.loops:
    v=o.data.vertices[loop.vertex_index].co
    if v.y<-.10:
        w=math.exp(-((abs(v.x)-.0545)/.034)**4-((v.z-1.424)/.027)**4)
        o.data.uv_layers[0].data[loop.index].uv.y+=.007*w
# UV1 retains the Y/Z eyelid displacement for the editable source and validation.
# Runtime uses the compact data atlas below. X changes less than 0.6 mm and is
# deliberately omitted. No vertex colors tint the portrait or backup material.
uv=o.data.uv_layers.new(name='EyelidDelta')
for loop in o.data.loops:
    d=deltas[loop.vertex_index]
    uv.data[loop.index].uv=(d.y,d.z)
o.data.uv_layers.active_index=0
o.data.uv_layers[0].active_render=True
# An anatomical speech pose on the complete head, including lips, cheeks and
# jaw. RGB carries signed displacement, not skin color. The geometry shader
# consumes it then restores white vertex color before material shading.
# USD/RealityKit only maps the standard displayColor primvar to geometry.color.
# A custom name exports successfully but is silently ignored by the importer.
motion=o.data.color_attributes.new(name='displayColor',type='FLOAT_COLOR',domain='POINT')
for color,delta in zip(motion.data,speech_deltas):
    color.color=(*(0.5+d/.08 for d in delta),1)
o.data.color_attributes.active_color=motion
o.parent=head
for v in o.data.vertices:v.co.z-=1.37
o.select_set(False)
landmarks=[('lowerLip',(0,-.214,-.074)),('chin',(0,-.204,-.12)),
           ('cheek',(.065,-.185,-.08)),('forehead',(0,-.15,.15)),
           ('eyelid',(.054,-.21,.055))]
samples=[]
for name,point in landmarks:
    index=min(range(len(o.data.vertices)),key=lambda i:(o.data.vertices[i].co-Vector(point)).length)
    samples.append({'name':name,'position':list(o.data.vertices[index].co),'encoded':list(motion.data[index].color[:3])})
(SOURCE/'speech-samples.json').write_text(json.dumps(samples,indent=2)+'\n')

# Compact numerical displacement atlas (not artwork). Sampling in local X/Z
# bypasses USD importers that retain UV1 on the CPU but omit it from GPU inputs.
# Only the eye region is stored: 256 x 128 linear RG displacement data.
import numpy as np
width,height=256,128
pixels=np.full((height,width,4),.5,dtype=np.float32);pixels[:,:,2]=0;pixels[:,:,3]=1
front=np.full((height,width),np.inf)
o.data.calc_loop_triangles()
for tri in o.data.loop_triangles:
    ids=list(tri.vertices)
    if not any(deltas[i].length>1e-7 for i in ids):continue
    ps=[o.data.vertices[i].co for i in ids]
    if any(v.y>-.1 for v in ps):continue
    xy=[((v.x+.105)/.21*width,(v.z-.01)/.12*height) for v in ps]
    minx=max(0,int(math.floor(min(v[0] for v in xy))));maxx=min(width-1,int(math.ceil(max(v[0] for v in xy))))
    miny=max(0,int(math.floor(min(v[1] for v in xy))));maxy=min(height-1,int(math.ceil(max(v[1] for v in xy))))
    (ax,ay),(bx,by),(cx,cy)=xy
    denominator=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
    if abs(denominator)<1e-10:continue
    for y in range(miny,maxy+1):
        for x in range(minx,maxx+1):
            px,py=x+.5,y+.5
            wa=((by-cy)*(px-cx)+(cx-bx)*(py-cy))/denominator
            wb=((cy-ay)*(px-cx)+(ax-cx)*(py-cy))/denominator
            wc=1-wa-wb
            if min(wa,wb,wc)<-1e-5:continue
            depth=wa*ps[0].y+wb*ps[1].y+wc*ps[2].y
            if depth>=front[y,x]:continue
            front[y,x]=depth
            d=deltas[ids[0]]*wa+deltas[ids[1]]*wb+deltas[ids[2]]*wc
            pixels[y,x,:2]=(.5+d.y/.05,.5+d.z/.05)
atlas=bpy.data.images.new('Zen eyelid displacement',width=width,height=height,float_buffer=True)
atlas.use_fake_user=True
atlas.colorspace_settings.name='Non-Color';atlas.pixels.foreach_set(pixels.ravel())
atlas.filepath_raw=str(OUT/'ZenEyelids.png');atlas.file_format='PNG'
bpy.context.scene.render.image_settings.color_depth='16'
atlas.save();atlas.pack()

sclera=material('Eye sclera',(.28,.245,.205),False,.48)
iris=material('Brown iris',(.052,.030,.016),False,.4)
pupil=material('Pupil',(.004,.003,.002),False,.28)
limbus=material('Iris outer ring',(.020,.014,.010),False,.5)
# Real curved eye surfaces with radial iris geometry: round pupils remain round
# as the upper and lower anatomical lids occlude them during a blink.
for label,cx in [('Left',-.0545),('Right',.0545)]:
    # Register the iris within the lid opening while preserving the globe that
    # fits behind the lids. Moving the whole sphere can poke through the skin.
    pivot=empty('Eye'+label+'Pivot',(cx,-.184,1.422-1.37),head)
    iris_alignment=Euler((-.075,0,math.copysign(.12,cx))).to_matrix()
    verts=[];faces=[];slots=[]
    segments,rings=64,28
    # Polar axis points towards the camera (-Y). Ring boundaries explicitly
    # match pupil and iris radii, avoiding blocky per-face color thresholds.
    angles=[0,.06,.12,.17,.21,.25,.29,.33,.37,.41,.45,.49,.53,.58,.65,.75,.90,1.1,1.35,1.57,1.9,2.2,2.5,2.8,math.pi]
    for angle in angles:
        for j in range(segments):
            phi=j/segments*math.tau
            direction=iris_alignment @ Vector((math.sin(angle)*math.cos(phi),-math.cos(angle),math.sin(angle)*math.sin(phi)))
            verts.append((.031*direction.x,.027*direction.y,.025*direction.z))
    for i in range(len(angles)-1):
        for j in range(segments):
            # Outward winding is essential: RealityKit culls inward-facing eye
            # surfaces, unlike Blender's default double-sided preview materials.
            faces.append(((i+1)*segments+j,(i+1)*segments+(j+1)%segments,i*segments+(j+1)%segments,i*segments+j))
            theta=(angles[i]+angles[i+1])/2
            slots.append(2 if theta<.17 else 1 if theta<.41 else 3 if theta<.45 else 0)
    mesh=bpy.data.meshes.new('Eyeball '+label);mesh.from_pydata(verts,[],faces);mesh.update()
    eye=bpy.data.objects.new('Eyeball'+label,mesh);bpy.context.collection.objects.link(eye);eye.parent=pivot
    for mat in [sclera,iris,pupil,limbus]:mesh.materials.append(mat)
    for f,slot in zip(mesh.polygons,slots):f.material_index=slot;f.use_smooth=True

# Keep every lip, cheek and chin face connected. Only the natural opening
# between the upper and lower lips reveals this recessed oral cavity.
bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=(0,0,0))
mouth=bpy.context.object;mouth.name='Mouth inset';mouth.parent=head
mouth.location=(0,-.192,-.083)
for v in mouth.data.vertices:v.co.x*=.043;v.co.y*=.01;v.co.z*=.035
mouth.data.materials.append(dark)
# A recessed, curved upper dental edge appears only as the lips part. Keeping
# it behind the lip surface gives the opening depth without a bright flat bar.
tooth=material('Upper teeth ivory',(.38,.33,.26),False,.62)
verts=[];faces=[]
for i in range(33):
    x=(i/32*2-1)*.031
    y=-.209+.015*(x/.031)**2
    scallop=.0004*math.cos(i/32*math.pi*12)
    verts.extend([(x,y,-.072),(x,y,-.077+scallop)])
for i in range(32):faces.append((i*2,i*2+1,i*2+3,i*2+2))
mesh=bpy.data.meshes.new('Recessed upper dental arch');mesh.from_pydata(verts,[],faces);mesh.update()
teeth=bpy.data.objects.new('Upper dental arch',mesh);bpy.context.collection.objects.link(teeth);teeth.parent=head
mesh.materials.append(tooth)
for f in mesh.polygons:f.use_smooth=True

# The portrait's beads retain physical highlights and depth near the wrist.
for i in range(12):
    a=math.tau*i/12
    px=615+12*math.cos(a);py=704+29*math.sin(a)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=(0,0,0))
    b=bpy.context.object;b.name='Prayer bead';b.parent=body;b.location=world(px,py,robe_depth(px,py)+.026)
    for v in b.data.vertices:v.co*=.0075
    b.data.materials.append(beads)
    for f in b.data.polygons:f.use_smooth=True

# Batch geometry within each animated pivot/material to limit draw submissions.
groups={}
for ob in list(bpy.data.objects):
    if ob.type=='MESH' and ob.name not in {'AnatomicalHead','Layered linen robe'}:groups.setdefault((ob.parent.name,tuple(m.name for m in ob.data.materials)),[]).append(ob)
for (parent,mats),objects in groups.items():
    if len(objects)<2:continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    bpy.context.object.name=parent+'_'+mats[0].split(' ')[0]

bpy.ops.object.select_all(action='DESELECT')
triangles=0
for o in list(bpy.data.objects):
    if o.type in {'MESH','EMPTY'}:o.select_set(True)
    if o.type=='MESH':o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.usd_export(filepath=str(OUT/'ZenMinimalist.usdz'),selected_objects_only=True,
    export_animation=False,export_materials=True,generate_preview_surface=True,
    export_subdivision='TESSELLATE',export_cameras=False,export_lights=False,
    convert_world_material=False,convert_orientation=True,
    export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',root_prim_path='/ZenAvatar')

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.22,.22,.22);scene.render.film_transparent=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
def area(name,loc,power,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=size
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc
    o.rotation_euler=(Vector((0,0,.85))-o.location).to_track_quat('-Z','Y').to_euler()
area('Broad studio key',(-2,-4,4),260,5);area('Soft frontal fill',(2,-3,2),130,4)
d=bpy.data.cameras.new('Front camera');cam=bpy.data.objects.new('Front camera',d);bpy.context.collection.objects.link(cam)
cam.location=(0,-8,.84);cam.rotation_euler=(Vector((0,0,.84))-cam.location).to_track_quat('-Z','Y').to_euler()
d.type='ORTHO';d.ortho_scale=2.05;scene.camera=cam
bpy.context.preferences.filepaths.save_version=0
image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'ZenMinimalist.blend'))
scene.render.filepath=str(SOURCE/'ZenMinimalist-preview.png');bpy.ops.render.render(write_still=True)
# An open-eye preview of exactly the displacement used in the GPU shader.
face=bpy.data.objects.get('AnatomicalHead')
seen=set()
for loop in face.data.loops:
    if loop.vertex_index in seen:continue
    seen.add(loop.vertex_index)
    d=face.data.uv_layers['EyelidDelta'].data[loop.index].uv
    face.data.vertices[loop.vertex_index].co+=Vector((0,d.x,d.y))
scene.render.filepath=str(SOURCE/'ZenMinimalist-open-eyes.png');bpy.ops.render.render(write_still=True)
for v,delta in zip(face.data.vertices,speech_deltas):v.co+=delta*.65
scene.render.filepath=str(SOURCE/'ZenMinimalist-speaking.png');bpy.ops.render.render(write_still=True)
report={'triangles':triangles,'mesh_objects':len([o for o in bpy.data.objects if o.type=='MESH']),
        'texture_dimensions':list(image.size),'motion_texture_dimensions':[width,height],
        'motion_texture_bytes':(OUT/'ZenEyelids.png').stat().st_size,'usdz_bytes':(OUT/'ZenMinimalist.usdz').stat().st_size}
(SOURCE/'asset-metrics.json').write_text(json.dumps(report,indent=2)+'\n');print(report)

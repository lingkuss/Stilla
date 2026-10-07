"""Shared frontal-avatar mesh primitives. Coordinates use a 1024px reference plane.
Geometry has closed backs, physical depth and shared HeadPivot/BreathPivot anchors.
"""
import bpy, bmesh, math
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

class PortraitMesh:
    def __init__(self,image,origin_y=997,scale_x=560,scale_z=580,background=None):
        self.background=background
        self.image=image; self.origin_y=origin_y; self.scale_x=scale_x; self.scale_z=scale_z
        self.paint=self.material('Portrait fabric and skin',(1,1,1),texture=True)
        self.back=self.material('Indigo cloth back',(.028,.039,.062))
    def point(self,x,y,depth): return ((x-512)/self.scale_x,-depth,(self.origin_y-y)/self.scale_z)
    def material(self,name,color,texture=False,roughness=.78,metallic=0):
        m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
        p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
        p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=metallic
        if texture:
            t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=self.image
            m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
        return m
    def project(self,o):
        # Preserve UV1 and motion colors on the shared anatomical head.
        uv=o.data.uv_layers.get('PortraitProjection') or o.data.uv_layers.new(name='PortraitProjection')
        uv.active_render=True;o.data.uv_layers.active=uv
        for loop in o.data.loops:
            v=o.matrix_world @ o.data.vertices[loop.vertex_index].co
            uv.data[loop.index].uv=((v.x*self.scale_x+512)/1024,1-(self.origin_y-v.z*self.scale_z)/1024)
    def shell(self,name,outline,depth,parent,grid=10,back=-.14,holes=()):
        # Pull traced outer vertices just inside the painted silhouette. This
        # changes geometry/UV coverage, not the source image, avoiding grey fringes.
        def inset(point):
            x,y=point
            for _ in range(40):
                px=min(1023,max(0,round(x)));py=min(1023,max(0,1023-round(y)))
                start=(py*1024+px)*4
                rgb=self.image.pixels[start:start+3]
                if not (self.background(rgb) if self.background else max(rgb)>=.30 and max(rgb)-min(rgb)<=.075):break
                x+=(512-x)*.012
            return (x,y)
        outline=[inset(p) for p in outline]
        points=[];edges=[]
        for contour in [outline,*holes]:
            start=len(points);points.extend(Vector(p) for p in contour)
            edges.extend((start+i,start+(i+1)%len(contour)) for i in range(len(contour)))
        valid=lambda p: inside(p,outline) and not any(inside(p,h) for h in holes)
        for y in range(int(min(p[1] for p in outline))+grid,int(max(p[1] for p in outline)),grid):
            for x in range(int(min(p[0] for p in outline))+grid,int(max(p[0] for p in outline)),grid):
                if valid((x,y)): points.append(Vector((x,y)))
        vs,_,faces,*_=delaunay_2d_cdt(points,edges,[],0,.0001)
        front=[list(f) for f in faces if valid(tuple(sum((vs[i] for i in f),Vector((0,0)))/len(f)))]
        vertices=[self.point(p.x,p.y,depth(p.x,p.y)) for p in vs];n=len(vertices)
        vertices += [self.point(p.x,p.y,back) for p in vs]
        boundary={}
        for f in front:
            for a,b in zip(f,f[1:]+f[:1]):
                k=tuple(sorted((a,b)));boundary[k]=boundary.get(k,0)+1
        faces=front+[[i+n for i in reversed(f)] for f in front]
        faces += [[a,b,b+n,a+n] for (a,b),count in boundary.items() if count==1]
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        mesh.materials.append(self.paint);mesh.materials.append(self.back)
        for i,p in enumerate(mesh.polygons):p.material_index=0 if i<len(front) else 1;p.use_smooth=True
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        self.project(obj)
        # Mesh vertices above are world coordinates; keep them fixed when parenting.
        obj.parent=parent;obj.matrix_parent_inverse=parent.matrix_world.inverted()
        return obj

def inside(p,poly):
    x,y=p;yes=False;j=len(poly)-1
    for i,(xi,yi) in enumerate(poly):
        xj,yj=poly[j]
        if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi:yes=not yes
        j=i
    return yes

def bell(x,y,cx,cy,wx,wy): return math.exp(-((x-cx)/wx)**2-((y-cy)/wy)**2)

def studio(source,root,texture,asset_name):
    from pathlib import Path
    output=Path(source);output.mkdir(parents=True,exist_ok=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.world.color=(.22,.22,.22);scene.render.film_transparent=True
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    for name,loc,power in [('Key',(-2,-4,4),260),('Fill',(2,-3,2),130)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=5
        o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc
        o.rotation_euler=(Vector((0,0,.84))-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('Front camera');cam=bpy.data.objects.new('Front camera',d);bpy.context.collection.objects.link(cam)
    cam.location=(0,-8,.84);cam.rotation_euler=(Vector((0,0,.84))-cam.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO';d.ortho_scale=2.05;scene.camera=cam
    bpy.context.preferences.filepaths.save_version=0;texture.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(output/(asset_name+'.blend')))
    scene.render.filepath=str(output/(asset_name+'-front.png'));bpy.ops.render.render(write_still=True)
    cam.location=(2.7,-8,1.3);cam.rotation_euler=(Vector((0,0,.84))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(output/(asset_name+'-angle.png'));bpy.ops.render.render(write_still=True)

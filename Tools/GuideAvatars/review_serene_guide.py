"""Repeatable near-frontal detail checks, beyond the small in-app dock preview."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Tools/GuideAvatars/SereneGuide'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / 'SereneGuide.blend'))
scene = bpy.context.scene
scene.cycles.samples = 48
scene.render.resolution_x = 900
scene.render.resolution_y = 1000
camera = scene.camera
camera.data.ortho_scale = .57
focus = Vector((0, -.12, 1.405))
for name, location in [('face-front', (0, -8, 1.405)), ('face-angle', (1.45, -8, 1.405))]:
    camera.location = location
    camera.rotation_euler = (focus - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(SOURCE / (name + '.png'))
    bpy.ops.render.render(write_still=True)

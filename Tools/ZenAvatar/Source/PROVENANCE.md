# Head anatomy source

Derived locally from [MakeHuman Community MPFB2](https://github.com/makehumancommunity/mpfb2)
commit `b58176c661a9680294eb75f127842cb8378e4974`, with Blender 4.5.9 LTS.
The upstream base mesh, targets and output are [CC0 assets](https://github.com/makehumancommunity/mpfb2/blob/b58176c661a9680294eb75f127842cb8378e4974/LICENSE.md).
The addon code is GPLv3 and is not bundled in Vindla. The included CC0 license
applies to the anatomy data; Vindla's existing portrait is a separate app asset.

The snapshot is a baked head/neck, without addon or rig dependencies. Starting
macro settings: gender 1.0, age 0.95, weight 0.28, muscle 0.3; Asian 0.95,
Caucasian 0.05, African 0.0, remaining values default 0.5.

Additional MakeHuman targets:

- `head/head-age-incr`: 0.8
- `head/head-scale-horiz-decr`: 0.12
- `chin/chin-width-decr`: 0.15
- `nose/nose-scale-vert-incr`: 0.2
- `expression/units/asian/eye-left-closure`: 1.0
- `expression/units/asian/eye-right-closure`: 1.0

The mesh is converted to bake targets and helper masks, then vertices below
Blender Z=1.285 are removed. The final avatar script further crops the shoulders,
adjusts dimensions, adds one subdivision level and projects the app's existing
portrait. No code from the addon is required to regenerate the final avatar from
this source snapshot.

`ZenHeadOpenAnatomy.blend` uses the same macro/anatomical settings and cropping,
with the two eye-closure targets omitted. Vertex topology matches the closed
snapshot. The generator interpolates their Y/Z displacement at 90% openness for
a relaxed reading expression and registers the painted lid crease to this anatomy.

`ZenHeadSpeechAnatomy.blend` uses the closed-eye settings above, plus
`expression/units/asian/mouth-open` at 0.32. It retains the same topology and
provides a moderate anatomical speech pose, including lower lip, jaw and cheeks.
The final generator fades its small upper-face displacements to zero below the
eyelids, registers the lip contact seam to the portrait and keeps the skin mesh
connected. Signed speech displacement is exported in the standard `displayColor`
primvar and consumed (then reset to white) by the native geometry modifier.

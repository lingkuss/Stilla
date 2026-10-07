# Ra transparent-image experiment

Created with the built-in Imagegen tool on 2026-09-25 from
`Stilla/Assets.xcassets/kai_ra.imageset/image.png` (original preserved).
Final asset: `Stilla/Assets.xcassets/kai_ra_cutout.imageset/image.png`.
RGBA PNG, 1254 × 1254, actual zero-alpha background and soft alpha edges.

`GuideCutoutAsset` registers the image independently of the 3D model registry.
The mountain scene uploads it once to an unlit, alpha-blended rectangle with its
original aspect ratio. It uses the same dock, gallery and meditation anchors,
hover, Reduce Motion and inactive-app handling as the other guides. No second
renderer, model generation, runtime inference or new voice is involved. A failed
image load uses the original portrait fallback. Other Ra portrait uses are intact.

This is a flat illustration with a gentle hover, not a rigged body: it has no
mouth animation or independent chest breathing. It preserves the existing
standing, falcon-headed identity, crown, robes and held staffs.

Verification: Debug build passed; actual RGBA transparency was inspected
(1,037,241 fully transparent pixels, soft partial-alpha edges). Native guide
gallery and main dock were visually checked against the procedural landscape.
The meditation placement uses the common guide transform; a complete Ra session
and physical-device performance have not been verified in this pass.

## Final generation prompt

Use case: background-extraction / identity-preserve. Create a genuinely transparent-background PNG cutout of Ra from the reference for the Vindla meditation app. Preserve the same benevolent front-facing falcon-headed Egyptian celestial guide, same standing floating posture, full body including feet, detailed gold and deep-blue nemes headdress, small physical sun disk and horns on the crown, ornate golden collar, flowing dark blue and gold robes, both arms and hands holding the existing two slender ceremonial staffs, including the ankh on the right. Maintain the reference's beautiful intricate painterly illustration and warm golden illumination on the character, calm sacred expression. Extract ONLY the entire character with his worn clothing, physical crown and held staffs. Completely remove the cosmic background, nebula, surrounding stars, geometric diagrams, large glowing halo behind the head, swirling light trails, bottom magic circle and all floor/environment. These removed areas must be actual alpha transparency, not white, black, grey or a checkerboard illustration. No background glow rectangle. Retain refined softly antialiased edges with restrained self-contained gold highlights, clean readable silhouette for overlay on light and dark generated landscapes. Keep original proportions and identity; do not redesign as a human or a sitting person. Center full figure within a square transparent canvas with modest breathing room around crown, robes, staff tips and feet; no clipping; no text or watermark. Output a real RGBA PNG with transparent background.

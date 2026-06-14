# Godot Mobile-Optimized Foliage Plugin

A 3D foliage instancing plugin designed for mobile GPUs

![screenshot](splash.png)

Creating visually pleasing yet performant trees and bushes in mobile VR is a huge challenge and, if you're working on an outdoor scene, chances are you're going to want to put some trees in it. Professionally modeled assets might come with hundreds of thousands or millions of polygons and that's just not going to work on a mobile GPU, especially if you're making a forest. Let's consider some of the common workarounds.

### Stylized trees
Low polygon count, flat toon shading, etc. These are highly performant but they look like cartoons and it means your whole project will be locked into this art style for consistency.

### Billboards
If your trees are far away, you can use a simple quad with an image of a tree on a transparent background. Don't use too many overlapping cards, though, or the overdraw will cause your FPS to suffer. Even better if you have a cluster of billboards, render them as a single large image in your DCC software and then you only need to load one texture. However, if the user is expected to get close to them, they will look really fake.

### GPU Instances
If the meshes are simple enough, you can use GPU instancing and even give them some variety in size and color, which also works well at a distance but not up close.

### Impostors
This is an interesting technique in which many lower-resolution views of the subject are captured from several perspectives and combined as a grid in a single image. The shader selects the appropriate section of the texture, depending on the camera's position relative to the object. This also only works at a distance due to the low resolution.

---

### How this plugin works

If you want the user to be able to walk near the tree and not break the immersion, then it's going to require quite a few more polygons. However, this is not as much of a deal breaker as it once was. Modern hardware like the Meta Quest can handle a surprising number of vertices. What we do need to be careful about, though, are things like texture lookups, transparency, and light and shadows. This plugin takes advantage of GPU instancing, alpha to coverage transparency, and fake lighting and shadows.

First of all, we'll start with a tree mesh that consists of just the trunk and branches. This is much simpler geometry, relative to the leaves, so it's not going to break the bank. We can also use LOD to further simplify it as the camera moves away. We can render the trunk/branch texture using Blender's Cycles engine so the light and shadow information is baked in and can skip the PBR pipeline. The branches will be less visible than the leaves, so we don't need the texture to be too high-res. With some diligent UV unwrapping, we can also devote more pixel real estate to the lower part of the trunk, which is more conspicuous than the branches. Now we can create a `MultimeshInstance3D` and scatter transparent leaf cards on the branches. I separated the trunk and branches into two meshes because leaves generally don't grow on the trunk. To make a really dense, leafy tree, it might make more sense to combine clusters of leaves on a single card and instantiate small branches rather than individual leaves. This is especially helpful with conifers, which would otherwise require a vast amount of triangles to represent their needles.

Since transparency is in use, with many overlapping quads, alpha blending is not going to cut it. We'll use [alpha to coverage](https://en.wikipedia.org/wiki/Alpha_to_coverage) instead, which is similar to alpha test (in which pixels are either fully transparent or fully opaque) but it sends the alpha channel to the multisample anti-aliasing (MSAA) process (which is cheap to use on mobile GPUs) and compares the binary `AND` of the two masks, resulting in a strict 0 or 1 value, yet with a smoother appearance due to the anti-aliasing. This setting is called "Alpha Edge Clip" in Godot's `StandardMaterial3D` and the corresponding render mode is `alpha_to_coverage_and_one` in Godot's shading language.

I'm also using the `unshaded` render mode in the leaf shader to avoid PBR overhead. To make up for this, the shader will have to fake the light and shadow. The assumption is that, being an outdoor scene, there is a single directional light source (the sun) illuminating any other objects in the scene since that's relatively cheap and we pass this light node as a parameter to the GDScript part of the plugin (`BakedFoliage`). As the node bakes leaf instance positions, it calculates their position on the tree relative to the light source and stores this brightness value in the red channel of the instance's custom data, available in the shader as `INSTANCE_CUSTOM.r`. The shader will then darken the albedo based on this, approximating self-shadowing and adding some nice depth information to what would otherwise look very flat. By designing the leaf card mesh with the base of the twig at the origin and growing upward along the +Z axis in Blender (+Y in Godot coordinates), the shader can evaluate the height of the individual mesh in local space and create a shadow gradient along its length, further enhancing the depth effect.

Since the terrain in this demo is also unshaded, blob shadows are projected under each shrub using a `Decal` node and a procedurally generated radial gradient texture. By default, decals apply to all render layers so it is best to move the terrain mesh to a dedicated layer so only it receives the blob shadow. If you want sharper details, you can instead bake the terrain texture with Cycles in Blender as shown in one of the alternative examples that use this plugin:

![pine trees](docs/example_pine_trees.png)

What we now have is a tree drawn entirely with the `unshaded` render mode that still retains some hints as to how light would interact with it. The GPU is doing the heavy lifting by rendering hundreds or thousands of leaves with a single draw call. And, best of all, the user can get right up close and view it from any angle.

For trees and bushes that are farther away, the plugin can also bake a **LOD impostor**: four orthographic captures of the foliage (front, right, back, left) are stitched into a 2×2 atlas texture. At runtime an angle-aware shader selects the two closest views and cross-fades between them as the camera rotates, while dithered fading transitions smoothly from the full leaf-card mesh to the flat billboard quad. Use this technique for trees in the foreground, let the impostor take over at mid-range, and put some plain billboards behind them (ideally where the scene prohibits the user from approaching) and you can create a reasonably convincing forest.

---

## Installation

1. Copy the `addons/mobile_optimized_foliage/` folder into your project.
2. In Godot, open **Project → Project Settings → Plugins** and enable **Mobile Optimized Foliage**.

## Setting up a foliage node

1. Add a `BakedFoliage` node to your scene (or inherit it as a sub-scene for reuse across multiple placements).
2. In the **Setup** export group, assign:
   - **Tree Scene** — the root `Node3D` of your imported tree glTF. The plugin automatically mirrors its `MeshInstance3D` children (trunk, branches, etc.) as children of the `BakedFoliage` node, placed at the correct relative offset.
   - **Target Mesh** — a `MeshInstance3D` descendant of the tree scene whose surface the leaf cards will be scattered on (typically the branch mesh).
   - **Leaf Mesh** — the `Mesh` resource for a single leaf card.
   - **Shader Material** — a `ShaderMaterial` using `foliage_shadow.gdshader`.
3. Tune **Orientation**, **Scaling**, and **Lighting** parameters to taste; the plugin rebakes automatically whenever any value changes in the editor.
4. Assign a **DirectionalLight3D** (the sun) in the Lighting group so per-instance brightness is computed against your actual scene light.

The `BakedFoliage` node creates and manages its own child nodes at bake time:

| Child node | Purpose |
|---|---|
| `FoliageInstances` (`MultiMeshInstance3D`) | Leaf cards scattered on the target mesh surface |
| `_foliage_tree_*` (`MeshInstance3D`) | Mirrored trunk/branch meshes, aligned to `BakedFoliage` |
| `FoliageBlobShadow` (`Decal`) | Auto-sized radial gradient shadow projected onto terrain |
| `FoliageImpostor` (`MeshInstance3D`) | Angle-aware billboard quad, only present when an atlas is baked |

## LOD impostor

To enable the impostor:

1. Select a `BakedFoliage` node in the Inspector.
2. Click the **Bake Impostor Atlas** button at the bottom of the Inspector panel.
3. The baker captures four orthographic views, stitches a 1024×1024 PNG atlas, imports it, and saves a `FoliageImpostorData` resource (`.tres`) next to the current scene file. The atlas and resource are named after the scene and node, so each `BakedFoliage` node gets its own file.
4. The **Impostor Data** slot in the **LOD / Impostor** export group is filled automatically. Multiple `BakedFoliage` nodes that represent the same species can share the same `.tres` to save texture memory.

Tune the transition with these exports:

| Property | Effect |
|---|---|
| `lod_switch_distance` | Distance (m) at which the leaf-card mesh begins fading out |
| `lod_fade_range` | Width (m) of the dithered crossfade zone |
| `lod_cull_distance` | Distance (m) at which the impostor is hard-culled |
| `impostor_directional_shadow_strength` | N·L contrast baked into the atlas (independent of the real-time leaf cards); reduce to avoid dark shadow sides on the impostor |

## Editor toolbar

When the plugin is enabled, a **Rebake All Foliage** button appears in the Godot toolbar. Use it after moving the sun (`DirectionalLight3D`) to refresh the per-instance brightness on every `BakedFoliage` node in the open scene at once. A warning indicator appears on any node whose light direction has drifted since the last bake.

## Plugin files

| File | Role |
|---|---|
| `baked_foliage.gd` | `BakedFoliage` — the main `Node3D` script; scatters and bakes leaf instances, manages child nodes |
| `foliage_shadow.gdshader` | Spatial shader for leaf cards: `unshaded`, `alpha_to_coverage_and_one`, reads `INSTANCE_CUSTOM.r` for per-instance brightness |
| `foliage_impostor.gdshader` | Spatial shader for the LOD billboard: angle-based view selection, dithered near/far fade |
| `foliage_capture.gdshader` | Variant of the leaf shader used during impostor capture — same visual output, no LOD discard |
| `foliage_impostor_data.gd` | `FoliageImpostorData` resource: atlas texture + quad dimensions |
| `impostor_baker.gd` | `ImpostorBaker` — editor-only utility that renders the four views and saves the atlas |
| `plugin.gd` | `EditorPlugin` — registers the toolbar button and the per-node Inspector buttons |

## Key constraints for mobile

- All materials use `unshaded` — no PBR, no dynamic shadow maps on foliage.
- Leaf transparency uses `alpha_to_coverage_and_one` (requires MSAA; cheap on tile-based GPUs). Do not switch to `blend_mix` — overdraw kills mobile performance.
- Per-instance lighting data lives in `INSTANCE_CUSTOM.r` and is computed once at bake time, not per frame.
- The impostor dither fade uses interleaved gradient noise, which works without a texture on the Mobile renderer.
- The terrain mesh should be on a separate render layer so the blob-shadow `Decal` only hits it and not the foliage.
- The project renderer must be set to `mobile` and MSAA 3D must be enabled (at least 2×) for the `alpha_to_coverage_and_one` render mode to work correctly.

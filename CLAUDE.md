# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A Godot 4.6 plugin and demo that renders foliage (shrubs/trees) efficiently on mobile GPUs (targeting Meta Quest). The technique combines GPU-instanced leaf cards with baked shadowing, `alpha_to_coverage`, and `unshaded` materials to avoid PBR overhead while retaining convincing depth. A LOD impostor system (4-view baked atlas + angle-aware billboard shader) takes over at configurable distances.

## Running the demo

Open the project in Godot 4.6 with the Mobile renderer and run `main.tscn`. WASD moves the player; arrow keys rotate the camera. There is no CLI build step — Godot's editor is the only build tool.

## Architecture

### Plugin: `addons/mobile_optimized_foliage/`

| File | Role |
|------|------|
| `baked_foliage.gd` | `BakedFoliage` — the main `Node3D` `@tool` script; scatters leaf instances on a target mesh surface, bakes per-instance brightness into `INSTANCE_CUSTOM.r`, auto-manages child nodes (MultiMeshInstance3D, trunk/branch mirrors, blob-shadow Decal, impostor quad) |
| `foliage_shadow.gdshader` | Spatial shader for leaf cards: `unshaded`, `cull_disabled`, `alpha_to_coverage_and_one`; reads `INSTANCE_CUSTOM.r` as `v_shadow`, computes per-vertex stem AO gradient, dithers LOD fade-out |
| `foliage_impostor.gdshader` | Spatial shader for the LOD billboard: Y-axis billboard, angle-based atlas view selection, blend between adjacent views, dithered near/far fade |
| `foliage_capture.gdshader` | Variant of the leaf shader used during impostor baking — same visual output but no LOD discard and depth write enabled so back-layer cards are correctly occluded in the atlas |
| `foliage_impostor_data.gd` | `FoliageImpostorData` resource: atlas `Texture2D` + quad dimensions (width/height) computed from the shrub AABB |
| `impostor_baker.gd` | `ImpostorBaker` — editor-only utility (`RefCounted`); captures 4 orthographic views into a 512×512-per-cell PNG atlas, saves a `.tres` alongside the current scene, and assigns it back to the `BakedFoliage` node |
| `plugin.gd` | `EditorPlugin` — adds a "Rebake All Foliage" toolbar button and per-node Inspector buttons ("Rebake", "Bake Impostor Atlas") |

### How `BakedFoliage` works

On `_ready()` (and whenever any export changes in the editor), `BakedFoliage._bake()`:
1. Creates or reuses a `MultiMeshInstance3D` child named `FoliageInstances`.
2. Scatters `instance_count` transforms on `target_mesh`'s surface using triangle-area-weighted sampling.
3. Re-orients each instance to radiate outward from the mesh origin (configurable `outward_bias_*`) and applies a random twist and vertical scale taper.
4. Computes per-instance brightness (`INSTANCE_CUSTOM.r`) using wrapped N·L against the assigned `DirectionalLight3D`, multiplied by a depth-based occlusion gradient.
5. Mirrors all `MeshInstance3D` children of `tree_scene` (trunk, branches) as `_foliage_tree_*` children, placed at the same relative offset from `BakedFoliage`.
6. Creates or updates the blob-shadow `Decal` (if `blob_shadow_enabled`).
7. Updates the impostor `MeshInstance3D` (if `impostor_data` is assigned).

`NOTIFICATION_EDITOR_PRE_SAVE` zeroes the MultiMesh `instance_count` so the buffer is not serialised into the scene file; `NOTIFICATION_EDITOR_POST_SAVE` rebakes immediately after.

### Demo scene: `yew_shrub.tscn`

A sub-scene with a single `BakedFoliage` root, instanced multiple times in `main.tscn`. Key exports wired up:
- `tree_scene` → the yew shrub glTF root (trunk + branches baked meshes)
- `target_mesh` → the branch-tips `MeshInstance3D`
- `leaf_mesh` → the yew twig quad mesh
- `shader_material` → `yew_leaf.tres` (`ShaderMaterial` using `foliage_shadow.gdshader`)
- `impostor_data` → `main_BakedFoliage_impostor.tres` (baked 4-view atlas)

### Terrain: `ground_noise.gdshader` / `ground_noise.tres`

Also `unshaded`. Displaces vertices in the vertex stage using a noise texture and overlays two noise textures in the fragment stage for color.

## Key constraints for mobile

- All materials use `unshaded` — no PBR, no dynamic shadow maps on foliage.
- Leaf transparency uses `alpha_to_coverage_and_one` (requires MSAA; cheap on tile-based GPUs). Do not switch to `blend_mix` — overdraw kills mobile performance.
- Per-instance lighting data lives in `INSTANCE_CUSTOM.r` and is computed once at bake time, not per frame.
- The impostor dither uses interleaved gradient noise (`dither()` in both shaders) — textureless, works on the Mobile renderer.
- The terrain mesh should be on a separate render layer so the blob-shadow `Decal` only hits it and not the foliage.
- The project renderer is set to `mobile` in `project.godot`; MSAA 3D must be ≥ 2× for `alpha_to_coverage_and_one` to work.

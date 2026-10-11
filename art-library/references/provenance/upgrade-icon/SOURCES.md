# Casual weapon art

`weapon_auto_turret_omni_02.png` was generated with OpenAI image generation on 2026-09-27 (`exec-8c6c12b2-537b-47cf-9808-6dcb974aa603.png`). Prompt: compact cute stylized modern-fantasy turret with a radial central crystal emitter and symmetric ports on every side, no forward barrel, transparent background and no baked shadow/text. Its WebP copy (quality 88) is used in combat and UI so 360-degree targeting matches the silhouette.

The ten `weapon_*_casual_01.png` masters were generated during the interrupted Seoul Hero casual-art redesign. The common direction was readable, stylized modern-fantasy equipment with transparent backgrounds and no baked text. These masters are kept for editing; `scripts/optimize-casual-art.py` makes the corresponding WebP runtime files without changing the source art. `src/data/images.ts` selects the WebP files for the archive, growth room, shop, and HUD.

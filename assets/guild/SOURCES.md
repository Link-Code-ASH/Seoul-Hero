# Guild image sources

The `*_casual_02.png` room and facility masters were generated with OpenAI image generation on 2026-09-27, then encoded as WebP (quality 88) for runtime. The room prompt requested a bright, hand-painted/pixel-art Seoul guild workshop with a broad empty floor, clear walls/windows and no interactive furniture; source `exec-96cea461-ceed-43bf-974d-a80087372fb3.png`. Training (`exec-8e08b540-84bd-414e-8c49-ccc32adc650b.png`), recovery (`exec-67b1d05e-9918-4ea0-b186-183a33537717.png`), supply (`exec-e63b6b63-ff76-469d-bfba-d43fed35e743.png`), gate terminal (`exec-b3604cf5-5583-4190-ae04-7d35a8c980a7.png`) and roster kiosk (`exec-3f7d14ae-ca6d-45ae-bd80-819466460595.png`) prompts requested matching transparent quarter-view cutouts with visible ground-contact feet and no baked floor or text. These assets are the current guild art.

The original guild images were generated for Seoul Hero with OpenAI image generation on 2026-09-25. The prompts requested a grounded blue-gray modern Seoul fantasy guild room and transparent facility cutouts, with no baked text. `guild_hall_01.png` is the earlier dark room; `guild_rail_foreground_01.webp` is its old masked front-rail layer.

`guild_hall_seoul_day_01.png` was generated with the built-in image tool on 2026-09-26 from `guild_hall_01.png` (`exec-62aaab0d-f49c-4a35-bea0-99c7150f1799.png`). Prompt: preserve the isometric room footprint, open walkable floor and window positions; change the dark workshop into a bright overcast modern Seoul guild workshop with blue-gray concrete, steel and city views; leave the floor empty for separate facility sprites; avoid fantasy-hotel decor, people, text and logos. It is the current runtime backdrop. The facility cutouts are once again separate depth-sorted props with individual contact shadows.

`guild_roster_kiosk_01.png` was generated with the built-in image tool on 2026-09-26 (`exec-915851b8-eed7-4ffa-951a-1f0682f4be42.png`). Prompt: transparent grounded blue-gray steel guild-membership kiosk, portrait terminal and registry folder fixed to a waist-high counter, three-quarter top-down view, broad feet at bottom edge, no floating book, people, logos or background. It replaces the free-floating lobby ID-card art inside the guild room.

Matching WebP files for the new room, roster kiosk and three facility cutouts are runtime exports from their PNG masters (Pillow quality 88). The image manifest selects WebP first; the editable PNGs remain in this folder.

`guild_hall_casual_01.png` is the newer generated casual guild room master from the interrupted redesign. It bakes each facility and its appropriately sized floor shadow into one grounded room image. `guild_hall_casual_01.webp` is the optimized runtime copy produced by `scripts/optimize-casual-art.py`. The separate facility cutouts and old background remain as source assets but are not rendered in this version.

| Asset | Intended use | Source generation |
| --- | --- | --- |
| `guild_hall_01.png` | guild room backdrop | `exec-ec1fe4a0-11fc-484f-980b-87fae94be0df.png` |
| `training_station_01.png` | training UI | `exec-8a517783-abb7-49b1-b793-98a00bff5bc2.png` |
| `recovery_station_01.png` | recovery UI | `exec-93a585a9-99f5-4081-8db8-6cf739d645ce.png` |
| `supply_station_01.png` | supply UI | `exec-b093235a-0e37-477f-a44d-a857700521e7.png` |
| `guild_rail_foreground_01.webp` | foreground occlusion | Derived from `guild_hall_01.png` using an alpha mask |
| `guild_song_pixel_01.png` | guild-only pixel scooter rider | Built-in image generation, reference `assets/characters/player_plaza_01.png`; chibi 3/4-view pixel-art rider on a teal magical scooter, transparent single pose. Cropped and reduced with nearest-neighbor sampling. |
| `guild_kang_pixel_01.png` | guild-only pixel mini-truck rider | Built-in image generation, reference `assets/characters/kang_taehoon_truck_01.png`; chibi 3/4-view tactical rider on an olive magical mini-truck, transparent single pose. Cropped and reduced with nearest-neighbor sampling. |

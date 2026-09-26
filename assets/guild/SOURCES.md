# Guild image sources

All images in this folder were generated for Seoul Hero with OpenAI image generation on 2026-09-25. The original prompts requested a grounded blue-gray modern Seoul fantasy guild room and transparent facility cutouts, with no baked text. The Pixi 2.5D room uses `guild_hall_01.png` as its floor and walls. `guild_rail_foreground_01.webp` is a masked foreground layer derived from that image so characters pass behind the front rail.

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

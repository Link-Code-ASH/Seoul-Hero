# 런타임 소재 보완 프롬프트

## panel_clean

Use case: background-extraction. Production game asset correction. Keep the exact cream panel, silver bevel, turquoise top rail and its geometry, colours and material unchanged. REMOVE ALL pixels outside the panel silhouette to actual alpha0, including the large dark/grey/teal background gradient and all external glow and shadows. This is an isolated 9-slice UI material with no background at all. Interior stays almost fully opaque white/cream. Preserve the panel size and position on1536x1024canvas, panel bounds approximatelyx57y200to1480y809. Every pixel outside these panel edges must be transparent. No new art, text or icons. Clean antialias only on actual panel boundary. Output actual transparent RGBA PNG. Do NOT render a black background.

## card_clean

Use case: precise-object-edit. Correct production empty shop bay while preserving its existing silhouette, front orthographic view, silver white sides, ivory quiet rear, warm top lamp, lower shelf and turquoise bottom rail. Move ONLY the upper clear horizontal shelf lip from its current44%height position upward to31%of visible bay height, approximatelyy508rather thany640on current995x1581canvas. This creates an upper small product area and a large unobstructed lower text area. Keep lower shelf and all other materials unchanged. REMOVE stray pixels, fragments, noise and external glow outside the bay silhouette to actual alpha0. Clean antialias on boundary, genuine transparent PNG. No text, numbers, logos, icons, locks, products or priceplate. Keep card overall dimensions/proportions and same framing.



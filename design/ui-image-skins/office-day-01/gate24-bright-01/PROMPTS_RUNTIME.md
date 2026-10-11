# 승인 시안 런타임 소재 프롬프트

Built-in image_gen.imagegen, 승인 시안 style reference, 원본 PNG 무손실 복사. 전체 화면이 아닌 텍스트 없는 게임용 소재.

## background

Use case: stylized-concept. Asset type: actual game background, full bleed 1830x824 landscape, wide 915:412 ratio.
Input image is ONLY a reference of the user-approved Gate24 convenience-store style. Generate the environment that would exist behind its interface, with NO interface at all.
Primary request: bright Korean hunter convenience store interior in daytime, exactly the approved image's inviting milk-white/cream mint orange yellow palette. Large sunny storefront windows on left looking at modern Seoul street, long luminous ceiling tubes and aisle perspective, colorful softly blurred packages along side shelves, tall glass beverage refrigerators on right, pale polished tile floor. Eye level, camera centered between the aisles. Focus softly blurred enough for game text overlaid later; richly rendered environment at edges and corners, central area spacious and quiet, no central checkout machine or large focal object.
Lighting warm gentle daylight, stylish illustrated 3D game background matching approved reference, readable supermarket atmosphere, balanced saturation. Background ONLY. NO panels, NO UI, NO characters, NO weapons, NO button, NO foreground card, NO price, NO Korean letters or any text, NO brand, NO signage typography or watermark; blank mint/yellow/orange sign planes permitted. Opaque image filling the whole canvas.

## panel

Use case: product-mockup. Asset type: ONE game UI 9-slice panel frame, transparent PNG, isolated centered.
Input is style reference only: approved bright convenience-store screen. Produce just one clean large rectangular MILK WHITE/ivory acrylic/enamel panel with restrained cut/chamfered corners and fine silvery bevel thickness, soft internal highlights, subtle warm ivory surface. Thin turquoise-mint top rail integrated into the material, soft warm reflected line below. Center is blank pale ivory #FBF6EC, uniform quiet texture. Straight-on front orthographic view, absolutely no perspective, rotation or tilt. Proportions wide rectangular ~2:1, with generous transparent margin outside. Aim visible panel from x64 y128 to1472 y896 on a1536x1024 transparent canvas. Corners small (~24px); horizontal/vertical edges remain uniform stretchable; border very thin at logical display, not thick decorative frame.
This surface is reused for bright Gate24 header/status/footer/popup through nine-slice. Match white cabinet of reference, no shadow spilling far outside. All content will be added natively. NO text, NO letters, NO number, NO logo, NO icon, NO product, NO inset region, NO buttons, NO neon. Real transparency outside; panel interior opaque cream.

## card

Use case: product-mockup. Asset type: ONE blank product display bay surface for actual game UI, transparent PNG.
Input image is approved style reference. Generate one empty white/cream convenience-store refrigerated display bay matching the four white bays in that image, viewed straight-on front, no perspective. Tall rectangle width:height162:266. Small chamfered corners, light grey/silver slender side thickness and ivory blank rear panel, gently luminous warm top light strip, one clear acrylic shelf lip at30%height separating future product from copy, a small clear lower shelf at83%height where separate yellow price label will overlay. Thin turquoise rail along bottom edge, very restrained fine chrome gloss, soft subtle ivory shading.
The middle text region must be QUIET cream, no busy reflections. This is EMPTY bay only. NO item or weapon or character, NO yellow price button, NO lock, NO glyph, NO text/letters/numbers/logos. No external drop shadow. Real alpha0 outside with full canvas margin ~32px. Centered canvas768x1280, subject fills about90% area. Match bright reference cream cabinet sophistication. No cyan glow, dark sci-fi or dark panels.

## controls

Use case: product-mockup. Asset type: ONE transparent game control sprite atlas, 1536x1536 square, exact grid arrangement.
Input image is approved Gate24 style reference. Produce a clean atlas with FIVE blank UI control surfaces, facing straight front, on real transparent background, no visible sheet background, no text or icons. All have restrained chamfered corners, slight enamel/acrylic thickness and fine silver/ivory material highlights, no external shadow. NOT flat vector. Same visual family as reference. Clearly separate by large alpha0 gaps.
Arrangement: five horizontal rows, each centered x128 to1408 (~1280width), height approximately190px, first row y64..254, second y352..542, third y640..830, fourth y928..1118, fifth y1216..1406. Blank transparent margin around each.
Row1 milk-white/ivory blank secondary button, thin grey-silver bevel.
Row2 rich teal/turquoise #00B6BD selected tab, thin shiny ivory bevel, uniform center for white text added later.
Row3 warm saturated ORANGE #FF8A24 primary next-wave button, subtle yellow highlight and orange lower side, no arrow or mark.
Row4 sunny pale YELLOW #FFE267 purchase priceplate, very thin ivory bevel and warm soft inner shading, center empty for navy number.
Row5 milk-white blank icon/toggle square-style surface but stretched horizontal shape here so it can be nine-sliced into square, similar row1 with cut corners of same size.
Every row exactly same outline positions, thin edge thickness. No labels, no number, no logo, no characters, no icons, no textures in the empty centers. Real transparent PNG, do NOT include checkerboard. Render all FIVE rows only.


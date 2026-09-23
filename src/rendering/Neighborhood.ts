import { Container, Graphics, Sprite, Text } from 'pixi.js';
import { WORLD_THEME } from '../data/worldTheme';
import type { SceneryTile } from '../world/SceneryTile';
import type { ImageAssets } from './ImageAssets';
import { neighborhoodLayouts, streetDecorations } from '../data/environment';

const theme = WORLD_THEME.neighborhood;

function label(text: string, x: number, y: number, size = 13, color: number = theme.lettering): Text {
  const view = new Text({ text, style: { fontFamily: 'Arial, sans-serif', fontSize: size, fill: color, letterSpacing: 1 } });
  view.position.set(x, y);
  return view;
}

/** Quiet geometric scenery: every object is deliberately outside the collision system. */
export function createNeighborhoodTile(chunk: SceneryTile, size: number, art?: ImageAssets, suppressProceduralGround = false): Container {
  const container = new Container();
  container.position.set(chunk.x * size, chunk.y * size);
  const ground = new Graphics();
  container.addChild(ground);
  ground.rect(0, 0, size, size).fill(theme.ground);
  ground.rect(0, 0, size, theme.roadWidth).fill(theme.asphalt);
  ground.rect(0, 0, theme.roadWidth, size).fill(theme.asphalt);
  ground.rect(theme.roadWidth, theme.roadWidth, size - theme.roadWidth, size - theme.roadWidth)
    .fill({ color: theme.pavement, alpha: 0.4 });
  for (let p = theme.roadWidth; p < size; p += theme.tileSize) {
    ground.moveTo(p, theme.roadWidth).lineTo(p, size);
    ground.moveTo(theme.roadWidth, p).lineTo(size, p);
  }
  ground.stroke({ color: theme.line, alpha: 0.14, width: 1 });
  ground.moveTo(0, theme.roadWidth).lineTo(size, theme.roadWidth);
  ground.moveTo(theme.roadWidth, 0).lineTo(theme.roadWidth, size);
  ground.stroke({ color: theme.line, alpha: 0.4, width: 2 });
  for (let p = 145; p < size; p += 95) {
    ground.rect(p, 54, 37, 3).fill({ color: 0xafa16f, alpha: 0.3 });
    ground.rect(54, p, 3, 37).fill({ color: 0xafa16f, alpha: 0.3 });
  }
  if (chunk.detail % 2 === 0) {
    for (let p = 14; p < 105; p += 17) {
      ground.rect(p, 124, 10, 32).fill({ color: 0x8a9995, alpha: 0.28 });
      ground.rect(124, p, 32, 10).fill({ color: 0x8a9995, alpha: 0.28 });
    }
  }

  // Fixed quiet street furniture: visual only, never registered for collision.
  ground.roundRect(430,190+chunk.detail*36,26,54,5).fill(0x30434b);
  ground.rect(434,201+chunk.detail*36,18,12).fill(0x142730);
  ground.rect(433,227+chunk.detail*36,20,8).fill(0x182b32);
  ground.roundRect(315,410,95,26,5).fill({color:0x304737,alpha:0.7});
  if(chunk.variant===3){
    ground.rect(170,190,210,155).fill({color:0x283944,alpha:0.6});
    for(let x=184;x<365;x+=32)for(let y=204;y<335;y+=34)ground.rect(x,y,15,17).fill({color:0x49606b,alpha:0.35});
    container.addChild(label('해오름 아파트 101',185,349,13));
  }
  if (art && art.loadedCount > 0) {
    if (suppressProceduralGround) ground.visible = false;
    for (const decoration of [...(neighborhoodLayouts[chunk.variant] ?? []), ...streetDecorations]) {
      const texture = art.get(decoration.image);
      if (!texture) continue;
      const sprite = new Sprite(texture);
      sprite.anchor.set(.5);
      sprite.position.set(decoration.x * size, decoration.y * size);
      sprite.scale.set(decoration.size * size / Math.max(texture.width, texture.height));
      sprite.alpha = decoration.alpha;
      container.addChild(sprite);
    }
    return container;
  }

  if (chunk.variant === 4) {
    ground.roundRect(173, 176, 246, 232, 30).fill({ color: theme.foliage, alpha: 0.35 });
    ground.roundRect(192, 290, 207, 19, 7).fill({ color: theme.pavement, alpha: 0.8 });
    for (const [x, y] of [[207, 215], [371, 213], [213, 365], [371, 357]]) {
      ground.circle(x!, y!, 27).fill({ color: theme.foliage, alpha: 0.72 });
      ground.circle(x! - 6, y! - 4, 13).fill({ color: 0x43634d, alpha: 0.18 });
    }
    container.addChild(label('동네 쉼터', 248, 326));
  } else {
    ground.roundRect(175, 187, 234, 200, 8).fill({ color: theme.building, alpha: 0.62 });
    ground.roundRect(185, 197, 214, 180, 3).stroke({ color: theme.line, alpha: 0.32, width: 1 });
    ground.rect(185, 341, 214, 31).fill({ color: chunk.variant === 0 ? 0x345b4d : 0x34484d, alpha: 0.65 });
    for (let p = 207; p < 378; p += 46) {
      ground.rect(p, 223, 25, 34).fill({ color: 0x36505a, alpha: 0.5 });
      ground.rect(p, 277, 25, 34).fill({ color: 0x36505a, alpha: 0.5 });
    }
    container.addChild(label(theme.storefronts[chunk.variant] ?? '동네 상가', 210, 347, 14));
    ground.roundRect(433, 200 + chunk.detail * 39, 25, 51, 5).fill({ color: 0x415357, alpha: 0.57 });
    ground.rect(437, 211 + chunk.detail * 39, 17, 12).fill({ color: 0x152b34, alpha: 0.8 });
  }
  if (chunk.detail === 1) {
    ground.roundRect(159, 428, 100, 31, 4).fill({ color: 0x294746, alpha: 0.55 });
    container.addChild(label('지하철 ③', 171, 436, 12));
  }
  return container;
}

export function createGate(art?: ImageAssets): Container {
  const gate = new Container();
  const texture = art?.get('gate');
  if (texture) {
    const sprite = new Sprite(texture);
    sprite.anchor.set(.5); sprite.scale.set(190 / texture.height);
    gate.addChild(sprite);
    return gate;
  }
  const rings = new Graphics();
  rings.circle(0, 0, 104).stroke({ color: 0xb491ef, alpha: 0.1, width: 1 });
  rings.circle(0, 0, 87).stroke({ color: 0xb491ef, alpha: 0.14, width: 8 });
  rings.circle(0, 0, 77).fill({ color: 0x543763, alpha: 0.2 }).stroke({ color: 0xb491ef, alpha: 0.55, width: 2 });
  rings.poly([0, -49, 30, 0, 0, 49, -30, 0]).fill({ color: 0xa381d0, alpha: 0.2 })
    .stroke({ color: 0xc4a2f2, alpha: 0.45, width: 1 });
  for (let i = 0; i < 8; i++) {
    const angle = i * Math.PI / 4;
    rings.moveTo(Math.cos(angle) * 91, Math.sin(angle) * 91)
      .lineTo(Math.cos(angle) * 100, Math.sin(angle) * 100);
  }
  rings.stroke({ color: 0xc4a2f2, alpha: 0.5, width: 2 });
  gate.addChild(rings);
  return gate;
}

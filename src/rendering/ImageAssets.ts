import { Assets, Texture, Rectangle } from 'pixi.js';
import { images } from '../data/images';
import type { ImageId } from '../data/images';

// UI <img> elements fetch their own art only when their screen is displayed.
// Pixi should not decode every lobby, archive and weapon-detail image at startup.
const isUiOnly = (id: ImageId): boolean =>
  id === 'wallet' || id === 'associationCoin' || id === 'supplyTicket' ||
  id === 'kangTaehoonPortrait' || id === 'songJinwooPortrait' ||
  id === 'supplyOpeningBurst' || id === 'supplyResultBackplate' ||
  id.startsWith('guild') ||
  /^(lobby|meta|weapon|weekly|blessing)/.test(id);

/** Shared decoded textures are loaded once, not reloaded for entities or chunks. */
export class ImageAssets {
  private readonly textures = new Map<ImageId, Texture>();
  readonly failures: string[] = [];
  async load(): Promise<void> {
    // Enemy sprites intentionally load from their individual image manifest entries.
    // The legacy enemy atlas is retained as source history only; using it here would
    // silently override redesigned sprites in both gameplay and future content updates.
    const effectCells: Partial<Record<ImageId, number>> = { piercingFx: 5, turretBolt: 6 };
    let effects: Texture | undefined;
    try { effects = await Assets.load<Texture>(new URL('../../assets/effects/plaza_effects_atlas_01.png', import.meta.url).href); }
    catch (error) { console.warn('Effect atlas unavailable', error); }
    await Promise.all((Object.entries(images) as [ImageId, typeof images[ImageId]][])
      .filter(([id]) => !isUiOnly(id)).map(async ([id, definition]) => {
      try {
        const effectCell = effectCells[id];
        if (effects && effectCell !== undefined) {
          const w = effects.width / 4, h = effects.height / 2;
          this.textures.set(id, new Texture({source:effects.source,frame:new Rectangle(effectCell % 4 * w, Math.floor(effectCell / 4) * h, w, h)}));
          return;
        }
        if (!definition.url) throw new Error('Missing asset URL');
        const texture = await Assets.load<Texture>(definition.url);
        if (id === 'player' || id === 'kangTaehoonTruck' || id === 'manaShotgunPellet' || id === 'magicStone' || id === 'guardianShuriken' || id === 'manaFieldAura' || id.startsWith('vfx') || id === 'brute' || id === 'hound' || id === 'boss' || id === 'riftQueen' || ['bulwark','spitter','swarm','charger','bomber','splitter','mender','summoner','sentinel','lurker','splitterAir','spitterFire','chargerBrace','bossAttack','riftQueenCast'].includes(id)) {
          texture.source.scaleMode = 'linear';
          texture.source.autoGenerateMipmaps = true;
          texture.source.maxAnisotropy = 4;
        }
        this.textures.set(id, texture);
      } catch (error) { this.failures.push(id); console.warn('Image asset failed', id, error); }
    }));
  }
  get(id: ImageId): Texture | undefined { return this.textures.get(id); }
  get loadedCount(): number { return this.textures.size; }
  destroy(): void {
    this.textures.clear();
  }
}

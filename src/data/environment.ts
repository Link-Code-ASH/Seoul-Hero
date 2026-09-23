import type { ImageId } from './images';
export interface Decoration { image: ImageId; x: number; y: number; size: number; alpha: number }
// Positions and sizes are fractions of one chunk; none affect collision or navigation.
export const neighborhoodLayouts: readonly (readonly Decoration[])[] = [
  [{ image: 'store', x: .59, y: .6, size: .57, alpha: .7 }],
  [{ image: 'subway', x: .58, y: .58, size: .46, alpha: .66 }],
  [{ image: 'busStop', x: .57, y: .56, size: .48, alpha: .7 }],
  [{ image: 'store', x: .58, y: .57, size: .52, alpha: .65 }, { image: 'planter', x: .77, y: .87, size: .19, alpha: .64 }],
  [{ image: 'planter', x: .5, y: .47, size: .25, alpha: .72 }, { image: 'planter', x: .76, y: .72, size: .23, alpha: .68 }, { image: 'busStop', x: .42, y: .8, size: .29, alpha: .65 }],
];
export const streetDecorations: readonly Decoration[] = [
  { image: 'streetLamp', x: .3, y: .35, size: .24, alpha: .7 },
  { image: 'planter', x: .88, y: .38, size: .17, alpha: .6 },
];

// Keep one mobile-landscape layout on every device; only its display scale changes.
const GAME_WIDTH = 915;
const GAME_HEIGHT = 412;
let gameScale = 1;

export function getGameViewportScale(): number { return gameScale; }

export function fitGameViewport(app: HTMLElement): () => void {
  const fit = (): void => {
    gameScale = Math.min(window.innerWidth / GAME_WIDTH, window.innerHeight / GAME_HEIGHT);
    app.style.setProperty('--game-scale', String(gameScale));
  };
  fit();
  window.addEventListener('resize', fit);
  window.visualViewport?.addEventListener('resize', fit);
  return () => {
    window.removeEventListener('resize', fit);
    window.visualViewport?.removeEventListener('resize', fit);
  };
}

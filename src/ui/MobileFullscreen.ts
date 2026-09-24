export async function requestMobileFullscreen(): Promise<boolean> {
  if (document.fullscreenElement || matchMedia('(display-mode: fullscreen)').matches) return true;
  if (!document.fullscreenEnabled) return false;
  try {
    await document.documentElement.requestFullscreen({ navigationUI: 'hide' });
    return true;
  } catch {
    return false;
  }
}

// Existing installed shortcuts can retain an old standalone manifest for a while.
// A touch inside the game applies full screen immediately without reinstalling it.
export function enableMobileFullscreenOnTouch(): () => void {
  const onClick = (event: MouseEvent): void => {
    if (!event.isTrusted || !matchMedia('(pointer: coarse)').matches || innerWidth <= innerHeight) return;
    if (event.target instanceof Element && event.target.closest('.account-panel')) return;
    void requestMobileFullscreen().then(success => {
      if (success) document.removeEventListener('click', onClick);
    });
  };
  document.addEventListener('click', onClick);
  return () => document.removeEventListener('click', onClick);
}

const CACHE_NAME = 'seoul-hero-pwa-v2';
const OFFLINE_PAGE = new URL('offline.html', self.registration.scope).href;

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll([
    OFFLINE_PAGE,
    new URL('icons/icon-192.png', self.registration.scope).href,
  ])));
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(Promise.all([
    caches.keys().then(keys => Promise.all(keys.filter(key => (key.startsWith('seoul-gate-pwa-') || key.startsWith('seoul-hero-pwa-')) && key !== CACHE_NAME).map(key => caches.delete(key)))),
    self.clients.claim(),
  ]));
});

self.addEventListener('fetch', event => {
  if (event.request.mode !== 'navigate') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || !url.pathname.startsWith(new URL(self.registration.scope).pathname)) return;
  event.respondWith(fetch(event.request).catch(async () => (await caches.open(CACHE_NAME)).match(OFFLINE_PAGE)));
});

// Only static public shell files are cached. Private account data and Supabase responses are NEVER cached.
const CACHE='between-us-secure-v2';
const ASSETS=['./','./index.html','./app.js','./config.js','./manifest.webmanifest','./icon.svg','./icon-192.png','./icon-512.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);
  if(url.origin!==self.location.origin)return;
  if(url.pathname.endsWith('/config.js'))return; // always fetch current configuration
  if(event.request.mode==='navigate'){
    event.respondWith(fetch(event.request).catch(()=>caches.match('./index.html')));return;
  }
  if(!ASSETS.some(asset=>url.pathname.endsWith(asset.replace('./','/'))))return;
  event.respondWith(caches.match(event.request).then(cached=>cached||fetch(event.request)));
});

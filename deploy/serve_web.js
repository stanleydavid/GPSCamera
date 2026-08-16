// serve_web.js — static server untuk GPS Camera web build (PRJ-012-T1).
// SPA fallback + MIME types betul (application/wasm untuk canvaskit,
// application/javascript untuk main.dart.js). Guna dengan PM2 pada 0.0.0.0:3005.
//
//   PORT=3005 pm2 start deploy/serve_web.js --name gpscamera-web && pm2 save
//
// NOTA BUILDER 2026-08-16: port 3002 pada Charlie TELAH digunakan oleh
// perkhidmatan lain (D-Billboard DBKK login) dan 3003 (Public Complaint)
// serta 3004 (Smart City Friends) juga sudah diambil. 3005 disahkan KOSONG
// (connection refused) — guna 3005.
//
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = '/home/ubuntu/gpscamera-web';
const PORT = process.env.PORT || 3005;

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.webmanifest': 'application/manifest+json',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
};

http
  .createServer((req, res) => {
    let p = path.join(ROOT, req.url.split('?')[0]);
    if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) {
      p = path.join(ROOT, 'index.html'); // SPA fallback
    }
    res.setHeader('Content-Type', MIME[path.extname(p)] || 'application/octet-stream');
    fs.createReadStream(p).pipe(res);
  })
  .listen(PORT, '0.0.0.0', () => {
    console.log(`gpscamera-web serving ${ROOT} on 0.0.0.0:${PORT}`);
  });

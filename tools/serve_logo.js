const http = require('http');
const fs = require('fs');
const path = require('path');

const dir = path.resolve('assets-source/logo');
const server = http.createServer((req, res) => {
    const filePath = path.join(dir, req.url.replace(/^\//, ''));
    if (fs.existsSync(filePath)) {
        const ext = path.extname(filePath).toLowerCase();
        const mime = ext === '.png' ? 'image/png' : 'image/jpeg';
        res.writeHead(200, { 'Content-Type': mime, 'Access-Control-Allow-Origin': '*' });
        fs.createReadStream(filePath).pipe(res);
    } else {
        res.writeHead(404);
        res.end('Not found: ' + req.url);
    }
});

server.listen(8765, '127.0.0.1', () => {
    console.log('Serving on http://127.0.0.1:8765');
});

import { WebSocketServer } from 'ws';
import http from 'node:http';
import readline from 'node:readline';

const port = Number(process.env.VIBE_PATCH_PORT || 8787);
const server = http.createServer((req, res) => {
  if (req.method !== 'POST' || req.url !== '/patch') {
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('not found\n');
    return;
  }

  let body = '';
  req.setEncoding('utf8');
  req.on('data', (chunk) => {
    body += chunk;
    if (body.length > 1024 * 1024) req.destroy();
  });
  req.on('end', () => {
    try {
      const patch = JSON.parse(body);
      broadcast(patch);
      res.writeHead(202, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
    } catch (error) {
      res.writeHead(400, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: false, error: error.message }));
    }
  });
});

const wss = new WebSocketServer({ server });
const clients = new Set();

wss.on('connection', (socket) => {
  clients.add(socket);
  socket.on('message', (message) => {
    try {
      const patch = JSON.parse(message.toString());
      broadcast(patch);
    } catch (error) {
      socket.send(JSON.stringify({ ok: false, error: error.message }));
    }
  });
  socket.on('close', () => clients.delete(socket));
});

function broadcast(payload) {
  const msg = typeof payload === 'string' ? payload : JSON.stringify(payload);
  for (const client of clients) {
    if (client.readyState === client.OPEN) client.send(msg);
  }
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: false });
rl.on('line', (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  try {
    broadcast(JSON.parse(trimmed));
  } catch (error) {
    console.error(`Invalid JSON patch: ${error.message}`);
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`BearBox vibe patch server listening on http/ws://0.0.0.0:${port}`);
});

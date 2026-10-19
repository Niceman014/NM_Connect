import type { WebSocket } from 'ws';

const PROTOCOL_VERSION = 1;

interface Peer {
  socket: WebSocket;
  deviceId: string;
  deviceName: string;
}

/** deviceId -> peer */
const peers = new Map<string, Peer>();

function send(socket: WebSocket, msg: object): void {
  if (socket.readyState === 1 /* OPEN */) {
    socket.send(JSON.stringify(msg));
  }
}

function sendTo(deviceId: string, msg: object): boolean {
  const peer = peers.get(deviceId);
  if (!peer) return false;
  send(peer.socket, msg);
  return true;
}

export function registerSignaling(socket: WebSocket): void {
  console.log('[ws] connection opened');

  socket.on('message', (raw) => {
    let msg: any;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      send(socket, { type: 'error', code: 'invalid-json' });
      return;
    }

    // Version gate
    if (msg.v !== undefined && msg.v !== PROTOCOL_VERSION) {
      send(socket, { type: 'error', code: 'invalid-version', expected: PROTOCOL_VERSION });
      return;
    }

    switch (msg.type) {
      // ── Register ─────────────────────────────────────────
      case 'register': {
        if (typeof msg.deviceId !== 'string' || msg.deviceId.length < 6) {
          send(socket, { type: 'error', code: 'invalid-json', message: 'bad deviceId' });
          return;
        }
        if (peers.has(msg.deviceId)) {
          send(socket, { type: 'error', code: 'id-in-use', to: msg.deviceId });
          return;
        }
        peers.set(msg.deviceId, {
          socket,
          deviceId: msg.deviceId,
          deviceName: String(msg.deviceName ?? 'Unknown'),
        });
        send(socket, { type: 'registered', v: PROTOCOL_VERSION, deviceId: msg.deviceId });
        console.log(`[ws] ${msg.deviceId} registered  (online: ${peers.size})`);
        return;
      }

      // ── Connect request (viewer → server → host) ────────
      case 'connect-request': {
        if (!isRegistered(socket)) return notRegistered(socket);
        const ok = sendTo(msg.to, {
          type: 'connect-request',
          v: PROTOCOL_VERSION,
          from: currentPeer(socket)!.deviceId,
          fromDeviceName: currentPeer(socket)!.deviceName,
        });
        if (!ok) {
          send(socket, { type: 'error', code: 'peer-offline', to: msg.to });
        }
        return;
      }

      // ── Passthrough messages (relay to peer) ────────────
      case 'connect-response':
      case 'offer':
      case 'answer':
      case 'ice':
      case 'bye': {
        if (!isRegistered(socket)) return notRegistered(socket);
        const from = currentPeer(socket)!.deviceId;
        sendTo(msg.to, { ...msg, from, v: PROTOCOL_VERSION });
        return;
      }

      default: {
        send(socket, { type: 'error', code: 'unknown-type', message: String(msg.type) });
      }
    }
  });

  socket.on('close', () => {
    const peer = currentPeer(socket);
    if (peer) {
      peers.delete(peer.deviceId);
      console.log(`[ws] ${peer.deviceId} disconnected  (online: ${peers.size})`);
    }
  });

  socket.on('error', (err) => console.error('[ws] socket error', err));
}

// ── Helpers ──────────────────────────────────────────────
function currentPeer(socket: WebSocket): Peer | undefined {
  for (const p of peers.values()) if (p.socket === socket) return p;
  return undefined;
}

function isRegistered(socket: WebSocket): boolean {
  return currentPeer(socket) !== undefined;
}

function notRegistered(socket: WebSocket): void {
  send(socket, { type: 'error', code: 'not-registered' });
}
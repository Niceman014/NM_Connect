import WebSocket from 'ws';

const URL = 'ws://localhost:8080/ws';

function waitFor(ws, type, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout waiting for ${type}`)), timeoutMs);
    const handler = (raw) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.type === type) {
          clearTimeout(t);
          ws.off('message', handler);
          resolve(msg);
        }
      } catch { /* ignore */ }
    };
    ws.on('message', handler);
  });
}

async function main() {
  const host = new WebSocket(URL);
  const viewer = new WebSocket(URL);
  await Promise.all([
    new Promise(r => host.once('open', r)),
    new Promise(r => viewer.once('open', r)),
  ]);

  host.send(JSON.stringify({ type: 'register', v: 1, deviceId: '111111111', deviceName: 'Host-PC' }));
  console.log('✓ host registered:', await waitFor(host, 'registered'));

  viewer.send(JSON.stringify({ type: 'register', v: 1, deviceId: '222222222', deviceName: 'Viewer-PC' }));
  console.log('✓ viewer registered:', await waitFor(viewer, 'registered'));

  const hostReceive = waitFor(host, 'connect-request');
  viewer.send(JSON.stringify({ type: 'connect-request', v: 1, to: '111111111' }));
  const forward = await hostReceive;
  console.log('✓ host received connect-request:', forward);
  if (forward.from !== '222222222') throw new Error('wrong from field');

  viewer.send(JSON.stringify({ type: 'connect-request', v: 1, to: '999999999' }));
  const offline = await waitFor(viewer, 'error');
  if (offline.code !== 'peer-offline') throw new Error('expected peer-offline');
  console.log('✓ offline peer rejected:', offline);

  host.close();
  viewer.close();
  console.log('\n✅ All signaling tests passed.\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Test failed:', err);
  process.exit(1);
});
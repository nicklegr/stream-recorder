require('date-utils');
const WebSocket = require('ws');

const CHAT = 1
const CONTROL = 2
const AUTH = 3

const space_id = process.argv[2]
const chatAccessToken = process.argv[3]

const ws = new WebSocket(
  'wss://prod-chatman-ancillary-ap-northeast-1.pscp.tv/chatapi/v1/chatnow',
  // 'wss://chatman-replay-ap-northeast-1.pscp.tv/chatapi/v1/chatnow',
  [],
  {
    origin: "https://twitter.com",
    perMessageDeflate: true,
    headers: {'User-Agent': 'ChatMan/1 (Android) '},
  }
);

ws.on('open', () => {
  token = JSON.stringify({
    "access_token": chatAccessToken
  })
  str = JSON.stringify({"payload": token, "kind": 3})
  ws.send(str)

  room = JSON.stringify({"room": space_id})
  body = JSON.stringify({"body": room, "kind": 1})
  str = JSON.stringify({"payload": body, "kind": 2})
  ws.send(str)
});

ws.on('message', (buffer) => {
  msg = JSON.parse(buffer)
  if (msg.kind == CHAT) {
    payload = JSON.parse(msg.payload)
    body = JSON.parse(payload.body)
    if (body.final) {
      const now = new Date(body.timestamp)
      const timeStr = now.toFormat("YYYY/MM/DD HH24:MI:SS")
      const message = `${timeStr}: ${body.username}: ${body.body}`
      console.log(message)
    }
  }
});

ws.on('close', (code, reason) => {
  console.log('close: %d %s', code, reason);
})

ws.on('error', (error) => {
  console.log('error: %s', error);
})

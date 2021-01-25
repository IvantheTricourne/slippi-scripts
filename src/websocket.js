const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8081 });

wss.on('connection', ws => {
    ws.on('message', message => {
        console.log(message);
    });
    ws.send("hello from the src dir");
});

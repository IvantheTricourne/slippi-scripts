const WebSocket = require('ws');
const _ = require('lodash');
const {
    SlpFolderStream,
    SlpRealTime
} = require("@vinceau/slp-realtime");
const OBSWebSocket = require('obs-websocket-js'); // npm install obs-websocket-js
const slp = require('@slippi/slippi-js');

const wss = new WebSocket.Server({
    port: 8081
});
// @TODO make this configurable
const slpLiveFolderPath = "/home/carl/Slippi/";
console.log(`Monitoring ${slpLiveFolderPath} for new SLP files`);
// Connect to the relay
const stream = new SlpFolderStream();
const realtime = new SlpRealTime();
realtime.setStream(stream);

// setup obs websocket
const obs = new OBSWebSocket();
obs.connect({
    // @TODO: make this configurable
    address: "localhost:4444",
    password: "rubielle"
}).then(() => {
    console.log("Connected to OBS.");
}).catch(err => { // Promise convention dicates you have a catch on every chain.
    console.log(err);
});
obs.on('SwitchScenes', data => {
    console.log(`New Active Scene: ${data.sceneName}`);
});
obs.on('error', err => {
    console.error('Unable to connect to obs:', err);
});

function makePayloadMessage(type, payload) {
    return JSON.stringify({
        type,
        payload
    }, null, 2);
}
// setup websocket server
wss.on('connection', ws => {
    ws.on('message', message => {
        console.log(message);
    });
    ws.send(`Watching from ${slpLiveFolderPath}`);
    // realtime stuff
    realtime.game.start$.subscribe((payload) => {
        console.log(`Detected a new game in ${stream.latestFile()}`);
        obs.send('SetCurrentScene', {
            'scene-name': 'gaming'
        });
        const msg = makePayloadMessage("NewGame", payload);
        console.log(msg);
        ws.send(msg);
    });
    realtime.stock.percentChange$.subscribe((payload) => {
        const msg = makePayloadMessage("PercentChange", payload);
        // console.log(msg);
        ws.send(msg);
    });
    realtime.stock.countChange$.subscribe((payload) => {
        const msg = makePayloadMessage("StockChange", payload);
        // console.log(msg);
        ws.send(msg);
    });
    realtime.game.end$.subscribe((payload) => {
        console.log('Game ended!');
        obs.send('SetCurrentScene', {
            'scene-name': 'waiting'
        });
        const msg = makePayloadMessage("EndGame", payload);
        console.log(msg);
        ws.send(msg);
    });
});
// Start monitoring the folder for changes
stream.start(slpLiveFolderPath, true);
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
    // ws.send(`Watching from ${slpLiveFolderPath}`);
    ws.send(makePayloadMessage("NewGame", {
        slpVersion: null,
        isTeams: false,
        isPAL: false,
        stageId: 3,
        players: [{
                playerIndex: 0,
                port: 1,
                characterId: 2,
                characterColor: 0,
                startStocks: 4,
                type: 0,
                teamId: null,
                controllerFix: null,
                nametag: null
            },
            {
                playerIndex: 1,
                port: 2,
                characterId: 9,
                characterColor: 3,
                startStocks: 4,
                type: 0,
                teamId: null,
                controllerFix: null,
                nametag: null
            }
        ]
    }));
    ws.send(makePayloadMessage("CharacterChange", {
        characters: [{
                characterName: slp.characters.getCharacterName(2),
                color: slp.characters.getCharacterColorName(2, 0),
            },
            {
                characterName: slp.characters.getCharacterName(9),
                color: slp.characters.getCharacterColorName(9, 3),
            }
        ]
    }));
    ws.send(makePayloadMessage("PercentChange", {
        playerIndex: 0,
        percent: 420
    }));
    ws.send(makePayloadMessage("PercentChange", {
        playerIndex: 1,
        percent: 69
    }));
    ws.send(makePayloadMessage("StockChange", {
        playerIndex: 0,
        stocksRemaining: 2
    }));
    ws.send(makePayloadMessage("StockChange", {
        playerIndex: 1,
        stocksRemaining: 1
    }));

    // realtime stuff
    realtime.game.start$.subscribe((payload) => {
        console.log(`Detected a new game in ${stream.latestFile()}`);
        obs.send('SetCurrentScene', {
            'scene-name': 'gaming'
        });
        const msg = makePayloadMessage("NewGame", payload);
        const charMsg = makePayloadMessage("CharacterChange",
            _.map(payload.characters, ({
                characterId,
                characterColor
            }) => {
                return {
                    characterName: slp.characters.getCharacterName(characterId),
                    color: slp.characters.getCharacterColorName(characterId, characterColor),
                };
            }));
        console.log(msg);
        ws.send(msg);
        console.log(charMsg);
        ws.send(charMsg);
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
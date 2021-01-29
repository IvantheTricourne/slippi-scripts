const WebSocket = require('ws');
const { SlpFolderStream, SlpRealTime } = require("@vinceau/slp-realtime");
const OBSWebSocket = require('obs-websocket-js'); // npm install obs-websocket-js
const slp = require('@slippi/slippi-js');
const wss = new WebSocket.Server({ port: 8081 });
// @TODO make this configurable
const slpLiveFolderPath = "/home/carl/Slippi/";
console.log(`Monitoring ${slpLiveFolderPath} for new SLP files`);

// Connect to the relay
const stream = new SlpFolderStream();
const realtime = new SlpRealTime();
realtime.setStream(stream);
// some helpers
function newPlayerInfo() {
    return {
        1: { percent: 0,
             stocks: null,
             character: null,
             nametag: null
           },
        2: { percent: 0,
             stocks: null,
             character: null,
             nametag: null
           }
    };
}
function showStocks(stockCount) {
    return "o".repeat(stockCount);
}
function showPlayerInfo(playerInfo) {
    return `P1 (${playerInfo[1].character.color} ${playerInfo[1].character.characterName}) ${playerInfo[1].percent}% - P2 (${playerInfo[2].character.color} ${playerInfo[2].character.characterName}) ${playerInfo[2].percent}%\n
${showStocks(playerInfo[1].stocks)} - ${showStocks(playerInfo[2].stocks)}
`;
}
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

// setup websocket server
wss.on('connection', ws => {
    ws.on('message', message => {
        console.log(message);
    });
    ws.send(`Watching from ${slpLiveFolderPath}`);
    let playerInfo = newPlayerInfo();
    // realtime stuff
    realtime.game.start$.subscribe((payload) => {
        console.log(`Detected a new game in ${stream.latestFile()}`);
        playerInfo = newPlayerInfo();
        playerInfo[1].stocks = payload.players[0].startStocks;
        playerInfo[1].character = {
            characterName: slp.characters.getCharacterName(payload.players[0].characterId),
            color: slp.characters.getCharacterColorName(payload.players[0].characterId, payload.players[1].characterColor)
        };
        playerInfo[1].nametag = payload.players[0].nametag;
        playerInfo[2].stocks = payload.players[1].startStocks;
        playerInfo[2].character = {
            characterName: slp.characters.getCharacterName(payload.players[1].characterId),
            color: slp.characters.getCharacterColorName(payload.players[1].characterId, payload.players[1].characterColor)
        };
        playerInfo[2].nametag = payload.players[1].nametag;
        obs.send('SetCurrentScene', {
            'scene-name': 'gaming'
        });
    });
    realtime.stock.percentChange$.subscribe((payload) => {
        const player = payload.playerIndex + 1;
        playerInfo[player].percent = payload.percent.toFixed(0);
        // console.log(`player ${player} percent: ${payload.percent.toFixed(0)}`);
        ws.send(showPlayerInfo(playerInfo));
    });
    realtime.stock.countChange$.subscribe((payload) => {
        const player = payload.playerIndex + 1;
        playerInfo[player].stocks = payload.stocksRemaining;
        // console.log(`player ${player} stocks: ${payload.stocksRemaining}`);
        ws.send(showPlayerInfo(playerInfo));
    });
    realtime.game.end$.subscribe((payload) => {
        console.log('Game ended!');
        let winnerIdx = payload.winnerPlayerIndex + 1;
        if (playerInfo[winnerIdx].nametag !== "") {
            ws.send(`${playerInfo[winnerIdx].nametag} wins!`);
        } else {
            ws.send(`Player ${winnerIdx} wins!`);
        }
        obs.send('SetCurrentScene', {
            'scene-name': 'waiting'
        });
    });
});
// Start monitoring the folder for changes
stream.start(slpLiveFolderPath, true);

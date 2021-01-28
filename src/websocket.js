const WebSocket = require('ws');
const { SlpFolderStream, SlpRealTime } = require("@vinceau/slp-realtime");

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
        1: { stocks: 4,
             percent: 0
           },
        2: { stocks: 4,
             percent: 0
           }
    };
}
function showStocks(stockCount) {
    return "o".repeat(stockCount);
}
function showPlayerInfo(playerInfo) {
    return `P1 ${playerInfo[1].percent}% - P2 ${playerInfo[2].percent}%\n
${showStocks(playerInfo[1].stocks)} - ${showStocks(playerInfo[2].stocks)}
`;
}
// setup websocket
wss.on('connection', ws => {
    ws.on('message', message => {
        console.log(message);
    });
    ws.send(`Watching from ${slpLiveFolderPath}`);
    let playerInfo = newPlayerInfo();
    // realtime stuff
    realtime.game.start$.subscribe(() => {
        console.log(`Detected a new game in ${stream.latestFile()}`);
        playerInfo = newPlayerInfo();
        ws.send('NEW GAME');
    });
    realtime.stock.percentChange$.subscribe((payload) => {
        const player = payload.playerIndex + 1;
        playerInfo[player].percent = payload.percent.toFixed(0);
        console.log(`player ${player} percent: ${payload.percent.toFixed(0)}`);
        ws.send(showPlayerInfo(playerInfo));
    });
    realtime.stock.countChange$.subscribe((payload) => {
        const player = payload.playerIndex + 1;
        playerInfo[player].stocks = payload.stocksRemaining;
        console.log(`player ${player} stocks: ${payload.stocksRemaining}`);
        ws.send(showPlayerInfo(playerInfo));
    });
    realtime.game.end$.subscribe(() => {
        ws.send('GAME END');
    });
});
// Start monitoring the folder for changes
stream.start(slpLiveFolderPath, true);

const WebSocket = require('ws');
const { SlpFolderStream, SlpRealTime } = require("@vinceau/slp-realtime");
const slp = require('@slippi/slippi-js');
const SlippiGame = slp.default;

const wss = new WebSocket.Server({ port: 8081 });
const chokidar = require('chokidar');
const listenPath = "/Users/carl/Slippi/2021-01";
const watcher = chokidar.watch(listenPath, {
    depth: 0,
    persistent: true,
    usePolling: true,
    ignoreInitial: true,
});

const slpLiveFolderPath = "/Users/carl/Slippi/";
console.log(`Monitoring ${slpLiveFolderPath} for new SLP files`);

// Connect to the relay
const stream = new SlpFolderStream();
const realtime = new SlpRealTime();
realtime.setStream(stream);

// // realtime stuff
// realtime.game.start$.subscribe(() => {
//     console.log(`Detected a new game in ${stream.latestFile()}`);
//     // wss.send('NEW GAME');
// });
// realtime.stock.percentChange$.subscribe((payload) => {
//     const player = payload.playerIndex + 1;
//     console.log(`player ${player} percent: ${payload.percent}`);
//     // wss.send(`Player ${player} got hit: ${payload.percent.toFixed(0)}%`);
// });
// realtime.stock.countChange$.subscribe((payload) => {
//     const player = payload.playerIndex + 1;
//     console.log(`player ${player} stocks: ${payload.stocksRemaining}`);
//     // wss.send(`Player ${player} lost a stock: ${payload.stocksRemaining}`);
// });
// realtime.game.end$.subscribe(() => {
//     console.log('game ended');
//     // wss.send('GAME END');
// });

wss.on('connection', ws => {
    ws.on('message', message => {
        console.log(message);
    });
    ws.send(`Watching from ${listenPath}`);
    // const gameByPath = {};
    // watcher.on("change", (path) => {
    //     const start = Date.now();

    //     let gameState, settings, stats, frames, latestFrame, gameEnd;
    //     try {
    //         let game = _.get(gameByPath, [path, "game"]);
    //         if (!game) {
    //             console.log(`New file at: ${path}`);
    //             // Make sure to enable `processOnTheFly` to get updated stats as the game progresses
    //             game = new SlippiGame(path, { processOnTheFly: true });
    //             gameByPath[path] = {
    //                 game: game,
    //                 state: {
    //                     settings: null,
    //                     detectedPunishes: {},
    //                 },
    //             };
    //         }

    //         gameState = _.get(gameByPath, [path, "state"]);

    //         settings = game.getSettings();

    //         // You can uncomment the stats calculation below to get complex stats in real-time. The problem
    //         // is that these calculations have not been made to operate only on new data yet so as
    //         // the game gets longer, the calculation will take longer and longer
    //         // stats = game.getStats();

    //         frames = game.getFrames();
    //         latestFrame = game.getLatestFrame();
    //         gameEnd = game.getGameEnd();
    //     } catch (err) {
    //         console.log(err);
    //         return;
    //     }

    //     if (!gameState.settings && settings) {
    //         console.log(`[Game Start] New game has started`);
    //         console.log(settings);
    //         gameState.settings = settings;
    //     }

    //     console.log(`We have ${_.size(frames)} frames.`);
    //     _.forEach(settings.players, (player) => {
    //         const frameData = _.get(latestFrame, ["players", player.playerIndex]);
    //         if (!frameData) {
    //             return;
    //         }

    //         console.log(
    //             `[Port ${player.port}] ${frameData.post.percent.toFixed(1)}% | ` + `${frameData.post.stocksRemaining} stocks`,
    //         );
    //     });

    //     // Uncomment this if you uncomment the stats calculation above. See comment above for details
    //     // // Do some conversion detection logging
    //     // // console.log(stats);
    //     // _.forEach(stats.conversions, conversion => {
    //     //   const key = `${conversion.playerIndex}-${conversion.startFrame}`;
    //     //   const detected = _.get(gameState, ['detectedPunishes', key]);
    //     //   if (!detected) {
    //     //     console.log(`[Punish Start] Frame ${conversion.startFrame} by player ${conversion.playerIndex + 1}`);
    //     //     gameState.detectedPunishes[key] = conversion;
    //     //     return;
    //     //   }

    //     //   // If punish was detected previously, but just ended, let's output that
    //     //   if (!detected.endFrame && conversion.endFrame) {
    //     //     const dmg = conversion.endPercent - conversion.startPercent;
    //     //     const dur = conversion.endFrame - conversion.startFrame;
    //     //     console.log(
    //     //       `[Punish End] Player ${conversion.playerIndex + 1}'s punish did ${dmg} damage ` +
    //     //       `with ${conversion.moves.length} moves over ${dur} frames`
    //     //     );
    //     //   }

    //     //   gameState.detectedPunishes[key] = conversion;
    //     // });

    //     if (gameEnd) {
    //         // NOTE: These values and the quitter index will not work until 2.0.0 recording code is
    //         // NOTE: used. This code has not been publicly released yet as it still has issues
    //         const endTypes = {
    //             1: "TIME!",
    //             2: "GAME!",
    //             7: "No Contest",
    //         };

    //         const endMessage = _.get(endTypes, gameEnd.gameEndMethod) || "Unknown";

    //         const lrasText = gameEnd.gameEndMethod === 7 ? ` | Quitter Index: ${gameEnd.lrasInitiatorIndex}` : "";
    //         console.log(`[Game Complete] Type: ${endMessage}${lrasText}`);
    //     }

    //     console.log(`Read took: ${Date.now() - start} ms`);
    // });

    // realtime stuff
    realtime.game.start$.subscribe(() => {
        console.log(`Detected a new game in ${stream.latestFile()}`);
        ws.send('NEW GAME');
    });
    realtime.stock.percentChange$.subscribe((payload) => {
        const player = payload.playerIndex + 1;
        console.log(`player ${player} percent: ${payload.percent}`);
        ws.send(`Player ${player} got hit: ${payload.percent.toFixed(0)}%`);
    });
    realtime.stock.countChange$.subscribe((payload) => {
        const player = payload.playerIndex + 1;
        console.log(`player ${player} stocks: ${payload.stocksRemaining}`);
        ws.send(`Player ${player} lost a stock: ${payload.stocksRemaining}`);
    });
    realtime.game.end$.subscribe(() => {
        ws.send('GAME END');
    });
});
// Start monitoring the folder for changes
stream.start(slpLiveFolderPath, true);

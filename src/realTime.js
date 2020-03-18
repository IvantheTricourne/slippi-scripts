const { default: SlippiGame } = require('slp-parser-js');
const path = require('path');
const chokidar = require('chokidar');
const _ = require('lodash');
const Multispinner = require('multispinner');
const player = require('node-wav-player');

// taunting
const { playerIsTaunting } = require('./getTaunts.js');
var chadCityGameState =
    {
        // player states
        '1': { 'lastTaunt': -123,
               'stocks': 4,
               'points': 0,
               'opponent': 2
             },
        '2': { 'lastTaunt': -123,
               'stocks': 4,
               'points': 0,
               'opponent': 1
             },
        // length of chad buffer (in frames)
        'chadBuffer': 600
    };

function resetChadState() {
    chadCityGameState['1'].lastTaunt = -123;
    chadCityGameState['1'].points = 0;
    chadCityGameState['2'].lastTaunt = -123;
    chadCityGameState['2'].points = 0;
}

function withinChadBuffer(latestFrameNumber, lastTauntFrameNumber) {
    if (lastTauntFrameNumber > 0) {
        return latestFrameNumber - lastTauntFrameNumber <= chadCityGameState.chadBuffer;
    } else {
        return false;
    }
}

const resourceDir = path.join(process.cwd(), 'rsrc');
function crowdGasp() {
    player.play({
        path: `${resourceDir}/gasp.wav`,
    }).catch((error) => {
        console.error(error);
    });
}

function patrickScream() {
    player.play({
        path: `${resourceDir}/patrick-scream.wav`,
    }).catch((error) => {
        console.error(error);
    });
}

function crowdCheer() {
    player.play({
        path: `${resourceDir}/cheer.wav`,
    }).catch((error) => {
        console.error(error);
    });
}

function planktonYes() {
    player.play({
        path: `${resourceDir}/come-to-papa.wav`,
    }).catch((error) => {
        console.error(error);
    });
}

function finishHim() {
    player.play({
        path: `${resourceDir}/finish-him.wav`,
    }).catch((error) => {
        console.error(error);
    });
}

const listenPath = process.argv[2];
console.log(`Listening at: ${listenPath}`);

const watcher = chokidar.watch(listenPath, {
    depth: 0,
    persistent: true,
    usePolling: true,
    ignoreInitial: true,
});

// @NOTE: this is basically the view state of the mini-game
var multispinner = new Multispinner(
    // spinners
    {
        // TODO make this port sensitive
        '1': 'Waiting for game',
        '2': 'Waiting for game',
        // 'frames': 'Waiting for game',
        'lag': 'Waiting for game'
    },
    // options
    {
        'frames': ['⬡']
    });

const gameByPath = {};
watcher.on('change', (path) => {
    const start = Date.now();

    let gameState, settings, stats, frames, latestFrame, gameEnd;
    try {
        let game = _.get(gameByPath, [path, 'game']);
        if (!game) {
            game = new SlippiGame(path);
            gameByPath[path] = {
                game: game,
                state: {
                    settings: null,
                    detectedPunishes: {},
                }
            };
        }

        gameState = _.get(gameByPath, [path, 'state']);
        settings = game.getSettings();

        frames = game.getFrames();
        latestFrame = game.getLatestFrame();
        gameEnd = game.getGameEnd();
    } catch (err) {
        console.log(err);
        return;
    }

    // reset when new game
    if (!gameState.settings && settings) {
        resetChadState();
        gameState.settings = settings;
    }

    // multispinner.spinners['frames']['text'] = `Frames: ${_.size(frames)}`;
    _.forEach(settings.players, player => {
        let pIdx = player.port.toString();
        const frameData = _.get(latestFrame, ['players', player.playerIndex]);
        // @NOTE: FUCKING INDEXES!!!
        const oppData = _.get(latestFrame, ['players', chadCityGameState[pIdx].opponent - 1]);
        if (!frameData && !oppData) {
            return;
        }

        // maybe update chad scores
        let playerTaunted = playerIsTaunting(frameData),
            within = withinChadBuffer(frameData.post.frame, chadCityGameState[pIdx]['lastTaunt']),
            playerCurrStock = frameData.post.stocksRemaining;
        if (within) {
            let opponentCurrStock = oppData.post.stocksRemaining,
                opponentLastStock = chadCityGameState[chadCityGameState[pIdx].opponent].stocks,
                playerLastStock = chadCityGameState[pIdx].stocks;

            if (opponentCurrStock < opponentLastStock) {
                planktonYes();
                chadCityGameState[pIdx].points += (opponentLastStock - opponentCurrStock);
            }
            if (playerCurrStock < playerLastStock) {
                patrickScream();
                chadCityGameState[pIdx].points -= (playerLastStock - playerCurrStock);
            }
        }

        // update game state
        if (playerTaunted && !within) {
            finishHim();
            chadCityGameState[pIdx]['lastTaunt'] = frameData.post.frame;
        }
        chadCityGameState[pIdx]['stocks'] = playerCurrStock;
        // update game view state
        multispinner.spinners[pIdx]['text'] =
            `[Port ${player.port}] ` +
            // `${frameData.post.percent.toFixed(1)}% | ` +
            // `${frameData.post.stocksRemaining} stocks | ` +
            `${chadCityGameState[pIdx]['points']} chadPoints` +
            `${within ? ' <<CHAD MODE ENABLED>>':''}`;
    });
    multispinner.spinners['lag']['text'] = `${Date.now() - start} ms`;
});

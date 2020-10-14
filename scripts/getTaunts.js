const path = require('path');
const _ = require('lodash');
const slp = require('slp-parser-js');
const SlippiGame = slp.default;

////////////////////////////////////////////////////////////

function actionStateIsTauntingLeftOrRight({actionStateId}) {
    return actionStateId === 0x108 || actionStateId === 0x109;
}

function playerIsTaunting(player) {
    let { pre, post } = player;
    return actionStateIsTauntingLeftOrRight(pre) || actionStateIsTauntingLeftOrRight(post);
}

function frameHasTaunting(frame) {
    let { players } = frame;
    return _.some(players, playerIsTaunting);
}

function getTaunterFromFrame(frame) {
    let { players } = frame;
    return _.find(players, playerIsTaunting);
}

function identifyPlayer(playersSettings, playersMetadata, playerIndex) {
    let playerSetting = _.get(playersSettings, playerIndex),
        playerMetadata = _.get(playersMetadata, playerIndex);
    return { "name": playerMetadata.names.netplay || playerSetting.nametag || "No Name",
             "characterName": slp.characters.getCharacterInfo(playerSetting.characterId).name,
             "color": slp.characters.getCharacterColorName(playerSetting.characterId, playerSetting.characterColor),
             "port": playerSetting.port
           };
}
////////////////////////////////////////////////////////////

// // get game from commandline (relative to this script)
// const gameArg = path.join(process.cwd(), process.argv[2]);
// const game = new SlippiGame(gameArg);


// const { players: playersSettings } = game.getSettings();
// const { players: playersMetadata } = game.getMetadata();
// const frames = game.getFrames();

// let tauntFrames = _.filter(frames, frameHasTaunting),
//     firstFrame = _.head(tauntFrames),
//     lastFrame = _.last(tauntFrames),
//     taunter = getTaunterFromFrame(firstFrame),
//     taunterIndex = taunter.pre.playerIndex,
//     { name, characterName, color, port } = identifyPlayer(taunterIndex);

// console.log(`${name} (P${port}) playing ${color} ${characterName} taunted (frame ${firstFrame.frame} - ${lastFrame.frame})`);

////////////////////////////////////////////////////////////
// exports
exports.actionStateIsTauntingLeftOrRight = actionStateIsTauntingLeftOrRight;
exports.playerIsTaunting = playerIsTaunting;

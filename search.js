const {
    withGamesFromDir,
    isValidGame,
    withMatchingFrames,
    sortedFrames
} = require("slippi-search");
const { stages, externalCharacters } = require("slp-parser-js");
const path = require('path');
const basePath = path.join(__dirname, "./Slippi");

// Define game criteria
const gameCriteria = {
    // stageId: [stages.STAGE_BATTLEFIELD, stages.STAGE_DREAM_LAND],
    stageId: [stages.STAGE_BATTLEFIELD],
    // players: [
    //     {
    //         characterId: [0, 20] // Captain Falcon, Falco
    //     },
    //     {
    //         characterId: [19] // Sheik
    //     }
    // ],
    players: [{characterId: [2]}, {characterId: [20]}],
    isPAL: [false, true], // Can also just omit
    isTeams: [false]
};

// Define frame criteria
const frameCriteria = {
    players: [
        {
            pre: {
                playerIndex: [1],
                percent: [[10, 20]], // Between 10 and 20 percent
                facingDirection: [-1]
            }
        }
    ]
};

const validGames = [];
const validFrames = [];

// With each game in the directory
withGamesFromDir(basePath, game => {
    // Check that game matches criteria
    if (isValidGame(game, gameCriteria)) {
        validGames.push(game);

        // // With each frame that matches criteria
        // withMatchingFrames(sortedFrames(game), frameCriteria, frame => {
        //     validFrames.push(frame);

        //     // Print info about players in frame
        //     console.log(frame.players);
        // });
    }
});

console.log(validGames.forEach(({input}) => {console.log(input.filePath);}));

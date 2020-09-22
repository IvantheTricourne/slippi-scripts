const { walk } = require('./utils.js');
const _ = require('lodash');
const path = require('path');
const fs = require('fs');
const slp = require('slp-parser-js');
const SlippiGame = slp.default; // npm install slp-parser-js
const yargs = require('yargs'); // npm install yargs

const argv = yargs
      .scriptName("getGamesOnDate")
      .usage('$0 [args]')
      // input/output options
      .option('dir', {
          alias: 'd',
          description: 'Slippi directory to use',
          type: 'string',
          default: './Slippi'
      })
      .option('players', {
          alias: 'p',
          description: 'Get only games from specified players (enter at least 2 names)',
          type: 'array',
          default: []
      })
      .help()
      .alias('help', 'h')
      .argv;

const basePath = path.join(process.cwd(), argv.dir);
let files = walk(basePath);
console.log(`${files.length} files found in target directory`);
var player0Info = {};
var player1Info = {};
var currPlayers = null;

// create player info object
function makePlayerInfo(idx, settings, metadata) {
    let player = _.get(settings, ["players", idx]);
    return {
      	port: player.port,
        tag: player.nametag,
        netplayName: _.get(metadata, ["players", idx, "names", "netplay"], null) || "No Name",
        rollbackCode: _.get(metadata, ["players", idx, "names", "code"], null) || "n/a",
      	characterName: slp.characters.getCharacterName(player.characterId),
      	color: slp.characters.getCharacterColorName(player.characterId, player.characterColor),
        idx: idx
    };
}
// get most used move
function getMostUsedMove(arr) {
    var mf = 1;
    var m = 0;
    var item;
    for (var i=0; i<arr.length; i++) {
        for (var j=i; j<arr.length; j++) {
            if (arr[i] == arr[j])
                m++;
            if (mf<m) {
                mf=m;
                item = arr[i];
            }
        }
        m=0;
    }
    return { moveName: item,
             timesUsed: mf
           };
}
// associated saga icon / character
const characterSagaDict = {
    "Fox": "Star Fox",
    "Falco": "Star Fox",
    "Jigglypuff": "Pokemon",
    "Pikachu": "Pokemon",
    "Mewtwo": "Pokemon",
    "Pichu": "Pokemon",
    "Captain Falcon": "F-Zero",
    "Donkey Kong": "Donkey Kong",
    "Mr. Game & Watch": "Mr Game & Watch",
    "Kirby": "Kirby",
    "Bowser": "Mario",
    "Link": "Zelda",
    "Luigi": "Mario",
    "Mario": "Mario",
    "Marth": "Fire Emblem",
    "Ness": "Mother",
    "Peach": "Mario",
    "Ice Climbers": "Ice Climbers",
    "Samus": "Metroid",
    "Yoshi": "Yoshi",
    "Zelda": "Zelda",
    "Sheik": "Zelda",
    "Young Link": "Zelda",
    "Dr. Mario": "Mario",
    "Roy": "Fire Emblem",
    "Ganondorf": "Zelda"
};
function getSagaIconName(statsJson) {
    let player0Kills = statsJson.playerStats[0].kills;
    let player1Kills = statsJson.playerStats[1].kills;
    // determine who had the most kill
    if (player0Kills > player1Kills) {
        return characterSagaDict[statsJson.players[0].characterName];
    } else if (player1Kills > player0Kills) {
        return characterSagaDict[statsJson.players[1].characterName];
    } else {
        // return the smash logo when its a tie/indeterminate
        return "Smash";
    }
}
var statsJson = {
    "totalGames": 0,
    "stages": [],
    "wins": [],
    "totalLengthSeconds": 0,
    "players": null,
    "playerStats": [
        { "totalDamage": 0,
          "neutralWins": 0,
          "counterHits": 0,
          "kills": 0
        },
        { "totalDamage": 0,
          "neutralWins": 0,
          "counterHits": 0,
          "kills": 0
        }
    ]
};
var playerTotals = [
    { "apms": 0,
      "openingsPerKills": 0,
      "damagePerOpenings": 0,
      "moves": [],
      "killMoves": []
    },
    { "apms": 0,
      "openingsPerKills": 0,
      "damagePerOpenings": 0,
      "moves": [],
      "killMoves": []
    }
];
_.each(files, (file, i) => {
    try {
        const game = new SlippiGame(file);
        // since it is less intensive to get the settings we do that first
        const settings = game.getSettings();
        const metadata = game.getMetadata();
        const gameDate = new Date(metadata.startAt);
        // calculate game length in seconds
        const gameLength = metadata.lastFrame / 60;
      	// padded game length (w/ ready splash + black screen)
      	let paddedGameLength = (metadata.lastFrame + 123) / 60;
        // filter out games by players
        let player0 = makePlayerInfo(0, settings, metadata);
        let player1 = makePlayerInfo(1, settings, metadata);
        if (argv.players.length !== 0) {
            let namesLowercased = Object.values(argv.players).map(x => x.toLowerCase());
            ({tag, netplayName, rollbackCode} = player0);
            let player0Ids = [tag, netplayName, rollbackCode, rollbackCode.split('#').shift()].map(x => x.toLowerCase());
            ({tag, netplayName, rollbackCode} = player1);
            let player1Ids = [tag, netplayName, rollbackCode, rollbackCode.split('#').shift()].map(x => x.toLowerCase());
            if (!player0Ids.some(x => namesLowercased.includes(x)) ||
                !player1Ids.some(x => namesLowercased.includes(x))) {
                console.log(`File ${i+1} | Game excluded: No id from list [${argv.players}] found`);
                return;
            } else {
                player0Info = player0;
                player1Info = player1;
            }
        } else {
            player0Info = player0;
            player1Info = player1;
        }
        // Get stats after filtering is done (bc it slows things down a lot)
        const stats = game.getStats();
        // determine whether to keep the game
        let totalKills = 0;
        _.each(stats.overall, (playerStats, i) => {
            totalKills += playerStats.killCount;
        });
        if (gameLength < 60 && totalKills < 3) {
            console.log(`File ${i+1} | Game excluded: <60secs + <3 kills`);
            return;
        }
        // get moves from conversions and combos
        _.each(stats.combos.concat(stats.conversions), (combo, i) => {
            let namedMoves = combo.moves.map(move => slp.moves.getMoveShortName(move.moveId));
            playerTotals[combo.playerIndex].moves = playerTotals[combo.playerIndex].moves.concat(namedMoves);
            if (combo.didKill) {
                let killingMove = namedMoves[namedMoves.length - 1];
                playerTotals[combo.playerIndex].killMoves.push(killingMove);
            }
        });
        // write the stats to file
        _.each(stats.overall, (playerStats, i) => {
            // sum things
            statsJson.playerStats[i].totalDamage += playerStats.totalDamage;
            statsJson.playerStats[i].neutralWins += playerStats.neutralWinRatio.count;
            statsJson.playerStats[i].counterHits += playerStats.counterHitRatio.count;
            statsJson.playerStats[i].kills += playerStats.killCount;
            // avg things
            playerTotals[i].apms += playerStats.inputsPerMinute.ratio;
            playerTotals[i].openingsPerKills += playerStats.openingsPerKill.ratio;
            playerTotals[i].damagePerOpenings += playerStats.damagePerOpening.ratio;
        });
        // track stages, winner, total games and set length
        statsJson.stages.push(slp.stages.getStageName(settings.stageId));
         statsJson.totalGames += 1;
        statsJson.totalLengthSeconds += paddedGameLength;
    } catch (err) {
        fs.appendFileSync("./get-stats-log.txt", `${err.stack}\n\n`);
        console.log(`File ${i+1} | Error processing ${file}`);
    }
});
// warn if no games were found
if (statsJson.totalGames === 0) {
    console.log("WARNING: No games found!");
} else {
    console.log(`Found ${statsJson.totalGames} games.`);
}
// write player info
statsJson.players = [player0Info, player1Info];
// determine which saga icon to use
statsJson.sagaIcon = getSagaIconName(statsJson);
// write avgs
let totalGames = statsJson.totalGames;
_.each(playerTotals, (totals, i) => {
    // console.log(totals);
    statsJson.playerStats[i].avgApm = totals.apms / totalGames;
    statsJson.playerStats[i].avgOpeningsPerKill = totals.openingsPerKills / totalGames;
    statsJson.playerStats[i].avgDamagePerOpening = totals.damagePerOpenings / totalGames;
    statsJson.playerStats[i].favoriteMove = getMostUsedMove(totals.moves);
    statsJson.playerStats[i].favoriteKillMove = getMostUsedMove(totals.killMoves);
});
fs.writeFileSync("./stats.json", JSON.stringify(statsJson));

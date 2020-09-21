const { walk } = require('./utils.js');
const _ = require('lodash');
const path = require('path');
const fs = require('fs');
const slp = require('slp-parser-js');
const SlippiGame = slp.default; // npm install slp-parser-js
const yargs = require('yargs'); // npm install yargs

const argv = yargs
      .scriptName("getGamesOnDate")
      .usage('$0 <cmd> [args]')
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
      	characterName: slp.characters.getCharacterShortName(player.characterId),
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
var statsJson = {
    "totalGames": 0,
    "stages": [],
    "totalLengthSeconds": 0,
    "players": null,
    "playerStats": [
        { "totalDamage": 0,
          "neutralWins": 0,
          "counterHits": 0
        },
        { "totalDamage": 0,
          "neutralWins": 0,
          "counterHits": 0
        }
    ]
};
var playerTotals = [
    { "apms": 0,
      "openingsPerKills": 0,
      "damagePerOpenings": 0,
      "moves": []
    },
    { "apms": 0,
      "openingsPerKills": 0,
      "damagePerOpenings": 0,
      "moves": []
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
        _.each(stats.conversions, (conversion, i) => {
            let namedMoves = conversion.moves.map(x => slp.moves.getMoveShortName(x.moveId));
            playerTotals[conversion.playerIndex].moves = playerTotals[conversion.playerIndex].moves.concat(namedMoves);
        });
        _.each(stats.combos, (combo, i) => {
            let namedMoves = combo.moves.map(x => slp.moves.getMoveShortName(x.moveId));
            playerTotals[combo.playerIndex].moves = playerTotals[combo.playerIndex].moves.concat(namedMoves);
        });
        // write the stats to file
        _.each(stats.overall, (playerStats, i) => {
            // console.log(playerStats);
            // sum things
            statsJson.playerStats[i].totalDamage += playerStats.totalDamage;
            statsJson.playerStats[i].neutralWins += playerStats.neutralWinRatio.count;
            statsJson.playerStats[i].counterHits += playerStats.counterHitRatio.count;
            // avg things
            playerTotals[i].apms += playerStats.inputsPerMinute.ratio;
            playerTotals[i].openingsPerKills += playerStats.openingsPerKill.ratio;
            playerTotals[i].damagePerOpenings += playerStats.damagePerOpening.ratio;
        });
        // track stages, total games and set length
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
// write avgs
let totalGames = statsJson.totalGames;
_.each(playerTotals, (totals, i) => {
    // console.log(totals);
    statsJson.playerStats[i].avgApm = totals.apms / totalGames;
    statsJson.playerStats[i].avgOpeningsPerKill = totals.openingsPerKills / totalGames;
    statsJson.playerStats[i].avgDamagePerOpening = totals.damagePerOpenings / totalGames;
    statsJson.playerStats[i].favoriteMove = getMostUsedMove(totals.moves);
});
fs.writeFileSync("./stats.json", JSON.stringify(statsJson));

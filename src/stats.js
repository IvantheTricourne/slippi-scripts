const _ = require('lodash');
const path = require('path');
const fs = require('fs');
const slp = require('slp-parser-js');
const SlippiGame = slp.default; // npm install slp-parser-js

// create player info object
function makePlayerInfo(idx, settings, metadata) {
    let player = _.get(settings, ["players", idx]);
    return {
      	port: player.port,
        tag: player.nametag,
        netplayName: _.get(metadata, ["players", idx, "names", "netplay"], null) || "No Name",
        rollbackCode: _.get(metadata, ["players", idx, "names", "code"], null) || "n/a",
        character: {
            characterName: slp.characters.getCharacterName(player.characterId),
            color: slp.characters.getCharacterColorName(player.characterId, player.characterColor),
        },
        characters: [],
        idx: idx
    };
}
// determine if action state represents player in dead state
const deadStates = [ 0x000, 0x001, 0x002, 0x003, 0x004, 0x005,
                     0x006, 0x007, 0x008, 0x009, 0x009, 0x00A
                   ];
function playerIsDead(playerFrame) {
    return (deadStates.includes(playerFrame.pre.actionStateId) ||
            deadStates.includes(playerFrame.post.actionStateId)
           );
}
// determine who won the game by determining who died when the game ended
function getGameWinner(game, player0, player1) {
    let latestFrame = game.getLatestFrame();
    let player0Frame = latestFrame.players[0];
    let player1Frame = latestFrame.players[1];
    let noOneWins = {
      	port: 5,
        tag: "",
        netplayName: "No Name",
        rollbackCode: "n/a",
      	character: {
            characterName: "Wireframe",
            color: "Default"
        },
        characters: [],
        idx: 5
    };
    if (playerIsDead(player0Frame) && playerIsDead(player1Frame)) {
        // both players died
        return noOneWins;
    } else if (playerIsDead(player0Frame)) {
        // player 0 lost
        return player1;
    } else if (playerIsDead(player1Frame)) {
        // player 1 lost
        return player0;
    } else {
        // game didn't end with a death
        return noOneWins;
    }
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
            if (mf<=m) {
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
// get most used char
function getMostUsedChar(arr) {
    var mf = 1;
    var m = 0;
    var item;
    if (arr.length === 1) {
        return { character: arr[0],
                 timesUsed: mf
               };
    }
    for (var i=0; i<arr.length; i++) {
        for (var j=i; j<arr.length; j++) {
            if (_.isEqual(arr[i],arr[j]))
                m++;
            if (mf<=m) {
                mf=m;
                item = arr[i];
            }
        }
        m=0;
    }
    return { character: item,
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
    let player0Wins = 0;
    let player1Wins = 0;
    _.each(statsJson.games, (game, i) => {
        let player = game.winner;
        if (player.idx === 0) {
            player0Wins += 1;
        } else {
            player1Wins += 1;
        }
    });
    if (player0Wins > player1Wins) {
        return characterSagaDict[statsJson.players[0].character.characterName];
    } else if (player1Wins > player0Wins) {
        return characterSagaDict[statsJson.players[1].character.characterName];
    } else if (player0Kills > player1Kills) {  // determine who had the most kills
        return characterSagaDict[statsJson.players[0].character.characterName];
    } else if (player1Kills > player0Kills) {
        return characterSagaDict[statsJson.players[1].character.characterName];
    } else {
        // return the smash logo when its a tie/indeterminate
        console.log("Set winner indeterminate!");
        return "Smash";
    }
}

function getStats(files, players = []) {
    var player0Info = {};
    var player0Chars = [];
    var player1Info = {};
    var player1Chars = [];
    var statsJson = {
        "totalGames": 0,
        "games": [],
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
            // purely for the script usage
            if (players.length !== 0) {
                let namesLowercased = Object.values(players).map(x => x.toLowerCase());
                ({tag, netplayName, rollbackCode} = player0);
                let player0Ids = [tag, netplayName, rollbackCode, rollbackCode.split('#').shift()]
                    .map(x => x.toLowerCase());
                ({tag, netplayName, rollbackCode} = player1);
                let player1Ids = [tag, netplayName, rollbackCode, rollbackCode.split('#').shift()]
                    .map(x => x.toLowerCase());
                if (!player0Ids.some(x => namesLowercased.includes(x)) ||
                    !player1Ids.some(x => namesLowercased.includes(x))) {
                    console.log(`File ${i+1} | Game excluded: No id from list [${players}] found`);
                    return;
                }
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
            // write first player info
            player0Info = player0;
            player1Info = player1;
            // track char info
            player0Chars.push(player0.character);
            player1Chars.push(player1.character);
            // get moves from conversions and combos
            _.each(stats.combos.concat(stats.conversions), (combo, i) => {
                let namedMoves = combo.moves.map(move => slp.moves.getMoveShortName(move.moveId));
                playerTotals[combo.playerIndex].moves = playerTotals[combo.playerIndex]
                    .moves
                    .concat(namedMoves);
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
            statsJson.games.push({ stage: slp.stages.getStageName(settings.stageId),
                                   winner: getGameWinner(game, player0, player1),
                                   players: [player0, player1],
                                   // @NOTE: this field is not used by the frontend (yet)
                                   date: gameDate
                                 });
            statsJson.totalGames += 1;
            statsJson.totalLengthSeconds += paddedGameLength;
        } catch (err) {
            fs.appendFileSync("./get-stats-log.txt", `${err.stack}\n\n`);
            console.log(`File ${i+1} | Error processing ${file}`);
        }
    });
    // warn if no games were found
    if (statsJson.totalGames === 0) {
        console.log("WARNING: No valid games found!");
    } else {
        console.log(`Found ${statsJson.totalGames} games.`);
    }
    // sort games in case files were uploaded out of order
    statsJson.games.sort((a,b) => a.date - b.date);
    // console.log(JSON.stringify(statsJson.games, null, 2));
    // write player info
    statsJson.players = [player0Info, player1Info];
    // console.log(JSON.stringify(statsJson.players, null, 2));
    // handle chars
    // console.log(JSON.stringify(statsJson.players, null, 2));
    _.each([player0Chars, player1Chars], (playerChars, i) => {
        // console.log(`P${i}: ${JSON.stringify(playerChars, null, 2)}`);
        // determine main
        // console.log(getMostUsedChar(playerChars));
        statsJson.players[i].character = getMostUsedChar(playerChars).character;
        // uniquify secondaries
        statsJson.players[i].characters = _.uniqWith(playerChars, _.isEqual);
        // @TODO filter out: if secondary is the same as main, get rid of it
        // if (player.characters.length === 1 && _.isEqual(player.characters[0], player.main)) {
        //     player.secondaries = [];
        // }
    });
    // console.log(JSON.stringify(statsJson.players, null, 2));
    // determine which saga icon to use
    // console.log(JSON.stringify(statsJson.players, null, 2));
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
    // console.log(JSON.stringify(statsJson, null, 2));
    return statsJson;
}
exports.getStats = getStats;

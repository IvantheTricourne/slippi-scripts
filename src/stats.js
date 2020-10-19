const _ = require('lodash');
const path = require('path');
const fs = require('fs');
const slp = require('@slippi/slippi-js');
const SlippiGame = slp.default;

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
const deadStates = [0x000, 0x001, 0x002, 0x003, 0x004, 0x005,
    0x006, 0x007, 0x008, 0x009, 0x009, 0x00A
];

function playerIsDead(playerFrame) {
    return (deadStates.includes(playerFrame.pre.actionStateId) ||
        deadStates.includes(playerFrame.post.actionStateId)
    );
}

function playerHasMoreStocks(player0Frame, player1Frame) {
    return player0Frame.post.stocksRemaining > player1Frame.post.stocksRemaining;
}
// determine who won the game by determining who died when the game ended
function getGameWinner(game, player0, player1) {
    let latestFrame = game.getLatestFrame();
    let player0Frame = latestFrame.players[0];
    let player1Frame = latestFrame.players[1];
    let gameEnd = game.getGameEnd();
    // console.log(JSON.stringify(gameEnd, null, 2));
    // console.log(JSON.stringify(Object.keys(game), null, 2));
    // console.log(JSON.stringify(game.actionsComputer, null, 2));
    // console.log(JSON.stringify(latestFrame, null, 2));
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
    switch (gameEnd.gameEndMethod) {
    case 1:
        // Timeout determine percents
        if (player0Frame.post.percent < player1Frame.post.percent) {
            // player 0 has less percent
            return {
                winner: player0,
                stocks: player0Frame.post.stocksRemaining
            };
        } else if (player1Frame.post.percent < player0Frame.post.percent) {
            // player 1 has less percent
            return {
                winner: player1,
                stocks: player1Frame.post.stocksRemaining
            };
        } else {
            // game ended in equal percents
            // A SUDDEN DEATH!
            // @TODO: Make this more obvious
            return {
                winner: noOneWins,
                stocks: 0
            };
        }
    case 2:
        // a normal game end: GAME!
        if (playerHasMoreStocks(player0Frame, player1Frame)) {
            // player 0 has more stocks
            return {
                winner: player0,
                stocks: player0Frame.post.stocksRemaining
            };
        } else if (playerHasMoreStocks(player1Frame, player0Frame)) {
            // player 1 has more stocks
            return {
                winner: player1,
                stocks: player1Frame.post.stocksRemaining
            };
        } else {
            // both died at the same time
            // A SUDDEN DEATH!
            // @TODO: Make this more obvious
            return {
                winner: noOneWins,
                stocks: 0
            };
        }
    case 7:
        // someone quit out
        if (gameEnd.lrasInitiatorIndex === 0) {
            // player 0 quit
            return {
                winner: player1,
                stocks: player1Frame.post.stocksRemaining
            };
        } else if (gameEnd.lrasInitiatorIndex === 1) {
            // player 1 quit
            return {
                winner: player0,
                stocks: player0Frame.post.stocksRemaining
            };
        } else {
            // something unknown happened
            return {
                winner: noOneWins,
                stocks: 0
            };
        }
    }
    return {
        winner: noOneWins,
        stocks: 0
    };
}

// get most used move
function getMostUsedMove(arr) {
    var mf = 1;
    var m = 0;
    var item;
    // when someone doesn't move or gets 0 kills
    if (arr.length === 0) {
        return {
            moveName: "n/a",
            timesUsed: 0
        };
    }
    // if someone just does one thing or gets only 1 kill
    if (arr.length === 1) {
        return {
            moveName: arr[0],
            timesUsed: 1
        };
    }
    for (var i = 0; i < arr.length; i++) {
        for (var j = i; j < arr.length; j++) {
            if (arr[i] == arr[j])
                m++;
            if (mf <= m) {
                mf = m;
                item = arr[i];
            }
        }
        m = 0;
    }
    return {
        moveName: item,
        timesUsed: mf
    };
}
// get most used char
function getMostUsedChar(arr) {
    var mf = 1;
    var m = 0;
    var item;
    // when someone is a solo main
    if (arr.length === 1) {
        return {
            character: arr[0],
            timesUsed: mf
        };
    }
    for (var i = 0; i < arr.length; i++) {
        for (var j = i; j < arr.length; j++) {
            if (_.isEqual(arr[i], arr[j]))
                m++;
            if (mf <= m) {
                mf = m;
                item = arr[i];
            }
        }
        m = 0;
    }
    return {
        character: item,
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
    let player0Wins = statsJson.playerStats[0].wins;
    let player1Wins = statsJson.playerStats[1].wins;
    // console.log(player0Wins, player1Wins);
    if (player0Wins > player1Wins) {
        return characterSagaDict[statsJson.players[0].character.characterName];
    } else if (player1Wins > player0Wins) {
        return characterSagaDict[statsJson.players[1].character.characterName];
    } else if (player0Kills > player1Kills) { // determine who had the most kills
        return characterSagaDict[statsJson.players[0].character.characterName];
    } else if (player1Kills > player0Kills) {
        return characterSagaDict[statsJson.players[1].character.characterName];
    } else {
        // return the smash logo when its a tie/indeterminate
        console.log("Set winner indeterminate!");
        return "Smash";
    }
}

function sec2time(timeInSeconds) {
    var pad = function(num, size) { return ('000' + num).slice(size * -1); },
        time = parseFloat(timeInSeconds).toFixed(3),
        // hours = Math.floor(time / 60 / 60),
        minutes = Math.floor(time / 60) % 60,
        seconds = Math.floor(time - minutes * 60),
        milliseconds = time.slice(-3);
    return minutes + ':' + pad(seconds, 2);
}

function getStats(files, players = []) {
    var player0Info = {};
    var player0Chars = [];
    var player1Info = {};
    var player1Chars = [];
    var totalGames = 0;
    var statsJson = {
        "games": [],
        "totalLengthSeconds": 0,
        "players": null,
        "playerStats": [{
                "totalDamage": 0,
                "neutralWins": 0,
                "counterHits": 0,
                "avgs": {},
                "kills": 0,
                "wins": 0
            },
            {
                "totalDamage": 0,
                "neutralWins": 0,
                "counterHits": 0,
                "avgs": {},
                "kills": 0,
                "wins": 0
            }
        ]
    };
    var playerTotals = [{
            "apms": 0,
            "openingsPerKills": 0,
            "damagePerOpenings": 0,
            "moves": [],
            "killMoves": [],
            "killPercentGameAvgs": 0
        },
        {
            "apms": 0,
            "openingsPerKills": 0,
            "damagePerOpenings": 0,
            "moves": [],
            "killMoves": [],
            "killPercentGameAvgs": 0
        }
    ];
    _.each(files, (file, i) => {
        try {
            const game = new SlippiGame(file);
            // since it is less intensive to get the settings we do that first
            const settings = game.getSettings();
            const metadata = game.getMetadata();
            // console.log(JSON.stringify(metadata,null,2));
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
                ({
                    tag,
                    netplayName,
                    rollbackCode
                } = player0);
                let player0Ids = [tag, netplayName, rollbackCode, rollbackCode.split('#').shift()]
                    .map(x => x.toLowerCase());
                ({
                    tag,
                    netplayName,
                    rollbackCode
                } = player1);
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
            if (gameLength < 60 && totalKills < 2) {
                console.log(`File ${i+1} | Game excluded: <60secs + <2 kills`);
                return;
            }
            // write first player info
            player0Info = player0;
            player1Info = player1;
            // track char info
            player0Chars.push(player0.character);
            player1Chars.push(player1.character);
            // update kill percent sums
            let playerGameKillPercentSums = [0, 0];
            _.each(game.stockComputer.stocks, (stock, i) => {
                if (stock.deathAnimation !== null) {
                    // console.log(JSON.stringify(stock, null, 2));
                    // console.log(`${stock.opponentIndex} kills ${stock.playerIndex} @ ${stock.endPercent}`);
                    playerGameKillPercentSums[stock.opponentIndex] += stock.endPercent;
                }
            });
            // console.log(playerGameKillPercentSums);
            // get moves from conversions and combos
            _.each(stats.conversions, (combo, i) => {
                let namedMoves = combo.moves.map(move => slp.moves.getMoveShortName(move.moveId));
                playerTotals[combo.playerIndex].moves = playerTotals[combo.playerIndex]
                    .moves
                    .concat(namedMoves);
                if (combo.didKill) {
                    let killingMove = namedMoves[namedMoves.length - 1];
                    playerTotals[combo.playerIndex].killMoves.push(killingMove);
                }
            });
            // update stats
            // console.log(JSON.stringify(stats.overall, null, 2));
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
                if (playerStats.killCount !== 0) {
                    playerTotals[i].killPercentGameAvgs += playerGameKillPercentSums[i] / playerStats.killCount;
                }
            });
            // update win counts
            let {
                winner,
                stocks
            } = getGameWinner(game, player0, player1);
            // console.log(JSON.stringify(winner, null, 2));
            if (statsJson.playerStats[winner.idx] !== undefined) {
                statsJson.playerStats[winner.idx].wins += 1;
            }
            // track stages, winner, total games and set length
            statsJson.games.push({
                stage: slp.stages.getStageName(settings.stageId),
                winner: winner,
                stocks: stocks,
                players: [player0, player1],
                length: sec2time(gameLength),
                // @NOTE: this field is not used by the frontend (yet)
                date: gameDate
            });
            totalGames += 1;
            statsJson.totalLengthSeconds += paddedGameLength;
        } catch (err) {
            fs.appendFileSync("./get-stats-log.txt", `${err.stack}\n\n`);
            console.log(`File ${i+1} | Error processing ${file}`);
        }
    });
    // warn if no games were found
    if (totalGames === 0) {
        console.log("WARNING: No valid games found!");
    } else {
        console.log(`Found ${totalGames} games.`);
    }
    // sort games in case files were uploaded out of order
    statsJson.games.sort((a, b) => a.date - b.date);
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
    // console.log(getSagaIconName(statsJson));
    statsJson.sagaIcon = getSagaIconName(statsJson);
    // write avgs
    _.each(playerTotals, (totals, i) => {
        // console.log(totals);
        statsJson.playerStats[i].avgs.avgApm = totals.apms / totalGames;
        statsJson.playerStats[i].avgs.avgOpeningsPerKill = totals.openingsPerKills / totalGames;
        statsJson.playerStats[i].avgs.avgDamagePerOpening = totals.damagePerOpenings / totalGames;
        statsJson.playerStats[i].avgs.avgKillPercent = totals.killPercentGameAvgs / totalGames;
        statsJson.playerStats[i].favoriteMove = getMostUsedMove(totals.moves);
        statsJson.playerStats[i].favoriteKillMove = getMostUsedMove(totals.killMoves);
    });
    // console.log(JSON.stringify(statsJson, null, 2));
    return { totalGames: totalGames,
             stats: statsJson
           };
}
exports.characterSagaDict = characterSagaDict;
exports.getStats = getStats;

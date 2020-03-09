// slippi deps
const fs = require('fs');
const _ = require('lodash');
const path = require('path');
const slp = require('slp-parser-js');
const SlippiGame = slp.default; // npm install slp-parser-js
// cli deps
const yargs = require('yargs'); // npm install yargs

/////////////////////////////////////////////////////////////////
// CLI
/////////////////////////////////////////////////////////////////
let todayDate = new Date();
const defaultOutputFileDateStr=`${todayDate.getFullYear()}-${todayDate.getMonth() + 1}-${todayDate.getDate()}`;
const argv = yargs
      .scriptName("getGamesOnDate")
      .usage('$0 <cmd> [args]')
      .command('all', "Get all games in directory; default command", {})
      .command('today', "Get today's games", {})
      .command('on', 'Get games on a specific date', {
          date: {
              description: 'Date to find games on',
              alias: 'd',
              type: 'string',
              default: '',
          },
      })
      .command('range', 'Get games within a given date range', {
          startDate: {
              description: 'Date to start range (inclusive)',
              alias: 's',
              type: 'string',
              default: '',
          },
          endDate: {
              description: 'Date to end range (exclusive)',
              alias: 'e',
              type: 'string',
              default: '',
          }
      })
      // options for generating description
      .option('title', {
          alias: 't',
          description: 'Generate focus title for VOD description',
          type: 'string',
          default: 'FoxInTheB0XX' // @NOTE: change this to desired default if you don't want to set it manually
      })
      .option('type', {
          alias: 's',
          description: 'Generate sub focus title for VOD description',
          type: 'string',
          default: 'SmashLadder Ranked' // @NOTE: change this to desired default if don't want to set it manually
      })
      // options for filtering bad games (i.e., handwarmers)
      .option('minGameLength', {
          alias: 'l',
          description: 'Minimum game length (secs) to include',
          type: 'number',
          default: 60
      })
      .option('minKills', {
          alias: 'k',
          description: 'Minimum game kill-count to include',
          type: 'number',
          default: 3
      })
      // input/output options
      .option('dir', {
          alias: 'i',
          description: 'Slippi directory to use (relative to script)',
          type: 'string',
          default: './Slippi'
      })
      .option('dolphin', {
          description: 'Set output filename for dolphin replay file',
          type: 'string',
          default: `./output/${defaultOutputFileDateStr}-replay.json`
      })
      .option('timestamp', {
          description: 'Set output filename for timestamp file',
          type: 'string',
          default: `./output/${defaultOutputFileDateStr}-vod-info.txt`
      })
      // by character filtering
      .option('character', {
          alias: 'c',
          description: 'Include all games with character (use short name)',
          type: 'string'
      })
      .option('characters', {
          description: 'Include games with characters (use short name; empty = all)',
          type: 'array',
          default: []
      })
      .option('excludeDittos', {
          description: 'Exclude games with dittos',
          type: 'boolean',
          default: false
      })
      // generate a highlight reel
      .option('highlight', {
          description: 'Generate a playback file for highlights (combos)',
          type: 'boolean',
          default: false
      })
      .option('combo', {
          description: 'Set highlight reel killing combo damage minimum',
          type: 'number',
          default: 50
      })
      .option('acceptable', {
          description: 'Set highlight reel non-killing combo damage minimum',
          type: 'number',
          default: 80
      })
      .option('highlightType', {
          description: 'Set highlight reel type',
          choices: ["conversions", "combos"],
          default: "conversions"
      })
      .option('highlightFile', {
          description: 'Set output filename for highlight file',
          type: 'string',
          default: `./output/${defaultOutputFileDateStr}-highlights.json`
      })
      .option('highlightNames', {
          description: 'Include combos by combo-er name',
          type: 'array',
          default: []
      })
      .option('highlightCharacters', {
          description: 'Include combos by character name',
          type: 'array',
          default: []
      })
      .help()
      .alias('help', 'h')
      .argv;

// help filter out handwarmers
var minGameLengthSeconds = argv.minGameLength;
var minKills = argv.minKills;
// @TODO: timestamp type representing max win count in a set
// 2 for Bo3
// 3 for Bo5
// anything else for character timestamping
var timestampType = 0;
// slippi directory
const basePath = path.join(__dirname, argv.dir);
// output
if (!fs.existsSync("./output")) {
    fs.mkdirSync("./output");
}
const dolphinOutputFileName = argv.dolphin;
const VODTimestampFileName = argv.timestamp;
const highlightFileName = argv.highlightFile;
// optional description stuff
var focusName = argv.title;
var matchType = argv.type;;
fs.writeFileSync(VODTimestampFileName, "");
if (focusName !== '' && matchType !== '') {
    fs.appendFileSync(VODTimestampFileName, `${focusName} - ${matchType} matches\n\n`);
}
fs.appendFileSync(VODTimestampFileName, `Timestamps autogenerated via: "https://gist.github.com/IvantheTricourne/96ebf55ae7023d307f0c1a140885b05b"\n\n`);
// Date values for filtering slp dir
var start = '';
var end = '';
if (argv._.includes('today')) {
    start = new Date().toLocaleDateString();
    console.log(`Looking for today's (${start}) games\n`);
} else if (argv._.includes('on')) {
    start = argv.date;
    let endDate = new Date(start);
    end = `${endDate.getFullYear()}/${endDate.getMonth() + 1}/${endDate.getDate() + 1}`;
    console.log(`Looking for games on ${start}\n`);
} else if (argv._.includes('range')) {
    start = argv.startDate;
    end = argv.endDate;
    console.log(`Looking for games between ${start} and ${end}\n`);
} else if (argv._.includes('all')) {
    console.log(`Using all files in provided Slippi directory\n`);
} else {
    // default behavior is to just use all files in a dir
    console.log(`Using all files in provided Slippi directory\n`);
}
/////////////////////////////////////////////////////////////////
// Script
/////////////////////////////////////////////////////////////////

// dolphin replay object
const dolphin = {
    "mode": "queue",
    "replay": "",
    "isRealTimeMode": false,
    "outputOverlayFiles": true,
    "queue": [],
    "totalLengthSeconds": 0
};
// highlight reel object
const highlight = {
    "mode": "queue",
    "replay": "",
    "isRealTimeMode": false,
    "outputOverlayFiles": true,
    "queue": [],
    "totalLengthSeconds": 0
};
const fdCGers = [9, 12, 13, 22]; // Marth, Peach, Pikachu, and Doc
var noCombos = 0;
var minimumComboPercent = argv.combo; // this decides the threshold for combos
var originalMin = minimumComboPercent; // we use this to reset the threshold
var numWobbles = 0;
var numCG = 0;
var puffMiss = 0;

// just to provide variety in case some people combo a lot in the same game
function shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
}
function filterCombos(combos, settings, metadata) {
    return _.filter(combos, (combo) => {
        var wobbles = [];
        let pummels = 0;
        let chaingrab = false;
        minimumComboPercent = originalMin;
        let player = _.find(settings.players, (player) => player.playerIndex === combo.playerIndex);
        if (argv.highlightNames.length > 0) {
            var matches = [];
            _.each(argv.highlightNames, (filterName) => {
                const netplayName = _.get(metadata, ["players", player.playerIndex, "names", "netplay"], null) || null;
                const playerTag = _.get(player, "nametag") || null;
                const names = [netplayName, playerTag];
                matches.push(_.includes(names, filterName));
            });
            const filteredName = _.some(matches, (match) => match);
            if (!filteredName) return filteredName;
        }
        if (argv.highlightCharacters.length > 0) {
            var matches = [];
            _.each(argv.highlightCharacters, (filterChar) => {
                const charName = slp.characters.getCharacterInfo(player.characterId).name;
                const charShortName = slp.characters.getCharacterInfo(player.characterId).shortName;
                const names = [charName, charShortName];
                matches.push(_.includes(names, filterChar));
            });
            const filteredChar = _.some(matches, (match) => match);
            if (!filteredChar) return filteredChar;
        }
        if (player.characterId === 15) {
            minimumComboPercent += 25;
        } else if (player.characterId === 14) { // check for a wobble (8 pummels or more in a row)
            _.each(combo.moves, ({moveId}) => {
                if (moveId === 52) {
                    pummels++;
                } else {
                    wobbles.push(pummels);
                    pummels = 0;
                }
            });
            wobbles.push(pummels);
        } else if (_.includes(fdCGers, player.characterId)) {
            const upthrowpummel = _.filter(combo.moves, ({moveId}) => moveId === 55 || moveId === 52).length;
            const numMoves = combo.moves.length;
            chaingrab = upthrowpummel / numMoves >= .8;
        }
        const wobbled = _.some(wobbles, (pummelCount) => pummelCount > 8);
        const threshold = (combo.endPercent - combo.startPercent) > minimumComboPercent;
        const acceptable = (combo.endPercent - combo.startPercent) > argv.acceptable;
        const totalDmg = _.sumBy(combo.moves, ({damage}) => damage);
        const largeSingleHit = _.some(combo.moves, ({damage}) => damage/totalDmg >= .8);
        if (wobbled) numWobbles++;
        if(chaingrab) numCG++;
        if (player.characterId === 15 && !threshold && (combo.endPercent - combo.startPercent) > originalMin) puffMiss++;
        return !wobbled && !chaingrab && !largeSingleHit && (acceptable || (combo.didKill && threshold));
    });
}

// allow putting files in folders
function walk(dir) {
    let results = [];
    let list = fs.readdirSync(dir);
    _.each(list, (file) => {
        file = path.join(dir, file);
        let stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            // Recurse into a subdirectory
            results = results.concat(walk(file));
        } else if (path.extname(file) === ".slp"){
            results.push(file);
        }
    });
    return results;
}

// convert seconds to HH:mm:ss,ms
// from: https://gist.github.com/vankasteelj/74ab7793133f4b257ea3
function sec2time(timeInSeconds) {
    var pad = function(num, size) { return ('000' + num).slice(size * -1); },
        time = parseFloat(timeInSeconds).toFixed(3),
        hours = Math.floor(time / 60 / 60),
        minutes = Math.floor(time / 60) % 60,
        seconds = Math.floor(time - minutes * 60),
        milliseconds = time.slice(-3);
    return pad(hours, 2) + ':' + pad(minutes, 2) + ':' + pad(seconds, 2);
}

// within given date range
function isWithinDateRange(start,end,gameDate) {
    let startDate = new Date(start);
    let endDate = new Date(end);
    // if no dates are provided, use all files
    // if only one or the other is provided, then use the approp comparison
    // otherwise, use the range
    if (start === '' || start === null || start === undefined &&
        end === '' || end === null || end === undefined) {
        return true;
    } else if (end === '' || end === null || end === undefined) {
        return (startDate.valueOf() <= gameDate.valueOf());
    } else if (start === '' || start === null || start === undefined) {
        return (gameDate.valueOf() <= endDate.valueOf());
    } else {
        return (startDate.valueOf() <= gameDate.valueOf() &&
                gameDate.valueOf() <= endDate.valueOf());
    }
}

// create player info object
function makePlayerInfo(idx, settings, metadata) {
    let player = _.get(settings, ["players", idx]);
    return {
      	port: player.port,
        tag: player.nametag,
        netplayName: _.get(metadata, ["players", idx, "names", "netplay"], null) || "No Name",
      	characterName: slp.characters.getCharacterShortName(player.characterId),
      	color: slp.characters.getCharacterColorName(player.characterId, player.characterColor)
    };
}

// determine if set of players is the same
function isSamePlayers(currPlayers, newPlayersInfo) {
    // return false when players is uninitiated
    if (currPlayers === null) {
        return false;
    }
    // @TODO: there's probably a better way to do this
    return (currPlayers.player0.characterName === newPlayersInfo.player0.characterName &&
            currPlayers.player0.color === newPlayersInfo.player0.color &&
            currPlayers.player0.netplayName === newPlayersInfo.player0.netplayName &&
            currPlayers.player1.characterName === newPlayersInfo.player1.characterName &&
            currPlayers.player1.color === newPlayersInfo.player1.color &&
            currPlayers.player1.netplayName === newPlayersInfo.player1.netplayName) ||
        (currPlayers.player1.characterName === newPlayersInfo.player0.characterName &&
         currPlayers.player1.color === newPlayersInfo.player0.color &&
         currPlayers.player1.netplayName === newPlayersInfo.player0.netplayName &&
         currPlayers.player0.characterName === newPlayersInfo.player1.characterName &&
         currPlayers.player0.color === newPlayersInfo.player1.color &&
         currPlayers.player0.netplayName === newPlayersInfo.player1.netplayName);
}

// make versus string from player infos
function makeVersusStringPlayerInfo (playerInfo) {
    var info = '';
    if (playerInfo.tag !== '' && playerInfo.netplayName !== '') {
        info = `${playerInfo.netplayName}/${playerInfo.tag} (P${playerInfo.port},${playerInfo.color} ${playerInfo.characterName})`;
    } else if (playerInfo.tag !== '') {
        info = `${playerInfo.tag} (P${playerInfo.port},${playerInfo.color} ${playerInfo.characterName})`;
    } else if (playerInfo.netplayName !== '') {
        info = `${playerInfo.netplayName} (P${playerInfo.port},${playerInfo.color} ${playerInfo.characterName})`;
    } else {
        info = `No Name (P${playerInfo.port},${playerInfo.color} ${playerInfo.characterName})`;
    }
    return info;
}
function makeVersusString(currPlayers) {
    if (currPlayers === null) {
        return '';
    }
    let player0Info = currPlayers.player0;
    let player1Info = currPlayers.player1;
    return `${makeVersusStringPlayerInfo(player0Info)} vs ${makeVersusStringPlayerInfo(player1Info)}`;
}

// Write to timestamp file
// @TODO: convert this to a set count
function writeToTimestampFile(currTimestamp, currSetLength, currSetGameCount, currPlayers) {
    if (currSetGameCount !== 0) {
        console.log(`(${currSetGameCount} game(s) found: ${sec2time(currTimestamp)} - ${sec2time(currTimestamp + currSetLength)}, total: ${sec2time(currSetLength)})\n`);
        fs.appendFileSync(VODTimestampFileName, `${sec2time(currTimestamp)} ${makeVersusString(currPlayers)}\n`);
    } else {
        console.log('No timestamp generated. No games included!');
    }
}

// main script
function getGames() {
    let files = walk(basePath);
    console.log(`${files.length} files found in target directory`);
    var filteredFiles = 0;

    // VOD data report
    var badFiles = 0;
    var numCPU = 0;
    var totalVODLength = 0;
    var totalHighlightLength = 0;
    var unpaddedLength = 0;

    // VOD timestamp info containers
    var currPlayers = null;
    var currTimestamp = 0;
    var currSetLength = 0;
    var currSetGameCount = 0;
    var player0Info = {};
    var player1Info = {};
    var stageInfo = '';

    _.each(files, (file, i) => {
        try {
            const game = new SlippiGame(file);
            // since it is less intensive to get the settings we do that first
            const settings = game.getSettings();
            const metadata = game.getMetadata();
            const gameDate = new Date(metadata.startAt);
            // game date filtering
            if (isWithinDateRange(start, end, gameDate)) {
                // skip to next file if CPU exists
                const cpu = _.some(settings.players, (player) => player.type != 0);
                const notsingles = settings.players.length != 2;
                if (cpu) {
                    numCPU++;
                    return;
                } else if (notsingles) {
                    return;
                }
                // calculate game length in seconds
                const gameLength = metadata.lastFrame / 60;
      	        // padded game length (w/ ready splash + black screen)
      	        let paddedGameLength = (metadata.lastFrame + 123) / 60;
      	        // update player+character information
      	        player0Info = makePlayerInfo(0, settings, metadata);
      	        player1Info = makePlayerInfo(1, settings, metadata);
                // filter based on character here
                if (argv.excludeDittos && (player0Info.characterName === player1Info.characterName)) {
                    console.log(`File ${i+1} | Game excluded: ${player0Info.characterName} ditto`);
                    return;
                }
                if (argv.character !== undefined) {
                    if (argv.character !== player0Info.characterName && argv.character !== player1Info.characterName) {
                        console.log(`File ${i+1} | Game excluded: ${argv.character} is not used`);
                        return;
                    }
                }
                if (argv.characters.length !== 0) {
                    let validChars = argv.characters;
                    if (argv.character !== undefined) {
                        validChars.push(argv.character);
                    }
                    // remove game if characters don't match desired
                    if (!validChars.includes(player0Info.characterName)) {
                        console.log(`File ${i+1} | Game excluded: ${player0Info.characterName} is used`);
                        return;
                    }
                    if (!validChars.includes(player1Info.characterName)) {
                        console.log(`File ${i+1} | Game excluded: ${player1Info.characterName} is used`);
                        return;
                    }
                }
                // Get stats after filtering is done (bc it slows things down a lot)
                // @TODO: determine player win counts
                const stats = game.getStats();
                // update player tracker info
                let newPlayersInfo = {
                    player0: player0Info,
                    player1: player1Info
                };
                if (!(isSamePlayers(currPlayers, newPlayersInfo))) {
                    // push current info into vod string iff players are already tracked
                    if (currPlayers !== null) {
                        writeToTimestampFile(currTimestamp, currSetLength, currSetGameCount, currPlayers);
                    }
                    // reset new values
                    currPlayers = newPlayersInfo;
                    currTimestamp += currSetLength;
                    currSetLength = 0;
                    currSetGameCount = 0;
                    console.log("____________________________________________________________");
                    console.log(makeVersusString(currPlayers));
                    console.log("____________________________________________________________");
                }
                // filter out short games (i.e., handwarmers) + not enough kills
                let totalKills = 0;
                _.each(stats.overall, (playerStats, i) => {
                    totalKills += playerStats.killCount;
                });
                if (gameLength < minGameLengthSeconds && totalKills < minKills) {
                    console.log(`File ${i+1} | Game excluded: <${minGameLengthSeconds}secs + <${minKills} kills`);
                    return;
                }
                // good game information logging
                console.log(`File ${i+1} | Game included: ${sec2time(paddedGameLength)}`);
                // highlight reel generation
                if (argv.highlight) {
                    const originalCombos = _.get(stats, argv.highlightType);
                    // filter out any non-killing combos and low percent combos
                    const combos = filterCombos(originalCombos, settings, metadata);
                    _.each(combos, ({startFrame, endFrame, playerIndex, endPercent, startPercent}) => {
                        let player = _.find(settings.players, (player) => player.playerIndex === playerIndex);
                        let opponent = _.find(settings.players, (player) => player.playerIndex !== playerIndex);
                        // adding a buffer is key to getting the combo with some space so you can cut out the buffer and the black frames
                        let x = {
                            path: file,
                            startFrame: startFrame - 240 > -123 ? startFrame - 240 : -123,
                            endFrame: endFrame + 180 < metadata.lastFrame ? endFrame + 180 : metadata.lastFrame,
                            gameStartAt: _.get(metadata, "startAt", ""),
                            gameStation: _.get(metadata, "consoleNick", ""),
                            additional: {
                                characterId: player.characterId,
                                characterName: slp.characters.getCharacterInfo(player.characterId).name,
                                opponentCharacterId: opponent.characterId,
                                opponentCharacterName: slp.characters.getCharacterInfo(opponent.characterId).name,
                                damageDone: endPercent-startPercent,
                            }
                        };
                        highlight.queue.push(x);
                        let totalFrames = x.endFrame - x.startFrame;
                        totalHighlightLength += (totalFrames / 60);
                    });
                    combos.length === 0 ? noCombos++ : console.log(`File ${i+1} | ${combos.length} highlight(s) found`);
                }
                // create object w/ game info
                let gameReplaySpec = {
                    path: file,
                    startFrame: -123, // this includes the Ready splash screen
                    endFrame: metadata.lastFrame,
                    gameStartAt: _.get(metadata, "startAt", ""),
                    gameStation: _.get(metadata, "consoleNick", ""),
                    // attach additional info for lols
                    additional: {
                        gameLength: sec2time(paddedGameLength),
                        stage: slp.stages.getStageName(settings.stageId),
                        player0: player0Info,
                        player1: player1Info
                    }
                };
                totalVODLength += paddedGameLength;
                currSetLength += paddedGameLength;
                currSetGameCount += 1;
                filteredFiles += 1;
                // push game object to queue
                dolphin.queue.push(gameReplaySpec);
            }
        } catch (err) {
            fs.appendFileSync("./log.txt", `${err.stack}\n\n`);
            badFiles++;
            console.log(`File ${i+1} | Error processing ${file}`);
        }
    });
    // push the last set to timestamp file
    writeToTimestampFile(currTimestamp, currSetLength, currSetGameCount, currPlayers);
    // add total length to replay object (+ a 1 second buffer for each clip)
    dolphin.totalLengthSeconds = totalVODLength + dolphin.queue.length;
    // write dolphin replay object
    fs.writeFileSync(dolphinOutputFileName, JSON.stringify(dolphin));
    console.log(`**** Summary ****`);
    console.log(`${badFiles} bad file(s) ignored`);
    console.log(`${numCPU} game(s) with CPUs removed`);
    console.log(`${dolphin.queue.length} game(s) found`);
    console.log(`Approximate VOD length: ${sec2time(totalVODLength)}\n`);
    // report/write highlights
    if (argv.highlight) {
        highlight.queue = shuffle(highlight.queue);
        // @NOTE: some clips take longer to start playing, so a buffer is necessary
        highlight.totalLengthSeconds = totalHighlightLength + highlight.queue.length * 10;
        fs.writeFileSync(highlightFileName, JSON.stringify(highlight));
        console.log(`**** Highlights ****`);
        console.log(`${noCombos / (filteredFiles - badFiles) * 100}% of games had no valid ${argv.highlightType}`);
        console.log(`${highlight.queue.length} highlight(s) found`);
        console.log(`Approximate highlight reel length: ${sec2time(totalHighlightLength)}\n`);
    }
}
getGames();

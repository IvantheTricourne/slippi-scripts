const fs = require('fs');
const _ = require('lodash');
const path = require('path');
const slp = require('slp-parser-js');
const SlippiGame = slp.default; // npm install slp-parser-js

const basePath = path.join(process.cwd(), 'slp/'); // this var is "<directory your script is in>/slp"

const outputFilename = "./combos.json";

const filterSet = "combos"; // can be either combos or conversions, conversions are from when a player is put into a punish state to when they escape or die

const dolphin = {
  "mode": "queue",
  "replay": "",
  "isRealTimeMode": false,
  "outputOverlayFiles": true,
  "queue": []
};

const fdCGers = [9, 12, 13, 22]; // Marth, Peach, Pikachu, and Doc

const filterByNames = ["FoxInTheB0XX"]; // add names as strings to this array (checks both netplay name and nametags). `["Nikki", "Metonym", "metonym"]`
const filterByCharacters = ["Fox"]; //add character names as strings. Use the regular or shortnames from here: https://github.com/project-slippi/slp-parser-js/blob/master/src/melee/characters.ts

var minimumComboPercent = 40; // this decides the threshold for combos
var originalMin = minimumComboPercent; // we use this to reset the threshold

// Removal Statistics
var numWobbles = 0;
var numCG = 0;
var numCPU = 0;
var puffMiss = 0;
var badFiles = 0;
var noCombos = 0;

// just to provide variety in case some people combo a lot in the same game
function shuffle(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
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

function filterCombos(combos, settings, metadata) {
  return _.filter(combos, (combo) => {
    var wobbles = [];
    let pummels = 0;
    let chaingrab = false;
    minimumComboPercent = originalMin;
    let player = _.find(settings.players, (player) => player.playerIndex === combo.playerIndex);
    if (filterByNames.length > 0) {
      var matches = []
      _.each(filterByNames, (filterName) => {
        const netplayName = _.get(metadata, ["players", player.playerIndex, "names", "netplay"], null) || null;
        const playerTag = _.get(player, "nametag") || null;
        const names = [netplayName, playerTag];
        matches.push(_.includes(names, filterName));
      });
      const filteredName = _.some(matches, (match) => match);
      if (!filteredName) return filteredName;
    }
    if (filterByCharacters.length > 0) {
      var matches = []
      _.each(filterByCharacters, (filterChar) => {
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
    const acceptable = (combo.endPercent - combo.startPercent) > 70;
    const totalDmg = _.sumBy(combo.moves, ({damage}) => damage);
    const largeSingleHit = _.some(combo.moves, ({damage}) => damage/totalDmg >= .8);

    if (wobbled) numWobbles++;
    if(chaingrab) numCG++;
    if (player.characterId === 15 && !threshold && (combo.endPercent - combo.startPercent) > originalMin) puffMiss++;
    return !wobbled && !chaingrab && !largeSingleHit && (acceptable || (combo.didKill && threshold));
          
  });
}

function getCombos() {
  let checkPercent = .1;
  let files = walk(basePath);
  console.log(`${files.length} files found, starting to filter for ${minimumComboPercent}% combos`);
  _.each(files, (file, i) => {
    try {
      const game = new SlippiGame(file);

      // since it is less intensive to get the settings we do that first
      const settings = game.getSettings();
      const metadata = game.getMetadata();

      // skip to next file if CPU exists
      const cpu = _.some(settings.players, (player) => player.type != 0)
      const notsingles = settings.players.length != 2;
      if (cpu) {
        numCPU++;
        return;
      } else if (notsingles) {
        return;
      }

      // Calculate stats and pull out the combos
      const stats = game.getStats();
      const originalCombos = _.get(stats, filterSet);

      // filter out any non-killing combos and low percent combos
      const combos = filterCombos(originalCombos, settings, metadata);

      // create objects that will be in the queue and make sure they stay within the bounds of each file
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

        dolphin.queue.push(x);
      });
      combos.length === 0 ? noCombos++ : console.log(`File ${i+1} | ${combos.length} combo(s) found in ${path.basename(file)}`);
    } catch (err) {
      fs.appendFileSync("./log.txt", `${err.stack}\n\n`);
      badFiles++;
      console.log(`File ${i+1} | ${file} is bad`);
    }
    if (i/files.length >= checkPercent && checkPercent != 1) {
      console.log(`About ${checkPercent * 100}% of files have been checked`);
      checkPercent += .1;
    }
  });
  dolphin.queue = shuffle(dolphin.queue);
  fs.writeFileSync(outputFilename, JSON.stringify(dolphin));
  console.log(`${badFiles} bad file(s) ignored`);
  console.log(`${numCPU} game(s) with CPUs removed`);
  console.log(`${numWobbles} wobble(s) removed`);
  console.log(`${numCG} chaingrab(s) removed`);
  console.log(`${puffMiss} Puff combo(s) removed\n`);
  console.log(`${dolphin.queue.length} good combo(s) found`)
  console.log(`${noCombos / (files.length - badFiles) * 100}% of the good files had no valid combos`);
}
getCombos();

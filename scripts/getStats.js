const path = require('path');
const fs = require('fs');
const yargs = require('yargs'); // npm install yargs
const { getStats } = require('../src/stats.js');

// node script
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
// let files = walk(basePath);
let files = fs.readdirSync(basePath)
    .map(file => {
        return path.join(basePath, file);
    });
console.log(`${files.length} files found in target directory`);
let outputJsonObj = getStats(files, argv.players);
fs.writeFileSync("./stats.json", JSON.stringify(outputJsonObj));

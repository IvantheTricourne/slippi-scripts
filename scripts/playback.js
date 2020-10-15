const { sleep } = require('./utils.js');
const { launchDolphin } = require('./dolphin.js');
const { launchOBSWebsocket, recordOBSWebsocket} = require('./obs.js');
const OBSWebSocket = require('obs-websocket-js');
const yargs = require('yargs');
const ora = require("ora");

// cli
const argv = yargs
      .scriptName("playback")
      .usage('$0 <cmd> [args]')
      .command('play', 'Launch dolphin and play', {})
      .command('record', 'Launch dolphin + OBS websocket to make a VOD', {})
      .option('config', {
          alias: 'c',
          description: 'Path to config file to use (relative to script)',
          type: 'string',
          default: '../config.json'
      })
      .option('dolphinLag', {
          alias: 'l',
          description: 'Set amount of time dolphin needs to start up',
          type: 'number'
      })
      .help()
      .alias('help', 'h')
      .argv;

// config
var config;
if (argv.config === undefined) {
    console.error('No config file.');
} else {
    config = require(argv.config);
}

// playback script: determine what to run
async function playback(wip) {
    return new Promise(async function (resolve, reject) {
        if (argv._.includes('play')) {
            resolve(launchDolphin(config, argv.dolphinLag, wip));
        } else if (argv._.includes('record')) {
            // create a new OBS websocket
            const websocket = new OBSWebSocket();
            try {
                // get length from replay spec
                let { totalLengthSeconds } = require(config["REPLAY"]);
                // launch obs + dolphin, then record
                launchOBSWebsocket(config, websocket, wip);
                await sleep(10);
                launchDolphin(config, argv.dolphinLag, wip);
                await sleep(argv.dolphinLag);
                resolve(recordOBSWebsocket(websocket, totalLengthSeconds, wip));
            } catch (error) {
                console.error(error);
            }
        } else {
            wip.fail(`Unknown command used. Use --help for information.`);
            reject();
        }
    });
}

// main
async function main() {
    const wip = ora('Script is starting...').start();
    await playback(wip);
    wip.succeed('Done');
    process.exit();

}
main();

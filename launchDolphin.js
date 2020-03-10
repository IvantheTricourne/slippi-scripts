const { sec2time, isWin, sleep, runCommand, kill } = require('./utils.js');
const { exec, execSync } = require("child_process");
const path = require('path');
const ora = require("ora");

// from config file
const config = require(process.argv[2]);
// set dolphin path
const pathToDolphin = config["DOLPHIN"];
// set path to playback file
const pathToReplayFile = config["REPLAY"];
const replayObject = require(pathToReplayFile);
// set path to Melee ISO
const pathToMeleeIso = config["ISO"];

// Starts dolphin with .json file
// kills it after playback is completed
async function launchDolphin() {
    // determine command by os
    const dolphinExtension = isWin ? '.exe' : '';
    const dolphinCmd = `Dolphin${dolphinExtension} -i "${pathToReplayFile}" -e "${pathToMeleeIso}"`;
    // launch dolphin
    runCommand(dolphinCmd, pathToDolphin);
    await sleep(3); // @NOTE: slower pcs will require longer to launch dolphin
    const playing = ora(`Playing ${path.basename(pathToReplayFile, '.json')} (length: ${sec2time(replayObject.totalLengthSeconds)}) ...`).start();
    await sleep(replayObject.totalLengthSeconds);
    playing.succeed('Playback complete.');
    // kill dolphin
    const stopping = ora('Killing Dolphin').start();
    kill('Dolphin');
    stopping.succeed();
}

// run
launchDolphin();
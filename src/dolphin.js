const { sec2time, isWin, sleep, runCommand, kill } = require('./utils.js');
const { exec, execSync } = require("child_process");
const path = require('path');
const ora = require("ora");

// Starts dolphin with .json file
// kills it after playback is completed
// @NOTE: slower pcs will require longer to launch dolphin
// optional lag argument to wait for dolphin to start up
async function launchDolphin(config, dolphinLag = 3, spinner) {
    // set dolphin path
    const pathToDolphin = config["DOLPHIN"];
    // set path to playback file
    const pathToReplayFile = config["REPLAY"];
    const replayObject = require(pathToReplayFile);
    // set path to Melee ISO
    const pathToMeleeIso = config["ISO"];
    // determine command by os
    const dolphinExe = isWin ? 'Dolphin.exe' : 'Dolphin';
    const dolphinCmd = `${dolphinExe} -i "${pathToReplayFile}" -e "${pathToMeleeIso}"`;
    // launch dolphin
    runCommand(dolphinCmd, pathToDolphin);
    await sleep(dolphinLag);
    spinner.text = `Launched Dolphin with ${path.basename(pathToReplayFile, '.json')}...`;
    await sleep(replayObject.totalLengthSeconds);
    // kill dolphin
    spinner.text = 'Killing Dolphin';
    kill('Dolphin');
}

// exports
exports.launchDolphin = launchDolphin;

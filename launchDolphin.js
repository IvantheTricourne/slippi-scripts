const { exec, execSync, execFile, spawn } = require("child_process");
const path = require('path');
const ora = require("ora");
// determine os
var isWin = process.platform === "win32";
// sleep async
const sleep = (s) => new Promise(resolve => setTimeout(resolve, s * 1000));
// from config file
const config = require(process.argv[2]);
// set dolphin path
const pathToDolphin = config["DOLPHIN"];
// set path to playback file
const pathToReplayFile = config["REPLAY"];
const replayObject = require(pathToReplayFile);
// set path to Melee ISO
const pathToMeleeIso = config["ISO"];
// commands
const dolphinExtension = isWin ? '.exe' : '';
const dolphinCmd = `Dolphin${dolphinExtension} -i "${pathToReplayFile}" -e ${pathToMeleeIso}`;
// exec
async function debugExec(cmd) {
    exec(cmd, (error, stdout, stderr) => {
        if (error) {
            console.log(`error: ${error.message}`);
            return;
        }
        if (stderr) {
            console.log(`stderr: ${stderr}`);
            return;
        }
        console.log(`stdout: ${stdout}`);
    });
    console.log(`${path.basename(pathToReplayFile)} is being played...`);
    const spinner = ora(`Wait ${replayObject.totalLengthSeconds} seconds for a special message!`).start();
    await sleep(replayObject.totalLengthSeconds);
    spinner.succeed();
    console.log('Happy Leif Erikson day! HINGA DINGA DOERGEN!');
}
// run
process.chdir(pathToDolphin);
debugExec(dolphinCmd);

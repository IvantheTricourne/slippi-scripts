const { exec, execSync } = require("child_process");
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
const dolphinCmd = `Dolphin${dolphinExtension} -i "${pathToReplayFile}" -e "${pathToMeleeIso}"`;



// convert seconds to HH:mm:ss,ms
// from: https://gist.github.com/vankasteelj/74ab7793133f4b257ea3
function sec2time(timeInSeconds) {
    var pad = function(num, size) { return ('000' + num).slice(size * -1); },
        time = parseFloat(timeInSeconds).toFixed(3),
        hours = Math.floor(time / 60 / 60),
        minutes = Math.floor(time / 60) % 60,
        seconds = Math.floor(time - minutes * 60),
        milliseconds = time.slice(-3);
    return pad(hours, 2) + ':' + pad(minutes, 2) + ':' + pad(seconds, 2)



// exec
async function launchDolphin(cmd) {
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
    const playing = ora(`${path.basename(pathToReplayFile)} is playing (length: ${sec2time(replayObject.totalLengthSeconds)}) ...`).start();
    await sleep(replayObject.totalLengthSeconds);
    playing.succeed("Playback complete.");
    // kill dolphin
    if (isWin) {
        execSync('taskkill /F /IM "Dolphin.exe" /T');
    } else {
        execSync('killall Dolphin');
    }
}



// run
process.chdir(pathToDolphin);
launchDolphin(dolphinCmd);
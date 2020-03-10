const { isWin, sleep, runCommand, kill } = require('./utils.js');
const OBSWebSocket = require('obs-websocket-js'); // npm install obs-websocket-js
const obs = new OBSWebSocket();
const { exec, execSync } = require("child_process");
const ora = require("ora");
const path = require('path');

////////////////////////////////////////////////////////////////////////////////
// Config
////////////////////////////////////////////////////////////////////////////////
const config = require(process.argv[2]); // pass path to config file directly to script

// obs config
const pathToOBS = config["OBS"]; // set obs path (i.e., directory it's in)
const sceneName = config["OBS_SCENE"];  // set scene name
const profileName = config["OBS_PROFILE"];  // set scene name
const obsWSAddress = `localhost:${config["OBS_PORT"]}`;
const obsWSPassword = config["OBS_PASS"];
// dolphin config
const pathToDolphin = config["DOLPHIN"]; // set dolphin path (i.e., the directory it's in)
const pathToReplayFile = config["REPLAY"]; // set path to playback file
const replayObject = require(pathToReplayFile);
const pathToMeleeIso = config["ISO"]; // set path to Melee ISO
// commands
const cmdExtension = isWin ? '.exe' : '';
const obsCommand = isWin ? `obs64${cmdExtension}` : 'open OBS.app'; // start normally
const dolphinCommand = `Dolphin${cmdExtension} -i "${pathToReplayFile}" -e "${pathToMeleeIso}"`; // autoplay

////////////////////////////////////////////////////////////////////////////////
// Script
////////////////////////////////////////////////////////////////////////////////

// start obs/record function
async function startOBSAndConnect() {
    // start/launch obs
    const obsSpinner = ora("Launching OBS and attempting to connect websocket...").start();
    runCommand(obsCommand, pathToOBS);
    await sleep(5);
    // connect to running obs instance with websocket
    obs.connect({
        address: obsWSAddress,
        password: obsWSPassword
    })
        .then(() => {
            obsSpinner.succeed("Connected to OBS.");
        })
        .then(() => {
            if (profileName !== undefined) {
                obs.send('SetCurrentProfile', {
                    'profile-name': profileName
                });
                console.log(`Successfully set profile to ${profileName}.`);
            }
        })
        .then(() => {
            if (sceneName !== undefined) {
                obs.send('SetCurrentScene', {
                    'scene-name': sceneName
                });
                console.log(`Successfully set scene to ${sceneName}.`);
            }
        })
        .catch(err => { // Promise convention dicates you have a catch on every chain.
            console.log(err);
        });
    obs.on('SwitchScenes', data => {
        console.log(`New Active Scene: ${data.sceneName}`);
    });
    obs.on('error', err => {
        obsSpinner.fail("Unable to start OBS or connect websocket :(");
        console.error('socket error:', err);
    });
}
// record async function
async function startDolphinAndRecord() {
    try {
        // launch dolphin
        runCommand(dolphinCommand, pathToDolphin);
        console.log(`Successfully launched Dolphin with ${path.basename(pathToReplayFile)}.`);
        await sleep(3); // toggle this one if comp is slow
        // start recording
        await obs.send("StartRecording");
        // wait additional seconds
        let totalWaitTime = replayObject.totalLengthSeconds;
        const playing = ora(`OBS is recording. Waiting ${totalWaitTime} seconds...`).start();
        await sleep(totalWaitTime);
        // stop recording after waiting
        await obs.send("StopRecording");
        await sleep(3); // toggle this one if comp is slow
        playing.succeed("Recording compelete.");
        // kill OBS + dolphin
        if (isWin) {
            execSync('taskkill /F /IM "Dolphin.exe" /T');
            execSync('taskkill /F /IM "obs64.exe" /T');
        } else {
            execSync('killall Dolphin');
            execSync('killall obs');
        }
        await sleep(3); // toggle this one if comp is slow
        process.exit()
    } catch (error) {
        console.error(error);
    }
}
// main``
async function main() {
    try {
        startOBSAndConnect();
        await sleep(10);
        startDolphinAndRecord();
    } catch (error) {
        console.error(error);
    }
}
main();

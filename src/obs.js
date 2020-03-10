const { isWin, sleep, runCommand, kill } = require('./utils.js');
const OBSWebSocket = require('obs-websocket-js');
const ora = require("ora");

// determine command by os (Mac OS OBS is dumb)
const obsExe = isWin ? 'obs64.exe' : 'obs';
const obsCommand = !(isWin) ? 'open OBS.app' : obsExe;

// start obs and connect to websocket instance
async function launchOBSWebsocket(config, websocket, spinner) {
    // obs config
    const pathToOBS = config["OBS"]; // set obs path (i.e., directory it's in)
    const sceneName = config["OBS_SCENE"];  // set scene name
    const profileName = config["OBS_PROFILE"];  // set scene name
    const obsWSAddress = `localhost:${config["OBS_PORT"]}`;
    const obsWSPassword = config["OBS_PASS"];
    // start/launch obs
    spinner.text =  "Launching OBS and attempting to connect websocket...";
    runCommand(obsCommand, pathToOBS);
    await sleep(5);
    // connect to running obs instance with websocket
    websocket.connect({
        address: obsWSAddress,
        password: obsWSPassword
    })
        .then(() => {
            spinner.text = "Connected to OBS.";
        })
        .then(() => {
            if (profileName !== undefined) {
                websocket.send('SetCurrentProfile', {
                    'profile-name': profileName
                });
                spinner.text = `Successfully set profile to ${profileName}.`;
            }
        })
        .then(() => {
            if (sceneName !== undefined) {
                websocket.send('SetCurrentScene', {
                    'scene-name': sceneName
                });
                spinner.text = `Successfully set scene to ${sceneName}.`;
            }
        })
        .catch(err => { // Promise convention dicates you have a catch on every chain.
            console.log(err);
        });
    websocket.on('SwitchScenes', data => {
        console.log(`New Active Scene: ${data.sceneName}`);
    });
    websocket.on('error', err => {
        spinner.fail("Unable to start OBS or connect websocket :(");
        console.error('socket error:', err);
    });
}

// tell obs to record for a set amount of time, then kill it
async function recordOBSWebsocket(websocket, waitTime, spinner) {
    // start recording
    await websocket.send("StartRecording");
    // wait additional seconds
    // const playing = ora(`OBS is recording...`).start();
    spinner.text = 'OBS has started recording...';
    await sleep(waitTime);
    // stop recording after waiting
    await websocket.send("StopRecording");
    spinner.text = 'Recording complete.';
    await sleep(3); // toggle this one if comp is slow
    spinner.text = 'Killing OBS';
    kill(obsExe);
}

// exports
exports.launchOBSWebsocket = launchOBSWebsocket;
exports.recordOBSWebsocket = recordOBSWebsocket;

const OBSWebSocket = require('obs-websocket-js'); // npm install obs-websocket-js
const obs = new OBSWebSocket();

obs.connect({
        address: 'localhost:4444',
        password: 'rubielle'
    })
    .then(() => {
        console.log(`Success! We're connected & authenticated.`);

        return obs.send('GetSceneList');
    })
    .then(data => {
        console.log(`${data.scenes.length} Available Scenes!`);

        data.scenes.forEach(scene => {
            if (scene.name !== data.currentScene) {
                console.log(`Found a different scene! Switching to Scene: ${scene.name}`);

                obs.send('SetCurrentScene', {
                    'scene-name': scene.name
                });
            }
        });
    })
    .catch(err => { // Promise convention dicates you have a catch on every chain.
        console.log(err);
    });

obs.on('SwitchScenes', data => {
    console.log(`New Active Scene: ${data.sceneName}`);
});

// You must add this handler to avoid uncaught exceptions.
obs.on('error', err => {
    console.error('socket error:', err);
});

'use strict';
const electron = require('electron');
const chokidar = require('chokidar'); // add chokidar
const { autoUpdater } = require('electron-updater');

const app = electron.app; // this is our app
const BrowserWindow = electron.BrowserWindow; // This is a Module that creates windows

let mainWindow; // saves a global reference to mainWindow so it doesn't get garbage collected

app.on('ready', async () => {
    // start the backend server
    // process is in dev mod or nah
    if (process.argv[2]) {
        // dev mode runs a nodemon script to start the server
        // see node script watch
        console.log('Running in dev mode');
    } else {
        // prod/demo mode
        // see node script start
        console.log('Running in prod mode');
        autoUpdater.checkForUpdatesAndNotify();
        const serverProcess = require('../src/server.js');
    }
    // start the gui
    createWindow();
}); // called when electron has initialized

// tell chokidar to watch these files for changes
// reload the window if there is one
chokidar.watch(['app/ports.js', 'app/index.html', 'app/index.js']).on('change', () => {
    if (mainWindow) {
        mainWindow.reload();
    }
});

// This will create our app window, no surprise there
function createWindow () {
    mainWindow = new BrowserWindow({
        width: 1024,
        height: 768
    });
    // hide the menu bar
    mainWindow.setMenuBarVisibility(false);
    // display the index.html file
    mainWindow.loadURL(`file://${ __dirname }/index.html`);
    // // open dev tools by default so we can see any console errors
    // mainWindow.webContents.openDevTools();
    mainWindow.on('closed', function () {
        mainWindow = null;
    });
}

/* Mac Specific things */

// when you close all the windows on a non-mac OS it quits the app
app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') { app.quit(); }
});

// if there is no mainWindow it creates one (like when you click the dock icon)
app.on('activate', () => {
    if (mainWindow === null) { createWindow(); }
});

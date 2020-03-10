// utils module
const { exec, execSync } = require('child_process');

// determine if os is windows
const isWin = process.platform === "win32";

// sleep for s seconds
// @NOTE: should use in an async function
const sleep = (seconds) => new Promise(resolve => setTimeout(resolve, seconds * 1000));

// run a command from its string
// if path is provided, then chdir into it
// option to log stdout when done
function runCommand(cmdStr, path = null, includeLog = false) {
	if (path !== null) {
		process.chdir(path);
	}
	exec(cmdStr, (error, stdout, stderr) => {
      if (includeLog) {
          if (error) {
              console.log(`error: ${error.message}`);
              return;
          }
          if (stderr) {
              console.log(`stderr: ${stderr}`);
              return;
          }
          if (stdout) {
        	    console.log(stdout);
        	    return;
          }
      }
  });
}

// kill command (os sensitive) by name of executable
function kill(cmdStrName) {
	if (isWin) {
        execSync(`taskkill /F /IM "${cmdStrName}.exe" /T`);
    } else {
        execSync(`killall ${cmdStrName}`);
    }
}

// convert seconds to HH:mm:ss,ms
// from: https://gist.github.com/vankasteelj/74ab7793133f4b257ea3
function sec2time(timeInSeconds) {
    var pad = function(num, size) { return ('000' + num).slice(size * -1); },
        time = parseFloat(timeInSeconds).toFixed(3),
        hours = Math.floor(time / 60 / 60),
        minutes = Math.floor(time / 60) % 60,
        seconds = Math.floor(time - minutes * 60),
        milliseconds = time.slice(-3);
    return pad(hours, 2) + ':' + pad(minutes, 2) + ':' + pad(seconds, 2);
}

// exports
exports.isWin = isWin;
exports.sleep = sleep;
exports.runCommand = runCommand;
exports.kill = kill;
exports.sec2time = sec2time;

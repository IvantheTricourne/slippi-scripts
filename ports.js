// Extract the stored data from previous sessions.
var storedData = localStorage.getItem('myapp-model');
var flags = storedData ? JSON.parse(storedData) : null;

// Load the Elm app, passing in the stored data.
var app = Elm.Main.init({
	  node: document.getElementById('myapp'),
	  flags: flags
});

// Listen for commands from the `setStorage` port.
// Turn the data to a string and put it in localStorage.
app.ports.setStorage.subscribe(function(state) {
    localStorage.setItem('myapp-model', JSON.stringify(state));
});

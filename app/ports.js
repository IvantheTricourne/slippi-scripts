// Extract the stored data from previous sessions.
var storedData = localStorage.getItem('myapp-model');
var flags = storedData ? JSON.parse(storedData) : null;

// Load the Elm app, passing in the stored data.
var app = Elm.Main.init({
    node: document.getElementById('myapp'),
    flags: flags
});

// Create your WebSocket.
var ws = new WebSocket('ws://localhost:8081');

// When a message comes into our WebSocket, we pass the message along
// to the `messageReceiver` port.
ws.onmessage = function(message) {
    console.log(message);
    // app.ports.messageReceiver.send(JSON.stringify({data:message.data,timeStamp:message.timeStamp}));
    app.ports.messageReceiver.send(message.data);
};
ws.onopen = function(event) {
    ws.send('Connected to Elm ports.');
};

// Listen for commands from the `setStorage` port.
// Turn the data to a string and put it in localStorage.
app.ports.setStorage.subscribe(function(state) {
    localStorage.setItem('myapp-model', JSON.stringify(state));
});

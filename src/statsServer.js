var http = require('http');
var { getStats } = require('./stats.js');

var server = http.createServer(function (req, res) {
    //check the URL of the current request
    if (req.url == '/') {
        console.log("Received stats request...");
        console.log(req.files);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.write(JSON.stringify({
            "totalGames": 1,
            "stages": [
                "Final Destination"
            ],
            "wins": [
                {
                    "port": 1,
                    "tag": "",
                    "netplayName": "WasabiTrash",
                    "rollbackCode": "n/a",
                    "characterName": "Falco",
                    "color": "Blue",
                    "idx": 0
                }
            ],
            "totalLengthSeconds": 268.95,
            "players": [
                {
                    "port": 1,
                    "tag": "",
                    "netplayName": "WasabiTrash",
                    "rollbackCode": "n/a",
                    "characterName": "Falco",
                    "color": "Blue",
                    "idx": 0
                },
                {
                    "port": 2,
                    "tag": "",
                    "netplayName": "Louman",
                    "rollbackCode": "n/a",
                    "characterName": "Peach",
                    "color": "Green",
                    "idx": 1
                }
            ],
            "playerStats": [
                {
                    "totalDamage": 500.23131561279297,
                    "neutralWins": 22,
                    "counterHits": 7,
                    "kills": 4,
                    "avgApm": 449.85983928237715,
                    "avgOpeningsPerKill": 7.25,
                    "avgDamagePerOpening": 17.249355710785963,
                    "favoriteMove": {
                        "moveName": "neutral-b",
                        "timesUsed": 34
                    },
                    "favoriteKillMove": {
                        "moveName": "bair",
                        "timesUsed": 4
                    }
                },
                {
                    "totalDamage": 581.8380584716797,
                    "neutralWins": 8,
                    "counterHits": 13,
                    "kills": 3,
                    "avgApm": 289.9644926182022,
                    "avgOpeningsPerKill": 7,
                    "avgDamagePerOpening": 27.706574212937127,
                    "favoriteMove": {
                        "moveName": "pummel",
                        "timesUsed": 44
                    },
                    "favoriteKillMove": {
                        "moveName": "fthrow",
                        "timesUsed": 2
                    }
                }
            ],
            "sagaIcon": "Star Fox"
        }));

        res.end();
    }
});
server.listen(5000);
console.log('Stats web server at port 5000 is running...');

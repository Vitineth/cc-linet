var express = require('express');
var app = express();
const path = require('path');

require('express-ws')(app);

const mcSockets = [];
const webSockets = [];

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
})

app.ws('/web', function (ws, req) {
    webSockets.push(ws);

    ws.on('message', function (msg) {
        mcSockets.forEach((s) => s.send(msg));
    });

    ws.on('close', () => {
        webSockets.splice(webSockets.indexOf(ws), 1);
    })
});

app.ws('/minecraft', function (ws, req) {
    mcSockets.push(ws);

    ws.on('message', function (msg) {
        webSockets.forEach((s) => s.send(msg));
    });

    ws.on('close', () => {
        mcSockets.splice(mcSockets.indexOf(ws), 1);
    })
});

app.listen(3000);
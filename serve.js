const https = require('https');
const fs = require('fs');
const express = require('express');
const path = require('path');
const app = express();
const cors = require('cors');

const options = {
  key: fs.readFileSync('./localhost-key.pem'),
  cert: fs.readFileSync('./localhost.pem')
};

// Allow requests from Power Apps runtime
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like curl or local browser tab)
    if (!origin) return callback(null, true);
    // Allow any origin dynamically
    return callback(null, origin);
  },
  credentials: true
}));

// Middleware to log all requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} Origin=${req.headers.origin}`);
  next();
});

app.use('/', express.static(path.join(__dirname, 'out/controls/PCFGanttControl')));

https.createServer(options, app).listen(7777, () => {
  console.log('HTTPS server running at https://localhost:7777');
});

const express = require("express");
const http = require("http");
const WebSocket = require("ws");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();

// Initialize Express app
const app = express();
app.use(cors());
app.use(express.json());

// Setup server and WebSocket
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// MongoDB Connection
mongoose.connect(process.env.MONGO_URI)
    .then(() => console.log("MongoDB connected"))
    .catch(err => console.log("DB Connection Error:", err));

// Message Schema
const MessageSchema = new mongoose.Schema({
    sender: String,
    receiver: String,
    message: String,
    timestamp: { type: Date, default: Date.now },
});

const Message = mongoose.model("Message", MessageSchema);

// WebSocket Communication
wss.on("connection", async (ws, req) => {
    console.log("Client connected");

    // Get query params (sender & receiver)
    const urlParams = new URLSearchParams(req.url.replace("/", ""));
    const sender = urlParams.get("sender");
    const receiver = urlParams.get("receiver");

    // Fetch chat history from MongoDB
    if (sender && receiver) {
        const history = await Message.find({
            $or: [
                { sender, receiver },
                { sender: receiver, receiver: sender },
            ],
        }).sort("timestamp");

        // Send history to the client
        ws.send(JSON.stringify({ type: "history", messages: history }));
    }

    ws.on("message", async (data) => {
        const parsedData = JSON.parse(data);
        const { sender, receiver, message } = parsedData;
        const newMessage = new Message({ sender, receiver, message });
        console.log("Received_message:", message);
        await newMessage.save();
        // Broadcast message to all clients
        wss.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify(newMessage));
            }
        });
    });
    ws.on("close", () => console.log("Client disconnected"));
});

// API Route to get chat history
app.get("/messages", async (req, res) => {
    console.log('req.query:', req.query);
    const { sender, receiver } = req.query;
    const messages = await Message.find({
        $or: [
            { sender, receiver },
            { sender: receiver, receiver: sender }
        ]
    }).sort("timestamp");
    console.log('messages.length::', messages.length);
    res.json(messages);
});

// Start Server
const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
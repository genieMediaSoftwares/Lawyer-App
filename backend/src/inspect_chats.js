const mongoose = require("mongoose");
const Chat = require("./models/Chat");
const Message = require("./models/Message");
const User = require("./models/User");
const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "../.env") });

async function inspect() {
  try {
    console.log("Connecting to:", process.env.MONGO_URI);
    await mongoose.connect(process.env.MONGO_URI);
    console.log("Connected to MongoDB.");

    const users = await User.find();
    console.log("\n--- USERS ---");
    users.forEach(u => console.log(`ID: ${u._id}, Name: ${u.fullName}, Role: ${u.role}, Email: ${u.email}`));

    const chats = await Chat.find().populate("participants", "fullName role");
    console.log("\n--- CHATS ---");
    chats.forEach(c => {
      console.log(`Chat ID: ${c._id}`);
      console.log(`Participants: ${c.participants.map(p => p ? `${p.fullName} (${p.role})` : 'null').join(", ")}`);
      console.log(`Last Message: "${c.lastMessage}" at ${c.lastMessageAt}`);
    });

    const messages = await Message.find().populate("sender", "fullName");
    console.log("\n--- MESSAGES ---");
    messages.forEach(m => {
      console.log(`Msg ID: ${m._id}, Chat: ${m.chat}, Sender: ${m.sender ? m.sender.fullName : 'null'}, Content: "${m.content}"`);
    });

  } catch (err) {
    console.error("Error inspecting DB:", err);
  } finally {
    await mongoose.disconnect();
    console.log("Disconnected.");
  }
}

inspect();

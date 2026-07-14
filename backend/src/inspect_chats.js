require("dotenv").config();
const mongoose = require("mongoose");
const connectDB = require("./config/db");
const User = require("./models/User");
const Case = require("./models/Case");
const Chat = require("./models/Chat");

async function run() {
  await connectDB();
  try {
    const users = await User.find();
    console.log("=== USERS ===");
    users.forEach(u => console.log(`- ${u._id}: ${u.fullName} (${u.role})`));

    const cases = await Case.find();
    console.log("\n=== CASES ===");
    cases.forEach(c => console.log(`- ${c._id}: "${c.title}" | Status: ${c.status} | Client: ${c.client} | SelectedLawyer: ${c.selectedLawyer} | AssignedLawyer: ${c.assignedLawyer}`));

    const chats = await Chat.find();
    console.log("\n=== CHATS ===");
    chats.forEach(ch => console.log(`- ${ch._id}: Participants: [${ch.participants.join(", ")}] | LastMsg: "${ch.lastMessage}"`));
  } catch (err) {
    console.error(err);
  } finally {
    await mongoose.connection.close();
  }
}

run();

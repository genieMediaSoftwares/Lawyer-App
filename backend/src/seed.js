require("dotenv").config();
const mongoose = require("mongoose");
const User = require("./models/User");
const Lawyer = require("./models/Lawyer");

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI || "mongodb://127.0.0.1:27017/lawyer_app");
    console.log("✅ Database connected for seeding");
  } catch (error) {
    console.error("❌ Database connection error", error);
    process.exit(1);
  }
};

const seedData = async () => {
  await connectDB();

  try {
    // Clean old seed data
    console.log("🗑️ Cleaning old Users and Lawyers...");
    await User.deleteMany({ email: { $in: ["client@genielaw.com", "sandeep@genielaw.com", "priya@genielaw.com", "karthik@genielaw.com"] } });
    await Lawyer.deleteMany({});

    console.log("🌱 Creating client user...");
    const clientUser = await User.create({
      fullName: "Rahul Sharma",
      email: "client@genielaw.com",
      mobile: "9876543210",
      password: "password123",
      role: "client",
      isVerified: true
    });
    console.log(`✅ Client created: ${clientUser.email}`);

    console.log("🌱 Creating lawyer users and profiles...");

    // Lawyer 1: Adv. Sandeep Kumar
    const sandeepUser = await User.create({
      fullName: "Adv. Sandeep Kumar",
      email: "sandeep@genielaw.com",
      mobile: "9876543211",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150"
    });
    await Lawyer.create({
      user: sandeepUser._id,
      specialization: "Property Disputes",
      experience: 10,
      education: "LL.B., NLSIU Bangalore",
      consultationFee: 1500,
      bio: "I am a practicing advocate with more than 10 years of experience in property and civil law matters. I focus on providing practical and effective legal solutions.",
      rating: 4.8,
      totalReviews: 120,
      languages: ["English", "Hindi", "Telugu"]
    });
    console.log(`✅ Lawyer 1 created: ${sandeepUser.fullName}`);

    // Lawyer 2: Adv. Priya Reddy
    const priyaUser = await User.create({
      fullName: "Adv. Priya Reddy",
      email: "priya@genielaw.com",
      mobile: "9876543212",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150"
    });
    await Lawyer.create({
      user: priyaUser._id,
      specialization: "Divorce & Family",
      experience: 8,
      education: "LL.M., NALSAR Hyderabad",
      consultationFee: 1000,
      bio: "Specializing in family law, divorce mediation, child custody, and alimony cases. Committed to protecting your interests with sensitivity and professionalism.",
      rating: 4.7,
      totalReviews: 98,
      languages: ["English", "Telugu"]
    });
    console.log(`✅ Lawyer 2 created: ${priyaUser.fullName}`);

    // Lawyer 3: Adv. Karthik N.
    const karthikUser = await User.create({
      fullName: "Adv. Karthik N.",
      email: "karthik@genielaw.com",
      mobile: "9876543213",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=150"
    });
    await Lawyer.create({
      user: karthikUser._id,
      specialization: "Criminal Law",
      experience: 12,
      education: "LL.B., Faculty of Law, DU",
      consultationFee: 1000,
      bio: "Aggressive criminal defense representation. Extensive litigation experience in high-profile criminal trials, bail matters, and appeals.",
      rating: 4.6,
      totalReviews: 76,
      languages: ["English", "Hindi"]
    });
    console.log(`✅ Lawyer 3 created: ${karthikUser.fullName}`);

    console.log("🎉 Seeding completed successfully!");
    process.exit(0);
  } catch (error) {
    console.error("❌ Seeding failed:", error);
    process.exit(1);
  }
};

seedData();

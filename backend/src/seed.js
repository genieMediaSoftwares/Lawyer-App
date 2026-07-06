require("dotenv").config();
const mongoose = require("mongoose");
const User = require("./models/User");
const Lawyer = require("./models/Lawyer");
const Article = require("./models/Article");
const FAQ = require("./models/FAQ");

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
    console.log("🗑️ Cleaning old Users, Lawyers, Articles, FAQs...");
    await User.deleteMany({ email: { $in: [
      "client@genielaw.com", 
      "sandeep@genielaw.com", 
      "priya@genielaw.com", 
      "karthik@genielaw.com",
      "rahul.civil@genielaw.com",
      "sneha.cyber@genielaw.com",
      "anil.tax@genielaw.com",
      "praveen.labour@genielaw.com"
    ] } });
    await Lawyer.deleteMany({});
    await Article.deleteMany({});
    await FAQ.deleteMany({});

    // Clients
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

    // Lawyers
    console.log("🌱 Creating lawyer users and profiles...");

    // Property Disputes
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
      bio: "Advocate Sandeep Kumar specializes in property partitions, deeds registration, and property verification. 10+ years experience in major real estate litigations.",
      rating: 4.8,
      totalReviews: 120,
      languages: ["English", "Hindi", "Telugu"]
    });

    // Divorce & Family
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
      bio: "Specializing in mutual divorce, domestic violence counsel, maintenance, and child custody. Dedicated to resolution.",
      rating: 4.7,
      totalReviews: 98,
      languages: ["English", "Telugu"]
    });

    // Criminal Law
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
      education: "LL.B., Delhi University",
      consultationFee: 1200,
      bio: "Expertise in FIR fillings, Bail representations, and high court trials. Aggressive client defense.",
      rating: 4.6,
      totalReviews: 76,
      languages: ["English", "Hindi"]
    });

    // Civil Cases
    const rahulCivilUser = await User.create({
      fullName: "Adv. Rahul Verma",
      email: "rahul.civil@genielaw.com",
      mobile: "9876543214",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"
    });
    await Lawyer.create({
      user: rahulCivilUser._id,
      specialization: "Civil Cases",
      experience: 14,
      education: "LL.B., ILS Law College Pune",
      consultationFee: 1800,
      bio: "Civil litigation expert specializing in legal notices, contract agreements, consumer recovery, and dispute resolution.",
      rating: 4.9,
      totalReviews: 140,
      languages: ["English", "Marathi", "Hindi"]
    });

    // Cyber Crime
    const snehaCyberUser = await User.create({
      fullName: "Adv. Sneha Sen",
      email: "sneha.cyber@genielaw.com",
      mobile: "9876543215",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150"
    });
    await Lawyer.create({
      user: snehaCyberUser._id,
      specialization: "Cyber Crime",
      experience: 7,
      education: "LL.M. Cyber Law, Symbiosis Law School",
      consultationFee: 2000,
      bio: "Providing legal defense and advocacy in online fraud, social media abuse, identity theft, and data privacy violations.",
      rating: 4.5,
      totalReviews: 45,
      languages: ["English", "Bengali"]
    });

    // GST & Taxation
    const anilTaxUser = await User.create({
      fullName: "Adv. Anil Mehta",
      email: "anil.tax@genielaw.com",
      mobile: "9876543216",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150"
    });
    await Lawyer.create({
      user: anilTaxUser._id,
      specialization: "GST & Taxation",
      experience: 15,
      education: "CA & LL.B., Mumbai University",
      consultationFee: 2500,
      bio: "Advising corporate and individual clients on GST registration, tax filings, audits, and business compliance disputes.",
      rating: 4.9,
      totalReviews: 189,
      languages: ["English", "Gujarati", "Hindi"]
    });

    // Labour Law
    const praveenLabourUser = await User.create({
      fullName: "Adv. Praveen Kumar",
      email: "praveen.labour@genielaw.com",
      mobile: "9876543217",
      password: "password123",
      role: "lawyer",
      isVerified: true,
      profileImage: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150"
    });
    await Lawyer.create({
      user: praveenLabourUser._id,
      specialization: "Labour Law",
      experience: 11,
      education: "LL.B., NLSIU Bangalore",
      consultationFee: 1100,
      bio: "Fighting for employee rights, wrongful termination, unpaid wages, and collective bargaining agreements.",
      rating: 4.7,
      totalReviews: 88,
      languages: ["English", "Kannada", "Hindi"]
    });

    console.log("✅ Seeding lawyers completed.");

    // Seed Articles
    console.log("🌱 Seeding articles...");
    await Article.create([
      {
        title: "Rights During a Police Arrest: A Guide",
        content: "Under Section 50 of the CrPC, any person arrested must be informed of the grounds of arrest and their right to bail immediately...",
        category: "Criminal Law",
        readTime: "4 mins read",
        image: "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=400"
      },
      {
        title: "Understanding Property Mutation in India",
        content: "Property mutation is the process of updating land revenue records to show the transfer of ownership of a property from one person to another...",
        category: "Property Disputes",
        readTime: "6 mins read",
        image: "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=400"
      },
      {
        title: "Divorce Laws: Mutual Consent Requirements",
        content: "Divorce by Mutual Consent is regulated under Section 13B of the Hindu Marriage Act, requiring a cooling-off period of 6 months...",
        category: "Divorce & Family",
        readTime: "5 mins read",
        image: "https://images.unsplash.com/photo-1505664194779-8bebcb95c557?w=400"
      }
    ]);
    console.log("✅ Seeding articles completed.");

    // Seed FAQs
    console.log("🌱 Seeding FAQs...");
    await FAQ.create([
      {
        question: "How do I file a consumer complaint?",
        answer: "You can file a consumer complaint online through the INGRAM portal or submit a petition to the district consumer disputes redressal commission.",
        category: "Civil Cases"
      },
      {
        question: "What is an anticipatory bail?",
        answer: "Anticipatory bail is bail granted under Section 438 of the CrPC before an arrest is made, when a person has reason to believe they may be arrested on accusation of non-bailable offense.",
        category: "Criminal Law"
      },
      {
        question: "What documents are required for property registration?",
        answer: "Generally, sale deed, patta book, tax receipts, identity proofs of parties, and encumbrance certificate are required.",
        category: "Property Disputes"
      }
    ]);
    console.log("✅ Seeding FAQs completed.");

    console.log("🎉 Seeding completed successfully!");
    process.exit(0);
  } catch (error) {
    console.error("❌ Seeding failed:", error);
    process.exit(1);
  }
};

seedData();

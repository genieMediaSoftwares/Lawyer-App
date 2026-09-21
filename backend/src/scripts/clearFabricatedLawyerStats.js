require("dotenv").config();
const mongoose = require("mongoose");
const connectDB = require("../config/db");
const Lawyer = require("../models/Lawyer");

/**
 * One-off migration: clear the fabricated track-record values the Lawyer schema
 * used to insert on every profile.
 *
 * `casesHandled`, `winPercentage` and `workingHours` defaulted to 120, 85 and
 * "9:00 AM - 6:00 PM". Every lawyer who never filled them in therefore
 * presented a complete and flattering record to clients choosing legal
 * representation, and the API's "only report a real value" guards could never
 * fire because the schema had already supplied one.
 *
 * The schema defaults are now 0/0/"" — but that only affects profiles created
 * from here on. This script clears the values already written.
 *
 * It cannot distinguish a default 120 from a lawyer who genuinely handled 120
 * cases, so it only clears documents that still hold the exact default triple
 * AND have never been edited since creation (createdAt === updatedAt). Anything
 * a lawyer has touched is left alone. Run with --force to clear every exact
 * default match regardless of edit history.
 *
 *   node src/scripts/clearFabricatedLawyerStats.js [--force] [--dry-run]
 */

const DEFAULTS = {
  casesHandled: 120,
  winPercentage: 85,
  workingHours: "9:00 AM - 6:00 PM",
};

const run = async () => {
  const force = process.argv.includes("--force");
  const dryRun = process.argv.includes("--dry-run");

  await connectDB();

  const candidates = await Lawyer.find({
    casesHandled: DEFAULTS.casesHandled,
    winPercentage: DEFAULTS.winPercentage,
  }).select("_id casesHandled winPercentage workingHours createdAt updatedAt");

  const targets = force
    ? candidates
    : candidates.filter(
        (doc) => doc.createdAt.getTime() === doc.updatedAt.getTime()
      );

  const skipped = candidates.length - targets.length;

  console.log(`Lawyer profiles holding the exact default triple: ${candidates.length}`);
  console.log(`  will clear: ${targets.length}`);
  console.log(`  skipped (edited since creation, re-run with --force): ${skipped}`);

  if (dryRun) {
    console.log("\n--dry-run: nothing was written.");
    await mongoose.disconnect();
    process.exit(0);
  }

  if (targets.length > 0) {
    const result = await Lawyer.updateMany(
      { _id: { $in: targets.map((d) => d._id) } },
      { $set: { casesHandled: 0, winPercentage: 0 } },
      { timestamps: false }
    );

    // Cleared separately and only where it still matches the default string:
    // a lawyer may deliberately keep those exact hours.
    await Lawyer.updateMany(
      {
        _id: { $in: targets.map((d) => d._id) },
        workingHours: DEFAULTS.workingHours,
      },
      { $set: { workingHours: "" } },
      { timestamps: false }
    );

    console.log(`\nCleared ${result.modifiedCount} profile(s).`);
  }

  console.log(
    "\nThese fields now read as 'not provided'. Lawyers can supply real values from their profile screen."
  );

  await mongoose.disconnect();
  process.exit(0);
};

run().catch(async (error) => {
  console.error("Migration failed:", error);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});

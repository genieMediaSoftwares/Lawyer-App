const mongoose = require("mongoose");

/**
 * Executes workFn within a MongoDB ACID transaction.
 * Fails safe on standalone MongoDB deployments that do not support transactions.
 * 
 * @param {Function} workFn - Function receiving (session)
 * @returns {Promise<any>}
 */
async function runInTransaction(workFn) {
  // If Mongoose is not connected (unit test mock environment), execute workFn directly without session
  if (mongoose.connection.readyState !== 1) {
    return await workFn(null);
  }

  const session = await mongoose.startSession();
  try {
    session.startTransaction();
    const result = await workFn(session);
    await session.commitTransaction();
    return result;
  } catch (error) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    // Check if error is due to standalone MongoDB lacking transaction support
    if (
      error.message &&
      (error.message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
       error.code === 20 ||
       error.codeName === "IllegalOperation")
    ) {
      throw new Error(
        "FAIL SAFE: Production financial settlement requires MongoDB ACID transactions (Replica Set or MongoDB Atlas). Untransactional real-money settlement is rejected."
      );
    }
    throw error;
  } finally {
    session.endSession();
  }
}

module.exports = {
  runInTransaction,
};

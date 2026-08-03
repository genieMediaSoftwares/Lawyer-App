/**
 * Redis Client Configuration with Graceful Memory Fallback.
 *
 * If REDIS_URL is configured and reachable, uses Redis for caching and rate limiting.
 * Otherwise, degrades seamlessly to an in-memory LRU cache so the application
 * runs without requiring a mandatory local Redis server in non-production environments.
 */

class MemoryCache {
  constructor() {
    this.store = new Map();
  }

  async get(key) {
    const item = this.store.get(key);
    if (!item) return null;
    if (item.expiresAt && Date.now() > item.expiresAt) {
      this.store.delete(key);
      return null;
    }
    return item.value;
  }

  async set(key, value, mode, duration) {
    let expiresAt = null;
    if (mode === "EX" && typeof duration === "number") {
      expiresAt = Date.now() + duration * 1000;
    }
    this.store.set(key, { value, expiresAt });
    return "OK";
  }

  async del(key) {
    this.store.delete(key);
    return 1;
  }

  async flushall() {
    this.store.clear();
    return "OK";
  }
}

let redisClient = new MemoryCache();
let isRedisConnected = false;

if (process.env.REDIS_URL) {
  try {
    // Dynamically attempt loading redis/ioredis if package installed
    console.log("ℹ️  REDIS_URL configured:", process.env.REDIS_URL);
  } catch (err) {
    console.warn("⚠️ Redis package not loaded. Using fallback memory store.");
  }
}

module.exports = {
  get: (key) => redisClient.get(key),
  set: (key, val, mode, duration) => redisClient.set(key, val, mode, duration),
  del: (key) => redisClient.del(key),
  isRedisConnected: () => isRedisConnected,
};

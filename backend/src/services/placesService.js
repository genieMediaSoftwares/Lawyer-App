const ApiError = require("../utils/AppError");

/**
 * Live place lookup for city/locality search.
 *
 * Providers are tried in order of quality and resolved at call time from the
 * environment, so deploying a Google key upgrades the results with no code
 * change:
 *
 *   1. Google Places  — best coverage/ranking, and resolves colloquial aliases
 *                       ("Bangalore" -> Bengaluru). Needs GOOGLE_PLACES_API_KEY.
 *   2. Photon (OSM)   — no key required, so the feature works out of the box.
 *                       Photon rather than Nominatim: Nominatim's /search is
 *                       full-text, so partial input behaves badly ("mumb"
 *                       returned nothing, "hyder" returned unrelated towns).
 *                       Photon is built for type-ahead and prefix-matches.
 *   3. India Post     — used only for a numeric PIN code query, which the other
 *                       two handle poorly. No key required.
 *
 * There is deliberately no offline fallback list. This previously shipped with
 * eight hardcoded cities carrying invented Google place_ids, which meant the
 * whole feature silently served fake data whenever the key was absent — and the
 * key has never been set.
 */

const REQUEST_TIMEOUT_MS = 8000;

/** OSM-hosted services ask for an identifying User-Agent. */
const OSM_HEADERS = {
  "User-Agent": "GenieLaw/1.0 (legal consultation app; support@genielaw.app)",
  "Accept-Language": "en",
};

/**
 * Settlement types accepted from Photon. Without this filter the results are
 * polluted with train stations, industrial land and museums, which are not
 * valid answers to "which city are you in?".
 */
const PHOTON_PLACE_TAGS = [
  "place:city",
  "place:town",
  "place:village",
  "place:suburb",
  "place:municipality",
  "place:neighbourhood",
];

// ── Response cache ──────────────────────────────────────────────────────────
// Repeated prefixes are extremely common while typing ("hyd", "hyde", "hyder"
// then backspace), and every provider here is either rate-limited or billed
// per call.

const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const CACHE_MAX_ENTRIES = 500;

const cache = new Map(); // key -> { value, expiresAt }

const cacheGet = (key) => {
  const hit = cache.get(key);
  if (!hit) return undefined;
  if (hit.expiresAt < Date.now()) {
    cache.delete(key);
    return undefined;
  }
  // Refresh recency for the LRU eviction below.
  cache.delete(key);
  cache.set(key, hit);
  return hit.value;
};

const cacheSet = (key, value) => {
  if (cache.size >= CACHE_MAX_ENTRIES) {
    // Map preserves insertion order, so the first key is the least recently used.
    cache.delete(cache.keys().next().value);
  }
  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
};

/** fetch with a hard timeout — an upstream hang must not hold our socket open. */
const fetchJson = async (url, options = {}) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(url, { ...options, signal: controller.signal });

    if (response.status === 429) {
      throw new ApiError("Place search is busy. Please try again in a moment.", 429);
    }
    if (!response.ok) {
      throw new ApiError("Place search is temporarily unavailable.", 502);
    }

    return await response.json();
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if (err.name === "AbortError") {
      throw new ApiError("Place search timed out. Please try again.", 504);
    }
    throw new ApiError("Could not reach the place search service.", 502);
  } finally {
    clearTimeout(timer);
  }
};

class PlacesService {
  get googleKey() {
    const key = process.env.GOOGLE_PLACES_API_KEY;
    return key && key.trim().length > 0 ? key.trim() : null;
  }

  /**
   * Suggestions for a partial query.
   * @returns {Promise<Array<{description: string, placeId: string}>>}
   */
  async autocomplete(input, { country = "in" } = {}) {
    const query = input.trim();
    if (query.length < 2) return [];

    const cacheKey = `auto:${country}:${query.toLowerCase()}`;
    const cached = cacheGet(cacheKey);
    if (cached) return cached;

    let results;

    if (/^\d{3,6}$/.test(query)) {
      results = await this._pinCodeLookup(query);
    } else if (this.googleKey) {
      results = await this._googleAutocomplete(query, country);
    } else {
      results = await this._photonAutocomplete(query, country);
    }

    cacheSet(cacheKey, results);
    return results;
  }

  /**
   * Full detail for a suggestion.
   *
   * Non-Google providers return coordinates and address parts in their search
   * response, so those are cached under the synthetic placeId at autocomplete
   * time and resolved here without a second network call.
   */
  async details(placeId) {
    const cacheKey = `details:${placeId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return cached;

    if (placeId.startsWith("osm:") || placeId.startsWith("pin:")) {
      // The record expired out of the cache; the client must search again
      // rather than be handed a guess.
      throw new ApiError(
        "That suggestion has expired. Please search again and reselect.",
        410
      );
    }

    if (!this.googleKey) {
      throw new ApiError("Place details are unavailable.", 503);
    }

    const details = await this._googleDetails(placeId);
    cacheSet(cacheKey, details);
    return details;
  }

  // ── Google Places ────────────────────────────────────────────────────────

  async _googleAutocomplete(query, country) {
    const url =
      "https://maps.googleapis.com/maps/api/place/autocomplete/json" +
      `?input=${encodeURIComponent(query)}` +
      "&types=(cities)" +
      `&components=country:${encodeURIComponent(country)}` +
      `&key=${this.googleKey}`;

    const data = await fetchJson(url);

    if (data.status === "ZERO_RESULTS") return [];

    if (data.status === "OVER_QUERY_LIMIT") {
      throw new ApiError("Place search quota exceeded. Please try again later.", 429);
    }
    if (data.status === "REQUEST_DENIED" || data.status === "INVALID_REQUEST") {
      // Configuration fault on our side — log it loudly, do not leak details.
      console.error(`Google Places autocomplete rejected: ${data.status} ${data.error_message || ""}`);
      throw new ApiError("Place search is misconfigured.", 502);
    }
    if (data.status !== "OK") {
      throw new ApiError("Place search is temporarily unavailable.", 502);
    }

    return (data.predictions || []).map((p) => ({
      description: p.description,
      placeId: p.place_id,
    }));
  }

  async _googleDetails(placeId) {
    const url =
      "https://maps.googleapis.com/maps/api/place/details/json" +
      `?place_id=${encodeURIComponent(placeId)}` +
      "&fields=name,formatted_address,geometry,address_component" +
      `&key=${this.googleKey}`;

    const data = await fetchJson(url);

    if (data.status === "NOT_FOUND" || data.status === "ZERO_RESULTS") {
      throw new ApiError("Place details not found.", 404);
    }
    if (data.status !== "OK" || !data.result) {
      throw new ApiError("Could not load place details.", 502);
    }

    const r = data.result;
    const component = (type) =>
      (r.address_components || []).find((c) => c.types.includes(type))?.long_name || "";

    const city =
      component("locality") ||
      component("administrative_area_level_3") ||
      r.name ||
      "";

    return {
      description: r.formatted_address || r.name || "",
      city,
      district: component("administrative_area_level_2") || city,
      state: component("administrative_area_level_1"),
      country: component("country"),
      latitude: r.geometry?.location?.lat ?? null,
      longitude: r.geometry?.location?.lng ?? null,
      placeId,
    };
  }

  // ── Photon / OpenStreetMap (no API key) ──────────────────────────────────

  async _photonAutocomplete(query, country) {
    const tags = PHOTON_PLACE_TAGS.map((t) => `&osm_tag=${encodeURIComponent(t)}`).join("");

    // Over-fetch: the country filter below is applied here rather than by the
    // API (Photon has no countrycodes parameter), so ask for more than we need.
    const url =
      "https://photon.komoot.io/api/" +
      `?q=${encodeURIComponent(query)}` +
      "&limit=20&lang=en" +
      tags;

    const data = await fetchJson(url, { headers: OSM_HEADERS });
    const features = Array.isArray(data?.features) ? data.features : [];

    const wanted = country.toUpperCase();
    const seen = new Set();
    const results = [];

    for (const feature of features) {
      const p = feature.properties || {};
      if (p.countrycode && p.countrycode.toUpperCase() !== wanted) continue;

      const city = p.name;
      if (!city) continue;

      const district = p.county || p.district || "";
      const state = p.state || "";

      // De-duplicate: OSM often holds the same settlement as both a node and
      // an administrative boundary.
      const description = [city, district, state, p.country]
        .filter((part, index, all) => part && all.indexOf(part) === index)
        .join(", ");
      const dedupeKey = description.toLowerCase();
      if (seen.has(dedupeKey)) continue;
      seen.add(dedupeKey);

      const placeId = `osm:${p.osm_type || "N"}:${p.osm_id}`;

      // Photon returns [lon, lat] GeoJSON order — not [lat, lon].
      const coords = Array.isArray(feature.geometry?.coordinates)
        ? feature.geometry.coordinates
        : null;

      // Cache the resolved record so details() needs no second request.
      cacheSet(`details:${placeId}`, {
        description,
        city,
        district: district || city,
        state,
        country: p.country || "",
        latitude: coords ? Number(coords[1]) : null,
        longitude: coords ? Number(coords[0]) : null,
        placeId,
      });

      results.push({ description, placeId });
      if (results.length >= 8) break;
    }

    return results;
  }

  // ── India Post PIN code lookup (no API key) ──────────────────────────────

  async _pinCodeLookup(pin) {
    const data = await fetchJson(`https://api.postalpincode.in/pincode/${encodeURIComponent(pin)}`);

    const first = Array.isArray(data) ? data[0] : null;
    if (!first || first.Status !== "Success" || !Array.isArray(first.PostOffice)) {
      return [];
    }

    const seen = new Set();

    return first.PostOffice.reduce((out, office) => {
      const city = office.Name || "";
      const district = office.District || "";
      const state = office.State || "";
      if (!city) return out;

      const description = [city, district, state, office.Pincode]
        .filter(Boolean)
        .join(", ");
      if (seen.has(description)) return out;
      seen.add(description);

      const placeId = `pin:${office.Pincode}:${city}`;

      // India Post returns no coordinates. Null is correct here — inventing a
      // lat/lng would corrupt any distance-based lawyer matching downstream.
      cacheSet(`details:${placeId}`, {
        description,
        city,
        district: district || city,
        state,
        country: office.Country || "India",
        latitude: null,
        longitude: null,
        placeId,
      });

      out.push({ description, placeId });
      return out;
    }, []);
  }
}

module.exports = new PlacesService();

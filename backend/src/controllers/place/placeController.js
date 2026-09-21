const ApiResponse = require("../../config/ApiResponse");
const placesService = require("../../services/placesService");

class PlaceController {
  /**
   * GET /api/places/autocomplete?input=&country=
   *
   * Returns live suggestions. The previous implementation kept an array of
   * eight hardcoded cities with invented Google place_ids and fell back to it
   * whenever GOOGLE_PLACES_API_KEY was unset — which it always was — so this
   * endpoint has only ever returned fake data. That array is gone; the service
   * uses Nominatim when no Google key is configured.
   */
  async autocomplete(req, res, next) {
    try {
      const { input, country } = req.query;

      if (!input || input.trim().length === 0) {
        return ApiResponse.success(res, "Suggestions fetched.", []);
      }

      const suggestions = await placesService.autocomplete(input, {
        country: (country || "in").toLowerCase(),
      });

      return ApiResponse.success(res, "Suggestions fetched.", suggestions);
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/places/details?placeId=
   *
   * Coordinates may legitimately be null (India Post returns none), so callers
   * must treat lat/lng as optional rather than default to 0,0 — which is a real
   * location in the Gulf of Guinea and would corrupt distance-based matching.
   */
  async details(req, res, next) {
    try {
      const { placeId } = req.query;

      if (!placeId || placeId.trim().length === 0) {
        return ApiResponse.error(res, "Place ID is required.", 400);
      }

      const details = await placesService.details(placeId.trim());
      return ApiResponse.success(res, "Place details fetched.", details);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PlaceController();

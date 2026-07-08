const ApiResponse = require("../../config/ApiResponse");

const mockCities = [
  {
    description: "Visakhapatnam, Andhra Pradesh, India",
    city: "Visakhapatnam",
    district: "Visakhapatnam",
    state: "Andhra Pradesh",
    country: "India",
    latitude: 17.6868,
    longitude: 83.2185,
    placeId: "ChIJsW1H-2xJyzsR9R1sN1D-U9M"
  },
  {
    description: "Vizianagaram, Andhra Pradesh, India",
    city: "Vizianagaram",
    district: "Vizianagaram",
    state: "Andhra Pradesh",
    country: "India",
    latitude: 18.1119,
    longitude: 83.3956,
    placeId: "ChIJZ3j3F647zjsRHGvG2E06Nzo"
  },
  {
    description: "Vijayawada, Andhra Pradesh, India",
    city: "Vijayawada",
    district: "NTR District",
    state: "Andhra Pradesh",
    country: "India",
    latitude: 16.5062,
    longitude: 80.6480,
    placeId: "ChIJb8u74hD3NzoRUbVjS5L8B1k"
  },
  {
    description: "Hyderabad, Telangana, India",
    city: "Hyderabad",
    district: "Hyderabad",
    state: "Telangana",
    country: "India",
    latitude: 17.3850,
    longitude: 78.4867,
    placeId: "ChIJXw65sV2TyTsRQDvJ3v3B1gM"
  },
  {
    description: "New Delhi, Delhi, India",
    city: "New Delhi",
    district: "New Delhi",
    state: "Delhi",
    country: "India",
    latitude: 28.6139,
    longitude: 77.2090,
    placeId: "ChIJu46S7635DDkR01D3V35N1zM"
  },
  {
    description: "Mumbai, Maharashtra, India",
    city: "Mumbai",
    district: "Mumbai",
    state: "Maharashtra",
    country: "India",
    latitude: 19.0760,
    longitude: 72.8777,
    placeId: "ChIJwe1EZc25DDkR01D3V35N1zM"
  },
  {
    description: "Bangalore, Karnataka, India",
    city: "Bangalore",
    district: "Bangalore",
    state: "Karnataka",
    country: "India",
    latitude: 12.9716,
    longitude: 77.5946,
    placeId: "ChIJwe1EZc25DDkR01D3V35N1zN"
  },
  {
    description: "Chennai, Tamil Nadu, India",
    city: "Chennai",
    district: "Chennai",
    state: "Tamil Nadu",
    country: "India",
    latitude: 13.0827,
    longitude: 80.2707,
    placeId: "ChIJwe1EZc25DDkR01D3V35N1zO"
  }
];

class PlaceController {
  async autocomplete(req, res, next) {
    try {
      const { input } = req.query;
      if (!input || input.trim().length === 0) {
        return ApiResponse.success(res, "Suggestions fetched.", []);
      }

      const apiKey = process.env.GOOGLE_PLACES_API_KEY;
      if (apiKey && apiKey.trim().length > 0) {
        // Fetch from real Google Places API
        const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}&types=(cities)&key=${apiKey}`;
        const response = await fetch(url);
        const data = await response.json();
        if (data.status === "OK" || data.status === "ZERO_RESULTS") {
          const suggestions = (data.predictions || []).map(p => ({
            description: p.description,
            placeId: p.place_id
          }));
          return ApiResponse.success(res, "Google suggestions fetched.", suggestions);
        }
      }

      // Local mock fallback
      const searchStr = input.toLowerCase().trim();
      const filtered = mockCities
        .filter(c => c.description.toLowerCase().includes(searchStr))
        .map(c => ({
          description: c.description,
          placeId: c.placeId
        }));

      return ApiResponse.success(res, "Mock suggestions fetched.", filtered);
    } catch (error) {
      next(error);
    }
  }

  async details(req, res, next) {
    try {
      const { placeId } = req.query;
      if (!placeId) {
        return ApiResponse.error(res, "Place ID is required.", 400);
      }

      const apiKey = process.env.GOOGLE_PLACES_API_KEY;
      if (apiKey && apiKey.trim().length > 0) {
        const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(placeId)}&key=${apiKey}`;
        const response = await fetch(url);
        const data = await response.json();
        if (data.status === "OK" && data.result) {
          const r = data.result;
          const lat = r.geometry.location.lat;
          const lng = r.geometry.location.lng;

          // Parse address components
          let city = "";
          let district = "";
          let state = "";
          let country = "";

          r.address_components.forEach(c => {
            if (c.types.includes("locality")) {
              city = c.long_name;
            } else if (c.types.includes("administrative_area_level_2")) {
              district = c.long_name;
            } else if (c.types.includes("administrative_area_level_1")) {
              state = c.long_name;
            } else if (c.types.includes("country")) {
              country = c.long_name;
            }
          });

          // Fallbacks
          if (!city) city = r.name || "";
          if (!district) district = city;

          return ApiResponse.success(res, "Google details fetched.", {
            description: r.formatted_address || `${city}, ${state}, ${country}`,
            city,
            district,
            state,
            country,
            latitude: lat,
            longitude: lng,
            placeId
          });
        }
      }

      // Mock details
      const matched = mockCities.find(c => c.placeId === placeId);
      if (matched) {
        return ApiResponse.success(res, "Mock details fetched.", matched);
      }

      return ApiResponse.error(res, "Place details not found.", 404);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PlaceController();

/**
 * Geocoding via Nominatim (OpenStreetMap) — completely free, no API key.
 * Rate limit: 1 request/second. Fine for one geocode per listing/meetup.
 */

// UCF main campus center — used as a fallback pin when a free-text area
// description (e.g. "Near the Student Union") doesn't resolve to a real place.
const UCF_CAMPUS_CENTER = [-81.2001, 28.6024]; // [lng, lat]

/**
 * Convert a general area description (e.g. "Near the Student Union") to
 * approximate [longitude, latitude] coordinates near campus.
 * Returns null if geocoding fails — caller saves without coordinates.
 */
const geocodeArea = async (area, city = 'Orlando', state = 'FL') => {
  const query = encodeURIComponent(`${area}, ${city}, ${state}, USA`);
  const url   = `https://nominatim.openstreetmap.org/search?q=${query}&format=json&limit=1`;

  try {
    const res  = await fetch(url, {
      headers: {
        // Nominatim requires a descriptive User-Agent
        'User-Agent': 'KnightMarket/1.0 (student-marketplace-app)',
      },
    });
    const data = await res.json();

    if (!data || data.length === 0) return null;

    const { lon, lat } = data[0];
    return [parseFloat(lon), parseFloat(lat)]; // GeoJSON order: [lng, lat]
  } catch (err) {
    console.error('Geocoding error:', err.message);
    return null;
  }
};

module.exports = { geocodeArea, UCF_CAMPUS_CENTER };

const functions = require('firebase-functions');
const { rateLimit } = require('./rate_limiter_functions');

function lookupTimezone(lat, lng) {
  try {
    const zones = require('geo-tz').find(lat, lng);
    return zones && zones.length ? zones[0] : null;
  } catch (e) {
    console.warn('geo-tz lookup failed:', e.message);
    return null;
  }
}

const RATE_LIMITS = {
  geocode_club_location: { max_calls: 20, window_seconds: 60 },
};

const NOMINATIM_UA = 'ToastmastersDaily/1.0 (https://toastmastersdaily.com)';

/**
 * Forward-geocode a place name via Nominatim and resolve IANA timezone from lat/lng.
 * @param {Object} data
 * @param {string} data.location - Place name or address
 * @returns {Promise<Object>}
 */
const geocode_club_location_handler = async (data, context) => {
  try {
    if (!context.auth || !context.auth.uid) {
      return { success: false, error: 'Authentication required' };
    }

    const location = (data.location || '').trim();
    if (!location) {
      return { success: false, error: 'Location is required' };
    }
    if (location.length > 300) {
      return { success: false, error: 'Location is too long' };
    }

    const params = new URLSearchParams({
      q: location,
      format: 'json',
      limit: '1',
    });

    const resp = await fetch(`https://nominatim.openstreetmap.org/search?${params}`, {
      headers: {
        Accept: 'application/json',
        'User-Agent': NOMINATIM_UA,
      },
    });

    if (!resp.ok) {
      console.error('Nominatim error:', resp.status, resp.statusText);
      return { success: false, error: 'Geocoding service unavailable' };
    }

    const results = await resp.json();
    if (!results || !results.length) {
      return { success: false, error: 'Could not find that location' };
    }

    const hit = results[0];
    const lat = parseFloat(hit.lat);
    const lng = parseFloat(hit.lon);
    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return { success: false, error: 'Invalid geocoding result' };
    }

    const timezone = lookupTimezone(lat, lng);

    return {
      success: true,
      lat,
      lng,
      timezone,
      display_name: hit.display_name || location,
    };
  } catch (err) {
    console.error('geocode_club_location error:', err);
    return { success: false, error: 'Geocoding failed' };
  }
};

exports.geocode_club_location = functions.https.onCall(
  rateLimit(geocode_club_location_handler, {
    ...RATE_LIMITS.geocode_club_location,
    function_name: 'geocode_club_location',
  })
);

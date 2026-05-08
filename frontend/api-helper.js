// API helper - Use Vercel Functions instead of Supabase REST API
// This bypasses the IPv6-only limitation

const API_BASE = ''; // Empty means use relative paths (same domain)

// Fetch all orchids from backend
async function getOrchids() {
  try {
    const response = await fetch(`${API_BASE}/api/orchids`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch orchids from backend:', error);
    return null;
  }
}

// Fetch specific orchid
async function getOrchidById(id) {
  try {
    const response = await fetch(`${API_BASE}/api/orchids?id=${encodeURIComponent(id)}`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    console.error(`Failed to fetch orchid ${id}:`, error);
    return null;
  }
}

// Get DENR approved sightings for a species
async function getDenrSightings(scientificName) {
  try {
    const response = await fetch(`${API_BASE}/api/denr-sightings?name=${encodeURIComponent(scientificName)}`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    console.error(`Failed to fetch DENR sightings for ${scientificName}:`, error);
    return null;
  }
}

// Get public sightings
async function getPublicSightings() {
  try {
    const response = await fetch(`${API_BASE}/api/sightings`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch public sightings:', error);
    return null;
  }
}

// Submit new sighting
async function submitSighting(data) {
  try {
    const response = await fetch(`${API_BASE}/api/sightings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    console.error('Failed to submit sighting:', error);
    return null;
  }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    getOrchids,
    getOrchidById,
    getDenrSightings,
    getPublicSightings,
    submitSighting
  };
}

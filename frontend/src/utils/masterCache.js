import api from '../api';

const TTL_MS = 60_000;
const cache = {
  materials: { data: null, ts: 0 },
  locations: { data: null, ts: 0 },
  suppliers: { data: null, ts: 0 },
};

function isFresh(entry) {
  return entry.data && Date.now() - entry.ts < TTL_MS;
}

export function invalidateMasterCache(key) {
  if (key) {
    if (cache[key]) {
      cache[key].data = null;
      cache[key].ts = 0;
    }
    return;
  }
  Object.keys(cache).forEach((k) => {
    cache[k].data = null;
    cache[k].ts = 0;
  });
}

export async function fetchMaterials(force = false) {
  if (!force && isFresh(cache.materials)) return cache.materials.data;
  const { data } = await api.get('/materials');
  cache.materials = { data, ts: Date.now() };
  return data;
}

export async function fetchLocations(force = false) {
  if (!force && isFresh(cache.locations)) return cache.locations.data;
  const { data } = await api.get('/locations');
  cache.locations = { data, ts: Date.now() };
  return data;
}

export async function fetchSuppliers(force = false) {
  if (!force && isFresh(cache.suppliers)) return cache.suppliers.data;
  const { data } = await api.get('/suppliers');
  cache.suppliers = { data, ts: Date.now() };
  return data;
}

export async function fetchMasters(force = false) {
  const [materials, locations, suppliers] = await Promise.all([
    fetchMaterials(force),
    fetchLocations(force),
    fetchSuppliers(force),
  ]);
  return { materials, locations, suppliers };
}

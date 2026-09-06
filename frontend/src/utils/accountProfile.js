import api from '../api';

const CACHE_KEY = 'companyProfile';

export function getStoredProfile() {
  try {
    return JSON.parse(localStorage.getItem(CACHE_KEY) || 'null');
  } catch {
    return null;
  }
}

export function storeProfile(profile) {
  if (profile) localStorage.setItem(CACHE_KEY, JSON.stringify(profile));
}

export async function fetchAccountProfile(force = false) {
  if (!force) {
    const cached = getStoredProfile();
    if (cached) return cached;
  }
  const { data } = await api.get('/account/profile');
  storeProfile(data);
  return data;
}

export function profileToCompany(profile) {
  const p = profile || {};
  const address = [p.CompanyAddress1, p.CompanyAddress2].filter(Boolean).join(', ');
  return {
    name: p.CompanyName || 'InventoryInOneTap',
    gstNo: p.CompanyGSTNo || '',
    email: p.Email || '',
    address1: p.CompanyAddress1 || '',
    address2: p.CompanyAddress2 || '',
    address: address || 'Ahmedabad, Gujarat, India',
    logo: p.CompanyLogo || null,
    description: p.CompanyDescription || '',
    nameColor: p.CompanyNameColor || '#f97316',
    firstName: p.FirstName || '',
    lastName: p.LastName || '',
  };
}

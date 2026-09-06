export const USERNAME_RE = /^[a-zA-Z0-9_]{3,50}$/;

export function validateUsername(value) {
  const trimmed = String(value || '').trim();
  if (!USERNAME_RE.test(trimmed)) {
    return 'Username must be 3-50 characters and use letters, numbers, or underscore only.';
  }
  return '';
}

export function validatePassword(value, label = 'Password') {
  const text = String(value || '');
  if (text.length < 8) {
    return `${label} must be at least 8 characters.`;
  }
  if (!/[A-Za-z]/.test(text) || !/\d/.test(text)) {
    return `${label} must include at least one letter and one number.`;
  }
  return '';
}

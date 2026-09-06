import { SITE_NAME, SUPPORT_EMAIL } from './site';

export const SUPPORT_WHATSAPP = '+918108221012';
export { SUPPORT_EMAIL };

export function whatsappSupportUrl(message = `Hi, I need help with ${SITE_NAME}.`) {
  const phone = SUPPORT_WHATSAPP.replace(/\D/g, '');
  const text = encodeURIComponent(message);
  return `https://wa.me/${phone}?text=${text}`;
}

export const CUSTOM_FEATURES = [
  'Tailored users, warehouses & materials',
  'Custom onboarding & training',
  'Dedicated account manager',
  'Priority support & SLA',
  'Custom integrations on request',
];

/** @deprecated Use CUSTOM_FEATURES */
export const ENTERPRISE_FEATURES = CUSTOM_FEATURES;

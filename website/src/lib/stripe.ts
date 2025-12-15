import Stripe from 'stripe';

if (!process.env.STRIPE_SECRET_KEY) {
  throw new Error('STRIPE_SECRET_KEY is not set');
}

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2024-04-10',
  typescript: true,
});

export const PRODUCT_PRICE = 1900; // $19.00 in cents
export const PRODUCT_NAME = 'REM Device';
export const PRODUCT_DESCRIPTION = 'Your personal memory companion - continuous recording, transcription, and searchable memories.';


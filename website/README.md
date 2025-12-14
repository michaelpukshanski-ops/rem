# REM Website

Marketing and e-commerce website for the REM (Recording Everything Memory) device.

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **Authentication:** Clerk
- **Payments:** Stripe
- **Deployment:** Vercel

## Setup

### 1. Install Dependencies

```bash
cd website
npm install
```

### 2. Configure Environment Variables

Copy the example env file and fill in your values:

```bash
cp .env.example .env.local
```

Required environment variables:

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Clerk publishable key (from clerk.com dashboard) |
| `CLERK_SECRET_KEY` | Clerk secret key |
| `NEXT_PUBLIC_CLERK_SIGN_IN_URL` | Set to `/login` |
| `NEXT_PUBLIC_CLERK_SIGN_UP_URL` | Set to `/login` |
| `NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL` | Set to `/dashboard` |
| `NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL` | Set to `/dashboard` |
| `STRIPE_SECRET_KEY` | Stripe secret key (from stripe.com dashboard) |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe publishable key |
| `NEXT_PUBLIC_APP_URL` | Your app URL (e.g., `http://localhost:3000`) |

### 3. Set Up Clerk

1. Create account at [clerk.com](https://clerk.com)
2. Create a new application
3. Enable Email and Google sign-in methods
4. Copy the API keys to your `.env.local`

### 4. Set Up Stripe

1. Create account at [stripe.com](https://stripe.com)
2. Get your API keys from the Dashboard
3. Set up a webhook endpoint pointing to `/api/stripe/webhook`
4. Copy the webhook signing secret to your `.env.local`

### 5. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## Pages

| Route | Description |
|-------|-------------|
| `/` | Marketing landing page |
| `/login` | Authentication (sign in/up) |
| `/dashboard` | Protected user dashboard |
| `/success` | Post-purchase success page |
| `/cancel` | Cancelled checkout page |

## API Routes

| Route | Method | Description |
|-------|--------|-------------|
| `/api/checkout` | POST | Create Stripe Checkout session |
| `/api/stripe/webhook` | POST | Handle Stripe webhook events |

## Deploy to Vercel

1. Push to GitHub
2. Import project in Vercel
3. Add environment variables in Vercel dashboard
4. Deploy

### Stripe Webhook for Production

After deploying, update your Stripe webhook endpoint to:
```
https://your-domain.vercel.app/api/stripe/webhook
```

## Project Structure

```
website/
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   ├── checkout/route.ts
│   │   │   └── stripe/webhook/route.ts
│   │   ├── dashboard/page.tsx
│   │   ├── login/[[...login]]/page.tsx
│   │   ├── success/page.tsx
│   │   ├── cancel/page.tsx
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── globals.css
│   ├── components/
│   │   ├── Header.tsx
│   │   ├── Footer.tsx
│   │   └── BuyButton.tsx
│   ├── lib/
│   │   └── stripe.ts
│   └── middleware.ts
├── public/
├── .env.example
├── package.json
├── tailwind.config.ts
└── tsconfig.json
```


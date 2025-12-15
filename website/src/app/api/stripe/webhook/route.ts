import { NextRequest, NextResponse } from 'next/server';
import { stripe } from '@/lib/stripe';
import { saveOrder, createOrderFromStripeSession } from '@/lib/orders';
import Stripe from 'stripe';

export async function POST(request: NextRequest) {
  const body = await request.text();
  const signature = request.headers.get('stripe-signature');

  if (!signature) {
    return NextResponse.json({ error: 'No signature' }, { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  // Handle the event
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session;

      console.log('Payment successful!', {
        sessionId: session.id,
        customerEmail: session.customer_details?.email,
        amountTotal: session.amount_total,
        paymentStatus: session.payment_status,
        shippingAddress: session.shipping_details?.address,
      });

      // Save order to DynamoDB
      try {
        const order = createOrderFromStripeSession(session);
        await saveOrder(order);
        console.log('Order saved to database:', order.orderId);
      } catch (dbError) {
        console.error('Failed to save order to database:', dbError);
        // Don't fail the webhook - Stripe will retry
      }

      break;
    }

    case 'payment_intent.payment_failed': {
      const paymentIntent = event.data.object as Stripe.PaymentIntent;
      console.log('Payment failed:', paymentIntent.id);
      break;
    }

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  return NextResponse.json({ received: true });
}


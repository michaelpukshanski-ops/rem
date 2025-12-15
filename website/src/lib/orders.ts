import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: process.env.AWS_ACCESS_KEY_ID ? {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  } : undefined,
});

const docClient = DynamoDBDocumentClient.from(dynamoClient);

const ORDERS_TABLE = process.env.ORDERS_TABLE || 'rem-orders-dev';

export interface Order {
  orderId: string;           // Stripe session ID
  createdAt: string;         // ISO timestamp
  email: string;
  customerName?: string;
  amountTotal: number;       // In cents
  currency: string;
  paymentStatus: string;
  shippingAddress?: {
    line1?: string;
    line2?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
  product: string;
  status: 'pending' | 'completed' | 'shipped' | 'delivered' | 'cancelled';
  stripePaymentIntentId?: string;
  updatedAt: string;
}

/**
 * Save a new order to DynamoDB
 */
export async function saveOrder(order: Order): Promise<void> {
  await docClient.send(
    new PutCommand({
      TableName: ORDERS_TABLE,
      Item: order,
    })
  );
  console.log(`Order saved: ${order.orderId}`);
}

/**
 * Get orders by email
 */
export async function getOrdersByEmail(email: string): Promise<Order[]> {
  const result = await docClient.send(
    new QueryCommand({
      TableName: ORDERS_TABLE,
      IndexName: 'EmailIndex',
      KeyConditionExpression: 'email = :email',
      ExpressionAttributeValues: {
        ':email': email,
      },
      ScanIndexForward: false, // Most recent first
    })
  );

  return (result.Items || []) as Order[];
}

/**
 * Create an order from a Stripe checkout session
 */
export function createOrderFromStripeSession(
  session: {
    id: string;
    customer_details?: {
      email?: string | null;
      name?: string | null;
    } | null;
    amount_total?: number | null;
    currency?: string | null;
    payment_status?: string | null;
    shipping_details?: {
      address?: {
        line1?: string | null;
        line2?: string | null;
        city?: string | null;
        state?: string | null;
        postal_code?: string | null;
        country?: string | null;
      } | null;
    } | null;
    payment_intent?: string | { id: string } | null;
    metadata?: { product?: string } | null;
  }
): Order {
  const now = new Date().toISOString();
  
  return {
    orderId: session.id,
    createdAt: now,
    email: session.customer_details?.email || 'unknown',
    customerName: session.customer_details?.name || undefined,
    amountTotal: session.amount_total || 0,
    currency: session.currency || 'usd',
    paymentStatus: session.payment_status || 'unknown',
    shippingAddress: session.shipping_details?.address ? {
      line1: session.shipping_details.address.line1 || undefined,
      line2: session.shipping_details.address.line2 || undefined,
      city: session.shipping_details.address.city || undefined,
      state: session.shipping_details.address.state || undefined,
      postalCode: session.shipping_details.address.postal_code || undefined,
      country: session.shipping_details.address.country || undefined,
    } : undefined,
    product: session.metadata?.product || 'rem-device',
    status: 'completed',
    stripePaymentIntentId: typeof session.payment_intent === 'string' 
      ? session.payment_intent 
      : session.payment_intent?.id,
    updatedAt: now,
  };
}


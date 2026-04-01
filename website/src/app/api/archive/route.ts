import { auth } from '@clerk/nextjs/server';
import { NextRequest } from 'next/server';

const SERVER = process.env.MEETING_SERVER_URL ?? 'http://localhost:8766';

export async function GET() {
  const { userId } = await auth();
  if (!userId) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  const res = await fetch(`${SERVER}/archive/status`);
  const data = await res.json();
  return Response.json(data);
}

export async function POST(req: NextRequest) {
  const { userId } = await auth();
  if (!userId) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  const { question } = await req.json();
  if (!question?.trim()) return Response.json({ error: 'Missing question' }, { status: 400 });

  // Proxy the SSE stream from the Python server straight to the client
  const upstream = await fetch(`${SERVER}/archive/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ question }),
  });

  return new Response(upstream.body, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
    },
  });
}

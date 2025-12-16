import type { Metadata } from 'next';
import { ClerkProvider } from '@clerk/nextjs';
import { Header } from '@/components/Header';
import { Footer } from '@/components/Footer';
import './globals.css';

export const metadata: Metadata = {
  title: 'REM - Your Life, Remembered For You',
  description: 'Never forget a conversation again. REM continuously records, transcribes, and makes your life searchable.',
  keywords: ['memory', 'recording', 'transcription', 'AI', 'wearable'],
  openGraph: {
    title: 'REM - Your Life, Remembered For You',
    description: 'Never forget a conversation again. REM continuously records, transcribes, and makes your life searchable.',
    type: 'website',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body className="min-h-screen flex flex-col">
          <Header />
          <main className="flex-grow">{children}</main>
          <Footer />
        </body>
      </html>
    </ClerkProvider>
  );
}


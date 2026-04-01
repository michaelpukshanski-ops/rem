import { auth } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { ArchiveChat } from '@/components/ArchiveChat';

export default async function ArchivePage() {
  const { userId } = await auth();
  if (!userId) redirect('/login');

  return (
    <div className="min-h-[80vh] gradient-bg py-12">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="mb-8">
          <Link
            href="/dashboard"
            className="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Dashboard
          </Link>
          <h1 className="text-3xl font-bold text-gray-900">Recording Archive</h1>
          <p className="text-gray-600 mt-2">
            Connect a USB disk — recordings are transcribed automatically and searchable with AI.
          </p>
        </div>

        <ArchiveChat />
      </div>
    </div>
  );
}

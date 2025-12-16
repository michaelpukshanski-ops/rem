import { auth } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { Calendar, Settings, Mic, HelpCircle, Users } from 'lucide-react';
import { MemoryChat } from '@/components/MemoryChat';

export default async function DashboardPage() {
  const { userId } = await auth();

  if (!userId) {
    redirect('/login');
  }

  return (
    <div className="min-h-[80vh] gradient-bg py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Your Dashboard</h1>
          <p className="text-gray-600 mt-2">Your life, remembered for you</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Chat Interface - Main Area */}
          <div className="lg:col-span-2">
            <MemoryChat />
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Quick Actions */}
            <div className="bg-white rounded-2xl shadow-lg p-6">
              <h3 className="font-semibold text-gray-900 mb-4">Quick Actions</h3>
              <div className="space-y-3">
                <QuickAction
                  icon={<Calendar className="w-5 h-5" />}
                  title="Timeline"
                  description="Browse by date"
                />
                <QuickAction
                  icon={<Mic className="w-5 h-5" />}
                  title="Recordings"
                  description="View all recordings"
                />
                <Link href="/dashboard/speakers">
                  <QuickAction
                    icon={<Users className="w-5 h-5" />}
                    title="Speakers"
                    description="Manage voice profiles"
                  />
                </Link>
                <QuickAction
                  icon={<Settings className="w-5 h-5" />}
                  title="Settings"
                  description="Configure your REM"
                />
              </div>
            </div>

            {/* Getting Started */}
            <div className="bg-primary-50 rounded-2xl p-6">
              <div className="flex items-center gap-2 mb-3">
                <HelpCircle className="w-5 h-5 text-primary-600" />
                <h3 className="font-semibold text-primary-900">Getting Started</h3>
              </div>
              <ol className="text-sm text-primary-800 space-y-2">
                <li>1. Receive your device</li>
                <li>2. Connect it to your WiFi</li>
                <li>3. Start recording conversations</li>
                <li>4. Search memories using the chat</li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function QuickAction({
  icon,
  title,
  description
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors cursor-pointer">
      <div className="w-10 h-10 bg-primary-100 rounded-lg flex items-center justify-center text-primary-600 flex-shrink-0">
        {icon}
      </div>
      <div>
        <h4 className="font-medium text-gray-900">{title}</h4>
        <p className="text-xs text-gray-500">{description}</p>
      </div>
    </div>
  );
}


import { auth } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import { Brain, Search, Calendar, Settings } from 'lucide-react';

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
          <p className="text-gray-600 mt-2">Welcome to your REM memory center</p>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-12">
          <QuickAction
            icon={<Search className="w-6 h-6" />}
            title="Search Memories"
            description="Find any conversation"
          />
          <QuickAction
            icon={<Calendar className="w-6 h-6" />}
            title="Timeline"
            description="Browse by date"
          />
          <QuickAction
            icon={<Brain className="w-6 h-6" />}
            title="Insights"
            description="AI-powered summaries"
          />
          <QuickAction
            icon={<Settings className="w-6 h-6" />}
            title="Settings"
            description="Configure your REM"
          />
        </div>

        {/* Placeholder Content */}
        <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
          <Brain className="w-24 h-24 mx-auto text-primary-300 mb-6" />
          <h2 className="text-2xl font-semibold text-gray-900 mb-4">
            Your REM Memories Will Appear Here
          </h2>
          <p className="text-gray-600 max-w-md mx-auto mb-8">
            Once you set up your REM device and start recording, all your transcribed 
            memories will be searchable from this dashboard.
          </p>
          <div className="bg-primary-50 rounded-xl p-6 max-w-lg mx-auto">
            <h3 className="font-semibold text-primary-900 mb-2">Getting Started</h3>
            <ol className="text-left text-primary-800 space-y-2">
              <li>1. Receive your REM device</li>
              <li>2. Connect it to your WiFi network</li>
              <li>3. Start recording your conversations</li>
              <li>4. Search and recall from this dashboard</li>
            </ol>
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
    <div className="bg-white rounded-xl p-6 shadow-md hover:shadow-lg transition-shadow cursor-pointer">
      <div className="w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center text-primary-600 mb-4">
        {icon}
      </div>
      <h3 className="font-semibold text-gray-900">{title}</h3>
      <p className="text-sm text-gray-500">{description}</p>
    </div>
  );
}


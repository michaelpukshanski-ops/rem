import { Brain, Mic, Search, Clock, Shield, MessageSquare, Cloud } from 'lucide-react';
import { BuyButton } from '@/components/BuyButton';

export default function HomePage() {
  return (
    <div className="gradient-bg">
      {/* Hero Section */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 md:py-32">
        <div className="text-center">
          <h1 className="text-4xl md:text-6xl font-extrabold text-gray-900 mb-6">
            Never Forget a <span className="gradient-text">Conversation</span> Again
          </h1>
          <p className="text-xl md:text-2xl text-gray-600 max-w-3xl mx-auto mb-10">
            REM is your personal memory companion. It continuously records, transcribes, 
            and makes your entire life searchable with AI.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <BuyButton />
            <a href="#how-it-works" className="btn-secondary">
              Learn More
            </a>
          </div>
        </div>

        {/* Hero Image Placeholder */}
        <div className="mt-16 relative">
          <div className="bg-gradient-to-r from-primary-100 to-accent-100 rounded-3xl p-8 md:p-16 text-center">
            <Brain className="w-32 h-32 mx-auto text-primary-600 mb-6" />
            <p className="text-gray-600 text-lg">Your memories, always accessible</p>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="bg-white py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="section-heading">Powerful Features</h2>
          <p className="section-subheading">
            Everything you need to capture and recall your most important moments.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <FeatureCard
              icon={<Mic className="w-8 h-8" />}
              title="Continuous Recording"
              description="Capture every conversation automatically. REM runs silently in the background."
            />
            <FeatureCard
              icon={<MessageSquare className="w-8 h-8" />}
              title="AI Transcription"
              description="State-of-the-art speech recognition converts audio to searchable text."
            />
            <FeatureCard
              icon={<Search className="w-8 h-8" />}
              title="Semantic Search"
              description="Find any memory by meaning, not just keywords. Ask natural questions."
            />
            <FeatureCard
              icon={<Clock className="w-8 h-8" />}
              title="Timeline View"
              description="Browse your memories chronologically. See what you discussed and when."
            />
            <FeatureCard
              icon={<Shield className="w-8 h-8" />}
              title="Privacy First"
              description="Your data stays yours. End-to-end encryption and local processing."
            />
            <FeatureCard
              icon={<Cloud className="w-8 h-8" />}
              title="Cloud Sync"
              description="Access your memories from anywhere. Secure cloud backup included."
            />
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section id="how-it-works" className="py-20 gradient-bg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="section-heading">How It Works</h2>
          <p className="section-subheading">
            Three simple steps to never forget anything important again.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <StepCard
              number="1"
              title="Wear REM"
              description="Clip the small, discreet device to your clothing. It's lightweight and comfortable."
            />
            <StepCard
              number="2"
              title="Live Your Life"
              description="REM automatically records and transcribes your conversations in real-time."
            />
            <StepCard
              number="3"
              title="Search & Recall"
              description="Ask questions like 'What did John say about the project?' and get instant answers."
            />
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section id="buy" className="bg-gray-900 py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">
            Ready to Upgrade Your Memory?
          </h2>
          <p className="text-xl text-gray-300 mb-10">
            Join thousands of people who never forget important conversations.
          </p>
          <BuyButton />
          <p className="text-gray-400 mt-6">
            30-day money-back guarantee • Free shipping • 1-year warranty
          </p>
        </div>
      </section>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="bg-gray-50 rounded-2xl p-6 hover:shadow-lg transition-shadow">
      <div className="w-14 h-14 bg-primary-100 rounded-xl flex items-center justify-center text-primary-600 mb-4">
        {icon}
      </div>
      <h3 className="text-xl font-semibold text-gray-900 mb-2">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </div>
  );
}

function StepCard({ number, title, description }: { number: string; title: string; description: string }) {
  return (
    <div className="text-center">
      <div className="w-16 h-16 bg-primary-600 rounded-full flex items-center justify-center text-white text-2xl font-bold mx-auto mb-6">
        {number}
      </div>
      <h3 className="text-xl font-semibold text-gray-900 mb-2">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </div>
  );
}


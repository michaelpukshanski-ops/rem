import Link from 'next/link';
import { XCircle, ArrowLeft, HelpCircle } from 'lucide-react';

export default function CancelPage() {
  return (
    <div className="min-h-[80vh] flex items-center justify-center gradient-bg py-12">
      <div className="max-w-lg mx-auto px-4 text-center">
        <div className="bg-white rounded-2xl shadow-xl p-8 md:p-12">
          <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
            <XCircle className="w-12 h-12 text-gray-400" />
          </div>
          
          <h1 className="text-3xl font-bold text-gray-900 mb-4">
            Order Cancelled
          </h1>
          
          <p className="text-gray-600 mb-8">
            Your order was cancelled and you haven't been charged. 
            If you have any questions, we're here to help.
          </p>

          <div className="bg-primary-50 rounded-xl p-6 mb-8">
            <div className="flex items-start gap-3">
              <HelpCircle className="w-5 h-5 text-primary-600 mt-0.5" />
              <div className="text-left">
                <p className="font-medium text-primary-900">Need Help?</p>
                <p className="text-sm text-primary-700">
                  If you encountered any issues or have questions about REM, 
                  feel free to reach out to our support team.
                </p>
              </div>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link href="/#buy" className="btn-primary">
              <ArrowLeft className="w-4 h-4 mr-2" />
              Try Again
            </Link>
            <Link href="/" className="btn-secondary">
              Back to Home
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}


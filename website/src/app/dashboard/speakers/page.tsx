'use client';

import { useState, useEffect } from 'react';
import { useAuth } from '@clerk/nextjs';
import Link from 'next/link';
import { Users, Edit2, Trash2, Save, X, Loader2, ArrowLeft } from 'lucide-react';

interface Speaker {
  speakerId: string;
  name: string;
  sampleCount: number;
  createdAt: string;
  updatedAt: string;
}

export default function SpeakersPage() {
  const { getToken } = useAuth();
  const [speakers, setSpeakers] = useState<Speaker[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || '';

  useEffect(() => {
    fetchSpeakers();
  }, []);

  async function fetchSpeakers() {
    try {
      setLoading(true);
      const token = await getToken();
      const res = await fetch(`${apiUrl}/speakers`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'x-clerk-user-id': token || ''
        }
      });
      
      if (!res.ok) throw new Error('Failed to fetch speakers');
      
      const data = await res.json();
      setSpeakers(data.speakers || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load speakers');
    } finally {
      setLoading(false);
    }
  }

  async function updateSpeaker(speakerId: string, name: string) {
    try {
      const token = await getToken();
      const res = await fetch(`${apiUrl}/speakers/${speakerId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'x-clerk-user-id': token || ''
        },
        body: JSON.stringify({ name })
      });
      
      if (!res.ok) throw new Error('Failed to update speaker');
      
      setSpeakers(speakers.map(s => 
        s.speakerId === speakerId ? { ...s, name } : s
      ));
      setEditingId(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update speaker');
    }
  }

  async function deleteSpeaker(speakerId: string) {
    if (!confirm('Are you sure you want to delete this speaker profile?')) return;
    
    try {
      const token = await getToken();
      const res = await fetch(`${apiUrl}/speakers/${speakerId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
          'x-clerk-user-id': token || ''
        }
      });
      
      if (!res.ok) throw new Error('Failed to delete speaker');
      
      setSpeakers(speakers.filter(s => s.speakerId !== speakerId));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete speaker');
    }
  }

  function startEditing(speaker: Speaker) {
    setEditingId(speaker.speakerId);
    setEditName(speaker.name);
  }

  function cancelEditing() {
    setEditingId(null);
    setEditName('');
  }

  if (loading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-primary-600" />
      </div>
    );
  }

  return (
    <div className="min-h-[80vh] gradient-bg py-12">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="mb-8">
          <Link
            href="/dashboard"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Dashboard
          </Link>
          <div className="flex items-center gap-3">
            <Users className="w-8 h-8 text-primary-600" />
            <h1 className="text-3xl font-bold text-gray-900">Speaker Profiles</h1>
          </div>
          <p className="text-gray-600 mt-2">
            Manage voice profiles for speaker identification in your recordings
          </p>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
            {error}
            <button onClick={() => setError(null)} className="ml-2 underline">Dismiss</button>
          </div>
        )}

        {speakers.length === 0 ? (
          <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
            <Users className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-2">No speakers yet</h3>
            <p className="text-gray-600">
              Speaker profiles are automatically created when REM detects different voices 
              in your recordings. Start recording to build your speaker library!
            </p>
          </div>
        ) : (
          <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
            <div className="divide-y divide-gray-100">
              {speakers.map(speaker => (
                <div key={speaker.speakerId} className="p-6 flex items-center justify-between">
                  <div className="flex-1">
                    {editingId === speaker.speakerId ? (
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          value={editName}
                          onChange={(e) => setEditName(e.target.value)}
                          className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 
                                   focus:ring-primary-500 focus:border-transparent"
                          autoFocus
                        />
                        <button
                          onClick={() => updateSpeaker(speaker.speakerId, editName)}
                          className="p-2 text-green-600 hover:bg-green-50 rounded-lg"
                        >
                          <Save className="w-5 h-5" />
                        </button>
                        <button
                          onClick={cancelEditing}
                          className="p-2 text-gray-600 hover:bg-gray-50 rounded-lg"
                        >
                          <X className="w-5 h-5" />
                        </button>
                      </div>
                    ) : (
                      <>
                        <h3 className="font-semibold text-gray-900">{speaker.name}</h3>
                        <p className="text-sm text-gray-500">
                          {speaker.sampleCount} voice sample{speaker.sampleCount !== 1 ? 's' : ''} • 
                          Added {new Date(speaker.createdAt).toLocaleDateString()}
                        </p>
                      </>
                    )}
                  </div>
                  
                  {editingId !== speaker.speakerId && (
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => startEditing(speaker)}
                        className="p-2 text-gray-600 hover:bg-gray-100 rounded-lg"
                        title="Rename speaker"
                      >
                        <Edit2 className="w-5 h-5" />
                      </button>
                      <button
                        onClick={() => deleteSpeaker(speaker.speakerId)}
                        className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                        title="Delete speaker"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="mt-8 p-6 bg-primary-50 rounded-2xl">
          <h3 className="font-semibold text-primary-900 mb-2">How it works</h3>
          <ul className="text-sm text-primary-800 space-y-1">
            <li>• REM automatically detects different speakers in your recordings</li>
            <li>• New speakers are added as &quot;Speaker 1&quot;, &quot;Speaker 2&quot;, etc.</li>
            <li>• Click the edit button to give them real names (e.g., &quot;Mom&quot;, &quot;John&quot;)</li>
            <li>• REM learns to recognize voices over time with more samples</li>
          </ul>
        </div>
      </div>
    </div>
  );
}


'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { Send, HardDrive, User, Loader2, FileAudio, Brain } from 'lucide-react';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

interface ArchiveStatus {
  count: number;
  files: { filename: string; volume: string; created_at: string }[];
}

export function ArchiveChat() {
  const [status, setStatus] = useState<ArchiveStatus | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const fetchStatus = useCallback(async () => {
    try {
      const res = await fetch('/api/archive');
      if (res.ok) setStatus(await res.json());
    } catch {
      // server not reachable yet
    }
  }, []);

  useEffect(() => {
    fetchStatus();
    // Poll for status changes (e.g. while transcription is in progress)
    const interval = setInterval(fetchStatus, 5000);
    return () => clearInterval(interval);
  }, [fetchStatus]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const question = input.trim();
    if (!question || isLoading) return;

    setMessages((prev) => [
      ...prev,
      { id: Date.now().toString(), role: 'user', content: question, timestamp: new Date() },
    ]);
    setInput('');
    setIsLoading(true);

    const assistantId = (Date.now() + 1).toString();
    setMessages((prev) => [
      ...prev,
      { id: assistantId, role: 'assistant', content: '', timestamp: new Date() },
    ]);

    try {
      const res = await fetch('/api/archive', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question }),
      });

      const reader = res.body!.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const payload = line.slice(6);
          if (payload === '[DONE]') break;
          try {
            const { text } = JSON.parse(payload);
            setMessages((prev) =>
              prev.map((m) =>
                m.id === assistantId ? { ...m, content: m.content + text } : m
              )
            );
          } catch { /* skip malformed */ }
        }
      }
    } catch {
      setMessages((prev) =>
        prev.map((m) =>
          m.id === assistantId
            ? { ...m, content: 'Sorry, something went wrong. Is the Meeting Assistant server running?' }
            : m
        )
      );
    } finally {
      setIsLoading(false);
    }
  };

  const noServer = status === null;
  const noFiles  = status !== null && status.count === 0;

  return (
    <div className="space-y-6">
      {/* Status card */}
      <div className="bg-white rounded-2xl shadow-lg p-6">
        <div className="flex items-center gap-3 mb-4">
          <HardDrive className="w-5 h-5 text-orange-500" />
          <h3 className="font-semibold text-gray-900">Disk Archive</h3>
          <span
            className={`ml-auto text-xs font-medium px-2 py-1 rounded-full ${
              noServer
                ? 'bg-gray-100 text-gray-500'
                : status.count > 0
                ? 'bg-green-100 text-green-700'
                : 'bg-yellow-100 text-yellow-700'
            }`}
          >
            {noServer ? 'Server offline' : status.count > 0 ? `${status.count} recordings ready` : 'No recordings yet'}
          </span>
        </div>

        {!noServer && status!.files.length > 0 && (
          <div className="space-y-2 max-h-40 overflow-y-auto">
            {status!.files.map((f) => (
              <div key={f.filename} className="flex items-center gap-2 text-sm text-gray-600">
                <FileAudio className="w-4 h-4 text-orange-400 flex-shrink-0" />
                <span className="truncate">{f.filename}</span>
                <span className="text-xs text-gray-400 flex-shrink-0">{f.volume}</span>
              </div>
            ))}
          </div>
        )}

        {noServer && (
          <p className="text-sm text-gray-500">
            Start the Meeting Assistant server on your Mac mini to use this feature.
          </p>
        )}
        {noFiles && (
          <p className="text-sm text-gray-500">
            Connect a USB disk with audio files. The server will detect and transcribe them automatically.
          </p>
        )}
      </div>

      {/* Chat */}
      <div className="flex flex-col h-[500px] bg-white rounded-2xl shadow-lg overflow-hidden">
        <div className="bg-orange-500 text-white px-6 py-4">
          <div className="flex items-center gap-3">
            <Brain className="w-6 h-6" />
            <div>
              <h2 className="font-semibold">Recording Q&amp;A</h2>
              <p className="text-sm text-orange-100">Ask anything about your transcribed recordings</p>
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 && (
            <div className="flex items-center justify-center h-full text-gray-400 text-sm">
              {noFiles || noServer
                ? 'Transcribed recordings will appear here once a disk is connected'
                : 'Ask a question about your recordings…'}
            </div>
          )}

          {messages.map((message) => (
            <div
              key={message.id}
              className={`flex gap-3 ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              {message.role === 'assistant' && (
                <div className="w-8 h-8 rounded-full bg-orange-100 flex items-center justify-center flex-shrink-0">
                  <Brain className="w-4 h-4 text-orange-600" />
                </div>
              )}
              <div
                className={`max-w-[80%] rounded-2xl px-4 py-3 ${
                  message.role === 'user'
                    ? 'bg-orange-500 text-white'
                    : 'bg-gray-100 text-gray-900'
                }`}
              >
                {message.content || (
                  <Loader2 className="w-4 h-4 animate-spin text-gray-400" />
                )}
              </div>
              {message.role === 'user' && (
                <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center flex-shrink-0">
                  <User className="w-4 h-4 text-gray-600" />
                </div>
              )}
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>

        <form onSubmit={handleSubmit} className="border-t p-4">
          <div className="flex gap-2">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder={
                noServer
                  ? 'Server offline…'
                  : noFiles
                  ? 'No recordings yet…'
                  : 'Ask about your recordings…'
              }
              disabled={isLoading || noServer || noFiles}
              className="flex-1 rounded-full border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent disabled:opacity-50"
            />
            <button
              type="submit"
              disabled={isLoading || !input.trim() || noServer || noFiles}
              className="w-10 h-10 rounded-full bg-orange-500 text-white flex items-center justify-center hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Send className="w-4 h-4" />
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

import React, { useState, useEffect, useRef } from 'react';
import { Conversation, Message } from '@/types';
import { Send, Sparkles, MessageSquareText, Settings, ArrowLeft } from 'lucide-react';
import { generateFollowUpMessage } from '@/services/geminiService';

interface Props {
  conversation: Conversation | null;
  presetMessage: string;
  onSendMessage: (convId: string, text: string) => void;
  onBack?: () => void; // New prop for mobile back navigation
}

export const ChatWindow: React.FC<Props> = ({ conversation, presetMessage, onSendMessage, onBack }) => {
  const [draft, setDraft] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Reset draft when switching conversations and auto-scroll
  useEffect(() => {
    setDraft('');
    // Short timeout to allow render
    setTimeout(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: "auto" });
    }, 100);
  }, [conversation?.id]);

  // Scroll on new message
  useEffect(() => {
     messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [conversation?.messages]);

  const handleUsePreset = () => {
    setDraft(presetMessage);
  };

  const handleGenerateAI = async () => {
    if (!conversation) return;
    setIsGenerating(true);
    try {
      const text = await generateFollowUpMessage(conversation.partnerName, conversation.messages);
      setDraft(text);
    } finally {
      setIsGenerating(false);
    }
  };

  const handleSend = () => {
    if (conversation && draft.trim()) {
      onSendMessage(conversation.id, draft);
      setDraft('');
    }
  };

  if (!conversation) {
    return (
      <div className="h-full flex flex-col items-center justify-center bg-white text-gray-400 p-4 text-center">
        <MessageSquareText size={64} className="mb-4 opacity-20" />
        <p className="text-lg font-medium">Selectează o conversație din listă</p>
        <p className="text-sm mt-2">Alege un utilizator din stânga pentru a începe.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full bg-white relative w-full">
      {/* Header */}
      <div className="h-16 border-b border-gray-200 flex items-center justify-between px-4 md:px-6 bg-white shrink-0 sticky top-0 z-10">
        <div className="flex items-center gap-3 overflow-hidden">
          {/* Mobile Back Button */}
          <button 
            onClick={onBack}
            className="md:hidden p-1 -ml-1 text-gray-600 hover:bg-gray-100 rounded-full"
          >
            <ArrowLeft size={24} />
          </button>

          <img src={conversation.partnerAvatar} className="w-8 h-8 md:w-10 md:h-10 rounded-full shrink-0" />
          <div className="min-w-0">
            <h2 className="font-bold text-gray-800 truncate text-sm md:text-base">{conversation.partnerName}</h2>
            <span className="text-[10px] md:text-xs text-green-600 flex items-center gap-1">
              <span className="w-1.5 h-1.5 md:w-2 md:h-2 rounded-full bg-green-500 shrink-0"></span>
              <span className="truncate">Conectat Facebook</span>
            </span>
          </div>
        </div>
        <div className="text-[10px] text-gray-400 hidden md:block">ID: {conversation.id}</div>
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto p-4 md:p-6 space-y-4 bg-gray-50">
        {conversation.messages.map((msg) => (
          <div 
            key={msg.id} 
            className={`flex ${msg.sender === 'me' ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[85%] md:max-w-[70%] rounded-2xl px-4 py-2 shadow-sm text-sm break-words whitespace-pre-wrap ${
              msg.sender === 'me' 
                ? 'bg-blue-600 text-white rounded-br-none' 
                : 'bg-white text-gray-800 border border-gray-200 rounded-bl-none'
            }`}>
              {msg.text}
              <div className={`text-[10px] mt-1 text-right ${msg.sender === 'me' ? 'text-blue-200' : 'text-gray-400'}`}>
                {msg.timestamp.toLocaleTimeString('ro-RO', {hour:'2-digit', minute:'2-digit'})}
              </div>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Action Area */}
      <div className="p-3 md:p-4 border-t border-gray-200 bg-white pb-safe">
        
        {/* Quick Actions - Scrollable horizontally on mobile */}
        <div className="flex gap-2 mb-3 overflow-x-auto pb-1 no-scrollbar">
          <button 
            onClick={handleUsePreset}
            className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors border border-gray-200 whitespace-nowrap"
          >
            <Settings size={12} />
            Presetare
          </button>
          <button 
            onClick={handleGenerateAI}
            disabled={isGenerating}
            className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-purple-700 bg-purple-50 hover:bg-purple-100 rounded-lg transition-colors border border-purple-200 whitespace-nowrap"
          >
            <Sparkles size={12} className={isGenerating ? "animate-spin" : ""} />
            {isGenerating ? "Generez..." : "Gemini AI"}
          </button>
        </div>

        {/* Input */}
        <div className="flex gap-2 items-end">
          <textarea 
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="Scrie un mesaj..."
            className="flex-1 resize-none border border-gray-300 rounded-xl px-4 py-3 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none h-12 max-h-32 min-h-[48px]"
          />
          <button 
            onClick={handleSend}
            disabled={!draft.trim()}
            className="w-12 h-12 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white rounded-xl flex items-center justify-center transition-all shadow-md active:scale-95 shrink-0"
          >
            <Send size={20} />
          </button>
        </div>
      </div>
    </div>
  );
};

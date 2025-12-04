import React from 'react';
import { Conversation } from '@/types';
import { Clock, CheckCheck, AlertCircle } from 'lucide-react';

interface Props {
  conversation: Conversation;
  isActive: boolean;
  onClick: () => void;
  hoursInactive: number;
  minUrgentHours: number;
  maxUrgentHours: number;
}

export const ConversationItem: React.FC<Props> = ({ 
  conversation, 
  isActive, 
  onClick, 
  hoursInactive,
  minUrgentHours,
  maxUrgentHours
}) => {
  const lastMsg = conversation.messages[conversation.messages.length - 1];

  // Helper to format concise time
  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('ro-RO', { hour: '2-digit', minute: '2-digit' });
  };

  const isUrgent = hoursInactive >= minUrgentHours && hoursInactive <= maxUrgentHours && conversation.lastSender === 'me';

  return (
    <div 
      onClick={onClick}
      className={`p-4 border-b border-gray-100 cursor-pointer transition-colors duration-200 hover:bg-gray-50 ${isActive ? 'bg-blue-50 border-l-4 border-l-blue-600' : ''}`}
    >
      <div className="flex justify-between items-start mb-1">
        <div className="flex items-center gap-3">
            <img 
              src={conversation.partnerAvatar} 
              alt={conversation.partnerName} 
              className="w-10 h-10 rounded-full object-cover shadow-sm"
            />
            <div>
              <h3 className={`text-sm font-semibold ${isActive ? 'text-blue-900' : 'text-gray-900'}`}>
                {conversation.partnerName}
              </h3>
              <div className="flex items-center gap-1 text-xs text-gray-500">
                {lastMsg.sender === 'me' ? <CheckCheck size={12} className="text-blue-500" /> : null}
                <span>{formatTime(conversation.lastMessageTimestamp)}</span>
              </div>
            </div>
        </div>
        {isUrgent && (
            <span className="flex items-center gap-1 px-2 py-1 bg-amber-100 text-amber-700 text-xs font-bold rounded-full">
                <Clock size={10} />
                {hoursInactive}h
            </span>
        )}
      </div>
      
      <p className="text-xs text-gray-600 mt-2 line-clamp-1 ml-14">
        {lastMsg.text}
      </p>
    </div>
  );
};

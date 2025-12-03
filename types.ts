
export interface Message {
  id: string;
  sender: 'me' | 'partner';
  text: string;
  timestamp: Date;
}

export interface Conversation {
  id: string;
  partnerName: string;
  partnerAvatar: string;
  messages: Message[];
  lastMessageTimestamp: Date;
  status: 'active' | 'archived' | 'pending_followup';
  lastSender: 'me' | 'partner';
  hoursInactive?: number; // Calculated field
  partnerId?: string; // PSID needed for sending messages via API
}

export interface AppStats {
  totalConversations: number;
  needsFollowUp: number;
  messagesSentToday: number;
}

export type BusinessType = 'general' | 'auto' | 'real_estate' | 'fashion' | 'beauty';

// --- Facebook Graph API Types ---

export interface FacebookUser {
  name: string;
  id: string;
  email?: string;
}

export interface FacebookMessageData {
  id: string;
  message: string;
  created_time: string;
  from: {
    name: string;
    id: string;
  };
}

export interface FacebookConversationData {
  id: string;
  updated_time: string;
  messages: {
    data: FacebookMessageData[];
    paging: any;
  };
  participants: {
    data: FacebookUser[];
  };
}

export interface FacebookAPIResponse {
  data: FacebookConversationData[];
  paging?: any;
  error?: {
    message: string;
    type: string;
    code: number;
  };
}

// --- Auth & Access Key Types ---

export interface AccessKey {
  key: string;        // The unique token (e.g., UUID)
  userId: string;     // Internal User Identifier
  pageId: string;     // Facebook Page ID allowed for this user
  createdAt: number;  // Timestamp
  expiresAt: number;  // Timestamp
  isRevoked: boolean; // Kill switch
  note?: string;      // Admin note
}

export interface AuthSession {
  isAuthenticated: boolean;
  role: 'admin' | 'user';
  accessKey?: AccessKey; // Only present if role is user
}

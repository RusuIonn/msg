

import React, { useState, useEffect, useMemo, useRef } from 'react';
import { LayoutDashboard, MessageCircle, Settings, Users, History, Link, Key, CheckCircle, XCircle, LogOut, Loader2, Filter, Info, RefreshCw, Terminal, PlayCircle, Globe, Database, Clock, Lock, Shield } from 'lucide-react';
import { Conversation, Message, BusinessType, FacebookAPIResponse, FacebookConversationData, AuthSession } from './types';
import { getMockConversations, DEFAULT_PRESET_MESSAGE } from './constants';
import { ConversationItem } from './components/ConversationItem';
import { ChatWindow } from './components/ChatWindow';
import { LoginScreen } from './components/LoginScreen';
import { AdminPanel } from './components/AdminPanel';

// Styles for the sidebar nav items
const NavItem = ({ icon: Icon, label, active, onClick, isMobile = false }: { icon: any, label: string, active?: boolean, onClick: () => void, isMobile?: boolean }) => (
  <button 
    onClick={onClick}
    className={`flex items-center gap-3 transition-all ${
      isMobile 
      ? `flex-col justify-center p-2 rounded-lg ${active ? 'text-blue-600' : 'text-gray-400'}`
      : `w-full px-4 py-3 text-sm font-medium rounded-xl ${active ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/30' : 'text-gray-500 hover:bg-white hover:text-gray-900'}`
    }`}
  >
    <Icon size={isMobile ? 24 : 20} />
    <span className={isMobile ? "text-[10px] font-medium" : ""}>{label}</span>
  </button>
);

const App: React.FC = () => {
  // --- AUTH STATE ---
  const [session, setSession] = useState<AuthSession | null>(null);

  // Core App State
  const [activeTab, setActiveTab] = useState<'dashboard' | 'messages' | 'settings'>('messages');
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConvId, setSelectedConvId] = useState<string | null>(null);
  const [presetMessage, setPresetMessage] = useState(DEFAULT_PRESET_MESSAGE);

  // Settings State
  const [fbPageId, setFbPageId] = useState('');
  const [fbToken, setFbToken] = useState('');
  const [businessType, setBusinessType] = useState<BusinessType>('auto');
  const [useLiveApi, setUseLiveApi] = useState(false); 
  
  // Urgent Logic State
  const [minUrgentHours, setMinUrgentHours] = useState(18);
  const [maxUrgentHours, setMaxUrgentHours] = useState(23);

  // Connection State
  const [isFbConnected, setIsFbConnected] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [connectionError, setConnectionError] = useState<string | null>(null);

  // Sync Logs State
  const [syncLogs, setSyncLogs] = useState<string[]>([]);
  const [showSyncModal, setShowSyncModal] = useState(false);
  const logsEndRef = useRef<HTMLDivElement>(null);

  // Filter State
  const [viewMode, setViewMode] = useState<'urgent' | 'all'>('all');

  // --- EFFECT: ENFORCE PAGE ID FROM KEY ---
  useEffect(() => {
    if (session?.role === 'user' && session.accessKey) {
      setFbPageId(session.accessKey.pageId);
    }
  }, [session]);

  // Auto-scroll logs
  useEffect(() => {
    if (showSyncModal && logsEndRef.current) {
        logsEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [syncLogs, showSyncModal]);

  // --- AUTH GUARD ---
  if (!session?.isAuthenticated) {
    return <LoginScreen onLogin={setSession} />;
  }

  // --- ADMIN PANEL RENDER ---
  if (session.role === 'admin') {
    return <AdminPanel onLogout={() => setSession(null)} />;
  }

  // --- MAIN APP LOGIC (Only runs if user is authenticated) ---

  const isMobileChatOpen = activeTab === 'messages' && !!selectedConvId;

  // Filter conversations
  const displayedConversations = conversations.map(conv => {
      const now = new Date();
      const diffInMs = now.getTime() - conv.lastMessageTimestamp.getTime();
      const diffInHours = Math.floor(diffInMs / (1000 * 60 * 60));
      return { ...conv, hoursInactive: diffInHours };
    }).filter(conv => {
      if (viewMode === 'all') return true;
      return conv.hoursInactive! >= minUrgentHours && conv.hoursInactive! <= maxUrgentHours && conv.lastSender === 'me';
    }).sort((a, b) => {
      if (viewMode === 'urgent') return (b.hoursInactive || 0) - (a.hoursInactive || 0);
      return b.lastMessageTimestamp.getTime() - a.lastMessageTimestamp.getTime();
    });

  const urgentCount = conversations.filter(conv => {
     const now = new Date();
     const diffInMs = now.getTime() - conv.lastMessageTimestamp.getTime();
     const diffInHours = Math.floor(diffInMs / (1000 * 60 * 60));
     return diffInHours >= minUrgentHours && diffInHours <= maxUrgentHours && conv.lastSender === 'me';
  }).length;

  const activeConversation = conversations.find(c => c.id === selectedConvId) || null;

  const handleSendMessage = async (convId: string, text: string) => {
    // Live API Logic
    if (useLiveApi && fbToken) {
      try {
        const conversation = conversations.find(c => c.id === convId);
        let url = `https://graph.facebook.com/v19.0/me/messages?access_token=${fbToken}`;
        let body: any = {
            recipient: { id: conversation?.partnerId },
            messaging_type: "RESPONSE",
            message: { text: text }
        };

        if (!conversation?.partnerId) {
             url = `https://graph.facebook.com/v19.0/${convId}/messages?access_token=${fbToken}`;
             body = { messaging_type: "RESPONSE", message: { text: text } };
        }

        const response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body)
        });

        const data = await response.json();
        
        if (data.error) {
          let errorMsg = typeof data.error === 'string' ? data.error : (data.error.message || JSON.stringify(data.error));
          alert(`Eroare Facebook: ${errorMsg}`);
          return;
        }
      } catch (error: any) {
        alert(`Eroare de rețea: ${error.message || String(error)}`);
        return;
      }
    }

    // Local Update
    setConversations(prev => prev.map(conv => {
      if (conv.id === convId) {
        return {
          ...conv,
          messages: [...conv.messages, { id: `new_${Date.now()}`, sender: 'me', text, timestamp: new Date() }],
          lastMessageTimestamp: new Date(),
          lastSender: 'me'
        };
      }
      return conv;
    }));
  };

  const addLog = (message: string) => {
    setSyncLogs(prev => [...prev, `> ${new Date().toLocaleTimeString('ro-RO')} - ${message}`]);
  };

  const fetchRealFacebookMessages = async (pageId: string, token: string) => {
    try {
        addLog(`[LIVE API] Inițializare descărcare paginată...`);
        const BATCH_SIZE = 50;
        const MAX_BATCHES = 6;
        let allRawConversations: FacebookConversationData[] = [];
        let nextUrl: string | null = `https://graph.facebook.com/v18.0/${pageId}/conversations?limit=${BATCH_SIZE}&fields=participants,updated_time,messages.limit(5){id,message,created_time,from}&access_token=${token}`;

        for (let i = 0; i < MAX_BATCHES; i++) {
            if (!nextUrl) break;
            addLog(`[LIVE API] Descărcare set ${i + 1}/${MAX_BATCHES}...`);
            const response = await fetch(nextUrl);
            const data: FacebookAPIResponse = await response.json();
            if (data.error) throw new Error(data.error.message);
            
            if (data.data && data.data.length > 0) {
                allRawConversations = [...allRawConversations, ...data.data];
                nextUrl = data.paging?.next || null;
            } else {
                nextUrl = null;
            }
        }
        
        // Transform logic...
        return allRawConversations.map((fbConv: FacebookConversationData): Conversation => {
            const partner = fbConv.participants?.data?.find(p => p.id !== pageId) || fbConv.participants?.data?.[0] || { name: 'Utilizator', id: 'unknown' };
            const messages: Message[] = (fbConv.messages?.data || []).map(m => ({
                id: m.id,
                text: m.message || '(Media)',
                timestamp: new Date(m.created_time),
                sender: (m.from.id === pageId ? 'me' : 'partner') as 'me' | 'partner'
            })).sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
            
            return {
                id: fbConv.id,
                partnerName: partner.name,
                partnerAvatar: `https://ui-avatars.com/api/?name=${encodeURIComponent(partner.name)}&background=random`,
                partnerId: partner.id,
                messages,
                lastMessageTimestamp: messages[messages.length - 1]?.timestamp || new Date(fbConv.updated_time),
                lastSender: messages[messages.length - 1]?.sender || 'partner',
                status: 'active'
            };
        });
    } catch (error: any) {
        addLog(`[EROARE API] ${error.message}`);
        throw error;
    }
  };

  const handleConnectFb = async () => {
    // Validate Page ID against Key
    if (session?.role === 'user' && session.accessKey) {
      if (fbPageId !== session.accessKey.pageId) {
        alert("ID-ul paginii nu corespunde cu cheia de acces!");
        setFbPageId(session.accessKey.pageId);
        return;
      }
    }

    if (fbPageId && fbToken) {
      setIsSyncing(true);
      setShowSyncModal(true);
      setSyncLogs([]);
      setConnectionError(null);

      try {
        addLog(useLiveApi ? "Mod LIVE API..." : "Mod SIMULARE...");
        await new Promise(r => setTimeout(r, 800));
        addLog(`Validare pentru Page ID: ${fbPageId}...`);
        
        let importedData: Conversation[] = [];
        if (useLiveApi) {
            importedData = await fetchRealFacebookMessages(fbPageId, fbToken);
        } else {
            addLog(`Generare scenarii (${businessType.toUpperCase()})...`);
            await new Promise(r => setTimeout(r, 1000));
            importedData = getMockConversations(businessType);
        }

        addLog(`Procesat ${importedData.length} conversații.`);
        setConversations(importedData);
        setIsFbConnected(true);
        setIsSyncing(false);
        setShowSyncModal(false);
        setActiveTab('messages');
        setViewMode('all');
      } catch (error: any) {
        setIsSyncing(false);
        setConnectionError(error.message);
      }
    }
  };

  const handleLogout = () => {
    if (confirm("Sigur doriți să vă deconectați? Veți avea nevoie de cheie pentru a reveni.")) {
      setSession(null);
      setIsFbConnected(false);
      setConversations([]);
    }
  };

  return (
    <div className="flex flex-col md:flex-row h-[100dvh] bg-[#f3f4f6] overflow-hidden">
      {/* Sync Modal Code (Identical to previous) */}
      {showSyncModal && (
          <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
              <div className="bg-gray-900 text-green-400 w-full max-w-lg rounded-xl shadow-2xl border border-gray-700 font-mono text-sm overflow-hidden flex flex-col max-h-[500px]">
                  <div className="bg-gray-800 px-4 py-2 border-b border-gray-700 flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Terminal size={16} />
                        <span className="font-bold text-gray-200">Terminal Sincronizare</span>
                      </div>
                      {!isSyncing && <button onClick={() => setShowSyncModal(false)}><XCircle size={18} /></button>}
                  </div>
                  <div className="p-4 overflow-y-auto flex-1 space-y-2 min-h-[200px]">
                      {syncLogs.map((log, i) => <div key={i} className={`break-words ${log.includes("EROARE") ? "text-red-400 font-bold" : ""}`}>{log}</div>)}
                      <div ref={logsEndRef} />
                      {isSyncing && <div className="flex items-center gap-2 mt-4 animate-pulse text-gray-400"><Loader2 size={16} className="animate-spin" /><span>Se procesează...</span></div>}
                      {connectionError && <div className="mt-4 p-3 bg-red-900/30 border border-red-800 rounded text-red-300 text-xs"><strong>Eroare:</strong> {connectionError}</div>}
                  </div>
              </div>
          </div>
      )}

      {/* Sidebar */}
      <aside className="hidden md:flex w-64 bg-[#f8fafc] border-r border-gray-200 flex-col p-4 shrink-0">
        <div className="flex items-center gap-2 px-2 mb-8">
          <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold text-xl">R</div>
          <h1 className="text-lg font-bold text-gray-800 tracking-tight">Retarget Pro</h1>
        </div>
        <nav className="flex-1 space-y-2">
          <NavItem icon={LayoutDashboard} label="Dashboard" active={activeTab === 'dashboard'} onClick={() => setActiveTab('dashboard')} />
          <div className="relative">
             <NavItem icon={MessageCircle} label="Mesaje" active={activeTab === 'messages'} onClick={() => setActiveTab('messages')} />
            {urgentCount > 0 && isFbConnected && <span className="absolute right-3 top-3 bg-amber-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{urgentCount}</span>}
          </div>
          <NavItem icon={Settings} label="Setări" active={activeTab === 'settings'} onClick={() => setActiveTab('settings')} />
        </nav>
        <div className="mt-auto pt-4 border-t border-gray-200 space-y-2">
           <div className="px-4 py-2 bg-blue-50 rounded-lg border border-blue-100">
             <p className="text-[10px] text-blue-500 font-bold uppercase tracking-wider mb-1">Conectat ca</p>
             <p className="text-xs font-semibold text-blue-900 truncate">{session?.accessKey?.userId}</p>
             <p className="text-[10px] text-blue-400 truncate">Page: {session?.accessKey?.pageId}</p>
           </div>
           <button onClick={handleLogout} className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors">
             <LogOut size={16} /> Deconectare
           </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className={`flex-1 flex overflow-hidden relative ${isMobileChatOpen ? 'mb-0' : 'mb-16 md:mb-0'}`}>
        
        {activeTab === 'messages' && (
          <>
            <div className={`w-full md:w-80 bg-white border-r border-gray-200 flex flex-col ${selectedConvId ? 'hidden md:flex' : 'flex'}`}>
              <div className="p-4 border-b border-gray-100 bg-white z-10">
                <div className="flex items-center justify-between mb-2">
                    <h2 className="font-bold text-gray-800">Inbox</h2>
                    {isFbConnected && (
                        <button onClick={() => isFbConnected && handleConnectFb()} className="p-1.5 text-gray-500 hover:text-blue-600 rounded-lg"><RefreshCw size={16} /></button>
                    )}
                </div>
                <div className="flex bg-gray-100 p-1 rounded-lg">
                    <button onClick={() => setViewMode('all')} disabled={!isFbConnected} className={`flex-1 py-1.5 text-xs font-medium rounded-md transition-all ${viewMode === 'all' && isFbConnected ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500'}`}>Toate</button>
                    <button onClick={() => setViewMode('urgent')} disabled={!isFbConnected} className={`flex-1 py-1.5 text-xs font-medium rounded-md transition-all ${viewMode === 'urgent' && isFbConnected ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500'}`}>Urgențe</button>
                </div>
              </div>
              <div className="flex-1 overflow-y-auto">
                {!isFbConnected ? (
                   <div className="flex flex-col items-center justify-center h-64 p-6 text-center">
                     <p className="text-gray-800 font-medium mb-1">Deconectat</p>
                     <button onClick={() => setActiveTab('settings')} className="text-blue-600 text-xs font-bold hover:underline">Conectează în Setări</button>
                   </div>
                ) : displayedConversations.length === 0 ? (
                  <div className="p-8 text-center text-gray-400 text-sm">Nu există mesaje.</div>
                ) : (
                  displayedConversations.map(conv => (
                    <ConversationItem key={conv.id} conversation={conv} isActive={selectedConvId === conv.id} onClick={() => setSelectedConvId(conv.id)} hoursInactive={conv.hoursInactive || 0} minUrgentHours={minUrgentHours} maxUrgentHours={maxUrgentHours} />
                  ))
                )}
              </div>
            </div>
            <div className={`flex-1 ${!selectedConvId ? 'hidden md:flex' : 'flex'}`}>
              <ChatWindow conversation={activeConversation} presetMessage={presetMessage} onSendMessage={handleSendMessage} onBack={() => setSelectedConvId(null)} />
            </div>
          </>
        )}

        {activeTab === 'settings' && (
           <div className="flex-1 p-4 md:p-8 overflow-y-auto">
             <div className="max-w-2xl mx-auto space-y-6">
               <h2 className="text-xl md:text-2xl font-bold text-gray-800 mb-4">Setări</h2>
               <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-200">
                  <h3 className="text-lg font-semibold mb-4 text-gray-700">Conexiune Facebook</h3>
                  <div className="space-y-4">
                      {/* Only allow Page ID edit if NOT enforced by key */}
                      <div>
                        <label className="block text-xs font-bold text-gray-500 mb-1">PAGE ID</label>
                        <div className="relative">
                            <input 
                                type="text" 
                                value={fbPageId}
                                onChange={(e) => setFbPageId(e.target.value)}
                                disabled={true} // ALWAYS LOCKED to the Key's Page ID
                                className="w-full bg-gray-100 border border-gray-200 text-gray-500 cursor-not-allowed rounded-lg p-2.5 text-sm outline-none" 
                            />
                            <Lock size={14} className="absolute right-3 top-3 text-gray-400" />
                        </div>
                        <p className="text-[10px] text-blue-600 mt-1 flex items-center gap-1">
                            <Shield size={10} />
                            ID blocat de cheia de acces curentă.
                        </p>
                      </div>

                      <div>
                        <label className="block text-xs font-bold text-gray-500 mb-1">ACCESS TOKEN</label>
                        <input type="password" value={fbToken} onChange={(e) => setFbToken(e.target.value)} className="w-full bg-gray-50 border border-gray-200 rounded-lg p-2.5 text-sm" />
                      </div>
                      
                      <div className="flex gap-4 pt-2">
                        <button onClick={() => setUseLiveApi(!useLiveApi)} className={`flex-1 py-2 rounded-lg text-xs font-bold border ${useLiveApi ? 'bg-purple-50 text-purple-700 border-purple-200' : 'bg-gray-50 text-gray-600'}`}>
                            {useLiveApi ? 'MODE: LIVE API' : 'MODE: SIMULATION'}
                        </button>
                        <button onClick={handleConnectFb} className="flex-1 py-2 bg-blue-600 text-white rounded-lg font-bold hover:bg-blue-700">Actualizează / Conectează</button>
                      </div>
                  </div>
               </div>
               <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-200">
                  <h3 className="text-lg font-semibold mb-4 text-gray-700 flex items-center gap-2">
                    <Clock size={18} className="text-amber-500" />
                    Configurare Interval Urgență
                  </h3>
                  <p className="text-xs text-gray-500 mb-4">
                    Setează intervalul de ore în care o conversație este considerată "urgentă" pentru follow-up.
                  </p>
                  <div className="flex items-center gap-4">
                    <div>
                      <label className="block text-xs font-bold text-gray-500 mb-1">DE LA (ORE)</label>
                      <input 
                        type="number" 
                        value={minUrgentHours} 
                        onChange={(e) => setMinUrgentHours(Number(e.target.value))} 
                        className="w-full bg-gray-50 border border-gray-200 rounded-lg p-2.5 text-sm" 
                      />
                    </div>
                    <div className="pt-5 text-gray-400">-</div>
                    <div>
                      <label className="block text-xs font-bold text-gray-500 mb-1">PÂNĂ LA (ORE)</label>
                      <input 
                        type="number" 
                        value={maxUrgentHours} 
                        onChange={(e) => setMaxUrgentHours(Number(e.target.value))} 
                        className="w-full bg-gray-50 border border-gray-200 rounded-lg p-2.5 text-sm" 
                      />
                    </div>
                  </div>
                </div>
             </div>
           </div>
        )}

        {activeTab === 'dashboard' && (
          <div className="flex-1 p-8 overflow-y-auto">
              <div className="max-w-4xl mx-auto">
                 <h2 className="text-2xl font-bold text-gray-800 mb-6">Bine ai venit, {session?.accessKey?.userId}!</h2>
                 <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    <StatCard title="Total Conversații" value={conversations.length} icon={Users} color="bg-blue-500" />
                    <StatCard title="Urgențe" value={urgentCount} icon={History} color="bg-amber-500" />
                    <StatCard title="Pagina" value={session?.accessKey?.pageId || '-'} icon={Link} color="bg-green-500" />
                 </div>
              </div>
          </div>
        )}
      </main>

      {/* Mobile Nav */}
      <nav className={`md:hidden fixed bottom-0 w-full bg-white border-t border-gray-200 flex justify-around p-2 z-50 pb-safe ${isMobileChatOpen ? 'hidden' : ''}`}>
          <NavItem icon={LayoutDashboard} label="Home" isMobile active={activeTab === 'dashboard'} onClick={() => setActiveTab('dashboard')} />
          <NavItem icon={MessageCircle} label="Mesaje" isMobile active={activeTab === 'messages'} onClick={() => setActiveTab('messages')} />
          <NavItem icon={Settings} label="Setări" isMobile active={activeTab === 'settings'} onClick={() => setActiveTab('settings')} />
          <button onClick={handleLogout} className="flex flex-col items-center justify-center p-2 text-red-400"><LogOut size={24} /><span className="text-[10px] font-medium">Exit</span></button>
      </nav>
    </div>
  );
};

const StatCard = ({ title, value, icon: Icon, color }: any) => (
  <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-200 flex items-center gap-4">
    <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-white ${color}`}><Icon size={20} /></div>
    <div><p className="text-sm text-gray-500 font-medium">{title}</p><p className="text-2xl font-bold text-gray-800">{value}</p></div>
  </div>
);

export default App;

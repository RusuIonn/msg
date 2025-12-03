
import React, { useState, useEffect } from 'react';
import { AccessKey } from '../types';
import { authService } from '../services/authService';
import { Key, Trash2, RefreshCw, Copy, ShieldCheck, User, Layout, X } from 'lucide-react';

interface Props {
  onLogout: () => void;
}

export const AdminPanel: React.FC<Props> = ({ onLogout }) => {
  const [keys, setKeys] = useState<AccessKey[]>([]);
  
  // Form State
  const [userId, setUserId] = useState('');
  const [pageId, setPageId] = useState('');
  const [note, setNote] = useState('');
  const [validDays, setValidDays] = useState(30);

  useEffect(() => {
    loadKeys();
  }, []);

  const loadKeys = () => {
    setKeys(authService.getAllKeys());
  };

  const handleGenerate = () => {
    if (!userId || !pageId) return alert('Utilizator și Page ID sunt obligatorii');
    authService.generateKey(userId, pageId, validDays, note);
    setUserId('');
    setPageId('');
    setNote('');
    loadKeys();
  };

  const handleRevoke = (keyStr: string) => {
    if (confirm('Sigur dorești să revoci accesul pentru această cheie?')) {
      authService.revokeKey(keyStr);
      loadKeys();
    }
  };

  const handleRenew = (keyStr: string) => {
    authService.renewKey(keyStr);
    loadKeys();
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    alert('Cheie copiată!');
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 p-4 md:p-8 font-sans">
      <div className="max-w-6xl mx-auto">
        
        {/* Header */}
        <div className="flex justify-between items-center mb-8 border-b border-slate-700 pb-4">
          <div className="flex items-center gap-3">
            <ShieldCheck className="text-emerald-400" size={32} />
            <div>
              <h1 className="text-2xl font-bold">Panou Administrator</h1>
              <p className="text-slate-400 text-sm">Gestionare Chei de Acces Unice</p>
            </div>
          </div>
          <button 
            onClick={onLogout}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg border border-slate-600 transition-colors"
          >
            Deconectare
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          
          {/* Generator Form */}
          <div className="bg-slate-800 p-6 rounded-2xl border border-slate-700 shadow-xl h-fit">
             <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
               <Key size={20} className="text-blue-400" />
               Generare Cheie Nouă
             </h2>
             
             <div className="space-y-4">
               <div>
                 <label className="block text-xs font-bold text-slate-400 mb-1">NUME / ID UTILIZATOR</label>
                 <input 
                   type="text" 
                   value={userId}
                   onChange={e => setUserId(e.target.value)}
                   placeholder="ex: popescu.ion"
                   className="w-full bg-slate-900 border border-slate-600 rounded-lg p-2.5 text-sm outline-none focus:border-blue-500 text-white"
                 />
               </div>

               <div>
                 <label className="block text-xs font-bold text-slate-400 mb-1">FACEBOOK PAGE ID</label>
                 <input 
                   type="text" 
                   value={pageId}
                   onChange={e => setPageId(e.target.value)}
                   placeholder="ex: 109283..."
                   className="w-full bg-slate-900 border border-slate-600 rounded-lg p-2.5 text-sm outline-none focus:border-blue-500 text-white"
                 />
                 <p className="text-[10px] text-slate-500 mt-1">
                   Cheia va fi blocată strict pe acest Page ID.
                 </p>
               </div>

               <div className="flex gap-4">
                 <div className="flex-1">
                    <label className="block text-xs font-bold text-slate-400 mb-1">VALABILITATE (ZILE)</label>
                    <input 
                      type="number" 
                      value={validDays}
                      onChange={e => setValidDays(Number(e.target.value))}
                      className="w-full bg-slate-900 border border-slate-600 rounded-lg p-2.5 text-sm outline-none focus:border-blue-500 text-white"
                    />
                 </div>
               </div>

               <div>
                 <label className="block text-xs font-bold text-slate-400 mb-1">NOTĂ INTERNĂ (OPȚIONAL)</label>
                 <input 
                   type="text" 
                   value={note}
                   onChange={e => setNote(e.target.value)}
                   placeholder="ex: Contract #442"
                   className="w-full bg-slate-900 border border-slate-600 rounded-lg p-2.5 text-sm outline-none focus:border-blue-500 text-white"
                 />
               </div>

               <button 
                 onClick={handleGenerate}
                 className="w-full py-3 bg-blue-600 hover:bg-blue-500 text-white font-bold rounded-lg mt-2 transition-all active:scale-95 shadow-lg shadow-blue-900/50"
               >
                 Generează Cheie Unică
               </button>
             </div>
          </div>

          {/* Keys List */}
          <div className="lg:col-span-2 space-y-4">
             <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
               <Layout size={20} className="text-purple-400" />
               Chei Active & Istoric
             </h2>

             <div className="space-y-3">
               {keys.length === 0 && (
                 <div className="text-center p-8 text-slate-500 border border-dashed border-slate-700 rounded-xl">
                   Nu există chei generate.
                 </div>
               )}
               
               {keys.map((k) => {
                 const isExpired = Date.now() > k.expiresAt;
                 const statusColor = k.isRevoked 
                    ? 'bg-red-900/20 border-red-800 text-red-400' 
                    : isExpired 
                      ? 'bg-amber-900/20 border-amber-800 text-amber-400' 
                      : 'bg-slate-800 border-slate-700 text-slate-200';

                 return (
                   <div key={k.key} className={`p-4 rounded-xl border flex flex-col md:flex-row md:items-center justify-between gap-4 transition-all ${statusColor}`}>
                      <div className="flex-1 overflow-hidden">
                         <div className="flex items-center gap-2 mb-1">
                            <User size={14} className="opacity-70" />
                            <span className="font-bold text-sm">{k.userId}</span>
                            <span className="text-xs opacity-50 px-2 border-l border-white/10">Page: {k.pageId}</span>
                         </div>
                         <div className="font-mono text-xs bg-black/30 p-2 rounded truncate select-all flex items-center justify-between group">
                            {k.key}
                            <button onClick={() => copyToClipboard(k.key)} className="text-slate-500 hover:text-white opacity-0 group-hover:opacity-100 transition-opacity">
                              <Copy size={12} />
                            </button>
                         </div>
                         <div className="flex items-center gap-4 mt-2 text-[10px] opacity-70">
                            <span>Creat: {new Date(k.createdAt).toLocaleDateString()}</span>
                            <span>Expiră: {new Date(k.expiresAt).toLocaleDateString()}</span>
                            {k.note && <span className="italic text-blue-300">"{k.note}"</span>}
                         </div>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                         {k.isRevoked || isExpired ? (
                           <button 
                             onClick={() => handleRenew(k.key)}
                             title="Reînnoiește Accesul"
                             className="p-2 bg-emerald-600/20 text-emerald-400 hover:bg-emerald-600 hover:text-white rounded-lg transition-colors border border-emerald-600/30"
                           >
                             <RefreshCw size={16} />
                           </button>
                         ) : (
                           <button 
                             onClick={() => handleRevoke(k.key)}
                             title="Revocă Accesul"
                             className="p-2 bg-red-600/20 text-red-400 hover:bg-red-600 hover:text-white rounded-lg transition-colors border border-red-600/30"
                           >
                             <Trash2 size={16} />
                           </button>
                         )}
                      </div>
                   </div>
                 );
               })}
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};

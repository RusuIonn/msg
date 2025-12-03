
import React, { useState } from 'react';
import { Key, Shield, ArrowRight, Lock, UserCog } from 'lucide-react';
import { authService } from '../services/authService';
import { AuthSession } from '../types';

interface Props {
  onLogin: (session: AuthSession) => void;
}

export const LoginScreen: React.FC<Props> = ({ onLogin }) => {
  const [view, setView] = useState<'user' | 'admin'>('user');
  const [input, setInput] = useState('');
  const [error, setError] = useState('');

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (view === 'user') {
      // Validate Key
      const result = authService.validateKey(input.trim());
      if (result.valid && result.data) {
        onLogin({
          isAuthenticated: true,
          role: 'user',
          accessKey: result.data
        });
      } else {
        setError(result.error || 'Cheie invalidă');
      }
    } else {
      // Admin Login (Hardcoded for demo purposes)
      if (input === 'admin123') {
        onLogin({
          isAuthenticated: true,
          role: 'admin'
        });
      } else {
        setError('Parolă de administrator incorectă');
      }
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-2xl shadow-xl overflow-hidden border border-slate-100">
        
        {/* Toggle Header */}
        <div className="flex text-sm font-medium border-b">
          <button 
            onClick={() => { setView('user'); setInput(''); setError(''); }}
            className={`flex-1 py-4 text-center transition-colors ${view === 'user' ? 'bg-white text-blue-600 border-b-2 border-blue-600' : 'bg-slate-50 text-slate-500 hover:text-slate-700'}`}
          >
            Acces Utilizator
          </button>
          <button 
            onClick={() => { setView('admin'); setInput(''); setError(''); }}
            className={`flex-1 py-4 text-center transition-colors ${view === 'admin' ? 'bg-white text-slate-800 border-b-2 border-slate-800' : 'bg-slate-50 text-slate-500 hover:text-slate-700'}`}
          >
            Administrator
          </button>
        </div>

        <div className="p-8">
          <div className="flex justify-center mb-6">
            <div className={`w-16 h-16 rounded-full flex items-center justify-center ${view === 'user' ? 'bg-blue-100 text-blue-600' : 'bg-slate-100 text-slate-800'}`}>
               {view === 'user' ? <Key size={32} /> : <UserCog size={32} />}
            </div>
          </div>

          <h2 className="text-xl font-bold text-center text-slate-800 mb-2">
            {view === 'user' ? 'Introduceți Cheia de Acces' : 'Autentificare Admin'}
          </h2>
          <p className="text-sm text-center text-slate-500 mb-8">
            {view === 'user' 
              ? 'Introduceți cheia unică primită de la administrator pentru a accesa contul dvs.' 
              : 'Panou de control pentru generarea și gestionarea cheilor.'}
          </p>

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-400 mb-1 ml-1">
                {view === 'user' ? 'CHEIE ACCES (UUID)' : 'PAROLĂ ADMINISTRATOR'}
              </label>
              <div className="relative">
                <input 
                  type={view === 'admin' ? 'password' : 'text'}
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  placeholder={view === 'user' ? 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' : '••••••••'}
                  className="w-full bg-slate-50 border border-slate-300 text-slate-900 rounded-xl px-4 py-3 pl-10 focus:ring-2 focus:ring-blue-500 outline-none transition-all font-mono text-sm"
                  autoFocus
                />
                <div className="absolute left-3 top-3.5 text-slate-400">
                  {view === 'user' ? <Shield size={16} /> : <Lock size={16} />}
                </div>
              </div>
            </div>

            {error && (
              <div className="p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-100 text-center font-medium animate-pulse">
                {error}
              </div>
            )}

            <button 
              type="submit"
              className={`w-full py-3.5 rounded-xl font-bold text-white flex items-center justify-center gap-2 transition-all active:scale-95 shadow-lg ${
                view === 'user' 
                  ? 'bg-blue-600 hover:bg-blue-700 shadow-blue-500/20' 
                  : 'bg-slate-800 hover:bg-slate-900 shadow-slate-500/20'
              }`}
            >
              <span>{view === 'user' ? 'Validează Cheia' : 'Intră în Cont'}</span>
              <ArrowRight size={18} />
            </button>
          </form>
          
          {view === 'user' && (
            <p className="text-[10px] text-center text-slate-400 mt-6">
              Notă: Cheia este valabilă doar pentru un singur utilizator și o singură pagină de Facebook.
            </p>
          )}
        </div>
      </div>
    </div>
  );
};

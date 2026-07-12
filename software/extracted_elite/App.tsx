
import React, { useState } from 'react';
import { 
  Settings, 
  Plus, 
  Mic, 
  ChevronRight,
  Sun,
  Moon,
  RefreshCw,
  MessageSquare
} from 'lucide-react';
import { GoogleGenAI } from '@google/genai';
import { Device, HomeState, Language, ROOMS, ChatMessage } from './types';
import DeviceCard from './components/DeviceCard';
import VoiceInterface from './components/VoiceInterface';
import ConversationPanel from './components/ConversationPanel';
import ImageEditor from './components/ImageEditor';
import { initialDevices } from './constants';

const App: React.FC = () => {
  const [homeState, setHomeState] = useState<HomeState>({
    devices: initialDevices.map(d => d.type === 'security' ? { ...d, imageUrl: 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&q=80&w=800' } : d),
    isAway: false,
    activeLanguage: 'English'
  });
  const [activeRoom, setActiveRoom] = useState<string>('All');
  const [isVoiceActive, setIsVoiceActive] = useState(false);
  const [showVoicePanel, setShowVoicePanel] = useState(false);
  const [isChatOpen, setIsChatOpen] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [editingImage, setEditingImage] = useState<string | null>(null);

  const toggleDevice = (id: string) => {
    setHomeState(prev => ({
      ...prev,
      devices: prev.devices.map(d => d.id === id ? { ...d, status: !d.status } : d)
    }));
  };

  const updateDeviceValue = (id: string, value: number) => {
    setHomeState(prev => ({
      ...prev,
      devices: prev.devices.map(d => d.id === id ? { ...d, value } : d)
    }));
  };

  const addMessage = (role: 'user' | 'assistant', text: string) => {
    setMessages(prev => [...prev, { role, text, timestamp: new Date() }]);
  };

  const handleSendMessage = async (text: string) => {
    addMessage('user', text);
    setIsProcessing(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      // Using gemini-2.5-flash-lite for fast responses
      const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash-lite-latest',
        contents: text,
        config: {
          systemInstruction: "You are the smart home controller. Keep answers brief and professional."
        }
      });
      if (response.text) addMessage('assistant', response.text);
    } catch (err) {
      console.error("Fast chat failed", err);
    } finally {
      setIsProcessing(false);
    }
  };

  const filteredDevices = activeRoom === 'All' 
    ? homeState.devices 
    : homeState.devices.filter(d => d.room === activeRoom);

  return (
    <div className="h-screen w-full flex flex-col overflow-hidden bg-zinc-950 text-zinc-100 selection:bg-blue-500/30">
      {/* Header */}
      <header className="h-16 border-b border-white/5 px-6 flex items-center justify-between z-20 bg-zinc-950/80 backdrop-blur-md">
        <div className="flex items-center gap-4">
          <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center shadow-lg shadow-blue-500/10">
            <RefreshCw className="text-white animate-spin-slow" size={18} />
          </div>
          <div className="hidden sm:block">
            <h1 className="font-bold text-base tracking-tight leading-none">Gemini Elite</h1>
            <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-1">Smart OS 2.5</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="hidden md:flex bg-white/5 rounded-full px-3 py-1 items-center gap-2 border border-white/5">
            <div className="w-1.5 h-1.5 rounded-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.4)]"></div>
            <span className="text-[10px] font-bold text-zinc-400 uppercase">Cloud Active</span>
          </div>
          
          <select 
            value={homeState.activeLanguage}
            onChange={(e) => setHomeState(prev => ({ ...prev, activeLanguage: e.target.value }))}
            className="bg-transparent border-none text-xs font-semibold text-zinc-400 focus:outline-none cursor-pointer hover:text-white transition-colors"
          >
            {Object.entries(Language).map(([key, val]) => (
              <option key={key} value={val} className="bg-zinc-900">{val}</option>
            ))}
          </select>

          <button 
            onClick={() => setIsChatOpen(!isChatOpen)}
            className={`p-2 rounded-lg transition-all ${isChatOpen ? 'bg-blue-600 text-white' : 'hover:bg-white/5 text-zinc-400'}`}
          >
            <MessageSquare size={18} />
          </button>
          
          <button className="p-2 rounded-lg hover:bg-white/5 text-zinc-400 transition-all">
            <Settings size={18} />
          </button>
        </div>
      </header>

      <div className="flex-1 flex overflow-hidden relative">
        {/* Sidebar */}
        <aside className="hidden lg:flex w-64 flex-col p-6 gap-8 border-r border-white/5 bg-zinc-950/40">
          <section>
            <h3 className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest mb-4">Location Control</h3>
            <div className="space-y-1">
              {['All', ...ROOMS].map(room => (
                <button
                  key={room}
                  onClick={() => setActiveRoom(room)}
                  className={`w-full text-left px-4 py-2 rounded-xl text-sm font-medium transition-all flex items-center justify-between group ${
                    activeRoom === room ? 'bg-white/5 text-blue-400 border border-white/10' : 'text-zinc-500 hover:text-zinc-300'
                  }`}
                >
                  {room}
                  <ChevronRight size={14} className={`transition-transform ${activeRoom === room ? 'rotate-90 opacity-100' : 'opacity-0 group-hover:opacity-40 group-hover:translate-x-1'}`} />
                </button>
              ))}
            </div>
          </section>

          <section>
            <h3 className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest mb-4">Quick Scenarios</h3>
            <div className="space-y-2">
              <button className="w-full p-3 rounded-xl bg-zinc-900/50 border border-white/5 flex items-center gap-3 hover:bg-zinc-900 transition-all group">
                <div className="p-2 rounded-lg bg-orange-500/10 text-orange-500 group-hover:scale-110 transition-transform"><Sun size={16} /></div>
                <span className="text-xs font-semibold">Morning Protocol</span>
              </button>
              <button className="w-full p-3 rounded-xl bg-zinc-900/50 border border-white/5 flex items-center gap-3 hover:bg-zinc-900 transition-all group">
                <div className="p-2 rounded-lg bg-blue-500/10 text-blue-400 group-hover:scale-110 transition-transform"><Moon size={16} /></div>
                <span className="text-xs font-semibold">Sleep Cycle</span>
              </button>
            </div>
          </section>
        </aside>

        {/* Content Area */}
        <div className="flex-1 overflow-y-auto p-6 lg:p-8 space-y-8 bg-zinc-950">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-white/5 pb-6">
            <div>
              <h2 className="text-2xl font-bold tracking-tight text-white">
                {activeRoom === 'All' ? 'System Overview' : activeRoom}
              </h2>
              <p className="text-xs text-zinc-500 mt-1 font-medium">Monitoring {filteredDevices.length} active nodes in current sector.</p>
            </div>
            
            <div className="flex gap-2">
              <div className="bg-zinc-900/50 border border-white/5 px-4 py-2 rounded-xl flex items-center gap-4">
                <div className="flex flex-col">
                  <span className="text-[9px] font-bold text-zinc-600 uppercase">Temp</span>
                  <span className="text-sm font-bold text-zinc-200">22.4°C</span>
                </div>
                <div className="w-px h-6 bg-white/5"></div>
                <div className="flex flex-col">
                  <span className="text-[9px] font-bold text-zinc-600 uppercase">Power</span>
                  <span className="text-sm font-bold text-zinc-200">1.2 kW</span>
                </div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4">
            {filteredDevices.map(device => (
              <DeviceCard 
                key={device.id} 
                device={device} 
                onToggle={() => toggleDevice(device.id)}
                onUpdateValue={(val) => updateDeviceValue(device.id, val)}
                onEditImage={device.imageUrl ? () => setEditingImage(device.imageUrl!) : undefined}
              />
            ))}
            <button className="border border-dashed border-white/10 rounded-2xl p-6 flex flex-col items-center justify-center gap-3 text-zinc-600 hover:text-zinc-400 hover:border-white/20 transition-all group min-h-[160px] bg-white/[0.01]">
              <div className="w-10 h-10 rounded-full border border-white/5 flex items-center justify-center group-hover:bg-white/5 transition-colors">
                <Plus size={20} />
              </div>
              <span className="font-bold text-[10px] uppercase tracking-widest">Integrate Device</span>
            </button>
          </div>
        </div>

        {/* Conversation Side Slide */}
        <ConversationPanel 
          isOpen={isChatOpen} 
          messages={messages} 
          onClose={() => setIsChatOpen(false)}
          onSendMessage={handleSendMessage}
          isProcessing={isProcessing}
        />
      </div>

      {/* Floating Voice Button */}
      <div className="fixed bottom-8 left-1/2 -translate-x-1/2 z-40">
        <button 
          onClick={() => setShowVoicePanel(true)}
          className={`w-14 h-14 rounded-2xl flex items-center justify-center shadow-2xl transition-all ${
            isVoiceActive 
              ? 'bg-blue-600 voice-active scale-110' 
              : 'bg-zinc-800 border border-white/10 hover:bg-zinc-700 hover:scale-105'
          }`}
        >
          <Mic size={24} className={isVoiceActive ? 'text-white' : 'text-blue-400'} />
        </button>
      </div>

      {/* Overlays */}
      {showVoicePanel && (
        <VoiceInterface 
          homeState={homeState}
          setHomeState={setHomeState}
          onClose={() => setShowVoicePanel(false)}
          onVoiceStateChange={setIsVoiceActive}
          onMessageAdded={addMessage}
        />
      )}

      {editingImage && (
        <ImageEditor 
          initialImage={editingImage} 
          onClose={() => setEditingImage(null)}
          onSave={(newImg) => {
            setHomeState(prev => ({
              ...prev,
              devices: prev.devices.map(d => d.imageUrl === editingImage ? { ...d, imageUrl: newImg } : d)
            }));
            setEditingImage(null);
          }}
        />
      )}
    </div>
  );
};

export default App;

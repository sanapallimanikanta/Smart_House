
import React from 'react';
import { 
  Lightbulb, 
  Wind, 
  Thermometer, 
  Lock, 
  Unlock, 
  Shield, 
  Zap,
  ChevronUp,
  ChevronDown,
  Sparkles
} from 'lucide-react';
import { Device } from '../types';

interface DeviceCardProps {
  device: Device;
  onToggle: () => void;
  onUpdateValue: (val: number) => void;
  onEditImage?: () => void;
}

const DeviceCard: React.FC<DeviceCardProps> = ({ device, onToggle, onUpdateValue, onEditImage }) => {
  const getIcon = () => {
    switch (device.type) {
      case 'light': return <Lightbulb size={20} />;
      case 'ac': return <Thermometer size={20} />;
      case 'fan': return <Wind size={20} />;
      case 'lock': return device.status ? <Lock size={20} /> : <Unlock size={20} />;
      case 'security': return <Shield size={20} />;
      case 'blinds': return <Zap size={20} />;
      default: return <Lightbulb size={20} />;
    }
  };

  const getStatusColor = () => {
    if (!device.status) return 'text-zinc-600';
    switch (device.type) {
      case 'light': return 'text-amber-400';
      case 'ac': return 'text-blue-400';
      case 'fan': return 'text-teal-400';
      case 'lock': return 'text-rose-400';
      case 'security': return 'text-indigo-400';
      case 'blinds': return 'text-orange-400';
      default: return 'text-blue-500';
    }
  };

  return (
    <div className={`p-6 rounded-2xl transition-all duration-500 relative group overflow-hidden border ${
      device.status 
        ? 'bg-zinc-900 border-white/10 shadow-2xl' 
        : 'bg-zinc-950/30 border-white/5 opacity-60 grayscale-[0.2]'
    }`}>
      <div className={`absolute top-0 left-0 w-full h-0.5 transition-all duration-500 ${
        device.status ? getStatusColor().replace('text', 'bg') : 'bg-transparent'
      }`}></div>

      <div className="flex justify-between items-start mb-4">
        <div className={`p-2.5 rounded-xl transition-all ${
          device.status ? 'bg-white/5' : 'bg-zinc-900'
        } ${getStatusColor()}`}>
          {getIcon()}
        </div>
        
        <button 
          onClick={onToggle}
          className={`w-10 h-5 rounded-full transition-all relative ${
            device.status ? 'bg-blue-600 shadow-[0_0_12px_rgba(37,99,235,0.3)]' : 'bg-zinc-800'
          }`}
        >
          <div className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-all transform ${
            device.status ? 'translate-x-5.5' : 'translate-x-0.5'
          } shadow-md`}></div>
        </button>
      </div>

      {device.imageUrl && device.status && (
        <div className="mb-4 relative group/img rounded-xl overflow-hidden aspect-video border border-white/5">
          <img src={device.imageUrl} alt={device.name} className="w-full h-full object-cover group-hover/img:scale-105 transition-transform duration-700" />
          {onEditImage && (
            <button 
              onClick={onEditImage}
              className="absolute inset-0 bg-black/40 opacity-0 group-hover/img:opacity-100 flex items-center justify-center transition-opacity gap-2"
            >
              <div className="bg-white text-black text-[9px] font-bold uppercase tracking-widest px-3 py-1.5 rounded-full flex items-center gap-1.5">
                <Sparkles size={10} />
                AI Edit
              </div>
            </button>
          )}
        </div>
      )}

      <div className="space-y-1">
        <h3 className="font-bold text-sm text-zinc-200">{device.name}</h3>
        <p className="text-[9px] text-zinc-600 font-bold uppercase tracking-[0.15em]">{device.room}</p>
      </div>

      {(device.type === 'ac' || device.type === 'fan') && device.status && (
        <div className="mt-6 flex items-center justify-between bg-black/20 rounded-xl p-2.5 border border-white/5">
          <div className="flex flex-col pl-1.5">
            <span className="text-[8px] text-zinc-600 font-bold uppercase">Level</span>
            <span className="text-xs font-bold text-zinc-300">{device.value}{device.type === 'ac' ? '°C' : ''}</span>
          </div>
          <div className="flex gap-1">
            <button onClick={() => onUpdateValue((device.value || 0) - 1)} className="p-1 rounded-lg hover:bg-white/5 text-zinc-500 hover:text-white transition-colors"><ChevronDown size={14} /></button>
            <button onClick={() => onUpdateValue((device.value || 0) + 1)} className="p-1 rounded-lg hover:bg-white/5 text-zinc-500 hover:text-white transition-colors"><ChevronUp size={14} /></button>
          </div>
        </div>
      )}

      {device.type === 'light' && device.status && (
        <div className="mt-6 h-0.5 w-full bg-zinc-800 rounded-full overflow-hidden">
          <div className="h-full bg-amber-400 w-3/4 rounded-full shadow-[0_0_8px_rgba(251,191,36,0.4)]"></div>
        </div>
      )}
    </div>
  );
};

export default DeviceCard;

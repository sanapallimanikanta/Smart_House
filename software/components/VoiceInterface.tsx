
import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { X, Mic, MicOff, Activity, ShieldCheck, Zap } from 'lucide-react';
import { GoogleGenAI, LiveServerMessage, Modality, Type, FunctionDeclaration } from '@google/genai';
import { HomeState } from '../types';

interface VoiceInterfaceProps {
  homeState: HomeState;
  setHomeState: React.Dispatch<React.SetStateAction<HomeState>>;
  onClose: () => void;
  onVoiceStateChange: (active: boolean) => void;
  onMessageAdded: (role: 'user' | 'assistant', text: string) => void;
}

// Audio Helpers
function decode(base64: string) {
  const binaryString = atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function encode(bytes: Uint8Array) {
  let binary = '';
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function decodeAudioData(
  data: Uint8Array,
  ctx: AudioContext,
  sampleRate: number,
  numChannels: number,
): Promise<AudioBuffer> {
  const dataInt16 = new Int16Array(data.buffer);
  const frameCount = dataInt16.length / numChannels;
  const buffer = ctx.createBuffer(numChannels, frameCount, sampleRate);
  for (let channel = 0; channel < numChannels; channel++) {
    const channelData = buffer.getChannelData(channel);
    for (let i = 0; i < frameCount; i++) {
      channelData[i] = dataInt16[i * numChannels + channel] / 32768.0;
    }
  }
  return buffer;
}

// Particle Component for 360-degree emission
const EmittingParticles = ({ active, color }: { active: boolean, color: string }) => {
  const particleCount = 40;
  const particles = useMemo(() => {
    return Array.from({ length: particleCount }).map((_, i) => ({
      id: i,
      angle: `${(360 / particleCount) * i}deg`,
      distance: `${80 + Math.random() * 120}px`,
      duration: `${1.5 + Math.random() * 2}s`,
      delay: `${Math.random() * 2}s`,
    }));
  }, []);

  if (!active) return null;

  return (
    <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
      {particles.map((p) => (
        <div
          key={p.id}
          className="particle"
          style={{
            '--angle': p.angle,
            '--distance': p.distance,
            '--duration': p.duration,
            '--delay': p.delay,
            '--particle-color': color,
          } as React.CSSProperties}
        />
      ))}
    </div>
  );
};

const VoiceInterface: React.FC<VoiceInterfaceProps> = ({ 
  homeState, 
  setHomeState, 
  onClose, 
  onVoiceStateChange,
  onMessageAdded
}) => {
  const [status, setStatus] = useState<'idle' | 'connecting' | 'listening' | 'speaking' | 'error'>('idle');
  const [inputTranscript, setInputTranscript] = useState<string>('');
  const [outputTranscript, setOutputTranscript] = useState<string>('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const sessionRef = useRef<any>(null);
  const inputAudioCtxRef = useRef<AudioContext | null>(null);
  const outputAudioCtxRef = useRef<AudioContext | null>(null);
  const nextStartTimeRef = useRef(0);
  const activeSourcesRef = useRef<Set<AudioBufferSourceNode>>(new Set());
  const streamRef = useRef<MediaStream | null>(null);

  const controlDeviceFn: FunctionDeclaration = {
    name: 'control_device',
    parameters: {
      type: Type.OBJECT,
      description: 'Turn a smart home device on or off, or change its numerical value.',
      properties: {
        id: { type: Type.STRING, description: 'The unique ID of the device to control.' },
        status: { type: Type.BOOLEAN, description: 'True to turn on/lock, false to turn off/unlock.' },
        value: { type: Type.NUMBER, description: 'Numerical value like temperature or fan speed.' }
      },
      required: ['id']
    }
  };

  const executeFunction = useCallback((name: string, args: any) => {
    if (name === 'control_device') {
      setHomeState(prev => ({
        ...prev,
        devices: prev.devices.map(d => {
          if (d.id === args.id) {
            return {
              ...d,
              status: args.status !== undefined ? args.status : d.status,
              value: args.value !== undefined ? args.value : d.value
            };
          }
          return d;
        })
      }));
      return "Successfully updated device state.";
    }
    return "Function not found.";
  }, [setHomeState]);

  const startSession = async () => {
    try {
      setStatus('connecting');
      setErrorMsg(null);
      
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      inputAudioCtxRef.current = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 16000 });
      outputAudioCtxRef.current = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 24000 });
      streamRef.current = await navigator.mediaDevices.getUserMedia({ audio: true });

      const sessionPromise = ai.live.connect({
        model: 'gemini-2.5-flash-native-audio-preview-09-2025',
        config: {
          responseModalities: [Modality.AUDIO],
          systemInstruction: `You are Gemini Smart Home Elite. Control devices for the user in ${homeState.activeLanguage}. Be concise.`,
          tools: [{ functionDeclarations: [controlDeviceFn] }],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Kore' } } },
          inputAudioTranscription: {},
          outputAudioTranscription: {}
        },
        callbacks: {
          onopen: () => {
            setStatus('listening');
            onVoiceStateChange(true);
            const source = inputAudioCtxRef.current!.createMediaStreamSource(streamRef.current!);
            const scriptProcessor = inputAudioCtxRef.current!.createScriptProcessor(4096, 1, 1);
            scriptProcessor.onaudioprocess = (e) => {
              const inputData = e.inputBuffer.getChannelData(0);
              const int16 = new Int16Array(inputData.length);
              for (let i = 0; i < inputData.length; i++) { int16[i] = inputData[i] * 32768; }
              const pcmBlob = { data: encode(new Uint8Array(int16.buffer)), mimeType: 'audio/pcm;rate=16000' };
              sessionPromise.then(s => s.sendRealtimeInput({ media: pcmBlob }));
            };
            source.connect(scriptProcessor);
            scriptProcessor.connect(inputAudioCtxRef.current!.destination);
          },
          onmessage: async (msg: LiveServerMessage) => {
            if (msg.serverContent?.inputTranscription) {
              const text = msg.serverContent.inputTranscription.text;
              setInputTranscript(prev => prev + text);
            }
            if (msg.serverContent?.outputTranscription) {
              const text = msg.serverContent.outputTranscription.text;
              setOutputTranscript(prev => prev + text);
            }
            if (msg.serverContent?.turnComplete) {
              if (inputTranscript) onMessageAdded('user', inputTranscript);
              if (outputTranscript) onMessageAdded('assistant', outputTranscript);
              setInputTranscript('');
              setOutputTranscript('');
            }
            if (msg.toolCall) {
              for (const fc of msg.toolCall.functionCalls) {
                const result = executeFunction(fc.name, fc.args);
                sessionPromise.then(s => s.sendToolResponse({
                  functionResponses: [{ id: fc.id, name: fc.name, response: { result } }]
                }));
              }
            }
            const audioData = msg.serverContent?.modelTurn?.parts[0]?.inlineData?.data;
            if (audioData && outputAudioCtxRef.current) {
              setStatus('speaking');
              const ctx = outputAudioCtxRef.current;
              nextStartTimeRef.current = Math.max(nextStartTimeRef.current, ctx.currentTime);
              const buffer = await decodeAudioData(decode(audioData), ctx, 24000, 1);
              const source = ctx.createBufferSource();
              source.buffer = buffer;
              source.connect(ctx.destination);
              source.addEventListener('ended', () => {
                activeSourcesRef.current.delete(source);
                if (activeSourcesRef.current.size === 0) setStatus('listening');
              });
              source.start(nextStartTimeRef.current);
              nextStartTimeRef.current += buffer.duration;
              activeSourcesRef.add(source);
            }
          },
          onerror: () => { setStatus('error'); setErrorMsg('Network link lost. Retrying protocol...'); onVoiceStateChange(false); },
          onclose: () => { setStatus('idle'); onVoiceStateChange(false); }
        }
      });
      sessionRef.current = await sessionPromise;
    } catch (err) {
      setStatus('error'); setErrorMsg('Vocal permissions denied.'); onVoiceStateChange(false);
    }
  };

  const stopSession = () => {
    if (sessionRef.current) sessionRef.current.close();
    if (streamRef.current) streamRef.current.getTracks().forEach(t => t.stop());
    setStatus('idle');
    onVoiceStateChange(false);
  };

  const isActive = status === 'listening' || status === 'speaking' || status === 'connecting';
  const particleColor = status === 'listening' ? '#22c55e' : status === 'speaking' ? '#3b82f6' : '#6366f1';

  return (
    <div className="fixed inset-0 bg-zinc-950/95 backdrop-blur-2xl z-[100] flex items-center justify-center">
      {/* Top Header Indicators */}
      <div className="absolute top-0 w-full p-8 flex justify-between items-start">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-3">
            <ShieldCheck size={14} className="text-blue-500" />
            <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest">Secure Uplink Established</span>
          </div>
          <div className="flex items-center gap-2">
            <Activity size={12} className={isActive ? 'text-green-500 animate-pulse' : 'text-zinc-600'} />
            <span className="text-[9px] font-medium text-zinc-400">Node Status: <span className="text-zinc-200 capitalize">{status}</span></span>
          </div>
        </div>
        <button 
          onClick={onClose} 
          className="p-3 bg-white/5 rounded-2xl hover:bg-white/10 transition-all border border-white/5 group"
        >
          <X size={20} className="text-zinc-400 group-hover:text-white transition-colors" />
        </button>
      </div>

      {/* Main Central Interaction Area */}
      <div className="relative flex flex-col items-center justify-center w-full max-w-2xl px-6">
        
        {/* Particle Emission Layer */}
        <EmittingParticles active={isActive} color={particleColor} />

        {/* Central Mic Button */}
        <div className="relative z-10 flex flex-col items-center">
          <div className={`relative p-1 rounded-full transition-all duration-700 ${
            isActive ? 'bg-gradient-to-br from-blue-500/20 to-indigo-600/20 shadow-[0_0_80px_rgba(59,130,246,0.2)]' : ''
          }`}>
            <button
              onClick={status === 'idle' ? startSession : stopSession}
              disabled={status === 'connecting'}
              className={`w-32 h-32 rounded-full flex items-center justify-center transition-all duration-500 relative overflow-hidden group ${
                isActive 
                  ? 'bg-zinc-900 border-2 border-white/20 core-active' 
                  : status === 'error' 
                    ? 'bg-red-500/10 border-2 border-red-500/20' 
                    : 'bg-zinc-900 border-2 border-white/10 hover:border-blue-500/40'
              }`}
            >
              {/* Internal Glow Effect */}
              {isActive && (
                <div className={`absolute inset-0 opacity-20 blur-2xl transition-colors ${
                  status === 'listening' ? 'bg-green-500' : 'bg-blue-500'
                }`} />
              )}
              
              <div className="relative z-20 transition-transform group-hover:scale-110">
                {status === 'connecting' ? (
                  <Zap size={40} className="text-indigo-400 animate-pulse" />
                ) : status === 'idle' ? (
                  <Mic size={40} className="text-zinc-400 group-hover:text-blue-400" />
                ) : status === 'error' ? (
                  <MicOff size={40} className="text-red-400" />
                ) : (
                  <Mic size={40} className={status === 'listening' ? 'text-green-400' : 'text-blue-400'} />
                )}
              </div>
            </button>
          </div>

          {/* Status Label */}
          <div className="mt-12 text-center space-y-2">
            <h3 className="text-sm font-bold text-white uppercase tracking-[0.3em] ml-[0.3em]">
              {status === 'idle' ? 'Ready to Assist' : status}
            </h3>
            <p className="text-[11px] text-zinc-500 font-medium max-w-xs leading-relaxed">
              {status === 'idle' 
                ? 'Tap the core to begin neural voice processing' 
                : status === 'listening' 
                  ? 'Input stream active. Speak your command.' 
                  : status === 'speaking'
                    ? 'Assistant is executing instructions...'
                    : errorMsg || 'Processing integration...'}
            </p>
          </div>
        </div>

        {/* Real-time Transcripts (Floating Bottom) */}
        {isActive && (
          <div className="absolute -bottom-40 w-full max-w-lg space-y-4 animate-in fade-in slide-in-from-bottom-8 duration-700">
            {inputTranscript && (
              <div className="bg-white/[0.03] border border-white/5 backdrop-blur-md rounded-2xl p-4 text-center">
                <span className="text-[9px] font-bold text-zinc-600 uppercase tracking-widest block mb-2">User Intent</span>
                <p className="text-sm text-zinc-300 italic">"{inputTranscript}"</p>
              </div>
            )}
            {outputTranscript && (
              <div className="bg-blue-500/[0.03] border border-blue-500/10 backdrop-blur-md rounded-2xl p-4 text-center">
                <span className="text-[9px] font-bold text-blue-500 uppercase tracking-widest block mb-2">Gemini Output</span>
                <p className="text-sm text-blue-100">{outputTranscript}</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Footer Branding */}
      <div className="absolute bottom-8 flex flex-col items-center gap-3">
        <div className="flex items-center gap-6 opacity-40">
           <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">Biometric Security</span>
           <div className="w-1 h-1 rounded-full bg-zinc-800"></div>
           <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">Neural Link 2.5</span>
           <div className="w-1 h-1 rounded-full bg-zinc-800"></div>
           <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">Spatial Sync</span>
        </div>
      </div>
    </div>
  );
};

export default VoiceInterface;

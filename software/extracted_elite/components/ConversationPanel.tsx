
import React, { useState, useRef } from 'react';
import { X, User, Bot, Clock, Volume2, Mic, Send, Loader2 } from 'lucide-react';
import { GoogleGenAI, Modality, Type } from '@google/genai';
import { ChatMessage } from '../types';

interface ConversationPanelProps {
  isOpen: boolean;
  messages: ChatMessage[];
  onClose: () => void;
  onSendMessage: (text: string) => void;
  isProcessing: boolean;
}

const ConversationPanel: React.FC<ConversationPanelProps> = ({ isOpen, messages, onClose, onSendMessage, isProcessing }) => {
  const [inputText, setInputText] = useState('');
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [playingId, setPlayingId] = useState<number | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);

  const handleSend = () => {
    if (!inputText.trim()) return;
    onSendMessage(inputText);
    setInputText('');
  };

  const startTranscription = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = [];

      mediaRecorder.ondataavailable = (e) => audioChunksRef.current.push(e.data);
      mediaRecorder.onstop = async () => {
        setIsTranscribing(true);
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
        const reader = new FileReader();
        reader.readAsDataURL(audioBlob);
        reader.onloadend = async () => {
          const base64Audio = (reader.result as string).split(',')[1];
          try {
            const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
            const response = await ai.models.generateContent({
              model: 'gemini-3-flash-preview',
              contents: [{
                parts: [
                  { inlineData: { mimeType: 'audio/webm', data: base64Audio } },
                  { text: "Transcribe the audio exactly." }
                ]
              }]
            });
            if (response.text) setInputText(response.text);
          } catch (err) {
            console.error("Transcription failed", err);
          } finally {
            setIsTranscribing(false);
          }
        };
      };

      mediaRecorder.start();
      setIsTranscribing(true);
      setTimeout(() => {
        mediaRecorder.stop();
        stream.getTracks().forEach(t => t.stop());
      }, 3000); // 3 seconds snippet
    } catch (err) {
      console.error("Mic access failed", err);
    }
  };

  const speakMessage = async (index: number, text: string) => {
    if (playingId === index) return;
    setPlayingId(index);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: "gemini-2.5-flash-preview-tts",
        contents: [{ parts: [{ text }] }],
        config: {
          responseModalities: [Modality.AUDIO],
          speechConfig: {
            voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Kore' } },
          },
        },
      });

      const base64Audio = response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
      if (base64Audio) {
        const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 24000 });
        const audioBuffer = await decodeAudioData(decode(base64Audio), audioCtx, 24000, 1);
        const source = audioCtx.createBufferSource();
        source.buffer = audioBuffer;
        source.connect(audioCtx.destination);
        source.onended = () => setPlayingId(null);
        source.start();
      }
    } catch (err) {
      console.error("TTS failed", err);
      setPlayingId(null);
    }
  };

  // Internal helper for TTS decoding
  function decode(base64: string) {
    const binaryString = atob(base64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) bytes[i] = binaryString.charCodeAt(i);
    return bytes;
  }
  async function decodeAudioData(data: Uint8Array, ctx: AudioContext, sampleRate: number, numChannels: number): Promise<AudioBuffer> {
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

  return (
    <div className={`absolute top-0 right-0 h-full w-80 sm:w-96 border-l border-white/10 bg-zinc-950/90 backdrop-blur-2xl z-30 transition-transform duration-500 ease-in-out transform shadow-2xl ${isOpen ? 'translate-x-0' : 'translate-x-full'}`}>
      <div className="h-full flex flex-col">
        <div className="p-6 border-b border-white/5 flex items-center justify-between">
          <div>
            <h2 className="text-sm font-bold text-white uppercase tracking-widest">Chat & Control</h2>
            <p className="text-[10px] text-zinc-500 font-medium mt-0.5">Fast Gemini Lite & TTS enabled</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-lg text-zinc-500"><X size={18} /></button>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-6 custom-scrollbar">
          {messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-center opacity-30">
              <Bot size={48} className="mb-4 text-zinc-500" />
              <p className="text-sm font-medium">Ready for your query</p>
            </div>
          ) : (
            messages.map((msg, i) => (
              <div key={i} className={`flex flex-col gap-2 ${msg.role === 'user' ? 'items-end' : 'items-start'}`}>
                <div className="flex items-center gap-2 px-1">
                  {msg.role === 'assistant' ? (
                    <div className="flex items-center gap-1.5">
                      <div className="p-1 rounded bg-blue-500/10 text-blue-400"><Bot size={10} /></div>
                      <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">System</span>
                      <button 
                        onClick={() => speakMessage(i, msg.text)}
                        className={`p-1 rounded hover:bg-white/5 transition-colors ${playingId === i ? 'text-blue-400 animate-pulse' : 'text-zinc-500'}`}
                      >
                        <Volume2 size={12} />
                      </button>
                    </div>
                  ) : (
                    <div className="flex items-center gap-1.5">
                      <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">You</span>
                      <div className="p-1 rounded bg-zinc-800 text-zinc-400"><User size={10} /></div>
                    </div>
                  )}
                </div>
                <div className={`max-w-[85%] px-4 py-3 rounded-2xl text-xs font-medium leading-relaxed ${msg.role === 'user' ? 'bg-zinc-800 text-zinc-100 rounded-tr-none' : 'bg-blue-600/10 text-blue-100 border border-blue-500/20 rounded-tl-none'}`}>
                  {msg.text}
                </div>
              </div>
            ))
          )}
          {isProcessing && <div className="flex items-center gap-2 text-zinc-500 text-[10px] animate-pulse"><Loader2 size={12} className="animate-spin" /> Gemini is thinking...</div>}
        </div>

        <div className="p-4 bg-zinc-950/50 border-t border-white/5 space-y-4">
          <div className="flex items-center gap-2 bg-zinc-900 rounded-xl p-2 border border-white/5 focus-within:border-blue-500/50 transition-colors">
            <button 
              onClick={startTranscription}
              disabled={isTranscribing}
              className={`p-2 rounded-lg transition-colors ${isTranscribing ? 'text-red-500 animate-pulse' : 'text-zinc-500 hover:text-white'}`}
            >
              <Mic size={18} />
            </button>
            <input 
              type="text" 
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSend()}
              placeholder="Type or speak..."
              className="flex-1 bg-transparent border-none text-xs focus:ring-0 text-white placeholder-zinc-600"
            />
            <button 
              onClick={handleSend}
              className="p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-500 transition-colors"
            >
              <Send size={16} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ConversationPanel;

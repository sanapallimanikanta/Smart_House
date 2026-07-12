
import React, { useState } from 'react';
import { X, Sparkles, Loader2, Save, Wand2 } from 'lucide-react';
import { GoogleGenAI } from '@google/genai';

interface ImageEditorProps {
  initialImage: string;
  onClose: () => void;
  onSave: (newImage: string) => void;
}

const ImageEditor: React.FC<ImageEditorProps> = ({ initialImage, onClose, onSave }) => {
  const [prompt, setPrompt] = useState('');
  const [currentImage, setCurrentImage] = useState(initialImage);
  const [isProcessing, setIsProcessing] = useState(false);

  const handleEdit = async () => {
    if (!prompt.trim()) return;
    setIsProcessing(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash-image',
        contents: {
          parts: [
            { inlineData: { data: currentImage.split(',')[1], mimeType: 'image/png' } },
            { text: prompt }
          ]
        }
      });

      for (const part of response.candidates[0].content.parts) {
        if (part.inlineData) {
          setCurrentImage(`data:image/png;base64,${part.inlineData.data}`);
          break;
        }
      }
    } catch (err) {
      console.error("Image edit failed", err);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-md z-[110] flex items-center justify-center p-4">
      <div className="bg-zinc-900 w-full max-w-4xl rounded-[32px] overflow-hidden border border-white/10 flex flex-col md:flex-row">
        <div className="flex-1 bg-black flex items-center justify-center p-8 relative min-h-[300px]">
          <img src={currentImage} alt="Editor" className="max-w-full max-h-[60vh] rounded-xl shadow-2xl" />
          <button onClick={onClose} className="absolute top-4 left-4 p-2 bg-zinc-800 rounded-full text-white/50 hover:text-white transition-colors">
            <X size={20} />
          </button>
        </div>
        
        <div className="w-full md:w-80 p-8 border-l border-white/5 space-y-8 flex flex-col">
          <div>
            <h3 className="text-xl font-bold flex items-center gap-2">
              <Sparkles className="text-blue-500" size={20} />
              AI Image Editor
            </h3>
            <p className="text-xs text-zinc-500 mt-1 uppercase font-bold tracking-widest">Nano Banana Powered</p>
          </div>

          <div className="space-y-4 flex-1">
            <div className="space-y-2">
              <label className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest">AI Prompt</label>
              <textarea 
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder="e.g. 'Add a retro film filter' or 'Make the room brighter'..."
                className="w-full h-32 bg-zinc-800/50 border border-white/5 rounded-2xl p-4 text-xs focus:ring-1 focus:ring-blue-500 text-white placeholder-zinc-600 resize-none"
              />
            </div>
            
            <button 
              onClick={handleEdit}
              disabled={isProcessing}
              className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-bold py-3 rounded-2xl transition-all flex items-center justify-center gap-2"
            >
              {isProcessing ? <Loader2 size={18} className="animate-spin" /> : <Wand2 size={18} />}
              Apply Nano Edit
            </button>
          </div>

          <button 
            onClick={() => onSave(currentImage)}
            className="w-full bg-white text-black font-bold py-3 rounded-2xl flex items-center justify-center gap-2 hover:bg-zinc-200 transition-colors"
          >
            <Save size={18} />
            Save Snapshot
          </button>
        </div>
      </div>
    </div>
  );
};

export default ImageEditor;

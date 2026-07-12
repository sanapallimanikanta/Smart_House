
export type DeviceType = 'light' | 'ac' | 'fan' | 'lock' | 'security' | 'blinds';

export interface Device {
  id: string;
  name: string;
  room: string;
  type: DeviceType;
  status: boolean;
  value?: number; // temperature or speed
  color?: string;
  imageUrl?: string; // For security cameras
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  text: string;
  timestamp: Date;
  audioData?: string; // Optional cached TTS
}

export interface HomeState {
  devices: Device[];
  isAway: boolean;
  activeLanguage: string;
}

export enum Language {
  EN = 'English',
  ES = 'Español',
  FR = 'Français',
  DE = 'Deutsch',
  JP = '日本語'
}

export const ROOMS = ['Living Room', 'Kitchen', 'Bedroom', 'Bathroom', 'Office'];

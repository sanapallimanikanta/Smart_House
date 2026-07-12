
import { Device } from './types';

export const initialDevices: Device[] = [
  { id: '1', name: 'Main Lights', room: 'Living Room', type: 'light', status: true },
  { id: '2', name: 'Ambient AC', room: 'Living Room', type: 'ac', status: true, value: 72 },
  { id: '3', name: 'Smart Fan', room: 'Bedroom', type: 'fan', status: false, value: 2 },
  { id: '4', name: 'Front Door', room: 'Kitchen', type: 'lock', status: true },
  { id: '5', name: 'Office Lamp', room: 'Office', type: 'light', status: false },
  { id: '6', name: 'Security Cam', room: 'Living Room', type: 'security', status: true },
  { id: '7', name: 'Kitchen AC', room: 'Kitchen', type: 'ac', status: false, value: 68 },
  { id: '8', name: 'Window Blinds', room: 'Bedroom', type: 'blinds', status: true },
];

import { Conversation, BusinessType } from './types';

// Helper to subtract hours
const subHours = (date: Date, hours: number) => {
  const newDate = new Date(date);
  newDate.setHours(newDate.getHours() - hours);
  return newDate;
};

export const DEFAULT_PRESET_MESSAGE = "Salut! Am observat că nu am mai vorbit de ieri. Mai ești interesat de ofertă?";

// Function to generate fresh mock data relative to "Now"
export const getMockConversations = (type: BusinessType = 'general'): Conversation[] => {
  const now = new Date();
  
  return [
    {
      id: 'fb_101',
      partnerName: 'Andrei Popescu',
      partnerAvatar: 'https://picsum.photos/id/101/200/200',
      partnerId: 'mock_pid_101',
      lastMessageTimestamp: subHours(now, 20), // 20 hours ago - TARGET for 18-23h
      status: 'active',
      lastSender: 'me',
      messages: [
        { id: 'm1', sender: 'partner', text: 'Bună ziua, mă interesează prețul pentru pachetul standard.', timestamp: subHours(now, 24) },
        { id: 'm2', sender: 'me', text: 'Salut Andrei! Pachetul standard costă 250 RON și include livrare gratuită.', timestamp: subHours(now, 20) }
      ]
    },
    {
      id: 'fb_102',
      partnerName: 'Maria Ionescu',
      partnerAvatar: 'https://picsum.photos/id/202/200/200',
      partnerId: 'mock_pid_102',
      lastMessageTimestamp: subHours(now, 2), // 2 hours ago - Active recently
      status: 'active',
      lastSender: 'me',
      messages: [
        { id: 'm3', sender: 'partner', text: 'Am plasat comanda #4451.', timestamp: subHours(now, 3) },
        { id: 'm4', sender: 'me', text: 'Mulțumim Maria! O pregătim chiar acum.', timestamp: subHours(now, 2) }
      ]
    },
    {
      id: 'fb_103',
      partnerName: 'Ion Georgescu',
      partnerAvatar: 'https://picsum.photos/id/303/200/200',
      partnerId: 'mock_pid_103',
      lastMessageTimestamp: subHours(now, 22), // 22 hours ago - TARGET
      status: 'active',
      lastSender: 'me',
      messages: [
        { id: 'm5', sender: 'partner', text: 'Aveți produsul și pe culoarea albastră?', timestamp: subHours(now, 26) },
        { id: 'm6', sender: 'me', text: 'Da, avem albastru pe stoc. Doriți să vă rezerv unul?', timestamp: subHours(now, 22) }
      ]
    },
    {
      id: 'fb_104',
      partnerName: 'Elena Dumitrescu',
      partnerAvatar: 'https://picsum.photos/id/404/200/200',
      partnerId: 'mock_pid_104',
      lastMessageTimestamp: subHours(now, 48), // 48 hours ago - Too old
      status: 'active',
      lastSender: 'me',
      messages: [
        { id: 'm7', sender: 'partner', text: 'Cât durează livrarea?', timestamp: subHours(now, 50) },
        { id: 'm8', sender: 'me', text: 'Livrarea durează 24-48 de ore lucrătoare.', timestamp: subHours(now, 48) }
      ]
    },
    {
      id: 'fb_105',
      partnerName: 'George Radu',
      partnerAvatar: 'https://picsum.photos/id/505/200/200',
      partnerId: 'mock_pid_105',
      lastMessageTimestamp: subHours(now, 19), // 19 hours ago - TARGET
      status: 'active',
      lastSender: 'me',
      messages: [
        { id: 'm9', sender: 'partner', text: 'Trimiteți factura pe email?', timestamp: subHours(now, 21) },
        { id: 'm10', sender: 'me', text: 'Sigur, v-am trimis factura pe adresa din cont.', timestamp: subHours(now, 19) }
      ]
    },
    {
      id: 'fb_106',
      partnerName: 'Ana Vasile',
      partnerAvatar: 'https://picsum.photos/id/606/200/200',
      partnerId: 'mock_pid_106',
      lastMessageTimestamp: subHours(now, 5), 
      status: 'active',
      lastSender: 'partner', // Last sender partner - No follow up needed
      messages: [
        { id: 'm11', sender: 'me', text: 'Comanda a plecat spre dvs.', timestamp: subHours(now, 6) },
        { id: 'm12', sender: 'partner', text: 'Super, mulțumesc mult pentru rapiditate!', timestamp: subHours(now, 5) }
      ]
    }
  ];
};
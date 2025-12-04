import { GoogleGenerativeAI } from "@google/generative-ai";
import { Message } from "@/types";

const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY;

const ai = new GoogleGenerativeAI(GEMINI_API_KEY || 'mock-key');

export const generateFollowUpMessage = async (
  partnerName: string,
  history: Message[]
): Promise<string> => {
  try {
    if (!GEMINI_API_KEY) {
      console.warn("API Key not found, using fallback mock response");
      return `Bună ${partnerName}, am vrut să mă asigur că ați primit ultimul meu mesaj. Vă pot ajuta cu alte informații?`;
    }

    const lastMessages = history.slice(-5).map(m => `${m.sender === 'me' ? 'Eu (Page)' : 'Client'}: ${m.text}`).join('\n');

    const prompt = `
      Ești un asistent politicos de suport clienți pe Facebook Messenger.
      Clientul nu a răspuns de aproximativ 20 de ore.
      
      Istoricul conversației:
      ${lastMessages}
      
      Sarcina:
      Generează un mesaj scurt, politicos și prietenos în limba română pentru a reactiva conversația.
      Nu fi agresiv. Întreabă dacă mai au nevoie de ajutor sau dacă au întrebări.
    `;

    const model = ai.getGenerativeModel({ model: "gemini-1.5-flash"});

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    return text.trim();
  } catch (error) {
    console.error("Error generating message:", error);
    return `Bună ${partnerName}, am vrut să mă asigur că totul este în regulă. Mai aveți întrebări?`;
  }
};

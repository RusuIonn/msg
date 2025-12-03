import { GoogleGenAI } from "@google/genai";
import { Message } from "../types";

const ai = new GoogleGenAI({ apiKey: process.env.API_KEY || 'mock-key' });

export const generateFollowUpMessage = async (
  partnerName: string,
  history: Message[]
): Promise<string> => {
  try {
    if (!process.env.API_KEY) {
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

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
    });

    return response.text.trim();
  } catch (error) {
    console.error("Error generating message:", error);
    return `Bună ${partnerName}, am vrut să mă asigur că totul este în regulă. Mai aveți întrebări?`;
  }
};
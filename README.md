<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://github.com/user-attachments/assets/0aa67016-6eaf-458a-adb2-6e31a0763ed6" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/drive/1K8ywpNsKRattHXpZBHDNOf2GJ6Dj3gJX

## Run Locally

**Prerequisites:**  Node.js


1. Install dependencies:
   `npm install`
2. Create a `.env` file in the root of the project and add your Gemini API key:
   `VITE_GEMINI_API_KEY=your_api_key`
3. Run the app:
   `npm run dev`

## Deploy to Vercel

1. Push your code to a GitHub repository.
2. Go to [Vercel](https://vercel.com) and create a new project.
3. Connect your GitHub repository.
4. In the "Environment Variables" section, add the following variable:
   - `VITE_GEMINI_API_KEY`: Your Gemini API key
5. Click "Deploy".

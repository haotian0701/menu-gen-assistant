# 🍽 Cookpilot

A Flutter + Supabase project that allows users to:

- Register and log in
- Upload images of food
- Store image links and metadata to a Supabase database

## ⚠️ Limitations

### Gemini API Rate Limits
The app uses Google's Gemini API models which have the following rate limitations:

- **Gemini 2.5 Pro**: 5 RPM (Requests Per Minute), 250,000 TPM (Tokens Per Minute), 100 RPD (Requests Per Day)
- **Gemini 2.5 Flash**: 10 RPM, 250,000 TPM, 250 RPD  
- **Gemini 2.5 Flash-Lite Preview**: 15 RPM, 250,000 TPM, 1,000 RPD

These rate limits may cause temporary delays or failures when multiple users are actively generating recipes simultaneously. Users may experience slower response times during peak usage periods.

### Netlify Free Tier Limitations
The app is deployed on Netlify's free tier which includes:

- **Bandwidth**: 100GB/month (Starter only; then $55 per 100GB)
- **Build minutes**: Limited monthly build time
- **Function invocations**: Limited serverless function calls
- **Form submissions**: Limited form handling capacity

Heavy usage may result in temporary service unavailability if these limits are exceeded.

# Presentation

Find our slide deck here:  
[View slides (PDF)](presentation_stuff/presentation.pdf)

## Sources:
- Gemini API
- Youtube
- Flutter
- Supabase
- Google Search API

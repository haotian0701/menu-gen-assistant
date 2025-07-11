# 🍽 Cookpilot

A Flutter + Supabase project that allows users to:

- Register and log in
- Upload images of food
- Store image links and metadata to a Supabase database

Find the hosted webapp here: https://cookpilot.xyz/

## Usage

- The main target device are mobile devices accessing the webapp through a browser.
- The website should also work for regular desktop devices but it is not targeted for them. 

## ⚠️ Limitations

### Gemini API Rate Limits
The app uses Google's Gemini API models which have the following rate limitations:

- **Gemini 2.5 Flash-Lite Preview 06-17**: 15 RPM, 250,000 TPM, 1,000 RPD -> Used for extracting labels and generating recipes.
- **Gemini 2.0 Flash Preview Image Generation**: 10 RPM, 200,000 TPM, 100 RPD -> Used for pre-view image dish generation.

RPM: Requests per Minute, TPM, Input Tokens per Minute, RPD: Requests per Day.

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

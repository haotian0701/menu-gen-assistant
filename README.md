# Cookpilot — AI Recipe Assistant

Cookpilot turns photos of ingredients into practical, personalized recipes. It combines image recognition, dietary preferences, cooking constraints, and generative AI in a responsive Flutter web app.

**Live app:** [cookpilot.netlify.app](https://cookpilot.netlify.app/)

## What Cookpilot does

- Detects ingredients from an uploaded food photo
- Lets users review and adjust detected ingredients
- Suggests three recipe ideas before generating the full recipe
- Adapts recipes to meal type, dietary goal, cooking time, serving size, cuisine, skill level, and available kitchen tools
- Provides a fitness-oriented mode with estimated nutrition information
- Supports email/password and GitHub authentication
- Saves recipe history, preferences, and bookmarked recipes for signed-in users
- Works on mobile and desktop browsers

## How it works

1. Upload or take a photo of ingredients.
2. Review the ingredients detected by Gemini.
3. Choose cooking preferences and dietary requirements.
4. Select one of the suggested dishes.
5. Receive a complete recipe with ingredients, instructions, and nutrition details.

## Technology

| Layer | Technology |
| --- | --- |
| Frontend | Flutter and Dart |
| Authentication | Supabase Auth |
| Database | Supabase Postgres |
| Image storage | Supabase Storage |
| Backend | Supabase Edge Functions |
| AI | Google Gemini 3.1 Flash-Lite |
| Hosting | Netlify |

Gemini is called only from the server-side Edge Function. The Gemini API key is never included in the Flutter web bundle. Optional AI-generated dish images are disabled by default to keep operating costs low.

## Run locally

Requirements:

- Flutter SDK
- A configured Supabase project
- A Supabase anonymous/public key

Create the local frontend configuration:

```powershell
cd frontend
Copy-Item config/dev.example.json config/dev.json
```

Fill in `config/dev.json` with your Supabase URL and anonymous/public key. Leave `OAUTH_REDIRECT_URL` empty to use the current browser origin automatically.

Then run:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/dev.json
```

The complete backend setup and deployment process is documented in [docs/MAINTENANCE.md](docs/MAINTENANCE.md).

## Project notes

- AI-generated recipes and nutrition estimates may contain mistakes and should be reviewed before use.
- Dietary and allergy requirements should always be verified independently.
- YouTube recommendations and external recipe images require optional API integrations and may be unavailable when those integrations are not configured.

## Presentation

A project presentation is available at [presentation_stuff/presentation.pdf](presentation_stuff/presentation.pdf).

---

Built as a personal project exploring multimodal AI, serverless backends, and cross-platform product development.

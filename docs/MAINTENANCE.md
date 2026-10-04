# Cookpilot maintenance guide

This document contains operational setup and deployment notes. Do not add API keys, access tokens, service-role keys, or other secrets to this repository.

## Backend setup

Create a Supabase project and authenticate the Supabase CLI:

```powershell
cd backend
npx supabase@latest login
npx supabase@latest link --project-ref YOUR_PROJECT_REF
npx supabase@latest db push
```

Create the local Edge Function environment file:

```powershell
Copy-Item supabase/.env.example supabase/.env
```

Set `GEMINI_API_KEY` in `backend/supabase/.env`. YouTube and Google Custom Search values are optional. The local `.env` file is ignored by Git.

Upload secrets and deploy the function:

```powershell
npx supabase@latest secrets set --env-file supabase/.env
npx supabase@latest functions deploy generate_recipe
```

The database migration creates the application tables, row-level security policies, and the `food-images` Storage bucket.

## Frontend configuration

Create a local configuration file:

```powershell
cd frontend
Copy-Item config/dev.example.json config/dev.json
```

Configure:

- `SUPABASE_URL`: the Supabase project URL
- `SUPABASE_ANON_KEY`: the project's anonymous/public browser key
- `OAUTH_REDIRECT_URL`: leave empty to use the current site origin

Never place `GEMINI_API_KEY` or the Supabase service-role key in a Flutter configuration file. Values compiled into a web application are visible to browser users.

## Authentication URLs

For local development, add this URL in Supabase Authentication → URL Configuration → Redirect URLs:

```text
http://localhost:3000/**
```

For production, set the Netlify URL as the Site URL and add it to Redirect URLs:

```text
https://YOUR_SITE.netlify.app/**
```

## Build the web app

```powershell
cd frontend
flutter pub get
flutter build web --release --dart-define-from-file=config/dev.json
```

The deployable output is `frontend/build/web`. Its root must directly contain `index.html`, `main.dart.js`, `assets`, and `icons`.

## Deploy to Netlify

For a manual deployment, open the existing Netlify project and upload the contents of `frontend/build/web` from the Deploys page.

If uploading a ZIP, verify that:

- `index.html` is at the ZIP root
- paths use forward slashes such as `assets/AssetManifest.bin.json`
- entries do not start with `./`
- there is no additional `web` directory surrounding the site files

The repository includes `frontend/web/_redirects`, which Flutter copies into future builds for Netlify single-page application routing.

After deployment, verify these URLs return their expected content rather than an HTML fallback:

```text
https://YOUR_SITE.netlify.app/
https://YOUR_SITE.netlify.app/manifest.json
https://YOUR_SITE.netlify.app/icons/Icon-192.png
https://YOUR_SITE.netlify.app/assets/AssetManifest.bin.json
```

## Model configuration and cost control

The Edge Function reads model names from Supabase secrets. Current defaults are listed in `backend/supabase/.env.example`.

- Text and vision use Gemini 3.1 Flash-Lite.
- AI dish-image generation is disabled by default with `ENABLE_AI_IMAGE_GENERATION=false`.
- Uploaded images or a static placeholder are used when generated imagery is disabled.

When changing models, update the local `.env`, upload the secrets again, and redeploy the Edge Function.

## Secret rotation

When rotating the Gemini key:

1. Replace `GEMINI_API_KEY` in the ignored local `backend/supabase/.env` file.
2. Run `npx supabase@latest secrets set --env-file supabase/.env` from `backend`.
3. Run an image-recognition and recipe-generation smoke test.

When rotating the Supabase anonymous/public key, update the ignored frontend config and rebuild the web application before redeploying it.

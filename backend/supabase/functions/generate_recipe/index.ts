// supabase/functions/generate_recipe/index.ts
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Gemini API key from environment
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_VISION_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" +
  GEMINI_API_KEY;
const GEMINI_TEXT_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" +
  GEMINI_API_KEY;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  if (!GEMINI_API_KEY) {
    return new Response(JSON.stringify({ error: "Missing Gemini API Key" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const { image_url, meal_type = "dinner", dietary_goal = "normal" } = body;

    // Step 1: Download image
    const imageResp = await fetch(image_url);
    if (!imageResp.ok) {
      return new Response("Failed to download image", {
        status: 400,
        headers: corsHeaders,
      });
    }

    const imageBlob = await imageResp.blob();
    const base64Image = await blobToBase64(imageBlob);

    // Step 2: Call Gemini Vision API
    const visionPayload = {
      contents: [
        {
          parts: [
            {
              text:
                "List the food items you see in this image in JSON format:\n{\"food_items\": [\"item1\", \"item2\"]}\nPlease ONLY return a valid JSON object with no extra text.",
            },
            {
              inlineData: { mimeType: imageBlob.type, data: base64Image },
            },
          ],
        },
      ],
    };

    const visionResp = await fetch(GEMINI_VISION_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(visionPayload),
    });

    if (!visionResp.ok) {
      const errorText = await visionResp.text();
      return new Response(
        JSON.stringify({ error: "Vision API error", detail: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const visionData = await visionResp.json();
    const visionText = visionData.candidates?.[0]?.content?.parts?.[0]?.text || "";
    const labels = extractLabelsFromJson(visionText);

    if (!labels || labels.length === 0) {
      return new Response(JSON.stringify({ error: "No food items detected." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Step 3: Call Gemini Text API for recipe
    const labelText = labels.join(", ");
    const recipePrompt =
      `I have the following ingredients: ${labelText}. ` +
      `My meal type is ${meal_type} and dietary goal is ${dietary_goal}. ` +
      `Please generate a full recipe including title, ingredients, steps, and estimated calories.`;

    const recipePayload = {
      contents: [
        {
          parts: [{ text: recipePrompt }],
        },
      ],
    };

    const recipeResp = await fetch(GEMINI_TEXT_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(recipePayload),
    });

    if (!recipeResp.ok) {
      const errorText = await recipeResp.text();
      return new Response(
        JSON.stringify({ error: "Recipe API error", detail: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const recipeData = await recipeResp.json();
    const recipe = recipeData.candidates?.[0]?.content?.parts?.[0]?.text || "";

    return new Response(JSON.stringify({ labels, recipe }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : JSON.stringify(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// Convert Blob to Base64 (safe for large files)
async function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const result = reader.result?.toString();
      const base64 = result?.split(",")[1];
      resolve(base64 || "");
    };
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

// Parse JSON with food_items from Gemini response
function extractLabelsFromJson(text: string): string[] {
  try {
    const match = text.match(/\{.*\}/s);
    if (!match) return [];
    const obj = JSON.parse(match[0]);
    return Array.isArray(obj.food_items) ? obj.food_items : [];
  } catch {
    return [];
  }
}

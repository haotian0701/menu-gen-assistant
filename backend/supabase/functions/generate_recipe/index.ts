import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

// Helper function to extract JSON safely from potential markdown code blocks
function extractLabelsFromJson(jsonString: string): { labels: string[], items: any[] } {
  try {
    // Remove potential markdown code block fences and trim whitespace
    const cleanedJsonString = jsonString.replace(/```json\n?/, '').replace(/```$/, '').trim();
    const data = JSON.parse(cleanedJsonString);
    const items = data.detected_items || [];
    // Extract labels just for logging or potential future use, but return full items
    const labels = items.map((item: any) => item?.item_label).filter((label: string | undefined) => label !== undefined);
    return { labels, items }; // Return both
  } catch (e) {
    console.error("Failed to parse JSON from Vision API:", e, "Raw text:", jsonString);
    return { labels: [], items: [] };
  }
}

// Retrieve API Key from environment variables (secrets)
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

// Define Gemini endpoints directly (without API key in URL)
const GEMINI_VISION_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
const GEMINI_TEXT_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

if (!GEMINI_API_KEY) {
  console.error("Missing GEMINI_API_KEY environment variable");
  // Optionally handle this case, e.g., by returning an error immediately in serve
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Check if required API Key environment variable is set
  if (!GEMINI_API_KEY) {
      return new Response(JSON.stringify({ error: "Server configuration error: Missing API key." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
  }

  try {
    const body = await req.json();
    // Provide default values and extract variables
    const { image_url, meal_type = "dinner", dietary_goal = "normal", mode, manual_labels } = body;

    if (!image_url) {
        return new Response(JSON.stringify({ error: "Missing 'image_url' in request body" }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    // Step 1: Download image
    const imageResp = await fetch(image_url);
    if (!imageResp.ok) {
      console.error(`Failed to download image from ${image_url}. Status: ${imageResp.status}`);
      return new Response(JSON.stringify({ error: "Failed to download image" }), {
        status: 400, // Or imageResp.status if you want to forward it
        headers: corsHeaders,
      });
    }
    const imageBlob = await imageResp.blob();

    // Convert Blob to Base64 using Deno compatible method
    const arrayBuffer = await imageBlob.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);
    let binaryString = '';
    uint8Array.forEach((byte) => {
      binaryString += String.fromCharCode(byte);
    });
    const base64Image = btoa(binaryString);

    let items: any[] = []; // Keep the full item structure

    // Step 2: Handle detection or manual input
    if (manual_labels && Array.isArray(manual_labels) && manual_labels.length > 0) {
      console.log("Using manual labels provided.");
      // Keep the full structure from manual_labels
      items = manual_labels.map((item: any) => ({
        item_label: item?.item_label,
        additional_info: item?.additional_info, // Keep additional info
        bounding_box: item?.bounding_box // Keep bounding box if needed later
      })).filter((item: any) => item.item_label); // Filter out items without a label
    } else {
      console.log("No manual labels provided or empty, using Vision API.");
      const visionPayload = {
        contents: [
          {
            parts: [
              {
                text: `Input: An image containing one or more grocery items.

Instructions:
1. Detect Grocery Items: Identify all distinct grocery items visible in the image.
2. Classify Items: For each detected item, provide a general classification label (e.g., "Apple", "Milk Carton").
3. Determine Bounding Boxes: Provide bounding box coordinates in normalized format (x_min, y_min, x_max, y_max).
4. Output Format: Return results in valid JSON, no extra text.

{
  "detected_items": [
    {
      "item_label": "string",
      "bounding_box": {
        "x_min": float,
        "y_min": float,
        "x_max": float,
        "y_max": float
      },
      "extracted_text": "string | null"
    }
  ]
}
                `.trim(),
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
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY,
        },
        body: JSON.stringify(visionPayload),
      });

      if (!visionResp.ok) {
        const errorText = await visionResp.text();
        console.error("Vision API error:", errorText);
        return new Response(
          JSON.stringify({ error: "Vision API error", detail: errorText }),
          { status: visionResp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const visionData = await visionResp.json();
      // Safely access nested properties
      const visionText = visionData?.candidates?.[0]?.content?.parts?.[0]?.text || "";
      if (!visionText) {
          console.warn("Vision API returned empty text content.");
      }
      // extractLabelsFromJson now returns { labels: string[], items: any[] }
      // We only need the 'items' part here as it contains the full structure
      const parsed = extractLabelsFromJson(visionText);
      items = parsed.items; // Use the items array directly
      console.log(`Detected items: ${items.map(i => i.item_label).join(', ')}`);
    }

    // Optional exit if only extraction was requested
    if (mode === 'extract_only') {
      console.log("Mode is 'extract_only', returning detected items.");
      // Return the full items array
      return new Response(JSON.stringify({ items }), { // Return items array
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Step 3: Generate recipe using Gemini (only if items were found)
    if (items.length === 0) {
        console.log("No items found (either from manual input or Vision API), cannot generate recipe.");
         return new Response(JSON.stringify({ items, recipe: "Could not generate recipe: No ingredients identified." }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    // Construct the ingredient list string including additional info
    const ingredientText = items.map(item => {
      let text = item.item_label;
      if (item.additional_info) {
        text += ` (${item.additional_info})`; // Add additional info in parentheses
      }
      return text;
    }).join(", ");

    console.log(`Generating recipe for: ${ingredientText}, Meal: ${meal_type}, Goal: ${dietary_goal}`);
    const manualNote = (manual_labels && Array.isArray(manual_labels) && manual_labels.length > 0) ? "<p><i>Note: Some labels or details might have been adjusted manually by the user.</i></p>" : ""; // Format note as HTML paragraph

    const recipePrompt =
      `Generate a recipe based on these details:
- **Ingredients Available:** ${ingredientText}
- **Meal Type:** ${meal_type}
- **Dietary Goal:** ${dietary_goal}

**Output Format Instructions:**
Format the entire response as a single block of HTML. Do NOT include \`\`\`html markdown fences.
Use the following structure:
- **Main Title:** Use an \`<h1>\` tag.
- **Sections (e.g., "Ingredients", "Instructions", "Estimated Calories"):** Use \`<h2>\` tags.
- **Ingredients List:** Use an unordered list (\`<ul>\` with \`<li>\` items). Include any provided details (like amounts) within the list items.
- **Instructions:** Use an ordered list (\`<ol>\` with \`<li>\` items).
- **Estimated Calories/Notes:** Use a paragraph tag (\`<p>\`). If providing a numeric calorie estimate, make it clear (e.g., \`<p>Estimated Calories: 650</p>\`).
${manualNote}

Start the HTML directly with the \`<h1>\` title.`;

    const recipePayload = {
      contents: [
        {
          parts: [{ text: recipePrompt }],
        },
      ],
      // Add safety settings or generation config if needed
      // generationConfig: { temperature: 0.7 }, // Example
      // safetySettings: [ ... ],
    };

    const recipeResp = await fetch(GEMINI_TEXT_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
       },
      body: JSON.stringify(recipePayload),
    });

    if (!recipeResp.ok) {
      const errorText = await recipeResp.text();
      console.error("Recipe API error:", errorText);
      return new Response(
        JSON.stringify({ error: "Recipe generation API error", detail: errorText }),
        { status: recipeResp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const recipeData = await recipeResp.json();
    const recipeHtml = recipeData?.candidates?.[0]?.content?.parts?.[0]?.text || "<p>Error: Could not generate recipe content.</p>"; // Default to HTML paragraph on error

    console.log("Recipe HTML generated successfully.");
    // Return the full items array along with the recipe HTML
    return new Response(JSON.stringify({ items, recipe: recipeHtml }), { // Return recipeHtml
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Unhandled error in Edge Function:", error);
    return new Response(JSON.stringify({ error: error.message || "An internal server error occurred." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

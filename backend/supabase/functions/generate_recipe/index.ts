// functions/generate_recipe.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
// === Added: helper + fallback for main image URL validation ===
const FALLBACK_IMAGE_URL = "https://via.placeholder.com/640x480.png?text=Recipe+Image";
async function validateImageUrl(url) {
  try {
    const u = new URL(url);
    // enforce https only (mixed-content issues on web)
    if (u.protocol !== "https:") return null;
    // Fast-path: has common image extension
    if (/\.(png|jpe?g|gif|webp)$/i.test(u.pathname)) {
      return url;
    }
    // Otherwise, do a HEAD request to ensure the resource is actually an image
    try {
      const headResp = await fetch(url, {
        method: "HEAD"
      });
      if (headResp.ok) {
        const ct = headResp.headers.get("content-type") || "";
        if (ct.startsWith("image/")) {
          return url;
        }
      }
    } catch (_) {
    // ignore network errors, we'll fall through to null
    }
  } catch  {
  // Malformed URL
  }
  return null;
}
function extractRecipeTitle(html) {
  const m = html.match(/<h1[^>]*>(.*?)<\/h1>/i);
  return m ? m[1].trim() : 'Recipe';
}
// Helper function to extract JSON safely from potential markdown code blocks
function extractLabelsFromJson(jsonString) {
  try {
    // Remove potential markdown code block fences and trim whitespace
    const cleanedJsonString = jsonString.replace(/```json\n?/, "").replace(/```$/, "").trim();
    const data = JSON.parse(cleanedJsonString);
    const items = data.detected_items || [];
    // Extract labels just for logging or potential future use, but return full items
    const labels = items.map((item)=>item?.item_label).filter((label)=>label !== undefined);
    return {
      labels,
      items
    }; // Return both
  } catch (e) {
    console.error("Failed to parse JSON from Vision API:", e, "Raw text:", jsonString);
    return {
      labels: [],
      items: []
    };
  }
}
// Helper to clean Gemini's JSON output for candidate list
function cleanGeminiJsonResponse(rawText) {
  return rawText.replace(/```json\n?/, '').replace(/```$/, '').trim();
}
// Environment variables
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY");
const GOOGLE_SEARCH_API_KEY = Deno.env.get("GOOGLE_SEARCH_API_KEY");
const GOOGLE_SEARCH_CX = Deno.env.get("GOOGLE_SEARCH_CX");
const GEMINI_VISION_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
const GEMINI_TEXT_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
const YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search";
if (!GEMINI_API_KEY) {
  console.error("Missing GEMINI_API_KEY environment variable");
}
if (!YOUTUBE_API_KEY) {
  console.warn("Missing YOUTUBE_API_KEY — video links will be omitted");
}
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  // Validate API key
  if (!GEMINI_API_KEY) {
    return new Response(JSON.stringify({
      error: "Server configuration error: Missing GEMINI_API_KEY."
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  try {
    const body = await req.json();
    // Ensure all relevant fields from the body are destructured
    const { user_id, image_url, meal_type = "dinner", dietary_goal = "normal", mode, manual_labels, restrict_diet, amount_people, meal_time, selected_title, stage } = body;
    if (!image_url && !(manual_labels && manual_labels.length > 0 && mode === 'extract_only')) {
      if (!image_url) {
        return new Response(JSON.stringify({
          error: "Missing 'image_url' in request body"
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
    }
    let sourceItems = []; // Raw items before grouping
    if (manual_labels && Array.isArray(manual_labels) && manual_labels.length > 0) {
      console.log("Using manual labels as source.");
      sourceItems = manual_labels.map((i)=>({
          item_label: i?.item_label,
          additional_info: i?.additional_info,
          bounding_box: i?.bounding_box,
          // If manual labels come with a quantity, it's treated as the count for that specific entry.
          // The grouping logic below will sum these up if multiple entries have the same item_label.
          _source_quantity: typeof i?.quantity === 'number' ? i.quantity : 1
        })).filter((i)=>i.item_label);
    } else if (image_url) {
      // Step 1: Download image
      const imageResp = await fetch(image_url);
      if (!imageResp.ok) {
        console.error(`Failed to download image: ${imageResp.status}`);
        return new Response(JSON.stringify({
          error: "Failed to download image"
        }), {
          status: 400,
          headers: corsHeaders
        });
      }
      const imageBlob = await imageResp.blob();
      const arrayBuffer = await imageBlob.arrayBuffer();
      const uint8Array = new Uint8Array(arrayBuffer);
      let binaryString = "";
      uint8Array.forEach((b)=>binaryString += String.fromCharCode(b));
      const base64Image = btoa(binaryString);
      console.log("No manual labels or image_url provided for non-extraction mode — calling Vision API.");
      const visionPayload = {
        contents: [
          {
            parts: [
              {
                text: `Input: An image containing one or more grocery items.

Instructions:
1. Detect Grocery Items: Identify all distinct **edible** grocery items visible in the image. **Only include items that are clearly identifiable as food.** Ignore any non-food items or objects whose edibility is ambiguous. For items that appear in multiples (e.g., a pack of buns, several tomatoes), attempt to count the individual units if visually discernible and include this as 'quantity'. If it's a single item, quantity is 1.
2. Classify Items: For each detected item, provide a general classification label (e.g., "Apple", "Milk", "Bread Rolls"). Don't include information about the packaging, e.g. Milk carton, or Mayonnaise jar. We are interested in the item itself, not the container.
3. Determine Bounding Boxes: Provide bounding box coordinates in normalized format (x_min, y_min, x_max, y_max) for each identified item or group. If quantity > 1 for a single bounding box, this box should encompass the group.
4. Output Format: Return results in valid JSON, no extra text. Ensure 'quantity' is an integer. If no edible grocery items are confidently detected, return an empty "detected_items" array.

{
  "detected_items": [
    {
      "item_label": "string",
      "quantity": integer, // Added quantity here
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
`.trim()
              },
              {
                inlineData: {
                  mimeType: imageBlob.type,
                  data: base64Image
                }
              }
            ]
          }
        ]
      };
      const visionResp = await fetch(GEMINI_VISION_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY
        },
        body: JSON.stringify(visionPayload)
      });
      if (!visionResp.ok) {
        const errText = await visionResp.text();
        console.error("Vision API error:", errText);
        return new Response(JSON.stringify({
          error: "Vision API error",
          detail: errText
        }), {
          status: visionResp.status,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
      const visionData = await visionResp.json();
      const visionText = visionData?.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const parsedVisionItems = extractLabelsFromJson(visionText).items;
      sourceItems = parsedVisionItems.map((item)=>({
          ...item,
          _source_quantity: typeof item.quantity === 'number' && item.quantity > 0 ? item.quantity : 1
        })); // Use quantity from Vision if available
      console.log("Raw detected items from Vision API:", sourceItems.map((i)=>`${i._source_quantity} ${i.item_label}`).join(", "));
    } else {
      // Should not happen if checks above are correct, but as a fallback
      return new Response(JSON.stringify({
        error: "Missing 'image_url' or 'manual_labels' in request body"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // **** GROUPING AND QUANTIFICATION STEP (applies to all sources) ****
    const labelMap = new Map();
    for (const item of sourceItems){
      const label = item.item_label;
      // Use a combination of label and additional_info for more precise grouping if needed,
      // or just label if additional_info is highly variable or less critical for grouping.
      // For now, grouping by item_label only.
      const groupKey = label; // Potentially: `${label}_${item.additional_info || ''}`;
      const itemSourceQuantity = item._source_quantity || 1;
      if (labelMap.has(groupKey)) {
        const existing = labelMap.get(groupKey);
        existing.totalQuantity += itemSourceQuantity;
      // Decide on merging strategy for additional_info or bounding_box if necessary.
      // Default: keep first item's details.
      } else {
        // Create a new object for the map, removing _source_quantity
        const { _source_quantity, ...representativeItemDetails } = item;
        labelMap.set(groupKey, {
          representativeItem: representativeItemDetails,
          totalQuantity: itemSourceQuantity
        });
      }
    }
    let items = Array.from(labelMap.values()).map((group)=>({
        ...group.representativeItem,
        quantity: group.totalQuantity // This is the final, summed quantity
      }));
    console.log("Processed items (after grouping):", items.map((i)=>`${i.quantity} ${i.item_label}${i.additional_info ? ' (' + i.additional_info + ')' : ''}`).join(", "));
    // If only extraction requested
    if (mode === "extract_only") {
      return new Response(JSON.stringify({
        items
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // If no items, return early
    if (items.length === 0) {
      return new Response(JSON.stringify({
        items,
        recipe: "<p>Could not generate recipe: No ingredients were identified. Please try a different image or add items manually.</p>" // Enhanced message
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Build ingredient text
    const QUANTITY_DISPLAY_CUTOFF = 10;
    const ingredientText = items.map((i) => {
      let txt = "";

      if (i.quantity > 1 && i.quantity <= QUANTITY_DISPLAY_CUTOFF) {
        txt += `${i.quantity} `;
      }

      txt += i.item_label;

      if (i.additional_info) txt += ` (${i.additional_info})`;

      return txt;
    }).join(", ");
    //STAGE: CANDIDATES
    if (stage === 'candidates') {
      // 1. Prompt Gemini
      const candidatesPrompt = `
    Given these available ingredients: ${ingredientText}
    - Meal Type: ${meal_type}
    - Dietary Goal: ${dietary_goal}
    - People Eating: ${amount_people || 'not specified'}
    - Preferred Cooking Time: ${meal_time || 'not specified'}
    ${restrict_diet && restrict_diet.trim() !== "" ? `- Strict Dietary Restriction: ${restrict_diet}` : ''}

    Suggest 3 possible recipe candidates.
    For each, only return:
    - title: a plausible dish name in English
    - description: one sentence description of the dish, suitable for a preview list

    Return ONLY valid JSON array of objects, e.g.:
    [
      {"title": "...", "description": "..."},
      ...
    ]
    `.trim();
      const candidateResp = await fetch(GEMINI_TEXT_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: candidatesPrompt
                }
              ]
            }
          ]
        })
      });
      if (!candidateResp.ok) {
        const errText = await candidateResp.text();
        return new Response(JSON.stringify({
          error: "Candidate recipe generation failed",
          detail: errText
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
      const candidateData = await candidateResp.json();
      let candidateList = [];
      try {
        const rawText = candidateData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";
        const cleanedText = cleanGeminiJsonResponse(rawText);
        candidateList = JSON.parse(cleanedText);
        console.log("Gemini candidate response raw text:", rawText);
        console.log("CandidateList after JSON parse:", candidateList);
      } catch (e) {
        console.error("Failed to parse Gemini candidate list:", e);
        candidateList = [];
      }
      // search photo for every candidate
      let enrichedCandidates = [];
      for (const c of candidateList){
        let image_url = null;
        if (GOOGLE_SEARCH_API_KEY && GOOGLE_SEARCH_CX && c.title) {
          try {
            const enhancedQuery = `${c.title} recipe`;
            const imgResp = await fetch(`https://www.googleapis.com/customsearch/v1?key=${GOOGLE_SEARCH_API_KEY}&cx=${GOOGLE_SEARCH_CX}&q=${encodeURIComponent(enhancedQuery)}&searchType=image&num=1`);
            if (imgResp.ok) {
              const imgData = await imgResp.json();
              const rawUrl = imgData.items?.[0]?.link;
              if (rawUrl) {
                let validated = await validateImageUrl(rawUrl);
                if (!validated && rawUrl.startsWith("http://")) {
                  // Try HTTPS fallback
                  validated = await validateImageUrl(rawUrl.replace(/^http:/, "https:"));
                }
                image_url = validated;
              }
              if (!image_url) {
                image_url = FALLBACK_IMAGE_URL;
              }
            }
          } catch (e) {
            console.warn("Image search error for:", c.title, e);
          }
        }
        enrichedCandidates.push({
          ...c,
          image_url
        });
      }
      return new Response(JSON.stringify({
        candidates: enrichedCandidates
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const manualNote = manual_labels && Array.isArray(manual_labels) && manual_labels.length > 0 ? "<p><i>Note: Some labels might have been adjusted manually.</i></p>" : "";
    let restrictionHandlingInstructions = "";
    if (restrict_diet && restrict_diet.trim() !== "") {
      restrictionHandlingInstructions = `
**Dietary Restriction Handling:**
- The specified dietary restriction is: **${restrict_diet}**.
- Review the "Ingredients Available".
- If any ingredient directly conflicts with this restriction (e.g., "Bacon" for "vegan", "Pork" for "vegetarian", "Wheat Bread" for "gluten-free"):
    - List the conflicting ingredient in the "Ingredients" section (e.g., in an <ul><li> structure).
    - Append a clear note *directly next to this ingredient in the list*, for example: " (excluded: conflicts with ${restrict_diet} restriction)".
    - **Crucially, DO NOT include this conflicting ingredient in the actual recipe "Instructions" (<ol><li>) or assume it's used in the meal preparation.** Base the recipe steps *only* on the usable, non-conflicting ingredients.
- All other non-conflicting ingredients should be used to create the recipe as usual.
- If ALL listed "Ingredients Available" conflict with the restriction, the "Instructions" section should clearly state that a recipe cannot be generated that adheres to the restriction with the provided items. The "Ingredients" section should still list all items with their conflict notes.
`;
    } else {
      restrictionHandlingInstructions = `
**Dietary Restriction Handling:**
- No specific dietary restrictions were provided. Prepare the recipe using all available ingredients as appropriate.
`;
    }
    const recipePrompt = `Generate a recipe based on these details:
- **Title (If provided, use as recipe title):** ${selected_title || ''}
- **Ingredients Available:** ${ingredientText}
- **Meal Type:** ${meal_type}
- **Dietary Goal:** ${dietary_goal}
- **People Eating:** ${amount_people || 'not specified'}
- **Preferred Cooking Time:** ${meal_time || 'not specified'}
${restrict_diet && restrict_diet.trim() !== "" ? `- **Strict Dietary Restriction to follow:** ${restrict_diet}` : ''}

**Output Format Instructions:**
Format the entire response as a single block of valid HTML. Do NOT include \`\`\`html fences or any text outside the HTML structure.
The HTML should include:
- <h1> for the recipe title.
- <h2> for main sections like "Ingredients", "Instructions", "Notes" (if any).
- For "Ingredients": Use <ul> and <li> for each ingredient. Include quantities as provided in "Ingredients Available".
- For "Instructions": Use <ol> and <li> for each step.
- <p> can be used for general notes, estimated calories, or descriptions.

**Recipe Generation Rules:**
1.  **Sensibility Check:** Create a coherent and sensible recipe.
2.  **Ingredient Viability:**
    *   After applying any "Strict Dietary Restriction", if fewer than two distinct usable ingredients remain, or if the remaining ingredients cannot logically form a meal for the specified "Meal Type", then DO NOT generate a recipe. Instead, output a single HTML paragraph: \`<p>A meaningful recipe cannot be generated with the available ingredients, especially after considering the dietary restrictions. Please adjust the ingredients or restrictions.</p>\`
    *   If all "Ingredients Available" conflict with the "Strict Dietary Restriction", also use the message above.
3.  **Quantity Consideration:** Pay attention to the "People Eating" when suggesting ingredient amounts in the "Instructions", if appropriate for the recipe.
${manualNote}

${restrictionHandlingInstructions}

Start directly with the <h1> title. Ensure the entire output is valid HTML.`;
    // Call Gemini Text API
    const recipeResp = await fetch(GEMINI_TEXT_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text: recipePrompt
              }
            ]
          }
        ]
      })
    });
    if (!recipeResp.ok) {
      const errText = await recipeResp.text();
      console.error("Recipe API error:", errText);
      return new Response(JSON.stringify({
        error: "Recipe generation API error",
        detail: errText
      }), {
        status: recipeResp.status,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const recipeData = await recipeResp.json();
    const recipeHtml = recipeData?.candidates?.[0]?.content?.parts?.[0]?.text || "<p>Error: Could not generate recipe content.</p>";
    // ====== YouTube Video Search Integration ======
    // Helper to extract the dish title from <h1>
    function extractTitle(html) {
      const m = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
      return m ? m[1].trim() : "";
    }
    const dishTitle = extractTitle(recipeHtml);
    let video_url = null;
    if (YOUTUBE_API_KEY && dishTitle) {
      try {
        const ytResp = await fetch(`${YOUTUBE_SEARCH_URL}?part=snippet&type=video&maxResults=1` + `&q=${encodeURIComponent(dishTitle)}` + `&key=${YOUTUBE_API_KEY}`);
        if (ytResp.ok) {
          const ytData = await ytResp.json();
          const vid = ytData.items?.[0]?.id?.videoId;
          if (vid) {
            video_url = `https://www.youtube.com/watch?v=${vid}`;
            console.log("YouTube video URL:", video_url);
          }
        } else {
          console.warn("YouTube API search failed:", await ytResp.text());
        }
      } catch (ytErr) {
        console.warn("YouTube API error:", ytErr);
      }
    }
    // ============ Google Image Search Integration ============
    let main_image_url = null;
    if (GOOGLE_SEARCH_API_KEY && GOOGLE_SEARCH_CX && dishTitle) {
      try {
        const imgResp = await fetch(`https://www.googleapis.com/customsearch/v1?key=${GOOGLE_SEARCH_API_KEY}&cx=${GOOGLE_SEARCH_CX}&q=${encodeURIComponent(dishTitle)}&searchType=image&num=1`);
        if (imgResp.ok) {
          const imgData = await imgResp.json();
          const imgUrl = imgData.items?.[0]?.link;
          let candidateUrl = null;
          if (imgUrl) {
            candidateUrl = await validateImageUrl(imgUrl);
            if (!candidateUrl && imgUrl.startsWith("http://")) {
              const httpsVersion = imgUrl.replace(/^http:/, "https:");
              candidateUrl = await validateImageUrl(httpsVersion);
            }
          }
          main_image_url = candidateUrl ?? null;
          console.log("Main image URL (validated)", main_image_url ?? "<none>");
        } else {
          console.warn("Google Image API search failed:", await imgResp.text());
        }
      } catch (imgErr) {
        console.warn("Google Image Search error:", imgErr);
      }
    }
    // ================================================
    const categories = [];
    if (meal_type && meal_type.toLowerCase() !== 'normal') {
      categories.push(meal_type);
    }
    if (dietary_goal && dietary_goal.toLowerCase() !== 'normal') {
      categories.push(dietary_goal);
    }
    if (restrict_diet && restrict_diet.toLowerCase() !== 'none') {
      categories.push(restrict_diet);
    }
    const recipeTitle = extractRecipeTitle(recipeHtml);
    const { data, error } = await supabase.from('history').insert({
      user_id,
      image_url,
      recipe_html: recipeHtml,
      recipe_title: recipeTitle,
      main_image_url,
      video_url,
      meal_type,
      dietary_goal,
      meal_time,
      amount_people,
      restrict_diet,
      detected_items: items,
      tags: categories
    });
    // Ensure we always have some image URL to send back 
    if (!main_image_url) {
      main_image_url = FALLBACK_IMAGE_URL;
    }
    return new Response(JSON.stringify({
      items,
      recipe: recipeHtml,
      video_url,
      categories,
      main_image_url
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Unhandled error in Edge Function:", error);
    return new Response(JSON.stringify({
      error: error.message || "An internal server error occurred."
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});

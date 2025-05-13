// functions/generate_recipe.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
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
// Environment variables
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY");
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
    const { image_url, meal_type = "dinner", dietary_goal = "normal", mode, manual_labels } = body;
    if (!image_url && !(manual_labels && manual_labels.length > 0 && mode === 'extract_only')) { // Allow extract_only with manual_labels without image_url
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
1. Detect Grocery Items: Identify all distinct grocery items visible in the image. For items that appear in multiples (e.g., a pack of buns, several tomatoes), attempt to count the individual units if visually discernible and include this as 'quantity'. If it's a single item, quantity is 1.
2. Classify Items: For each detected item, provide a general classification label (e.g., "Apple", "Milk", "Bread Rolls"). Don't include information about the packaging, e.g. Milk carton, or Mayonnaise jar. We are interested in the item itself, not the container.
3. Determine Bounding Boxes: Provide bounding box coordinates in normalized format (x_min, y_min, x_max, y_max) for each identified item or group. If quantity > 1 for a single bounding box, this box should encompass the group.
4. Output Format: Return results in valid JSON, no extra text. Ensure 'quantity' is an integer.

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
      sourceItems = parsedVisionItems.map(item => ({ ...item, _source_quantity: typeof item.quantity === 'number' && item.quantity > 0 ? item.quantity : 1 })); // Use quantity from Vision if available
      console.log("Raw detected items from Vision API:", sourceItems.map(i => `${i._source_quantity} ${i.item_label}`).join(", "));
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
    for (const item of sourceItems) {
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
                representativeItem: representativeItemDetails, // This includes bounding_box, additional_info
                totalQuantity: itemSourceQuantity
            });
        }
    }

    let items = Array.from(labelMap.values()).map(group => ({
        ...group.representativeItem,
        quantity: group.totalQuantity // This is the final, summed quantity
    }));

    console.log("Processed items (after grouping):", items.map(i => `${i.quantity} ${i.item_label}${i.additional_info ? ' (' + i.additional_info + ')' : ''}`).join(", "));
    
    // If only extraction requested
    if (mode === "extract_only") {
      return new Response(JSON.stringify({
        items // items now include quantity
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
        items, // items is an empty array
        recipe: "Could not generate recipe: No ingredients identified."
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Build ingredient text
    const ingredientText = items.map((i)=>{
      let txt = `${i.quantity > 1 ? i.quantity + " " : ""}${i.item_label}`;
      if (i.additional_info) txt += ` (${i.additional_info})`;
      return txt;
    }).join(", ");
    const manualNote = manual_labels && Array.isArray(manual_labels) && manual_labels.length > 0 ? "<p><i>Note: Some labels might have been adjusted manually.</i></p>" : "";
    const recipePrompt = `Generate a recipe based on these details:
- **Ingredients Available:** ${ingredientText}
- **Meal Type:** ${meal_type}
- **Dietary Goal:** ${dietary_goal}
- **Restriction:** ${restrict_diet}
- **People Eating:** ${amount_people}
- **Cooking Time:** ${meal_time}


**Output Format Instructions:**
Format the entire response as a single block of HTML. Do NOT include \`\`\`html fences.
Use:
- <h1> for title
- <h2> for sections ("Ingredients", "Instructions", etc.)
- <ul>/<li> for ingredient list
- <ol>/<li> for steps
- <p> for notes/calories
${manualNote}

Start directly with the <h1> title.`;
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
    // ================================================
    // Final response
    return new Response(JSON.stringify({
      items,
      recipe: recipeHtml,
      video_url
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

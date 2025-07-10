// functions/generate_recipe.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js';
import sanitizeHtml from "npm:sanitize-html";
// Simple in-memory throttle: IP ➜ last request timestamp
const lastRequestMap = new Map();
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
// === Added: helper + fallback for main image URL validation ===
const FALLBACK_IMAGE_URL = "https://via.placeholder.com/640x480.png?text=Recipe+Image";
// Maximum image size we allow to download (bytes)
const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB
function isPrivateIp(hostname) {
  // Reject obvious private IPv4 ranges. This is a heuristic; tighten if needed.
  const m = hostname.match(/^(\d{1,3}\.){3}\d{1,3}$/);
  if (!m) return false;
  const parts = hostname.split(".").map(Number);
  const [a, b] = parts;
  return a === 10 || a === 172 && b >= 16 && b <= 31 || a === 192 && b === 168;
}
async function validateImageUrl(url) {
  try {
    const u = new URL(url);
    if (u.protocol !== "https:") return null; // HTTPS only
    if (isPrivateIp(u.hostname)) return null; // prevent SSRF
    // HEAD request to verify type & size
    try {
      const headResp = await fetch(url, {
        method: "HEAD"
      });
      if (!headResp.ok) return null;
      const ct = headResp.headers.get("content-type") || "";
      if (!ct.startsWith("image/")) return null;
      const len = Number(headResp.headers.get("content-length"));
      if (len && len > MAX_IMAGE_BYTES) return null;
    } catch (_) {
      return null;
    }
    return url;
  } catch  {
    return null;
  }
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
// Helper to extract nutrition info
function extractNutritionInfo(html: string) {
  const info = { calories: 0, protein: 0, carbs: 0, fat: 0 };
  const patterns: { [K in keyof typeof info]: RegExp } = {
    calories: /Calories:\s*[^0-9]*([\d]+(?:\.\d+)?)/i,
    protein:  /Protein:\s*[^0-9]*([\d]+(?:\.\d+)?)/i,
    carbs:    /Carbs?:\s*[^0-9]*([\d]+(?:\.\d+)?)/i,
    fat:      /Fat:\s*[^0-9]*([\d]+(?:\.\d+)?)/i,
  };

  for (const key of Object.keys(patterns) as (keyof typeof info)[]) {
    const m = html.match(patterns[key]);
    if (m) info[key] = parseFloat(m[1]);
  }
  return info;
}
// Environment variables
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY");
const GOOGLE_SEARCH_API_KEY = Deno.env.get("GOOGLE_SEARCH_API_KEY");
const GOOGLE_SEARCH_CX = Deno.env.get("GOOGLE_SEARCH_CX");
const GEMINI_VISION_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite-preview-06-17:generateContent";
const GEMINI_TEXT_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite-preview-06-17:generateContent";
const YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search";
if (!GEMINI_API_KEY) {
  console.error("Missing GEMINI_API_KEY environment variable");
}
if (!YOUTUBE_API_KEY) {
  console.warn("Missing YOUTUBE_API_KEY — video links will be omitted");
}
// ──────────────────────────────────────────────────────────
//  Whitelists for user-selectable options (same lists as front-end)
// ──────────────────────────────────────────────────────────
const MEAL_TYPES = [
  'general',
  'breakfast',
  'lunch',
  'dinner'
];
const DIETARY_GOALS = [
  'normal',
  'fat_loss',
  'muscle_gain'
];
const MEAL_TIMES = [
  'fast',
  'medium',
  'long'
];
const AMOUNT_PEOPLE = [
  '1',
  '2',
  '4',
  '6+'
];
const RESTRICT_DIETS = [
  'None',
  'Vegan',
  'Vegetarian',
  'Gluten-free',
  'Lactose-free'
];
const PREFERRED_REGIONS = [
  'Any',
  'Asia',
  'Europe',
  'Mediterranean',
  'America',
  'Middle Eastern',
  'African',
  'Latin American'
];
const SKILL_LEVELS = [
  'Beginner',
  'Intermediate',
  'Advanced'
];
const KITCHEN_TOOLS = [
  'Stove Top',
  'Oven',
  'Microwave',
  'Air Fryer',
  'Sous Vide Machine',
  'Blender',
  'Food Processor',
  'BBQ',
  'Slow Cooker',
  'Pressure Cooker'
];
// Manual-label text validation
const LABEL_REGEX = /^[a-zA-Z0-9 ,.'()\-]{1,30}$/;
// Helper to build consistent error responses
function respondError(status, message, userError = false) {
  return new Response(JSON.stringify({
    error: message,
    user_error: userError
  }), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
}
// Gemini image generation endpoint
const GEMINI_IMAGE_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent";
async function generateDishImage(title) {
  if (!GEMINI_API_KEY) return null;
  const prompt = `Food photography of ${title}, plated on a neutral background, studio lighting`;
  try {
    const resp = await fetch(GEMINI_IMAGE_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY
      },
      body: JSON.stringify({
        model: "gemini-2.0-flash-preview-image-generation",
        contents: prompt,
        config: {
          responseModalities: ["IMAGE"],
        },
        generationConfig: {
          thinkingConfig: {
            thinkingBudget: 0
          }
        }
      })
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    const b64 = data?.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
    if (b64) return `data:image/png;base64,${b64}`;
    return null;
  } catch  {
    return null;
  }
}
serve(async (req)=>{
  // ──────────────────────────────────────────────────────────
  // Throttle: 1 request per IP per 5 s to protect Gemini quota
  // ──────────────────────────────────────────────────────────
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0] || "unknown";
  const now = Date.now();
  const last = lastRequestMap.get(ip) ?? 0;
  if (now - last < 5000) {
    return new Response(JSON.stringify({
      error: "Too many requests – wait a few seconds before trying again."
    }), {
      status: 429,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  lastRequestMap.set(ip, now);
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  // ──────────────────────────────────────────────────────────
  // Authentication – optional: derive user if JWT present
  // ──────────────────────────────────────────────────────────
  const authHeader = req.headers.get("authorization") || req.headers.get("Authorization");
  let derived_user_id = null;
  if (authHeader?.startsWith("Bearer ")) {
    const jwt = authHeader.substring(7);
    const { data: { user: authUser } = {
      user: null
    } } = await supabase.auth.getUser(jwt);
    if (authUser) {
      derived_user_id = authUser.id;
    }
  }
  try {
    const body = await req.json();
    // Ensure all relevant fields from the body are destructured
    const { user_id, image_url, meal_type = "", dietary_goal = "normal", mode, manual_labels, restrict_diet, amount_people, meal_time, selected_title, stage, preferred_region, skill_level, kitchen_tools, client_image_url, height_cm, weight_kg, gender, age, fitness_goal, other_note = "" } = body;
    // ─── Option Whitelist Validation ──────────────────────
    const invalidMsgs = [];
    if (meal_type && !MEAL_TYPES.includes(meal_type)) invalidMsgs.push(`meal_type '${meal_type}'`);
    if (dietary_goal && !DIETARY_GOALS.includes(dietary_goal)) invalidMsgs.push(`dietary_goal '${dietary_goal}'`);
    if (meal_time && !MEAL_TIMES.includes(meal_time)) invalidMsgs.push(`meal_time '${meal_time}'`);
    if (amount_people && !AMOUNT_PEOPLE.includes(amount_people)) invalidMsgs.push(`amount_people '${amount_people}'`);
    if (restrict_diet && !RESTRICT_DIETS.includes(restrict_diet)) invalidMsgs.push(`restrict_diet '${restrict_diet}'`);
    if (preferred_region && !PREFERRED_REGIONS.includes(preferred_region)) invalidMsgs.push(`preferred_region '${preferred_region}'`);
    if (skill_level && !SKILL_LEVELS.includes(skill_level)) invalidMsgs.push(`skill_level '${skill_level}'`);
    if (kitchen_tools && Array.isArray(kitchen_tools)) {
      const illegalTools = kitchen_tools.filter((t)=>!KITCHEN_TOOLS.includes(t));
      if (illegalTools.length) invalidMsgs.push(`kitchen_tools [${illegalTools.join(', ')}]`);
    }
    // Manual labels validation
    if (manual_labels && Array.isArray(manual_labels)) {
      for (const { item_label, additional_info } of manual_labels){
        if (item_label && !LABEL_REGEX.test(item_label)) invalidMsgs.push(`item_label '${item_label}'`);
        if (additional_info && !LABEL_REGEX.test(additional_info)) invalidMsgs.push(`additional_info '${additional_info}'`);
      }
    }
    if (other_note && typeof other_note !== 'string') {
      invalidMsgs.push(`other_note must be a string`);
    }
    if (other_note && other_note.length > 200) {
      invalidMsgs.push(`other_note is too long (max 200 chars)`);
    }
    if (invalidMsgs.length) {
      return respondError(400, `Invalid input for: ${invalidMsgs.join(', ')}`, true);
    }
    // Handle the new neutral 'general' option
    const mealTypeForPrompt = !meal_type || meal_type.toLowerCase() === 'general' ? 'not specified' : meal_type;
    if (!image_url && !(manual_labels && manual_labels.length > 0 && mode === 'extract_only')) {
      if (!image_url) {
        return respondError(400, "Missing 'image_url' in request body", true);
      }
    }
    // Validate incoming image URL early
    if (image_url) {
      const validatedInputUrl = await validateImageUrl(image_url);
      if (!validatedInputUrl) {
        return respondError(400, "Unsupported image URL. Use HTTPS images up to 5 MB.", true);
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
        return respondError(400, "Unable to download the provided image.", true);
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
        return respondError(502, "Image-analysis service failed. Please try again.", false);
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
      return respondError(400, "Missing 'image_url' or 'manual_labels' in request body", true);
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
    // ===== Fitness mode branch =====
    if (mode === "fitness") {
      const QUANTITY_DISPLAY_CUTOFF = 10;
      const ingredientText = items.map((i)=>{
        let txt = "";
        if (i.quantity > 1 && i.quantity <= QUANTITY_DISPLAY_CUTOFF) {
          txt += `${i.quantity} `;
        }
        txt += i.item_label;
        if (i.additional_info) txt += ` (${i.additional_info})`;
        return txt;
      }).join(", ");
      // Fitness prompt
      const fitnessPrompt = `
    Given these details:
    - Ingredients Available: ${ingredientText}
    - Height: ${height_cm || 'not specified'} cm
    - Weight: ${weight_kg || 'not specified'} kg
    - Gender: ${gender || 'not specified'}
    - Age: ${age || 'not specified'}
    - Goal: ${fitness_goal === 'fat_loss' ? 'fat loss' : fitness_goal === 'muscle_gain' ? 'muscle gain' : 'healthy eating'}
    ${other_note && other_note.trim() ? `- Additional Notes: ${other_note.trim()}` : ``}

    Goal meanings:
    - "muscle gain": maximize protein and calories for muscle growth.
    - "fat loss": low calorie, high protein, high volume, filling but low in fat and sugar.
    - "healthy eating": focus on balanced, nutritious meals, not for weight change, just well-being and health.

    Instructions:
    1. Estimate the user's target daily calorie intake and macronutrient distribution (protein, fats, carbs) using standard fitness formulas (such as Mifflin-St Jeor).
    2. Analyze whether the available ingredients can support the user's fitness goal (high protein for muscle gain, low calorie & high volume for fat loss, etc.).
    3. If possible, generate a recipe using these ingredients that aligns with the goal. If not possible, clearly explain what is missing or suboptimal, and suggest what should be added.
    4. Output format: valid HTML only, no markdown. Structure:
      - <h1> Recipe Title
      - <h2> Ingredients
      - <ul>
      - <h2> Instructions
      - <ol>
      - <h2> Fitness Explanation
      - <p> Why this recipe matches (or does not match) the fitness goal. Clearly explain what is missing if the result is not ideal.
      - <h2> Nutritional Analysis
      - <p> Estimated calories, protein, carbs, fat per portion.

    After the HTML recipe above, append the JSON object {"nutrition_info":{"calories":number,"protein":number,"carbs":number,"fat":number}} immediately after the HTML without any code fences. Ensure the values in this JSON match the nutritional analysis in the HTML, and return only the HTML recipe followed by the JSON object.
`.trim();
      // Gemini 
      const fitnessResp = await fetch(GEMINI_TEXT_ENDPOINT, {
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
                  text: fitnessPrompt
                }
              ]
            }
          ]
        })
      });
      if (!fitnessResp.ok) {
        const errText = await fitnessResp.text();
        return new Response(JSON.stringify({
          error: "Fitness recipe generation failed",
          detail: errText
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
      const fitnessData = await fitnessResp.json();
      // Get full response text (HTML + JSON block)
      const fullResponse = fitnessData?.candidates?.[0]?.content?.parts?.[0]?.text || "<p>Error: Could not generate fitness recipe.</p>";
      // Extract nutrition_info JSON (support both fenced and plain JSON) and strip it from the returned HTML
      let nutrition_info = { calories: 0, protein: 0, carbs: 0, fat: 0 };
      let fitnessHtml = fullResponse;
      let jsonString: string | null = null;
      // Try fenced JSON first
      const fenceMatch = fullResponse.match(/```json\s*([\s\S]*?)```/);
      if (fenceMatch) {
        jsonString = fenceMatch[1].trim();
        fitnessHtml = fullResponse.replace(/```json[\s\S]*?```/, '').trim();
      } else {
        // Try plain JSON object appended after HTML
        const plainMatch = fullResponse.match(/(\{[\s\S]*\})\s*$/);
        if (plainMatch) {
          jsonString = plainMatch[1];
          fitnessHtml = fullResponse.slice(0, plainMatch.index).trim();
        }
      }
      if (jsonString) {
        try {
          const parsed = JSON.parse(jsonString);
          if (parsed.nutrition_info) {
            nutrition_info = parsed.nutrition_info;
          }
        } catch (e) {
          console.error('Failed to parse nutrition_info JSON:', e);
          // Fallback: extract numbers from HTML if JSON parse fails
          nutrition_info = extractNutritionInfo(fitnessHtml);
        }
      } else {
        // No JSON block found: fallback to heuristics
        nutrition_info = extractNutritionInfo(fitnessHtml);
      }
      // Continue with title extraction on cleaned HTML
      function extractTitle(html) {
        const m = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
        return m ? m[1].trim() : "";
      }
      const dishTitle = extractTitle(fitnessHtml);
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
            main_image_url = candidateUrl ?? FALLBACK_IMAGE_URL;
          }
        } catch (imgErr) {
          main_image_url = FALLBACK_IMAGE_URL;
        }
      } else {
        main_image_url = FALLBACK_IMAGE_URL;
      }
      // Ensure image generation fallback for fitness mode
      if (!main_image_url) {
        main_image_url = await generateDishImage(dishTitle || "dish");
        if (!main_image_url) main_image_url = FALLBACK_IMAGE_URL;
      }
      // Persist fitness run in history table
      if (derived_user_id) {
        await supabase.from('history').insert({
          user_id: derived_user_id,
          image_url,              // original uploaded URL
          recipe_html: fitnessHtml,
          recipe_title: dishTitle,
          main_image_url,
          video_url: null,
          meal_type: '',
          dietary_goal: '',
          meal_time: '',
          amount_people: '',
          restrict_diet: '',
          detected_items: items,
          tags: ['fitness', fitness_goal],
          preferred_region,
          skill_level,
          kitchen_tools,
          nutrition_info,
          other_note,
        });
      }
      return new Response(JSON.stringify({
        items,
        recipe: fitnessHtml,
        main_image_url,
        video_url: null,
        categories: [
          "fitness",
          fitness_goal
        ],
        nutrition_info,
        other_note
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
    const ingredientText = items.map((i)=>{
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
    - Meal Type: ${mealTypeForPrompt}
    - Dietary Goal: ${dietary_goal}
    - People Eating: ${amount_people || 'not specified'}
    - Preferred Cooking Time: ${meal_time || 'not specified'}
    ${restrict_diet && restrict_diet.trim() !== "" ? `- Strict Dietary Restriction: ${restrict_diet}` : ''}
    - Preferred Region: ${preferred_region || 'Any'}
    - Skill Level: ${skill_level || 'Beginner'}
    - Kitchen Tools Available: ${Array.isArray(kitchen_tools) && kitchen_tools.length > 0 ? kitchen_tools.join(", ") : "Any"}
    - Additional Notes: ${other_note}
    Your task: Suggest exactly 3 RECIPE IDEAS that satisfy **all** the constraints above.
    • If a *Strict Dietary Restriction* is provided (e.g. "Vegan", "Gluten-free"), every candidate MUST comply with it; do NOT suggest dishes that inherently violate the restriction.
    • The *Dietary Goal* (fat_loss / muscle_gain / normal) should be reflected in the kind of dish you propose.
    • Take the available kitchen tools into account – do not propose a recipe that relies on a tool that is not listed (unless "Any" was specified).
    • The meal type and preferred region should inform the style / cuisine of the dish.

    Output format: **return ONLY valid JSON** – an array with 3 objects. Each object contains:
      - "title": a concise English dish name
      - "description": one short sentence that tells the user what the dish is like

    Example (format only):
    [
      {"title":"Grilled Tofu Buddha Bowl","description":"A protein-rich vegan bowl with colourful veggies and quinoa."},
      ... 2 more objects ...
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
        return respondError(502, "Could not generate recipe candidates. Please retry.", false);
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
                image_url = await generateDishImage(c.title);
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
- **Meal Type:** ${mealTypeForPrompt}
- **Dietary Goal:** ${dietary_goal}
- **People Eating:** ${amount_people || 'not specified'}
- **Preferred Cooking Time:** ${meal_time || 'not specified'}
${restrict_diet && restrict_diet.trim() !== "" ? `- **Strict Dietary Restriction to follow:** ${restrict_diet}` : ''}
- **Preferred Region/Cuisine:** ${preferred_region || 'Any'}
- **Skill Level:** ${skill_level || 'Beginner'}
- **Kitchen Tools Available:** ${Array.isArray(kitchen_tools) && kitchen_tools.length > 0 ? kitchen_tools.join(", ") : "Any"}
${other_note && other_note.trim() ? `- **Additional Notes:** ${other_note.trim()}` : ``}
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
      return respondError(502, "Failed to generate recipe. Please try again later.", false);
    }
    const recipeData = await recipeResp.json();
    const rawRecipeHtml = recipeData?.candidates?.[0]?.content?.parts?.[0]?.text || "<p>Error: Could not generate recipe content.</p>";
    const recipeHtml = sanitizeHtml(rawRecipeHtml, {
      allowedTags: sanitizeHtml.defaults.allowedTags.concat([
        "h1",
        "h2",
        "img"
      ]),
      allowedAttributes: {
        a: [
          "href",
          "title",
          "target"
        ],
        img: [
          "src",
          "alt"
        ]
      },
      allowedSchemes: [
        "https"
      ]
    });
    // ====== YouTube Video Search Integration ======
    // Helper to extract the dish title from <h1>
    function extractTitle1(html) {
      const m = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
      return m ? m[1].trim() : "";
    }
    const dishTitle = extractTitle1(recipeHtml);
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
    let main_image_url = client_image_url || null;
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
    if (meal_type && meal_type.toLowerCase() !== 'normal' && meal_type.toLowerCase() !== 'general') {
      categories.push(meal_type);
    }
    if (dietary_goal && dietary_goal.toLowerCase() !== 'normal') {
      categories.push(dietary_goal);
    }
    if (restrict_diet && restrict_diet.toLowerCase() !== 'none') {
      categories.push(restrict_diet);
    }
    const recipeTitle = extractRecipeTitle(recipeHtml);
    // Ensure main_image_url is set (fallback generation + placeholder)
    if (!main_image_url) {
      main_image_url = await generateDishImage(dishTitle || "dish");
      if (!main_image_url) main_image_url = FALLBACK_IMAGE_URL;
    }
    // Persist user history
    if (derived_user_id) {
      await supabase.from('history').insert({
        user_id: derived_user_id,
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
        tags: categories,
        preferred_region,
        skill_level,
        kitchen_tools,
        other_note, 
      });
    }
    return new Response(JSON.stringify({
      items,
      recipe: recipeHtml,
      video_url,
      categories,
      main_image_url,
      other_note
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

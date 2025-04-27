from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
from PIL import Image
import requests
import io
import json
import re
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
# CORS spanning configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],           
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API of GEMINI
genai.configure(api_key="AIzaSyB6YSko6Kyl1NINg2bi_uVnqZ4PPmbE1-M")



# data type
class RecipeRequest(BaseModel):
    image_url: str
    meal_type: str = "dinner"
    dietary_goal: str = "normal"

class RecipeResponse(BaseModel):
    labels: list
    recipe: str

# Download image binary from Supabase's URL
def fetch_image_bytes(url: str) -> bytes:
    resp = requests.get(url)
    resp.raise_for_status()
    return resp.content

# Extract JSON structure from text
def extract_json_from_text(text: str):
    try:
        json_str = re.search(r'\{.*\}', text, re.DOTALL).group()
        return json.loads(json_str)
    except Exception as e:
        print("Error extracting JSON:", e)
        return None

# Calling the Gemini Vision model to extract food labels
def extract_labels(image_bytes: bytes) -> list:
    img = Image.open(io.BytesIO(image_bytes))
    model = genai.GenerativeModel("gemini-2.0-flash")
    prompt = (
        "List the food items you see in this image in JSON format:\n"
        '{"food_items": ["item1", "item2", "item3"]}\n'
        "Please ONLY return a valid JSON object with no extra text."
    )
    response = model.generate_content([prompt, img])
    data = extract_json_from_text(response.text)
    if data and "food_items" in data:
        return data["food_items"]
    else:
        return []

# Calling the Gemini text model to generate full recipes based on ingredient labels
def generate_recipe(labels: list, meal_type="dinner", dietary_goal="normal") -> str:
    label_text = ", ".join(labels) # Spell the hashtag into a sentence
    model = genai.GenerativeModel("gemini-2.0-flash")
    prompt = (
        f"I have the following ingredients: {label_text}. "
        f"My meal type is {meal_type} and dietary goal is {dietary_goal}. "
        "Please generate a full recipe including title, ingredients, steps, and estimated calories."
    )
    response = model.generate_content(prompt)
    return response.text

# Main interface 
@app.post("/generate_recipe", response_model=RecipeResponse)
async def generate_recipe_endpoint(req: RecipeRequest):
    try:
        img_bytes = fetch_image_bytes(req.image_url)
        labels = extract_labels(img_bytes)
        if not labels:
            raise HTTPException(status_code=400, detail="No food items detected.")
        recipe = generate_recipe(labels, req.meal_type, req.dietary_goal)
        return {"labels": labels, "recipe": recipe}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

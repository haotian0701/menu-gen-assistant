# 🍽 Cookpilot - AI Recipe Assistant

Cookpilot is an intelligent recipe generation app that transforms your food photos into personalized recipes using advanced AI. Built with Flutter and Supabase, it offers multiple recipe generation modes to suit different cooking styles and dietary goals.

**🌐 Live Demo**: [https://cookpilot.xyz/](https://cookpilot.xyz/)

## ✨ Features

### 🤖 AI-Powered Recipe Generation
- **Smart Food Detection**: Upload food photos and get automatic ingredient identification using Google's Gemini Vision AI
- **Multiple Generation Modes**:
  - **Quick Mode**: Instant recipe generation with minimal input
  - **Advanced Mode**: Customizable options for meal type, dietary goals, cooking time, and more
  - **Fitness Mode**: Personalized nutrition-focused recipes with calorie and macro tracking

### 🎯 Personalization & Preferences
- **User Profiles**: Save personal preferences for meal types, dietary restrictions, and cooking skill level
- **Fitness Integration**: Input height, weight, age, and fitness goals for tailored nutrition recommendations
- **Dietary Restrictions**: Support for vegan, vegetarian, gluten-free, lactose-free diets
- **Kitchen Tools**: Recipe adaptation based on available cooking equipment
- **Regional Cuisines**: Preference settings for different cooking styles (Asian, Mediterranean, etc.)

### 📱 Modern User Experience
- **Mobile-First Design**: Optimized for smartphones with responsive desktop support
- **Real-Time Progress**: Visual progress indicators during recipe generation
- **Interactive UI**: Smooth animations and intuitive navigation
- **Cross-Platform**: Works seamlessly on iOS, Android, and web browsers

### 🍳 Recipe Management
- **Recipe History**: Automatic saving of all generated recipes with timestamps
- **Saved Recipes**: Bookmark favorite recipes for quick access
- **Recipe Sharing**: Share recipes via social media, email, or messaging apps
- **Detailed Nutrition**: Comprehensive nutrition information including calories, protein, carbs, and fats
- **Visual Nutrition Charts**: Interactive pie charts for macro distribution

### 🔐 Authentication & Security
- **Multiple Sign-in Options**: 
  - Email/password authentication
  - GitHub OAuth integration
- **Secure User Data**: All user preferences and recipes stored securely in Supabase
- **Session Management**: Persistent login with automatic session handling

### 📺 Enhanced Content
- **YouTube Integration**: Automatically find relevant cooking videos for generated recipes
- **Generated Food Images**: AI-generated preview images for recipes using Gemini image generation
- **Rich Recipe Format**: Detailed instructions with ingredient lists, cooking steps, and serving information

### 🎨 Design & Branding
- **Consistent Branding**: "Cookpilot" branding throughout the app with custom icon
- **Modern UI Components**: Clean, professional interface with smooth transitions

## 🚀 How It Works

1. **Upload**: Take a photo of food or ingredients
2. **Detect**: AI automatically identifies ingredients in your photo
3. **Customize**: Choose your preferences (meal type, dietary goals, cooking time)
4. **Generate**: Get a personalized recipe with nutrition information
5. **Cook**: Follow step-by-step instructions with optional video guides
6. **Save**: Bookmark favorites and track your cooking history

## 🛠 Technology Stack

### Frontend
- **Flutter**: Cross-platform UI framework for mobile and web
- **Dart**: Programming language for Flutter development
- **Responsive Design**: Mobile-first with desktop compatibility

### Backend
- **Supabase**: Backend-as-a-Service for database, authentication, and real-time features
- **PostgreSQL**: Relational database for user data and recipes
- **Supabase Edge Functions**: Serverless functions for AI processing

### AI & APIs
- **Google Gemini 2.5 Flash-Lite**: Advanced language model for recipe generation
- **Gemini Vision API**: Image analysis and ingredient detection
- **Gemini Image Generation**: AI-generated food preview images
- **YouTube Data API**: Automatic video recommendations
- **Google Custom Search API**: Enhanced image discovery

### Deployment
- **Netlify**: Static site hosting with continuous deployment
- **GitHub**: Version control

## 💻 Usage

### Target Devices
- **Primary**: Mobile devices (smartphones) via web browser
- **Secondary**: Desktop computers with full functionality

### Getting Started
1. Visit [https://cookpilot.xyz/](https://cookpilot.xyz/)
2. Create an account or sign in with GitHub
3. Upload a photo of food or ingredients
4. Choose your recipe preferences
5. Generate and enjoy your personalized recipe!

## ⚠️ Limitations

### Gemini API Rate Limits
The app uses Google's Gemini API models with the following limitations:

- **Gemini 2.5 Flash-Lite Preview 06-17**: 15 RPM, 250,000 TPM, 1,000 RPD
  - Used for ingredient detection and recipe generation
- **Gemini 2.0 Flash Preview Image Generation**: 10 RPM, 200,000 TPM, 100 RPD
  - Used for generating recipe preview images

*RPM: Requests per Minute, TPM: Input Tokens per Minute, RPD: Requests per Day*

During peak usage, users may experience slower response times or temporary delays.

### Netlify Free Tier Limitations
Deployed on Netlify's free tier with the following constraints:

- **Bandwidth**: 100GB/month
- **Build Minutes**: Limited monthly build time
- **Function Invocations**: Limited serverless function calls

Heavy usage may result in temporary service unavailability if limits are exceeded.

## 🎨 Presentation

Find our detailed presentation here:  
[📊 View Slides (PDF)](presentation_stuff/presentation.pdf)

## 🔧 Development

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- Supabase account
- Google AI API keys
- Node.js (for Supabase functions)

### Environment Setup (for local development)
1. Clone the repository
2. Install Flutter dependencies: `flutter pub get`
3. Configure Supabase credentials
4. Set up Google API keys
5. Deploy Supabase Edge Functions
6. Run: `flutter run -d web-server --web-port 3000`

### APIs & Services
- **Google Gemini AI**: Advanced language and vision models
- **YouTube Data API**: Video content integration
- **Supabase**: Backend infrastructure and real-time database
- **Netlify**: Web hosting and deployment

### Technologies
- **Flutter Framework**: Cross-platform development
- **Dart Language**: Application programming
- **PostgreSQL**: Database management

---

*Built with ❤️ for food lovers and cooking enthusiasts*

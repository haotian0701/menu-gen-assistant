import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedLoadingWidget extends StatefulWidget {
  final String? customMessage;
  final LoadingType type;
  final Color? primaryColor;
  final Color? textColor;
  final AnimationStyle animationStyle;

  const AnimatedLoadingWidget({
    super.key,
    this.customMessage,
    this.type = LoadingType.cooking,
    this.primaryColor,
    this.textColor,
    this.animationStyle = AnimationStyle.cookingAnimation,
  });

  @override
  State<AnimatedLoadingWidget> createState() => _AnimatedLoadingWidgetState();
}

enum AnimationStyle {
  cookingAnimation,     // Animated cooking utensils
  pulsatingCircles,     // Multiple pulsating circles
  rotatingFood,         // Rotating food emojis
  bouncingDots,         // Bouncing dots in a circle
  gradientWave,         // Animated gradient wave
  spinningPlate,        // Spinning plate with food
}

enum LoadingType {
  cooking,      // For recipe generation
  uploading,    // For image upload
  analyzing,    // For image analysis
  saving,       // For saving preferences/data
  loading,      // General loading
}

class _AnimatedLoadingWidgetState extends State<AnimatedLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  
  Timer? _messageTimer;
  String _currentMessage = '';
  int _currentIndex = 0;
  
  // 20 cool and funny cooking phrases
  static const List<String> _cookingPhrases = [
    "🧑‍🍳 Our chef is working their magic...",
    "🔥 Firing up the virtual stove...",
    "🥄 Stirring up something delicious...",
    "📖 Flipping through ancient cookbooks...",
    "🧂 Adding a pinch of creativity...",
    "🍳 Cracking the code of flavor...",
    "🥘 Simmering the perfect recipe...",
    "👨‍🍳 Master chef mode: ACTIVATED!",
    "🌟 Sprinkling some culinary stardust...",
    "🍴 Preparing a feast for your taste buds...",
    "🔮 Consulting the oracle of deliciousness...",
    "🎯 Targeting your perfect meal...",
    "🧬 Analyzing the DNA of flavor...",
    "🎭 Performing culinary theater...",
    "🚀 Launching flavor rockets...",
    "🧙‍♂️ Casting delicious spells...",
    "🎨 Painting with flavors and spices...",
    "🏆 Competing for the tastiest trophy...",
    "💡 Having a brilliant food idea...",
    "🎪 Running a three-ring flavor circus...",
  ];
  
  static const List<String> _uploadingPhrases = [
    "📸 Capturing your culinary vision...",
    "☁️ Sending your photo to the cloud kitchen...",
    "🚀 Uploading at warp speed...",
    "📡 Transmitting delicious data...",
    "💾 Saving your tasty snapshot...",
    "🌐 Sharing with our digital chefs...",
    "📮 Delivering your food photo...",
    "🎯 Targeting the perfect upload...",
    "⚡ Lightning-fast photo processing...",
    "🔄 Syncing with our recipe database...",
  ];
  
  static const List<String> _analyzingPhrases = [
    "🔍 Examining every delicious detail...",
    "🧠 AI brain is thinking hard...",
    "👀 Seeing what you're cooking...",
    "🤖 Robot chef analyzing ingredients...",
    "🔬 Under the culinary microscope...",
    "📊 Crunching the food data...",
    "🎯 Identifying tasty possibilities...",
    "💭 Having deep food thoughts...",
    "🔎 Detecting flavor patterns...",
    "🧩 Solving the ingredient puzzle...",
  ];
  
  static const List<String> _savingPhrases = [
    "💾 Saving your preferences...",
    "📝 Writing to the recipe book...",
    "🔒 Securing your settings...",
    "💫 Making it permanent...",
    "✅ Confirming your choices...",
    "📚 Adding to your cookbook...",
    "🎯 Targeting your preferences...",
    "💎 Storing your gems...",
    "🏠 Making yourself at home...",
    "⭐ Bookmarking your favorites...",
  ];
  
  static const List<String> _generalPhrases = [
    "⏳ Just a moment please...",
    "🎭 Setting the stage...",
    "🔄 Processing your request...",
    "⚡ Working at light speed...",
    "🎯 Getting everything ready...",
    "💫 Making magic happen...",
    "🚀 Launching preparations...",
    "🎪 Behind the scenes action...",
    "⭐ Almost there...",
    "🎨 Putting finishing touches...",
  ];

  List<String> get _phrases {
    switch (widget.type) {
      case LoadingType.cooking:
        return _cookingPhrases;
      case LoadingType.uploading:
        return _uploadingPhrases;
      case LoadingType.analyzing:
        return _analyzingPhrases;
      case LoadingType.saving:
        return _savingPhrases;
      case LoadingType.loading:
        return _generalPhrases;
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    
    // Start animations
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _bounceController.repeat();
    _startMessageCycle();
  }
  
  void _startMessageCycle() {
    _showNextMessage();
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _showNextMessage();
    });
  }
  
  void _showNextMessage() {
    if (widget.customMessage != null) {
      setState(() {
        _currentMessage = widget.customMessage!;
      });
      _fadeController.forward();
      _scaleController.forward();
      return;
    }
    
    final phrases = _phrases;
    final newIndex = Random().nextInt(phrases.length);
    
    // Make sure we don't show the same message twice in a row
    if (newIndex == _currentIndex && phrases.length > 1) {
      _showNextMessage();
      return;
    }
    
    _currentIndex = newIndex;
    
    // Fade out current message
    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentMessage = phrases[_currentIndex];
        });
        // Fade in new message
        _fadeController.forward();
        _scaleController.reset();
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final textColor = widget.textColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.3,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated loading based on style
                _buildAnimatedLoader(primaryColor),
                
                const SizedBox(height: 24),
                
                // Animated message
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 50,
                      maxHeight: 80,
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _currentMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Subtle pulsing dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        final delay = index * 0.2;
                        final animValue = (_scaleAnimation.value + delay) % 1.0;
                        final opacity = (sin(animValue * pi * 2) + 1) / 2;
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(opacity * 0.6),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnimatedLoader(Color primaryColor) {
    switch (widget.animationStyle) {
      case AnimationStyle.cookingAnimation:
        return _buildCookingAnimation(primaryColor);
      case AnimationStyle.pulsatingCircles:
        return _buildPulsatingCircles(primaryColor);
      case AnimationStyle.rotatingFood:
        return _buildRotatingFood(primaryColor);
      case AnimationStyle.bouncingDots:
        return _buildBouncingDots(primaryColor);
      case AnimationStyle.gradientWave:
        return _buildGradientWave(primaryColor);
      case AnimationStyle.spinningPlate:
        return _buildSpinningPlate(primaryColor);
    }
  }

  Widget _buildCookingAnimation(Color primaryColor) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating outer ring with cooking utensils
              Transform.rotate(
                angle: _rotationAnimation.value * 2 * pi,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
                  ),
                  child: const Stack(
                    children: [
                      Positioned(top: 5, left: 45, child: Text('🍳', style: TextStyle(fontSize: 16))),
                      Positioned(right: 5, top: 45, child: Text('🥄', style: TextStyle(fontSize: 16))),
                      Positioned(bottom: 5, left: 45, child: Text('🔪', style: TextStyle(fontSize: 16))),
                      Positioned(left: 5, top: 45, child: Text('🥘', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
              ),
              // Center pulsating chef
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.1),
                        border: Border.all(color: primaryColor, width: 2),
                      ),
                      child: const Center(
                        child: Text('👨‍🍳', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPulsatingCircles(Color primaryColor) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (index) {
              final delay = index * 0.3;
              final size = 40.0 + (index * 20);
              final opacity = 0.8 - (index * 0.2);
              final animValue = (_pulseAnimation.value + delay) % 1.0;
              
              return Transform.scale(
                scale: 0.5 + (animValue * 0.8),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(opacity * (1 - animValue)),
                    border: Border.all(
                      color: primaryColor.withOpacity(opacity),
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildRotatingFood(Color primaryColor) {
    const foodEmojis = ['🍕', '🍔', '🌮', '🍜', '🍲', '🥗'];
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center plate
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                  border: Border.all(color: primaryColor, width: 3),
                ),
                child: const Center(
                  child: Text('🍽️', style: TextStyle(fontSize: 24)),
                ),
              ),
              // Rotating food items
              ...List.generate(foodEmojis.length, (index) {
                final angle = (index * 2 * pi / foodEmojis.length) + (_rotationAnimation.value * 2 * pi);
                final radius = 40.0;
                return Transform.translate(
                  offset: Offset(
                    radius * cos(angle),
                    radius * sin(angle),
                  ),
                  child: Text(
                    foodEmojis[index],
                    style: const TextStyle(fontSize: 20),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBouncingDots(Color primaryColor) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              final delay = index * 0.2;
              final animValue = (_bounceAnimation.value + delay) % 1.0;
              final bounce = sin(animValue * pi * 2);
              
              return Transform.translate(
                offset: Offset(0, bounce * -20),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildGradientWave(Color primaryColor) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor,
                primaryColor.withOpacity(0.5),
                primaryColor.withOpacity(0.1),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
              transform: GradientRotation(_rotationAnimation.value * 2 * pi),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '🍳',
                  style: TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpinningPlate(Color primaryColor) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Spinning plate base
              Transform.rotate(
                angle: _rotationAnimation.value * 2 * pi,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.8),
                        primaryColor.withOpacity(0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              // Pulsating food in center
              Transform.scale(
                scale: _pulseAnimation.value,
                child: const Text(
                  '🍽️',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CompactLoadingWidget extends StatefulWidget {
  final String? customMessage;
  final LoadingType type;
  final Color? primaryColor;
  final Color? textColor;

  const CompactLoadingWidget({
    super.key,
    this.customMessage,
    this.type = LoadingType.uploading,
    this.primaryColor,
    this.textColor,
  });

  @override
  State<CompactLoadingWidget> createState() => _CompactLoadingWidgetState();
}

class _CompactLoadingWidgetState extends State<CompactLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  
  Timer? _messageTimer;
  String _currentMessage = '';
  int _currentIndex = 0;

  List<String> get _phrases {
    switch (widget.type) {
      case LoadingType.cooking:
        return _AnimatedLoadingWidgetState._cookingPhrases;
      case LoadingType.uploading:
        return _AnimatedLoadingWidgetState._uploadingPhrases;
      case LoadingType.analyzing:
        return _AnimatedLoadingWidgetState._analyzingPhrases;
      case LoadingType.saving:
        return _AnimatedLoadingWidgetState._savingPhrases;
      case LoadingType.loading:
        return _AnimatedLoadingWidgetState._generalPhrases;
    }
  }

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _rotationController.repeat();
    _startMessageCycle();
  }
  
  void _startMessageCycle() {
    _showNextMessage();
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _showNextMessage();
    });
  }
  
  void _showNextMessage() {
    if (widget.customMessage != null) {
      setState(() {
        _currentMessage = widget.customMessage!;
      });
      return;
    }
    
    final phrases = _phrases;
    final newIndex = Random().nextInt(phrases.length);
    
    if (newIndex == _currentIndex && phrases.length > 1) {
      _showNextMessage();
      return;
    }
    
    _currentIndex = newIndex;
    
    if (mounted) {
      setState(() {
        _currentMessage = phrases[_currentIndex];
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Colors.white;
    final textColor = widget.textColor ?? Colors.white;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2 * pi,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            _currentMessage.isNotEmpty ? _currentMessage : 'Loading...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

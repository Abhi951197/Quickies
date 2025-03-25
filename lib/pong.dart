import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class PongGame extends StatefulWidget {
  const PongGame({super.key});

  @override
  State<PongGame> createState() => _PongGameState();
}

class _PongGameState extends State<PongGame>
    with SingleTickerProviderStateMixin {
  static const double ballSize = 20;
  static const double paddleHeight = 100;
  static const double paddleWidth = 15;

  // Game configuration - modified for exponential speed increase
  static const double initialBallSpeed = 5.5;
  static const double baseSpeedMultiplier = 1.1; // Exponential growth factor
  static const double maxBallSpeed = 20.0; // Increased max speed
  static const double aiReactionSpeed = 0.08;
  static const double aiErrorRate = 0.5;

  // Game state
  double ballX = 0;
  double ballY = 0;
  double ballSpeedX = 0;
  double ballSpeedY = 0;
  double paddle1Y = 0;
  double paddle2Y = 0;
  bool isGameRunning = false;
  bool isCountingDown = false;
  int countdownValue = 3;
  late Size screenSize;

  // Track consecutive hits for exponential speed increase
  int consecutiveHits = 0;

  // Game loop
  Timer? gameTimer;
  Timer? countdownTimer;

  // Animation controller for intro
  late AnimationController _introAnimationController;
  late Animation<double> _introAnimation;

  // Effect animations
  double? hitEffectX;
  double? hitEffectY;
  double hitEffectOpacity = 0;

  @override
  void initState() {
    super.initState();
    _introAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _introAnimation = CurvedAnimation(
      parent: _introAnimationController,
      curve: Curves.easeOutBack,
    );
    _introAnimationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get screen size after layout is complete
    screenSize = MediaQuery.of(context).size;
    _resetGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    countdownTimer?.cancel();
    _introAnimationController.dispose();
    super.dispose();
  }

  void _resetGame() {
    gameTimer?.cancel();
    countdownTimer?.cancel();

    setState(() {
      isCountingDown = false;
      consecutiveHits = 0;
      _resetBall();
    });
  }

  void _resetBall() {
    // Position ball in the center of the game area
    final gameAreaHeight = screenSize.height * 0.7;

    setState(() {
      ballX = screenSize.width / 2 - ballSize / 2;
      ballY = (screenSize.height - gameAreaHeight) / 2 +
          gameAreaHeight / 2 -
          ballSize / 2;

      // Random initial direction with controlled angle
      double angle = (math.Random().nextDouble() * math.pi / 3) +
          math.pi / 6; // Between 30° and 60°
      if (math.Random().nextBool())
        angle = math.pi - angle; // Randomly go left or right

      // Reset to initial ball speed
      ballSpeedX = initialBallSpeed * math.cos(angle);
      ballSpeedY = initialBallSpeed * math.sin(angle);

      // Reset paddles to center
      paddle1Y = (screenSize.height - gameAreaHeight) / 2 +
          gameAreaHeight / 2 -
          paddleHeight / 2;
      paddle2Y = paddle1Y;

      // Reset consecutive hits counter
      consecutiveHits = 0;
    });

    // Show countdown if game is supposed to be running
    if (isGameRunning) {
      _showCountdown();
    }
  }

  void _showCountdown() {
    setState(() {
      isGameRunning = false;
      isCountingDown = true;
      countdownValue = 3;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        countdownValue--;
      });

      if (countdownValue <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            isCountingDown = false;
          });
          _startGame();
        }
      }
    });
  }

  void _startGame() {
    if (isGameRunning) return;

    setState(() {
      isGameRunning = true;
      consecutiveHits = 0;
    });

    // Start game loop
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
  }

  void _triggerHitEffect(double x, double y) {
    setState(() {
      hitEffectX = x;
      hitEffectY = y;
      hitEffectOpacity = 1.0;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          hitEffectOpacity = 0.0;
        });
      }
    });
  }

  void _gameLoop(Timer timer) {
    if (!mounted || !isGameRunning) return;

    final gameAreaHeight = screenSize.height * 0.7;
    final gameAreaTop = (screenSize.height - gameAreaHeight) / 2;
    final gameAreaBottom = gameAreaTop + gameAreaHeight;

    setState(() {
      // Ball movement
      ballX += ballSpeedX;
      ballY += ballSpeedY;

      // AI paddle movement
      double aiTargetY = paddle2Y;

      if (ballSpeedX > 0) {
        // Ball is moving toward AI paddle
        // Calculate time until ball reaches paddle
        double distanceToAI =
            (screenSize.width - paddleWidth - ballSize - ballX) / ballSpeedX;

        // Predict Y position with some error
        double errorFactor =
            1.0 + (math.Random().nextDouble() * aiErrorRate - aiErrorRate / 2);
        double predictedY = ballY + (ballSpeedY * distanceToAI * errorFactor);

        // Sometimes AI completely misses the prediction
        bool shouldMiss = math.Random().nextDouble() < (consecutiveHits * 0.01);
        if (shouldMiss) {
          // AI makes a bad prediction
          predictedY =
              math.Random().nextDouble() * gameAreaHeight + gameAreaTop;
        } else {
          // Account for bounces off top/bottom (with some error)
          if (predictedY < gameAreaTop ||
              predictedY > gameAreaBottom - ballSize) {
            // AI sometimes fails to predict bounces correctly
            if (math.Random().nextDouble() < 0.3) {
              // Incorrect bounce prediction
              predictedY =
                  math.Random().nextDouble() * gameAreaHeight / 2 + gameAreaTop;
            } else {
              // Correct bounce prediction (with some error)
              if (predictedY < gameAreaTop) {
                predictedY = 2 * gameAreaTop -
                    predictedY +
                    (math.Random().nextDouble() * 30);
              } else if (predictedY > gameAreaBottom - ballSize) {
                predictedY = 2 * (gameAreaBottom - ballSize) -
                    predictedY -
                    (math.Random().nextDouble() * 30);
              }
            }
          }
        }

        // Move toward the predicted position
        aiTargetY = predictedY - paddleHeight / 2;

        // Sometimes AI moves in wrong direction briefly
        if (math.Random().nextDouble() < 0.02) {
          aiTargetY = 2 * paddle2Y - aiTargetY;
        }
      } else {
        // Ball moving away - return to center with some randomness
        aiTargetY = (gameAreaTop + gameAreaHeight / 2 - paddleHeight / 2) +
            (math.Random().nextDouble() * paddleHeight - paddleHeight / 2);
      }

      // Smooth movement
      paddle2Y += (aiTargetY - paddle2Y) * aiReactionSpeed;

      // Keep paddles within game area bounds
      paddle1Y = paddle1Y.clamp(gameAreaTop, gameAreaBottom - paddleHeight);
      paddle2Y = paddle2Y.clamp(gameAreaTop, gameAreaBottom - paddleHeight);

      // Collision with top and bottom
      if (ballY <= gameAreaTop) {
        ballY = gameAreaTop;
        ballSpeedY = ballSpeedY.abs(); // Ensure we bounce down
        _triggerHitEffect(ballX, gameAreaTop);
      } else if (ballY >= gameAreaBottom - ballSize) {
        ballY = gameAreaBottom - ballSize;
        ballSpeedY = -ballSpeedY.abs(); // Ensure we bounce up
        _triggerHitEffect(ballX, gameAreaBottom - ballSize);
      }

      // Collision with paddles
      if (ballX <= paddleWidth &&
          ballY + ballSize >= paddle1Y &&
          ballY <= paddle1Y + paddleHeight &&
          ballSpeedX < 0) {
        // Only bounce if moving toward the paddle
        _bounceBall(true);
      }

      if (ballX >= screenSize.width - paddleWidth - ballSize &&
          ballY + ballSize >= paddle2Y &&
          ballY <= paddle2Y + paddleHeight &&
          ballSpeedX > 0) {
        // Only bounce if moving toward the paddle
        _bounceBall(false);
      }

      // Game over conditions - ball goes off screen
      if (ballX < -ballSize || ballX > screenSize.width) {
        // Game over - stop game
        isGameRunning = false;
        _showGameOver();
      }
    });
  }

  void _showGameOver() {
    // Game over - show dialog with restart option
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        title: Text(
          'GAME OVER',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.red,
                offset: Offset(0, 0),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Consecutive Hits: $consecutiveHits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(
                    color: Colors.cyanAccent,
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  'PLAY AGAIN',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: Colors.cyanAccent,
            width: 2,
          ),
        ),
      ),
    );
  }

  // Improved Ball Bounce Logic with exponential speed increase
  void _bounceBall(bool isLeftPaddle) {
    // Increment consecutive hits
    consecutiveHits++;

    // Calculate where on the paddle the ball hit (0 = middle, -1 = top edge, 1 = bottom edge)
    double paddleY = isLeftPaddle ? paddle1Y : paddle2Y;
    double relativeIntersectY =
        (paddleY + paddleHeight / 2) - (ballY + ballSize / 2);
    double normalizedRelativeIntersectY =
        (relativeIntersectY / (paddleHeight / 2)).clamp(-1.0, 1.0);

    // Calculate bounce angle (maximum of 75 degrees)
    double bounceAngle = normalizedRelativeIntersectY *
        (math.pi * 5 / 12); // 75 degrees in radians

    // Calculate current speed of the ball
    double currentSpeed =
        math.sqrt(ballSpeedX * ballSpeedX + ballSpeedY * ballSpeedY);

    // Exponentially increase speed based on consecutive hits
    // Using the base multiplier to the power of consecutive hits, with a maximum cap
    double speedMultiplier =
        math.pow(baseSpeedMultiplier, consecutiveHits).toDouble();
    double newSpeed =
        math.min(initialBallSpeed * speedMultiplier, maxBallSpeed);

    // Set new direction and speed
    ballSpeedX = newSpeed * math.cos(bounceAngle) * (isLeftPaddle ? 1 : -1);
    ballSpeedY = newSpeed * -math.sin(bounceAngle);

    // Ensure ball doesn't get stuck in paddle
    if (isLeftPaddle) {
      ballX = paddleWidth;
    } else {
      ballX = screenSize.width - paddleWidth - ballSize;
    }

    _triggerHitEffect(
        isLeftPaddle ? paddleWidth : screenSize.width - paddleWidth,
        ballY + ballSize / 2);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!isGameRunning) return;

    final gameAreaHeight = screenSize.height * 0.7;
    final gameAreaTop = (screenSize.height - gameAreaHeight) / 2;
    final gameAreaBottom = gameAreaTop + gameAreaHeight;

    setState(() {
      paddle1Y += details.delta.dy;
      paddle1Y = paddle1Y.clamp(gameAreaTop, gameAreaBottom - paddleHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
                'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?ixlib=rb-1.2.1&auto=format&fit=crop&w=1351&q=80'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.indigo.withOpacity(0.5),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                _buildHeader(),
                _buildGameArea(),
                _buildHitEffect(),
                _buildHitCounter(), // Hit counter instead of score
                if (!isGameRunning && !isCountingDown) _buildStartButton(),
                if (isCountingDown) _buildCountdown(),
                // Back button
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        gameTimer?.cancel();
                        countdownTimer?.cancel();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                // Reset button
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _resetGame,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'COSMIC PONG',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            color: Colors.white,
            letterSpacing: 3,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.blue,
                offset: Offset(0, 0),
              ),
              Shadow(
                blurRadius: 20.0,
                color: Colors.purple,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    final gameAreaHeight = screenSize.height * 0.7;

    return Positioned(
      top: (screenSize.height - gameAreaHeight) / 2,
      left: 0,
      right: 0,
      height: gameAreaHeight,
      child: GestureDetector(
        onVerticalDragUpdate: isGameRunning ? _onDragUpdate : null,
        child: Container(
          width: screenSize.width,
          height: gameAreaHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ScaleTransition(
            scale: _introAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Center line
                  Center(
                    child: Container(
                      width: 2,
                      height: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: List.generate(
                              (constraints.maxHeight / 20).floor(),
                              (index) => Container(
                                height: 10,
                                width: 2,
                                color: index % 2 == 0
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.transparent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Ball
                  Positioned(
                    left: ballX,
                    top: ballY - ((screenSize.height - gameAreaHeight) / 2),
                    child: Container(
                      width: ballSize,
                      height: ballSize,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Colors.white, Colors.cyanAccent],
                          center: Alignment(-0.3, -0.3),
                          focal: Alignment(-0.2, -0.2),
                          radius: 0.8,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Left paddle (Player 1)
                  Positioned(
                    left: 0,
                    top: paddle1Y - ((screenSize.height - gameAreaHeight) / 2),
                    child: Container(
                      width: paddleWidth,
                      height: paddleHeight,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.blue, Colors.lightBlueAccent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right paddle (Player 2 / AI)
                  Positioned(
                    right: 0,
                    top: paddle2Y - ((screenSize.height - gameAreaHeight) / 2),
                    child: Container(
                      width: paddleWidth,
                      height: paddleHeight,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.red, Colors.orangeAccent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitEffect() {
    if (hitEffectX == null || hitEffectY == null || hitEffectOpacity <= 0) {
      return Container();
    }

    return Positioned(
      left: hitEffectX! - 30,
      top: hitEffectY! - 30,
      child: AnimatedOpacity(
        opacity: hitEffectOpacity,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.cyanAccent.withOpacity(0.6),
                Colors.transparent
              ],
              stops: const [0.1, 0.4, 1.0],
            ),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // Replace score display with hit counter
  Widget _buildHitCounter() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.purple.withOpacity(0.7),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HITS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                consecutiveHits.toString(),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _getHitCountColor(),
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: _getHitCountColor(),
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Color for hit counter - changes based on number of hits
  Color _getHitCountColor() {
    if (consecutiveHits >= 30) return Colors.red;
    if (consecutiveHits >= 20) return Colors.orange;
    if (consecutiveHits >= 10) return Colors.yellow;
    if (consecutiveHits >= 5) return Colors.green;
    return Colors.cyanAccent;
  }

  Widget _buildStartButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _startGame,
          icon: const Icon(Icons.sports_volleyball),
          label: const Text('START GAME'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            backgroundColor: Colors.indigo.withOpacity(0.8),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(
                color: Colors.cyanAccent.withOpacity(0.8),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.8),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            countdownValue.toString(),
            style: TextStyle(
              fontSize: 70,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: countdownValue == 3
                      ? Colors.red
                      : (countdownValue == 2 ? Colors.yellow : Colors.green),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

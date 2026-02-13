import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '六边形物理弹跳',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const HexagonBouncePage(title: '六边形物理弹跳'),
    );
  }
}

// 六边形物理弹跳页面
class HexagonBouncePage extends StatefulWidget {
  const HexagonBouncePage({super.key, required this.title});

  final String title;

  @override
  State<HexagonBouncePage> createState() => _HexagonBouncePageState();
}

// 扩展颜色调色板
class AppColors {
  // 主色调 - 深邃宇宙
  static const Color deepSpace = Color(0xFF0A0A0F);
  static const Color cosmicPurple = Color(0xFF1A1025);
  static const Color nebulaBlue = Color(0xFF0F1729);
  
  // 霓虹强调色
  static const Color neonCyan = Color(0xFF00F5FF);
  static const Color neonMagenta = Color(0xFFFF00E5);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color neonOrange = Color(0xFFFF6B35);
  
  // 功能色
  static const Color speedColor = neonMagenta;
  static const Color energyColor = neonCyan;
  
  // 渐变组合
  static const List<Color> hexagonGradient = [
    Color(0xFF8B5CF6),
    Color(0xFF00F5FF),
  ];
  
  static const List<Color> ballGradient = [
    Color(0xFFFF00E5),
    Color(0xFFFF6B35),
  ];
}

// 六边形物理弹跳页面状态
class _HexagonBouncePageState extends State<HexagonBouncePage> with SingleTickerProviderStateMixin {
  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  // 动画控制器
  late AnimationController _controller;
  // 六边形旋转角度
  double _hexagonRotation = 0;
  // 小球位置
  Offset _ballPosition = const Offset(0, 0);
  // 小球速度
  Offset _ballVelocity = const Offset(80, 0);
  // 重力加速度
  final double _gravity = 250.0;
  // 摩擦系数
  final double _friction = 0.995;
  // 弹性系数
  final double _restitution = 0.85;
  // 六边形半径
  double _hexagonRadius = 150.0;
  // 小球半径
  final double _ballRadius = 18.0;
  // 上一帧时间
  DateTime? _lastTime;
  // 小球轨迹点
  final List<TrailPoint> _trailPoints = [];
  // 最大轨迹点数量
  final int _maxTrailPoints = 15;
  // 碰撞粒子
  final List<CollisionParticle> _particles = [];
  // 能量值（基于速度计算）
  double _energy = 0;
  // 碰撞次数
  int _collisionCount = 0;
  // 是否显示统计面板
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器 - 更新为10秒旋转一周，更舒缓
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    // 监听动画值变化，更新六边形旋转角度
    _controller.addListener(() {
      setState(() {
        _hexagonRotation = _controller.value * 2 * math.pi;
      });
    });
    
    // 设置帧回调，更新小球位置
    WidgetsBinding.instance.addPostFrameCallback(_updateBall);
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // 更新小球位置和速度
  void _updateBall(Duration timeStamp) {
    final DateTime now = DateTime.now();
    _lastTime ??= now;
    
    // 计算时间差（秒）
    final double dt = (now.difference(_lastTime!).inMicroseconds / 1000000).clamp(0.0, 0.05);
    _lastTime = now;
    
    // 应用重力
    _ballVelocity += Offset(0, _gravity * dt);
    
    // 应用摩擦力
    _ballVelocity *= _friction;
    
    // 更新位置
    final Offset newPosition = _ballPosition + _ballVelocity * dt;
    
    // 检测碰撞
    final CollisionResult result = _checkCollision(newPosition);
    
    // 更新碰撞计数和能量
    if (result.collided) {
      _collisionCount++;
    }
    _energy = (_ballVelocity.distance / 500).clamp(0.0, 1.0);
    
    // 添加轨迹点
    if (_trailPoints.length >= _maxTrailPoints) {
      _trailPoints.removeAt(0);
    }
    _trailPoints.add(TrailPoint(
      position: _ballPosition,
      radius: _ballRadius,
      opacity: 0.9,
      timestamp: DateTime.now(),
    ));
    
    // 更新粒子
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].lifetime <= 0) {
        _particles.removeAt(i);
      }
    }
    
    setState(() {
      _ballPosition = result.position;
    });
    
    // 继续下一帧更新
    WidgetsBinding.instance.addPostFrameCallback(_updateBall);
  }

  // 检测与六边形边界的碰撞
  CollisionResult _checkCollision(Offset newPosition) {
    // 获取六边形的六个顶点
    final List<Offset> vertices = _getHexagonVertices();
    
    // 获取六边形的六条边
    final List<List<Offset>> edges = [];
    for (int i = 0; i < 6; i++) {
      edges.add([vertices[i], vertices[(i + 1) % 6]]);
    }
    
    // 检查是否与任何边碰撞
    Offset adjustedPosition = newPosition;
    bool collided = false;
    
    for (final List<Offset> edge in edges) {
      if (_intersectsEdge(edge[0], edge[1], _ballPosition, newPosition, _ballRadius)) {
        // 计算边的法向量
        final Offset edgeVector = edge[1] - edge[0];
        // 手动计算法向量并归一化
        final Offset normalRaw = Offset(-edgeVector.dy, edgeVector.dx);
        final double normalLength = math.sqrt(normalRaw.dx * normalRaw.dx + normalRaw.dy * normalRaw.dy);
        final Offset normal = Offset(normalRaw.dx / normalLength, normalRaw.dy / normalLength);
        
        // 调整位置，使球不穿过边界
        final double penetration = _ballRadius - (newPosition - _closestPointOnLine(edge[0], edge[1], newPosition)).distance;
        if (penetration > 0) {
          adjustedPosition = newPosition + normal * penetration;
        }
        
        // 计算反弹速度
        final double dotProduct = _ballVelocity.dx * normal.dx + _ballVelocity.dy * normal.dy;
        _ballVelocity -= normal * (2 * dotProduct * _restitution);
        
        // 随机速度增量 (3-12%)
        final double speedBoost = 1.0 + (0.03 + math.Random().nextDouble() * 0.09);
        _ballVelocity *= speedBoost;
        
        // 限制最大速度
        final double maxSpeed = 600.0;
        if (_ballVelocity.distance > maxSpeed) {
          _ballVelocity = _ballVelocity * (maxSpeed / _ballVelocity.distance);
        }
        
        // 添加碰撞粒子
        _addCollisionParticles(adjustedPosition, normal);
        
        collided = true;
        break;
      }
    }
    
    return CollisionResult(position: adjustedPosition, collided: collided);
  }

  // 添加碰撞粒子
  void _addCollisionParticles(Offset position, Offset normal) {
    final int particleCount = 12 + math.Random().nextInt(10); // 12-21个粒子
    
    for (int i = 0; i < particleCount; i++) {
      final double angle = math.atan2(normal.dy, normal.dx) + 
          (math.Random().nextDouble() - 0.5) * math.pi * 0.7;
      
      final double speed = 80.0 + math.Random().nextDouble() * 150.0;
      final Offset velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      
      // 随机颜色
      final List<Color> colors = [
        AppColors.neonCyan,
        AppColors.neonMagenta,
        AppColors.neonViolet,
        AppColors.neonOrange,
        Colors.white,
      ];
      final Color color = colors[math.Random().nextInt(colors.length)];
      
      _particles.add(CollisionParticle(
        position: position,
        velocity: velocity,
        color: color,
        size: 2.0 + math.Random().nextDouble() * 4.0,
        lifetime: 0.4 + math.Random().nextDouble() * 0.6,
      ));
    }
  }

  // 获取旋转后的六边形顶点
  List<Offset> _getHexagonVertices() {
    final List<Offset> vertices = [];
    final double centerX = 0;
    final double centerY = 0;
    
    for (int i = 0; i < 6; i++) {
      final double angle = i * (math.pi / 3) + _hexagonRotation;
      final double x = centerX + _hexagonRadius * math.cos(angle);
      final double y = centerY + _hexagonRadius * math.sin(angle);
      vertices.add(Offset(x, y));
    }
    
    return vertices;
  }

  // 检查线段与圆是否相交
  bool _intersectsEdge(Offset lineStart, Offset lineEnd, Offset ballStart, Offset ballEnd, double radius) {
    // 找到线段上距离球心最近的点
    final Offset closestPoint = _closestPointOnLine(lineStart, lineEnd, ballEnd);
    
    // 检查最近点与球心的距离是否小于球半径
    return (closestPoint - ballEnd).distance < radius;
  }

  // 找到线段上距离点最近的点
  Offset _closestPointOnLine(Offset lineStart, Offset lineEnd, Offset point) {
    final Offset lineVector = lineEnd - lineStart;
    final double lineLength = lineVector.distance;
    final Offset lineDirection = lineVector / lineLength;
    
    final Offset pointVector = point - lineStart;
    double projection = pointVector.dx * lineDirection.dx + pointVector.dy * lineDirection.dy;
    projection = projection.clamp(0, lineLength);
    
    return lineStart + lineDirection * projection;
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸，调整六边形大小
    final Size screenSize = MediaQuery.of(context).size;
    _hexagonRadius = math.min(screenSize.width, screenSize.height) * 0.32;
    
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 3,
            shadows: [
              Shadow(
                color: AppColors.neonCyan.withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        actions: [
          // 统计面板开关
          IconButton(
            icon: Icon(
              _showStats ? Icons.analytics : Icons.analytics_outlined,
              color: AppColors.neonCyan,
            ),
            onPressed: () {
              setState(() {
                _showStats = !_showStats;
              });
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              AppColors.cosmicPurple,
              AppColors.nebulaBlue,
              AppColors.deepSpace,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景星空效果
            CustomPaint(
              painter: StarsPainter(),
            ),
            // 背景网格
            CustomPaint(
              painter: GridPainter(),
            ),
            // 游戏元素
            CustomPaint(
              painter: HexagonPainter(
                hexagonRotation: _hexagonRotation,
                hexagonRadius: _hexagonRadius,
                ballPosition: _ballPosition,
                ballRadius: _ballRadius,
                trailPoints: _trailPoints,
                particles: _particles,
              ),
            ),
            // 统计信息面板
            if (_showStats) ...[
              // 速度显示 - 左下角
              Positioned(
                bottom: 30,
                left: 20,
                child: _buildStatCard(
                  label: 'VELOCITY',
                  value: '${_ballVelocity.distance.toStringAsFixed(0)}',
                  unit: 'px/s',
                  color: AppColors.speedColor,
                  icon: Icons.speed,
                ),
              ),
              // 能量显示 - 右下角
              Positioned(
                bottom: 30,
                right: 20,
                child: _buildStatCard(
                  label: 'ENERGY',
                  value: '${(_energy * 100).toStringAsFixed(0)}',
                  unit: '%',
                  color: AppColors.energyColor,
                  icon: Icons.bolt,
                ),
              ),
              // 碰撞次数 - 顶部
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.deepSpace.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.neonViolet.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grain,
                          color: AppColors.neonViolet,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'COLLISIONS: $_collisionCount',
                          style: TextStyle(
                            color: AppColors.neonViolet,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            // 播放音效
            try {
              await _audioPlayer.play(AssetSource('sound-effect-1741695647399.mp3'));
            } catch (e) {
              // 忽略音频错误
            }
            // 重置小球位置和速度
            setState(() {
              _ballPosition = const Offset(0, 0);
              _ballVelocity = Offset(
                math.Random().nextDouble() * 300 - 150,
                math.Random().nextDouble() * 300 - 150,
              );
              _trailPoints.clear();
              _particles.clear();
              _collisionCount = 0;
            });
          },
          tooltip: '重置',
          elevation: 0,
          backgroundColor: AppColors.deepSpace,
          foregroundColor: AppColors.neonCyan,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.neonCyan.withOpacity(0.2),
                  AppColors.neonViolet.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.neonCyan.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.refresh, size: 28),
          ),
        ),
      ),
    );
  }

  // 构建统计卡片
  Widget _buildStatCard({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepSpace.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 碰撞结果类
class CollisionResult {
  final Offset position;
  final bool collided;

  CollisionResult({required this.position, required this.collided});
}

// 轨迹点类
class TrailPoint {
  final Offset position;
  final double radius;
  final double opacity;
  final DateTime timestamp;

  TrailPoint({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.timestamp,
  });
}

// 碰撞粒子类
class CollisionParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double lifetime;

  CollisionParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifetime,
  });

  void update(double dt) {
    position += velocity * dt;
    velocity *= 0.93; // 粒子减速
    lifetime -= dt;
  }
}

// 星空背景绘制器
class StarsPainter extends CustomPainter {
  final math.Random _random = math.Random(42); // 固定种子
  
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制星星
    for (int i = 0; i < 80; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final double starSize = _random.nextDouble() * 1.5 + 0.5;
      final double opacity = _random.nextDouble() * 0.5 + 0.2;
      
      canvas.drawCircle(
        Offset(x, y),
        starSize,
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
    }
    
    // 绘制一些较大的星星（带光晕）
    for (int i = 0; i < 15; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final double starSize = _random.nextDouble() * 2 + 1;
      final double opacity = _random.nextDouble() * 0.3 + 0.1;
      
      // 光晕
      canvas.drawCircle(
        Offset(x, y),
        starSize * 3,
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      
      // 星星核心
      canvas.drawCircle(
        Offset(x, y),
        starSize,
        Paint()
          ..color = Colors.white.withOpacity(opacity * 2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(StarsPainter oldDelegate) => false;
}

// 背景网格绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 网格间距
    const double spacing = 50.0;
    
    // 绘制水平线
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 绘制垂直线
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
    
    // 绘制中心强调线
    final Paint centerPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // 水平中线
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
    
    // 垂直中线
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

// 六边形和小球的绘制器
class HexagonPainter extends CustomPainter {
  final double hexagonRotation;
  final double hexagonRadius;
  final Offset ballPosition;
  final double ballRadius;
  final List<TrailPoint> trailPoints;
  final List<CollisionParticle> particles;

  HexagonPainter({
    required this.hexagonRotation,
    required this.hexagonRadius,
    required this.ballPosition,
    required this.ballRadius,
    required this.trailPoints,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 移动画布原点到中心
    canvas.translate(size.width / 2, size.height / 2);
    
    // 绘制轨迹点
    for (int i = 0; i < trailPoints.length; i++) {
      final TrailPoint point = trailPoints[i];
      final double progress = i / trailPoints.length;
      final double opacity = progress * point.opacity * 0.6;
      final double trailRadius = ballRadius * progress * 0.8;
      
      // 轨迹光晕
      canvas.drawCircle(
        point.position,
        trailRadius * 2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.neonCyan.withOpacity(opacity),
              AppColors.neonCyan.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: point.position, radius: trailRadius * 2))
          ..style = PaintingStyle.fill,
      );
      
      // 轨迹核心
      canvas.drawCircle(
        point.position,
        trailRadius,
        Paint()
          ..color = AppColors.neonCyan.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
    }
    
    // 绘制碰撞粒子
    for (final particle in particles) {
      final double opacity = (particle.lifetime * 2).clamp(0.0, 1.0);
      
      // 粒子光晕
      canvas.drawCircle(
        particle.position,
        particle.size * 2,
        Paint()
          ..color = particle.color.withOpacity(opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      
      // 粒子核心
      canvas.drawCircle(
        particle.position,
        particle.size,
        Paint()
          ..color = particle.color.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
    }
    
    // 创建六边形渐变填充
    final Gradient hexagonGradient = RadialGradient(
      colors: [
        AppColors.neonViolet.withOpacity(0.15),
        AppColors.neonCyan.withOpacity(0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    
    final Paint hexagonPaint = Paint()
      ..shader = hexagonGradient.createShader(
          Rect.fromCircle(center: Offset.zero, radius: hexagonRadius * 1.1))
      ..style = PaintingStyle.fill;
    
    // 六边形边框 - 双层效果
    final Paint hexagonBorderPaint = Paint()
      ..color = AppColors.neonCyan.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    final Paint hexagonBorderGlowPaint = Paint()
      ..color = AppColors.neonCyan.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    // 绘制六边形
    final Path hexagonPath = Path();
    final List<Offset> vertices = [];
    
    for (int i = 0; i < 6; i++) {
      final double angle = i * (math.pi / 3) + hexagonRotation;
      final double x = hexagonRadius * math.cos(angle);
      final double y = hexagonRadius * math.sin(angle);
      vertices.add(Offset(x, y));
      
      if (i == 0) {
        hexagonPath.moveTo(x, y);
      } else {
        hexagonPath.lineTo(x, y);
      }
    }
    hexagonPath.close();
    
    // 填充六边形
    canvas.drawPath(hexagonPath, hexagonPaint);
    
    // 绘制发光边框
    canvas.drawPath(hexagonPath, hexagonBorderGlowPaint);
    
    // 绘制六边形边框
    canvas.drawPath(hexagonPath, hexagonBorderPaint);
    
    // 绘制六边形边缘光效 - 动态渐变
    for (int i = 0; i < 6; i++) {
      final Offset start = vertices[i];
      final Offset end = vertices[(i + 1) % 6];
      
      // 霓虹渐变边
      final Gradient edgeGradient = LinearGradient(
        colors: [
          AppColors.neonCyan.withOpacity(0.9),
          AppColors.neonMagenta.withOpacity(0.9),
          AppColors.neonCyan.withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      
      final Paint edgePaint = Paint()
        ..shader = edgeGradient.createShader(Rect.fromPoints(start, end))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
      
      canvas.drawLine(start, end, edgePaint);
      
      // 顶点发光
      for (final vertex in vertices) {
        canvas.drawCircle(
          vertex,
          4,
          Paint()
            ..color = AppColors.neonCyan.withOpacity(0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
    
    // 内部装饰六边形（较小，半透明）
    final Path innerHexagonPath = Path();
    final double innerRadius = hexagonRadius * 0.7;
    for (int i = 0; i < 6; i++) {
      final double angle = i * (math.pi / 3) + hexagonRotation;
      final double x = innerRadius * math.cos(angle);
      final double y = innerRadius * math.sin(angle);
      
      if (i == 0) {
        innerHexagonPath.moveTo(x, y);
      } else {
        innerHexagonPath.lineTo(x, y);
      }
    }
    innerHexagonPath.close();
    
    canvas.drawPath(
      innerHexagonPath,
      Paint()
        ..color = AppColors.neonViolet.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    
    // 小球阴影
    canvas.drawCircle(
      ballPosition + const Offset(4, 4),
      ballRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    
    // 小球外发光
    canvas.drawCircle(
      ballPosition,
      ballRadius * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.neonMagenta.withOpacity(0.3),
            AppColors.neonMagenta.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: ballPosition, radius: ballRadius * 1.8))
        ..style = PaintingStyle.fill,
    );
    
    // 小球渐变
    final Gradient ballGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [
        Colors.white,
        AppColors.neonMagenta,
        AppColors.neonOrange,
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    
    final Paint ballPaint = Paint()
      ..shader = ballGradient.createShader(
          Rect.fromCircle(center: ballPosition, radius: ballRadius))
      ..style = PaintingStyle.fill;
    
    // 绘制小球
    canvas.drawCircle(ballPosition, ballRadius, ballPaint);
    
    // 小球高光
    canvas.drawCircle(
      ballPosition - Offset(ballRadius * 0.35, ballRadius * 0.35),
      ballRadius * 0.25,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
    
    // 小球边缘光
    canvas.drawCircle(
      ballPosition,
      ballRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }
  
  @override
  bool shouldRepaint(HexagonPainter oldDelegate) {
    return oldDelegate.hexagonRotation != hexagonRotation ||
           oldDelegate.ballPosition != ballPosition ||
           oldDelegate.trailPoints.length != trailPoints.length ||
           oldDelegate.particles.length != particles.length;
  }
}

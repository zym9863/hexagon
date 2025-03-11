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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF06B6D4)),
        useMaterial3: true,
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
  Offset _ballVelocity = const Offset(50, 0);
  // 重力加速度
  final double _gravity = 200.0;
  // 摩擦系数
  final double _friction = 0.98;
  // 弹性系数
  final double _restitution = 0.8;
  // 六边形半径
  double _hexagonRadius = 150.0;
  // 小球半径
  final double _ballRadius = 15.0;
  // 上一帧时间
  DateTime? _lastTime;
  // 小球轨迹点
  final List<TrailPoint> _trailPoints = [];
  // 最大轨迹点数量
  final int _maxTrailPoints = 10;
  // 碰撞粒子
  final List<CollisionParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器 - 更新为8秒旋转一周
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
    final double dt = (now.difference(_lastTime!).inMicroseconds / 1000000);
    _lastTime = now;
    
    // 应用重力
    _ballVelocity += Offset(0, _gravity * dt);
    
    // 应用摩擦力
    _ballVelocity *= _friction;
    
    // 更新位置
    final Offset newPosition = _ballPosition + _ballVelocity * dt;
    
    // 检测碰撞
    final Offset adjustedPosition = _checkCollision(newPosition);
    
    // 添加轨迹点
    if (_trailPoints.length >= _maxTrailPoints) {
      _trailPoints.removeAt(0);
    }
    _trailPoints.add(TrailPoint(
      position: _ballPosition,
      radius: _ballRadius,
      opacity: 0.8,
    ));
    
    // 更新粒子
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].lifetime <= 0) {
        _particles.removeAt(i);
      }
    }
    
    setState(() {
      _ballPosition = adjustedPosition;
    });
    
    // 继续下一帧更新
    WidgetsBinding.instance.addPostFrameCallback(_updateBall);
  }

  // 检测与六边形边界的碰撞
  Offset _checkCollision(Offset newPosition) {
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
        
        // 随机速度增量 (5-15%)
        final double speedBoost = 1.0 + (0.05 + math.Random().nextDouble() * 0.1);
        _ballVelocity *= speedBoost;
        
        // Y轴速度每次减少3%
        _ballVelocity = Offset(_ballVelocity.dx, _ballVelocity.dy * 0.97);
        
        // 添加碰撞粒子
        _addCollisionParticles(adjustedPosition, normal);
        
        collided = true;
        break;
      }
    }
    
    return adjustedPosition;
  }

  // 添加碰撞粒子
  void _addCollisionParticles(Offset position, Offset normal) {
    final int particleCount = 8 + math.Random().nextInt(8); // 8-15个粒子
    
    for (int i = 0; i < particleCount; i++) {
      final double angle = math.atan2(normal.dy, normal.dx) + 
          (math.Random().nextDouble() - 0.5) * math.pi * 0.8;
      
      final double speed = 50.0 + math.Random().nextDouble() * 100.0;
      final Offset velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      
      _particles.add(CollisionParticle(
        position: position,
        velocity: velocity,
        color: const Color(0xFFF472B6),
        size: 2.0 + math.Random().nextDouble() * 3.0,
        lifetime: 0.3 + math.Random().nextDouble() * 0.5,
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
    _hexagonRadius = math.min(screenSize.width, screenSize.height) * 0.35;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // 深空蓝背景色
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF06B6D4), // 霓虹青色
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              stops: [0.0, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
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
              // 速度显示
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SPEED',
                        style: TextStyle(
                          color: const Color(0xFF06B6D4),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_ballVelocity.distance.toStringAsFixed(1)} px/s',
                        style: TextStyle(
                          color: const Color(0xFFF472B6),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 播放音效
          await _audioPlayer.play(AssetSource('sound-effect-1741695647399.mp3'));
          // 重置小球位置和速度
          setState(() {
            _ballPosition = const Offset(0, 0);
            _ballVelocity = Offset(
              math.Random().nextDouble() * 200 - 100,
              math.Random().nextDouble() * 200 - 100,
            );
            _trailPoints.clear();
            _particles.clear();
          });
        },
        tooltip: '重置小球',
        child: const Icon(Icons.refresh),
        elevation: 8.0,
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: const Color(0xFF0F172A),
      ),
    );
  }
}

// 轨迹点类
class TrailPoint {
  final Offset position;
  final double radius;
  final double opacity;

  TrailPoint({
    required this.position,
    required this.radius,
    required this.opacity,
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
    velocity *= 0.95; // 粒子减速
    lifetime -= dt;
  }
}

// 背景网格绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 网格间距
    const double spacing = 40.0;
    
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
      final double opacity = (i / trailPoints.length) * point.opacity;
      
      canvas.drawCircle(
        point.position,
        point.radius * (i / trailPoints.length),
        Paint()
          ..color = const Color(0xFF06B6D4).withOpacity(opacity)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    
    // 绘制碰撞粒子
    for (final particle in particles) {
      canvas.drawCircle(
        particle.position,
        particle.size,
        Paint()
          ..color = particle.color.withOpacity(particle.lifetime * 2)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
    
    // 创建六边形渐变填充
    final Gradient hexagonGradient = RadialGradient(
      colors: [
        const Color(0xFF06B6D4).withOpacity(0.2),
        const Color(0xFF06B6D4).withOpacity(0.05),
      ],
      stops: const [0.4, 1.0],
    );
    
    final Paint hexagonPaint = Paint()
      ..shader = hexagonGradient.createShader(
          Rect.fromCircle(center: Offset.zero, radius: hexagonRadius))
      ..style = PaintingStyle.fill;
    
    // 六边形边框
    final Paint hexagonBorderPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
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
    
    // 绘制六边形边框
    canvas.drawPath(hexagonPath, hexagonBorderPaint);
    
    // 绘制六边形边缘光效
    for (int i = 0; i < 6; i++) {
      final Offset start = vertices[i];
      final Offset end = vertices[(i + 1) % 6];
      
      final Gradient edgeGradient = LinearGradient(
        colors: [
          const Color(0xFF06B6D4).withOpacity(0.8),
          const Color(0xFFF472B6).withOpacity(0.8),
          const Color(0xFF06B6D4).withOpacity(0.8),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      
      final Paint edgePaint = Paint()
        ..shader = edgeGradient.createShader(Rect.fromPoints(start, end))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);
      
      canvas.drawLine(start, end, edgePaint);
    }
    
    // 小球渐变和阴影
    final Gradient ballGradient = RadialGradient(
      colors: [
        const Color(0xFFF472B6),
        const Color(0xFFF472B6).withOpacity(0.7),
      ],
      stops: const [0.2, 1.0],
    );
    
    final Paint ballPaint = Paint()
      ..shader = ballGradient.createShader(
          Rect.fromCircle(center: ballPosition, radius: ballRadius))
      ..style = PaintingStyle.fill;
    
    // 绘制小球阴影
    canvas.drawCircle(
      ballPosition + const Offset(2, 2),
      ballRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    
    // 绘制小球
    canvas.drawCircle(ballPosition, ballRadius, ballPaint);
    
    // 绘制小球发光效果
    canvas.drawCircle(
      ballPosition,
      ballRadius * 1.2,
      Paint()
        ..color = const Color(0xFFF472B6).withOpacity(0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    
    // 绘制小球高光
    canvas.drawCircle(
      ballPosition - Offset(ballRadius * 0.3, ballRadius * 0.3),
      ballRadius * 0.2,
      Paint()..color = Colors.white.withOpacity(0.7),
    );
  }
  
  @override
  bool shouldRepaint(HexagonPainter oldDelegate) {
    return oldDelegate.hexagonRotation != hexagonRotation ||
           oldDelegate.ballPosition != ballPosition ||
           oldDelegate.trailPoints != trailPoints ||
           oldDelegate.particles != particles;
  }
}

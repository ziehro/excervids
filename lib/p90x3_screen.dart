import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'p90x3_data.dart';
import 'dart:math' as math;
import 'dart:io';
import 'video_player_screen.dart';

class P90X3Screen extends StatefulWidget {
  const P90X3Screen({Key? key}) : super(key: key);

  @override
  State<P90X3Screen> createState() => _P90X3ScreenState();
}

class _P90X3ScreenState extends State<P90X3Screen> with SingleTickerProviderStateMixin {
  String? selectedProgram;
  int currentDay = 1;
  Set<int> completedDays = {};
  DateTime? programStartDate;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadProgress();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedProgram = prefs.getString('p90x3_program');
      currentDay = prefs.getInt('p90x3_current_day') ?? 1;
      final completed = prefs.getStringList('p90x3_completed') ?? [];
      completedDays = completed.map((e) => int.parse(e)).toSet();
      final startStr = prefs.getString('p90x3_start_date');
      if (startStr != null) {
        programStartDate = DateTime.parse(startStr);
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('p90x3_program', selectedProgram ?? '');
    await prefs.setInt('p90x3_current_day', currentDay);
    await prefs.setStringList(
      'p90x3_completed',
      completedDays.map((e) => e.toString()).toList(),
    );
    if (programStartDate != null) {
      await prefs.setString('p90x3_start_date', programStartDate!.toIso8601String());
    }
  }

  void _selectProgram(String program) {
    setState(() {
      selectedProgram = program;
      currentDay = 1;
      completedDays.clear();
      programStartDate = DateTime.now();
    });
    _saveProgress();
  }

  void _markDayComplete(int day) {
    setState(() {
      if (completedDays.contains(day)) {
        completedDays.remove(day);
      } else {
        completedDays.add(day);
        _animationController.forward(from: 0);
        if (day == currentDay && currentDay < 90) {
          currentDay++;
        }
      }
    });
    _saveProgress();
  }

  String _getVideoFilename(String workoutName, int day) {
    final cleanName = workoutName.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('x3_', '')
        .replaceAll('or_dynamix', 'dynamix');
    return '${day.toString().padLeft(2, '0')}_$cleanName.mp4';
  }

  Future<void> _playVideo(String workoutName, int day) async {
    if (workoutName == 'Rest' || workoutName.contains('Rest')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rest day - no video to play'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.blueGrey,
        ),
      );
      return;
    }

    // Search for video file in movies directory
    final moviesDirs = [
      Directory('/storage/emulated/0/Movies'),
      Directory('/storage/emulated/0/Download/ExcerVids'),
      Directory('/storage/emulated/0/DCIM/Camera'),
    ];

    File? videoFile;

    // Try different filename patterns
    final patterns = [
      _getVideoFilename(workoutName, day),
      '${workoutName.toLowerCase().replaceAll(' ', '_')}.mp4',
      '${workoutName.toLowerCase().replaceAll(' ', '-')}.mp4',
      workoutName,
    ];

    for (final dir in moviesDirs) {
      if (!await dir.exists()) continue;

      try {
        final files = await dir.list().toList();
        for (var entity in files) {
          if (entity is File) {
            final filename = entity.path.split('/').last.toLowerCase();

            // Check if filename matches any pattern
            for (final pattern in patterns) {
              if (filename.contains(pattern.toLowerCase()) ||
                  pattern.toLowerCase().contains(filename.replaceAll('.mp4', ''))) {
                videoFile = entity;
                break;
              }
            }
            if (videoFile != null) break;
          }
        }
      } catch (e) {
        print('Error searching ${dir.path}: $e');
      }
      if (videoFile != null) break;
    }

    if (videoFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video not found: $workoutName\nLooking for: ${patterns[0]}'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Navigate to video player
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoFile: videoFile!),
        ),
      );
    }
  }

  Color _getWorkoutColor(String workout) {
    if (workout.contains('Rest') || workout.contains('Dynamix')) {
      return Colors.blueGrey;
    } else if (workout.contains('Yoga') || workout.contains('Pilates') ||
        workout.contains('Isometrix')) {
      return Colors.purple;
    } else if (workout.contains('CVX') || workout.contains('MMX') ||
        workout.contains('Agility')) {
      return Colors.deepOrange;
    } else if (workout.contains('Eccentric') || workout.contains('Challenge')) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  IconData _getWorkoutIcon(String workout) {
    if (workout.contains('Rest') || workout.contains('Dynamix')) {
      return Icons.bed_rounded;
    } else if (workout.contains('Yoga') || workout.contains('Pilates')) {
      return Icons.self_improvement_rounded;
    } else if (workout.contains('CVX') || workout.contains('Agility')) {
      return Icons.directions_run_rounded;
    } else {
      return Icons.fitness_center_rounded;
    }
  }

  void _showDayDialog(int day, String workout, bool isCompleted, bool isRest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getWorkoutColor(workout).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getWorkoutIcon(workout),
                color: _getWorkoutColor(workout),
              ),
            ),
            const SizedBox(width: 12),
            Text('Day $day'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isCompleted ? Colors.green : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.pending,
                    color: isCompleted ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCompleted ? 'Completed' : 'Pending',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isRest)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _playVideo(workout, day);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getWorkoutColor(workout),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () {
              _markDayComplete(day);
              Navigator.pop(context);
            },
            icon: Icon(isCompleted ? Icons.close : Icons.check),
            label: Text(isCompleted ? 'Undo' : 'Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedProgram == null) {
      return _buildProgramSelection();
    }

    final todayWorkout = P90X3Schedule.getWorkoutForDay(selectedProgram!, currentDay);
    final completedCount = completedDays.length;
    final progressPercent = completedCount / 90;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getWorkoutColor(todayWorkout).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'P90X3',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            selectedProgram!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_rounded, color: Colors.orange),
                                SizedBox(width: 12),
                                Text('Reset Program?'),
                              ],
                            ),
                            content: const Text('This will clear all your progress and start fresh.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedProgram = null;
                                    completedDays.clear();
                                    currentDay = 1;
                                    programStartDate = null;
                                  });
                                  _saveProgress();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Progress Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCircularStat('Day', currentDay, 90, Colors.blue),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.grey[200],
                      ),
                      _buildCircularStat('Done', completedCount, 90, Colors.green),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.grey[200],
                      ),
                      _buildPercentStat('Goal', progressPercent, Colors.orange),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Today's Workout Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getWorkoutColor(todayWorkout),
                        _getWorkoutColor(todayWorkout).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _getWorkoutColor(todayWorkout).withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _getWorkoutIcon(todayWorkout),
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TODAY',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'Day $currentDay of 90',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (completedDays.contains(currentDay))
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          todayWorkout,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: todayWorkout.contains('Rest')
                                    ? null
                                    : () => _playVideo(todayWorkout, currentDay),
                                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                label: const Text(
                                  'PLAY WORKOUT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _getWorkoutColor(todayWorkout),
                                  disabledBackgroundColor: Colors.white.withOpacity(0.3),
                                  disabledForegroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (_animationController.value * 0.2),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        completedDays.contains(currentDay)
                                            ? Icons.check_circle_rounded
                                            : Icons.check_circle_outline_rounded,
                                        size: 36,
                                      ),
                                      color: Colors.white,
                                      onPressed: () => _markDayComplete(currentDay),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Calendar Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '90-Day Calendar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        _buildLegendItem(Colors.green, 'Done'),
                        const SizedBox(width: 12),
                        _buildLegendItem(Colors.blue, 'Today'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Calendar Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: 90,
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        final workout = P90X3Schedule.getWorkoutForDay(selectedProgram!, day);
                        final isCompleted = completedDays.contains(day);
                        final isToday = day == currentDay;
                        final isRest = workout.contains('Rest') || workout.contains('Dynamix');

                        return InkWell(
                          onTap: () => _showDayDialog(day, workout, isCompleted, isRest),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isCompleted
                                  ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade600,
                                ],
                              )
                                  : isToday
                                  ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              )
                                  : null,
                              color: isCompleted || isToday
                                  ? null
                                  : isRest
                                  ? Colors.grey[100]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isToday
                                    ? Colors.blue.shade300
                                    : isCompleted
                                    ? Colors.green.shade300
                                    : Colors.grey.shade200,
                                width: 2,
                              ),
                              boxShadow: (isToday || isCompleted)
                                  ? [
                                BoxShadow(
                                  color: (isCompleted
                                      ? Colors.green
                                      : Colors.blue).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    day.toString(),
                                    style: TextStyle(
                                      color: isCompleted || isToday
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (isCompleted)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularStat(String label, int value, int max, Color color) {
    final percentage = value / max;
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 6,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Center(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '/$max',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildPercentStat(String label, double percentage, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 6,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${(percentage * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Complete',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgramSelection() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Choose Your',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey,
                      ),
                    ),
                    const Text(
                      'P90X3 Program',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the 90-day program that matches your goals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildProgramCard(
                      'Classic',
                      'Balanced strength and cardio',
                      'Build muscle while burning fat',
                      Icons.fitness_center_rounded,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildProgramCard(
                      'Lean',
                      'Maximum fat burning',
                      'Focus on cardio and agility',
                      Icons.local_fire_department_rounded,
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildProgramCard(
                      'Mass',
                      'Muscle building focus',
                      'Heavy resistance training',
                      Icons.sports_gymnastics_rounded,
                      Colors.red,
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

  Widget _buildProgramCard(
      String name,
      String subtitle,
      String description,
      IconData icon,
      Color color,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectProgram(name),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
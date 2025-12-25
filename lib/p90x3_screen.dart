import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'p90x3_data.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'video_player_screen.dart';
import 'main.dart';

// Color scheme
class P90X3Colors {
  static const primary = Color(0xFF0066FF);
  static const secondary = Color(0xFFFF6B00);
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFFFC107);
  static const gradientStart = Color(0xFF667eea);
  static const gradientEnd = Color(0xFF764ba2);
  static const cardBg = Color(0xFFF8F9FA);
}

class P90X3Screen extends StatefulWidget {
  const P90X3Screen({Key? key}) : super(key: key);

  @override
  State<P90X3Screen> createState() => _P90X3ScreenState();
}

class _P90X3ScreenState extends State<P90X3Screen> with SingleTickerProviderStateMixin {
  String? selectedProgram;
  int currentDay = 1;
  Set<int> completedDays = {};
  Set<int> completedAbRipper = {};
  Set<int> daysWithAbRipper = {};
  Map<int, String> workoutWeights = {}; // Store weights by day
  DateTime? programStartDate;
  bool alignRestToSunday = false;
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
      final completedAb = prefs.getStringList('p90x3_completed_ab') ?? [];
      completedAbRipper = completedAb.map((e) => int.parse(e)).toSet();
      final abRipper = prefs.getStringList('p90x3_ab_ripper') ?? [];
      daysWithAbRipper = abRipper.map((e) => int.parse(e)).toSet();
      alignRestToSunday = prefs.getBool('p90x3_align_rest_sunday') ?? false;
      final startStr = prefs.getString('p90x3_start_date');
      if (startStr != null) {
        programStartDate = DateTime.parse(startStr);
      }

      // Load weights
      final weightsJson = prefs.getString('p90x3_weights');
      if (weightsJson != null) {
        final decoded = Map<String, dynamic>.from(
            const JsonDecoder().convert(weightsJson)
        );
        workoutWeights = decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));
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
    await prefs.setStringList(
      'p90x3_completed_ab',
      completedAbRipper.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      'p90x3_ab_ripper',
      daysWithAbRipper.map((e) => e.toString()).toList(),
    );
    await prefs.setBool('p90x3_align_rest_sunday', alignRestToSunday);
    if (programStartDate != null) {
      await prefs.setString('p90x3_start_date', programStartDate!.toIso8601String());
    }

    // Save weights
    final weightsMap = workoutWeights.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('p90x3_weights', const JsonEncoder().convert(weightsMap));
  }

  void _selectProgram(String program) async {
    // Ask user if they want rest days on Sunday
    final alignToSunday = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Calendar Alignment',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Do you want rest days to fall on Sundays?\n\n'
              'This will adjust your program so rest days align with weekends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, start at Day 1'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: P90X3Colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, align to Sunday',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (alignToSunday == null) return;

    setState(() {
      selectedProgram = program;
      completedDays.clear();
      completedAbRipper.clear();
      alignRestToSunday = alignToSunday;

      // Auto-enable Ab Ripper for all eligible days
      daysWithAbRipper.clear();
      final eligibleDays = P90X3Schedule.abRipperDays[program] ?? [];
      daysWithAbRipper.addAll(eligibleDays);

      // Normalize today to midnight
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      if (alignToSunday) {
        // We want Day 7, 14, 21, etc. to fall on Sunday
        // So Day 1 should be on Monday
        final currentWeekday = normalizedToday.weekday; // 1=Monday, 7=Sunday

        // Days back to most recent Monday (0 if today is Monday)
        final daysBackToMonday = (currentWeekday - 1) % 7;

        // Program started on that Monday (normalized to midnight)
        programStartDate = normalizedToday.subtract(Duration(days: daysBackToMonday));

        // Current day = days since that Monday + 1
        currentDay = daysBackToMonday + 1;
      } else {
        programStartDate = normalizedToday;
        currentDay = 1;
      }
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

  void _goToPreviousDay() {
    if (currentDay > 1) {
      setState(() {
        currentDay--;
      });
      _saveProgress();
    }
  }

  void _goToNextDay() {
    if (currentDay < 90) {
      setState(() {
        currentDay++;
      });
      _saveProgress();
    }
  }

  void _resetToday() {
    setState(() {
      completedDays.remove(currentDay);
      completedAbRipper.remove(currentDay);
    });
    _saveProgress();
  }

  void _toggleAbRipperComplete(int day) {
    setState(() {
      if (completedAbRipper.contains(day)) {
        completedAbRipper.remove(day);
      } else {
        completedAbRipper.add(day);
        _animationController.forward(from: 0);
      }
    });
    _saveProgress();
  }

  String _getDayOfWeek(int day) {
    if (programStartDate == null) return '';
    final date = programStartDate!.add(Duration(days: day - 1));
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
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
    final canHaveAbRipper = P90X3Schedule.canHaveAbRipper(selectedProgram!, day);
    final hasAbRipper = daysWithAbRipper.contains(day);
    final weightController = TextEditingController(text: workoutWeights[day] ?? '');

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day $day'),
                  if (programStartDate != null)
                    Text(
                      _getDayOfWeek(day),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workout,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (hasAbRipper) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      '🥋',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ab Ripper X',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Weight input field
              if (!isRest) ...[
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Weight (lbs)',
                    hintText: 'e.g., 25',
                    prefixIcon: const Icon(Icons.fitness_center),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Main workout status
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
                    Expanded(
                      child: Text(
                        'Main Workout: ${isCompleted ? "Completed" : "Pending"}',
                        style: TextStyle(
                          color: isCompleted ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Ab Ripper status
              if (hasAbRipper) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (completedAbRipper.contains(day) ? Colors.orange : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        completedAbRipper.contains(day) ? Icons.check_circle : Icons.pending,
                        color: completedAbRipper.contains(day) ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ab Ripper X: ${completedAbRipper.contains(day) ? "Completed" : "Pending"}',
                          style: TextStyle(
                            color: completedAbRipper.contains(day) ? Colors.orange : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isRest) ...[
            if (hasAbRipper)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _playVideo('Ab Ripper X', day);
                },
                icon: const Text('🥋', style: TextStyle(fontSize: 16)),
                label: const Text('Ab Ripper'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _playVideo(workout, day);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Main'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getWorkoutColor(workout),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (hasAbRipper)
            ElevatedButton.icon(
              onPressed: () {
                _toggleAbRipperComplete(day);
                Navigator.pop(context);
              },
              icon: Icon(completedAbRipper.contains(day) ? Icons.close : Icons.check),
              label: Text(completedAbRipper.contains(day) ? 'Undo AB' : 'AB Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: completedAbRipper.contains(day) ? Colors.orange.shade300 : Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () {
              // Save weight if provided
              final weight = weightController.text.trim();
              if (weight.isNotEmpty) {
                setState(() {
                  workoutWeights[day] = weight;
                });
              } else {
                setState(() {
                  workoutWeights.remove(day);
                });
              }

              _markDayComplete(day);
              Navigator.pop(context);
            },
            icon: Icon(isCompleted ? Icons.close : Icons.check),
            label: Text(isCompleted ? 'Undo Main' : 'Main Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? Colors.green.shade300 : Colors.green,
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

  Widget _buildCalendarView() {
    if (programStartDate == null || selectedProgram == null) return const SizedBox();

    // Calculate how many months we need to show (at least 3 for 90 days)
    final endDate = programStartDate!.add(const Duration(days: 89));
    final months = <DateTime>[];

    var currentMonth = DateTime(programStartDate!.year, programStartDate!.month, 1);
    final lastMonth = DateTime(endDate.year, endDate.month, 1);

    while (currentMonth.isBefore(lastMonth) || currentMonth.isAtSameMomentAs(lastMonth)) {
      months.add(currentMonth);
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return Column(
      children: months.map((month) => _buildMonthCalendar(month)).toList(),
    );
  }

  Widget _buildMonthCalendar(DateTime month) {
    final monthName = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][month.month - 1];

    // Get first day of month and calculate offset for Monday start
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // Calculate offset: 1 = Monday, 7 = Sunday
    // We want Monday = 0, so: (weekday - 1) gives us 0 for Monday
    final startOffset = (firstDayOfMonth.weekday - 1) % 7;
    final daysInMonth = lastDayOfMonth.day;

    // Calculate total cells needed
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month and Year header
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '$monthName ${month.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Weekday headers (Mon - Sun)
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            Column(
              children: List.generate(rows, (rowIndex) {
                return Row(
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;

                    // Empty cell before month starts
                    if (cellIndex < startOffset) {
                      return Expanded(child: Container(height: 80));
                    }

                    final dayNumber = cellIndex - startOffset + 1;

                    // Empty cell after month ends
                    if (dayNumber > daysInMonth) {
                      return Expanded(child: Container(height: 80));
                    }

                    final date = DateTime(month.year, month.month, dayNumber);
                    final p90x3Day = _getP90X3DayForDate(date);

                    return Expanded(
                      child: _buildCalendarCell(date, p90x3Day),
                    );
                  }).toList(),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  int? _getP90X3DayForDate(DateTime date) {
    if (programStartDate == null) return null;

    // Normalize both dates to midnight for accurate day counting
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(
        programStartDate!.year,
        programStartDate!.month,
        programStartDate!.day
    );

    final difference = normalizedDate.difference(normalizedStart).inDays;

    // Day is 1-indexed, difference is 0-indexed
    final p90x3Day = difference + 1;

    if (p90x3Day < 1 || p90x3Day > 90) return null;

    return p90x3Day;
  }

  Widget _buildCalendarCell(DateTime date, int? p90x3Day) {
    // Check if this is today's actual date
    final now = DateTime.now();
    final isActualToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (p90x3Day == null) {
      // Just show the date if not part of program
      return Container(
        height: 80,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: isActualToday
              ? Border.all(color: Colors.orange, width: 3)
              : null,
        ),
        child: Center(
          child: Text(
            date.day.toString(),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final workout = P90X3Schedule.getWorkoutForDay(selectedProgram!, p90x3Day);
    final isCompleted = completedDays.contains(p90x3Day);
    final isToday = p90x3Day == currentDay;
    final isRest = workout.contains('Rest') || workout.contains('Dynamix');
    final hasAbRipper = daysWithAbRipper.contains(p90x3Day);
    final abCompleted = completedAbRipper.contains(p90x3Day);

    return InkWell(
      onTap: () => _showDayDialog(p90x3Day, workout, isCompleted, isRest),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 80,
        margin: const EdgeInsets.all(2),
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActualToday
                ? Colors.orange
                : isToday
                ? Colors.blue.shade300
                : isCompleted
                ? Colors.green.shade300
                : Colors.grey.shade200,
            width: isActualToday ? 3 : (isToday ? 2 : 1),
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar date
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isCompleted || isToday ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  // P90X3 day number
                  Text(
                    'D$p90x3Day',
                    style: TextStyle(
                      color: isCompleted || isToday
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Workout name (abbreviated)
                  Text(
                    _abbreviateWorkout(workout),
                    style: TextStyle(
                      color: isCompleted || isToday
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey[700],
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Ab Ripper completed belt (horizontal squeeze effect)
            if (abCompleted)
              Positioned.fill(
                child: CustomPaint(
                  painter: HorizontalBeltPainter(
                    color: _getBeltColor(),
                    strokeWidth: 8,
                  ),
                ),
              ),

            // Completed checkmark (only if no weight)
            if (isCompleted && !workoutWeights.containsKey(p90x3Day))
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),

            // Weight display in top right
            if (workoutWeights.containsKey(p90x3Day))
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted || isToday
                        ? Colors.white.withOpacity(0.9)
                        : Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted || isToday
                          ? Colors.black.withOpacity(0.2)
                          : Colors.white,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${workoutWeights[p90x3Day]}lb',
                    style: TextStyle(
                      color: isCompleted || isToday ? Colors.black87 : Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Ab Ripper scheduled indicator (belt emoji at bottom)
            if (hasAbRipper)
              Positioned(
                bottom: 2,
                right: 2,
                child: Text(
                  '🥋',
                  style: TextStyle(
                    fontSize: 10,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _abbreviateWorkout(String workout) {
    // Abbreviate long workout names for calendar display
    final abbreviations = {
      'Total Synergistics': 'Total Syn',
      'Agility X': 'Agility',
      'The Challenge': 'Challenge',
      'The Warrior': 'Warrior',
      'Eccentric Upper': 'Ecc Upper',
      'Eccentric Lower': 'Ecc Lower',
      'Incinerator': 'Incin',
      'Accelerator': 'Accel',
      'Decelerator': 'Decel',
      'Triometrics': 'Trio',
      'Pilates X': 'Pilates',
      'Isometrix': 'Iso',
      'Rest or Dynamix': 'Rest',
    };

    return abbreviations[workout] ?? workout;
  }

  Color _getBeltColor() {
    final completedCount = completedDays.length;

    if (completedCount < 23) {
      // 0-22 days: Bronze
      final progress = completedCount / 22;
      return Color.lerp(
        const Color(0xFFCD7F32), // Bronze
        const Color(0xFFB8722C), // Darker bronze
        progress,
      )!;
    } else if (completedCount < 45) {
      // 23-44 days: Bronze to Silver
      final progress = (completedCount - 23) / 22;
      return Color.lerp(
        const Color(0xFFB8722C), // Dark bronze
        const Color(0xFFC0C0C0), // Silver
        progress,
      )!;
    } else if (completedCount < 68) {
      // 45-67 days: Silver to Gold
      final progress = (completedCount - 45) / 22;
      return Color.lerp(
        const Color(0xFFC0C0C0), // Silver
        const Color(0xFFFFD700), // Gold
        progress,
      )!;
    } else {
      // 68-90 days: Gold to Pure Platinum
      final progress = (completedCount - 68) / 22;
      return Color.lerp(
        const Color(0xFFFFD700), // Gold
        const Color(0xFFF4F4F4), // Pure Platinum (bright white-silver)
        progress,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedProgram == null) {
      return _buildProgramSelection();
    }

    final todayWorkout = P90X3Schedule.getWorkoutForDay(selectedProgram!, currentDay);
    final completedCount = completedDays.length;
    final progressPercent = completedCount / 90;
    final canHaveAbRipper = P90X3Schedule.canHaveAbRipper(selectedProgram!, currentDay);
    final hasAbRipper = daysWithAbRipper.contains(currentDay);

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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Custom App Bar with Menu
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
                      // Menu button instead of reset
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) {
                          if (value == 'reset') {
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
                                        completedAbRipper.clear();
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
                          } else if (value == 'videos') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VideoListScreen(),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'videos',
                            child: Row(
                              children: [
                                Icon(Icons.play_circle_outline, size: 20),
                                SizedBox(width: 12),
                                Text('Videos'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'reset',
                            child: Row(
                              children: [
                                Icon(Icons.restart_alt_rounded, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Reset Program', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  todayWorkout,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (hasAbRipper)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    '🥋',
                                    style: TextStyle(fontSize: 32),
                                  ),
                                ),
                            ],
                          ),

                          // Day navigation and Ab Ripper toggle
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Previous day button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                  color: Colors.white,
                                  onPressed: currentDay > 1 ? _goToPreviousDay : null,
                                  tooltip: 'Previous Day',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Day of week badge
                              if (programStartDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getDayOfWeek(currentDay),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                              const Spacer(),

                              // Reset today button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.replay_rounded, size: 20),
                                  color: Colors.white,
                                  onPressed: _resetToday,
                                  tooltip: 'Reset Today',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Next day button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                  color: Colors.white,
                                  onPressed: currentDay < 90 ? _goToNextDay : null,
                                  tooltip: 'Next Day',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          if (hasAbRipper) ...[
                            // Two buttons for Ab Ripper days
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: todayWorkout.contains('Rest')
                                        ? null
                                        : () => _playVideo(todayWorkout, currentDay),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                    label: const Text(
                                      'MAIN',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: _getWorkoutColor(todayWorkout),
                                      disabledBackgroundColor: Colors.white.withOpacity(0.3),
                                      disabledForegroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _playVideo('Ab Ripper X', currentDay),
                                    icon: const Text('🥋', style: TextStyle(fontSize: 20)),
                                    label: const Text(
                                      'AB RIPPER',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.orange,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Separate completion buttons
                            Row(
                              children: [
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return OutlinedButton.icon(
                                        onPressed: () => _markDayComplete(currentDay),
                                        icon: Icon(
                                          completedDays.contains(currentDay)
                                              ? Icons.check_circle_rounded
                                              : Icons.check_circle_outline_rounded,
                                        ),
                                        label: Text(
                                          completedDays.contains(currentDay) ? 'DONE' : 'MARK DONE',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: completedDays.contains(currentDay)
                                                ? Colors.green
                                                : Colors.white.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          backgroundColor: completedDays.contains(currentDay)
                                              ? Colors.green.withOpacity(0.3)
                                              : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return OutlinedButton.icon(
                                        onPressed: () => _toggleAbRipperComplete(currentDay),
                                        icon: Icon(
                                          completedAbRipper.contains(currentDay)
                                              ? Icons.check_circle_rounded
                                              : Icons.check_circle_outline_rounded,
                                        ),
                                        label: Text(
                                          completedAbRipper.contains(currentDay) ? 'AB DONE' : 'AB MARK',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: completedAbRipper.contains(currentDay)
                                                ? Colors.orange
                                                : Colors.white.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          backgroundColor: completedAbRipper.contains(currentDay)
                                              ? Colors.orange.withOpacity(0.3)
                                              : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Single button for non-Ab Ripper days
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
                          const SizedBox(width: 12),
                          _buildLegendItem(Colors.orange, 'Now'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Calendar View
                _buildCalendarView(),

                const SizedBox(height: 16),
              ],
            ),
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

// Custom painter for horizontal belt (bottom only)
class HorizontalBeltPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  HorizontalBeltPainter({
    required this.color,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Bottom belt only
    final bottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.70 - strokeWidth, size.width, strokeWidth),
      const Radius.circular(2),
    );

    // Draw shadow first
    canvas.drawRRect(bottomRect.shift(const Offset(0, 1)), shadowPaint);

    // Draw belt
    canvas.drawRRect(bottomRect, paint);

    // Add highlight on top edge
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.70 - strokeWidth),
      Offset(size.width, size.height * 0.70 - strokeWidth),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
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
  int? displayDay;
  Set<int> completedDays = {};
  Set<int> completedAbRipper = {};
  Set<int> daysWithAbRipper = {};
  Set<int> completedElliptical = {};
  Map<int, String> workoutWeights = {}; // Store weights by day
  DateTime? programStartDate;
  bool alignRestToSunday = false;
  bool _celebrationShown = false;
  bool isRestWeek = false;
  DateTime? restWeekStartDate;
  late AnimationController _animationController;

  // Makeup week state
  bool isMakeupWeek = false;
  List<Map<String, dynamic>> makeupSchedule = [];
  Set<int> completedMakeupDays = {};
  Set<int> completedMakeupAbRipper = {};
  Set<int> completedMakeupElliptical = {};
  int currentMakeupIndex = 0;

  // Program history
  List<Map<String, dynamic>> programHistory = [];

  // Hybrid/custom schedule
  List<String>? hybridSchedule;

  bool get isProgramComplete => completedDays.contains(90);

  String _getWorkout(int dayNumber) {
    if (hybridSchedule != null && dayNumber >= 1 && dayNumber <= hybridSchedule!.length) {
      return hybridSchedule![dayNumber - 1];
    }
    return P90X3Schedule.getWorkoutForDay(selectedProgram ?? 'Classic', dayNumber);
  }

  String get _beltName {
    final count = completedDays.length;
    if (count >= 68) return 'Platinum';
    if (count >= 45) return 'Gold';
    if (count >= 23) return 'Silver';
    return 'Bronze';
  }

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

      // Load elliptical completion
      final completedEllip = prefs.getStringList('p90x3_completed_elliptical') ?? [];
      completedElliptical = completedEllip.map((e) => int.parse(e)).toSet();

      // Load weights
      final weightsJson = prefs.getString('p90x3_weights');
      if (weightsJson != null) {
        final decoded = Map<String, dynamic>.from(
            const JsonDecoder().convert(weightsJson)
        );
        workoutWeights = decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));
      }

      // Load completion/rest week state
      _celebrationShown = prefs.getBool('p90x3_celebration_shown') ?? false;
      isRestWeek = prefs.getBool('p90x3_rest_week') ?? false;
      final restStartStr = prefs.getString('p90x3_rest_week_start');
      if (restStartStr != null) {
        restWeekStartDate = DateTime.parse(restStartStr);
      }

      // Load makeup week state
      isMakeupWeek = prefs.getBool('p90x3_makeup_week') ?? false;
      final makeupJson = prefs.getString('p90x3_makeup_schedule');
      if (makeupJson != null) {
        final decoded = List<dynamic>.from(const JsonDecoder().convert(makeupJson));
        makeupSchedule = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final completedMakeup = prefs.getStringList('p90x3_completed_makeup') ?? [];
      completedMakeupDays = completedMakeup.map((e) => int.parse(e)).toSet();
      final completedMakeupAb = prefs.getStringList('p90x3_completed_makeup_ab') ?? [];
      completedMakeupAbRipper = completedMakeupAb.map((e) => int.parse(e)).toSet();
      final completedMakeupEllip = prefs.getStringList('p90x3_completed_makeup_elliptical') ?? [];
      completedMakeupElliptical = completedMakeupEllip.map((e) => int.parse(e)).toSet();
      currentMakeupIndex = prefs.getInt('p90x3_current_makeup_index') ?? 0;

      // Load program history
      final historyJson = prefs.getString('p90x3_program_history');
      if (historyJson != null) {
        final decoded = List<dynamic>.from(const JsonDecoder().convert(historyJson));
        programHistory = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // Load hybrid schedule
      final hybridJson = prefs.getString('p90x3_hybrid_schedule');
      if (hybridJson != null) {
        hybridSchedule = List<String>.from(const JsonDecoder().convert(hybridJson));
      } else {
        hybridSchedule = null;
      }
    });

    // Check if rest week has expired
    if (isRestWeek && restWeekStartDate != null) {
      final daysSinceRest = DateTime.now().difference(restWeekStartDate!).inDays;
      if (daysSinceRest >= 7) {
        // Rest week is over, prompt program selection
        _endRestWeek();
      }
    }
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
    await prefs.setStringList(
      'p90x3_completed_elliptical',
      completedElliptical.map((e) => e.toString()).toList(),
    );
    await prefs.setBool('p90x3_align_rest_sunday', alignRestToSunday);
    if (programStartDate != null) {
      await prefs.setString('p90x3_start_date', programStartDate!.toIso8601String());
    }

    // Save weights
    final weightsMap = workoutWeights.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('p90x3_weights', const JsonEncoder().convert(weightsMap));

    // Save completion/rest week state
    await prefs.setBool('p90x3_celebration_shown', _celebrationShown);
    await prefs.setBool('p90x3_rest_week', isRestWeek);
    if (restWeekStartDate != null) {
      await prefs.setString('p90x3_rest_week_start', restWeekStartDate!.toIso8601String());
    } else {
      await prefs.remove('p90x3_rest_week_start');
    }

    // Save makeup week state
    await prefs.setBool('p90x3_makeup_week', isMakeupWeek);
    if (makeupSchedule.isNotEmpty) {
      await prefs.setString('p90x3_makeup_schedule', const JsonEncoder().convert(makeupSchedule));
    } else {
      await prefs.remove('p90x3_makeup_schedule');
    }
    await prefs.setStringList(
      'p90x3_completed_makeup',
      completedMakeupDays.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      'p90x3_completed_makeup_ab',
      completedMakeupAbRipper.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      'p90x3_completed_makeup_elliptical',
      completedMakeupElliptical.map((e) => e.toString()).toList(),
    );
    await prefs.setInt('p90x3_current_makeup_index', currentMakeupIndex);

    // Save program history
    if (programHistory.isNotEmpty) {
      await prefs.setString('p90x3_program_history', const JsonEncoder().convert(programHistory));
    } else {
      await prefs.remove('p90x3_program_history');
    }

    // Save hybrid schedule
    if (hybridSchedule != null) {
      await prefs.setString('p90x3_hybrid_schedule', const JsonEncoder().convert(hybridSchedule));
    } else {
      await prefs.remove('p90x3_hybrid_schedule');
    }
  }

  Future<void> _exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final backupData = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'p90x3_program': prefs.getString('p90x3_program'),
        'p90x3_current_day': prefs.getInt('p90x3_current_day'),
        'p90x3_completed': prefs.getStringList('p90x3_completed'),
        'p90x3_completed_ab': prefs.getStringList('p90x3_completed_ab'),
        'p90x3_ab_ripper': prefs.getStringList('p90x3_ab_ripper'),
        'p90x3_completed_elliptical': prefs.getStringList('p90x3_completed_elliptical'),
        'p90x3_align_rest_sunday': prefs.getBool('p90x3_align_rest_sunday'),
        'p90x3_start_date': prefs.getString('p90x3_start_date'),
        'p90x3_weights': prefs.getString('p90x3_weights'),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${downloadsDir.path}/excervids_backup_$timestamp.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to: ${file.path}'),
            backgroundColor: P90X3Colors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final files = await downloadsDir.list().toList();
      final backupFiles = files
          .whereType<File>()
          .where((f) => f.path.contains('excervids_backup') && f.path.endsWith('.json'))
          .toList();

      if (backupFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No backup files found in Downloads folder'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Sort by name (most recent first due to timestamp)
      backupFiles.sort((a, b) => b.path.compareTo(a.path));

      // Show file picker dialog
      if (!mounted) return;
      final selectedFile = await showDialog<File>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.restore, color: P90X3Colors.primary),
              SizedBox(width: 12),
              Text('Select Backup'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backupFiles.length,
              itemBuilder: (context, index) {
                final file = backupFiles[index];
                final name = file.path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.file_present),
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  onTap: () => Navigator.pop(context, file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFile == null) return;

      final jsonStr = await selectedFile.readAsString();
      final backupData = Map<String, dynamic>.from(const JsonDecoder().convert(jsonStr));

      final prefs = await SharedPreferences.getInstance();

      if (backupData['p90x3_program'] != null) {
        await prefs.setString('p90x3_program', backupData['p90x3_program']);
      }
      if (backupData['p90x3_current_day'] != null) {
        await prefs.setInt('p90x3_current_day', backupData['p90x3_current_day']);
      }
      if (backupData['p90x3_completed'] != null) {
        await prefs.setStringList('p90x3_completed', List<String>.from(backupData['p90x3_completed']));
      }
      if (backupData['p90x3_completed_ab'] != null) {
        await prefs.setStringList('p90x3_completed_ab', List<String>.from(backupData['p90x3_completed_ab']));
      }
      if (backupData['p90x3_ab_ripper'] != null) {
        await prefs.setStringList('p90x3_ab_ripper', List<String>.from(backupData['p90x3_ab_ripper']));
      }
      if (backupData['p90x3_completed_elliptical'] != null) {
        await prefs.setStringList('p90x3_completed_elliptical', List<String>.from(backupData['p90x3_completed_elliptical']));
      }
      if (backupData['p90x3_align_rest_sunday'] != null) {
        await prefs.setBool('p90x3_align_rest_sunday', backupData['p90x3_align_rest_sunday']);
      }
      if (backupData['p90x3_start_date'] != null) {
        await prefs.setString('p90x3_start_date', backupData['p90x3_start_date']);
      }
      if (backupData['p90x3_weights'] != null) {
        await prefs.setString('p90x3_weights', backupData['p90x3_weights']);
      }

      await _loadProgress();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            backgroundColor: P90X3Colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleEllipticalComplete(int day) {
    setState(() {
      if (completedElliptical.contains(day)) {
        completedElliptical.remove(day);
      } else {
        completedElliptical.add(day);
        _animationController.forward(from: 0);
      }
    });
    _saveProgress();
  }

  int get actualTodayP90X3Day {
    if (programStartDate == null) return 1;

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedStart = DateTime(
        programStartDate!.year,
        programStartDate!.month,
        programStartDate!.day
    );

    final difference = normalizedToday.difference(normalizedStart).inDays;
    final day = difference + 1;

    if (day < 1 || day > 90) return 1;
    return day;
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
    final wasAlreadyComplete = completedDays.contains(day);
    setState(() {
      if (wasAlreadyComplete) {
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

    // Trigger celebration when Day 90 is marked complete for the first time
    if (!wasAlreadyComplete && day == 90 && !_celebrationShown) {
      _celebrationShown = true;
      _saveProgress();
      Future.microtask(() => _showCelebration());
    }
  }

  void _goToPreviousDay() {
    setState(() {
      final currentDisplay = displayDay ?? actualTodayP90X3Day;
      if (currentDisplay > 1) {
        displayDay = currentDisplay - 1;
      }
    });
  }

  void _goToNextDay() {
    setState(() {
      final currentDisplay = displayDay ?? actualTodayP90X3Day;
      if (currentDisplay < 90) {
        displayDay = currentDisplay + 1;
      }
    });
  }

  void _resetToday() {
    final today = displayDay ?? actualTodayP90X3Day;
    setState(() {
      completedDays.remove(today);
      completedAbRipper.remove(today);
      completedElliptical.remove(today);
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

    // Determine the day label based on actual calendar date
    String dayLabel;
    Color dayLabelColor;
    if (day == actualTodayP90X3Day) {
      dayLabel = 'TODAY';
      dayLabelColor = Colors.blue;
    } else if (day < actualTodayP90X3Day) {
      dayLabel = 'PAST';
      dayLabelColor = Colors.grey;
    } else {
      dayLabel = 'UPCOMING';
      dayLabelColor = Colors.orange;
    }

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
                  Row(
                    children: [
                      Text('Day $day'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: dayLabelColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: dayLabelColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
              // Elliptical status
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (completedElliptical.contains(day) ? Colors.purple : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      completedElliptical.contains(day) ? Icons.check_circle : Icons.pending,
                      color: completedElliptical.contains(day) ? Colors.purple : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Elliptical: ${completedElliptical.contains(day) ? "Completed" : "Pending"}',
                        style: TextStyle(
                          color: completedElliptical.contains(day) ? Colors.purple : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
          ElevatedButton.icon(
            onPressed: () {
              _toggleEllipticalComplete(day);
              Navigator.pop(context);
            },
            icon: Icon(completedElliptical.contains(day) ? Icons.close : Icons.check),
            label: Text(completedElliptical.contains(day) ? 'Undo Ellip' : 'Ellip Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: completedElliptical.contains(day) ? Colors.purple.shade300 : Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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

  // ==================== COMPLETION FEATURES ====================

  void _showCelebration() {
    if (!mounted) return;
    final completedCount = completedDays.length;
    final abCount = completedAbRipper.length;
    final ellipCount = completedElliptical.length;
    final totalWorkouts = completedCount + abCount + ellipCount;
    final completionPercent = (completedCount / 90 * 100).toStringAsFixed(1);
    final missedDays = <int>[];
    for (int i = 1; i <= 90; i++) {
      if (!completedDays.contains(i)) missedDays.add(i);
    }

    String duration = '';
    if (programStartDate != null) {
      final days = DateTime.now().difference(programStartDate!).inDays;
      duration = '$days days';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
                Color(0xFFf093fb),
                Color(0xFFf5576c),
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Trophy with belt color
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _getBeltColor(), width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: _getBeltColor().withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'CONGRATULATIONS!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You completed P90X3 ${selectedProgram ?? ""}!',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Stats cards
                  _celebrationStatCard(Icons.calendar_today, 'Days Completed', '$completedCount / 90'),
                  const SizedBox(height: 12),
                  _celebrationStatCard(Icons.sports_martial_arts, 'Ab Ripper Sessions', '$abCount'),
                  const SizedBox(height: 12),
                  _celebrationStatCard(Icons.directions_run, 'Elliptical Sessions', '$ellipCount'),
                  const SizedBox(height: 12),
                  _celebrationStatCard(Icons.fitness_center, 'Total Workouts', '$totalWorkouts'),
                  const SizedBox(height: 12),
                  if (duration.isNotEmpty)
                    _celebrationStatCard(Icons.timer, 'Program Duration', duration),
                  if (duration.isNotEmpty) const SizedBox(height: 12),
                  _celebrationStatCard(Icons.percent, 'Completion', '$completionPercent%'),
                  const SizedBox(height: 12),
                  _celebrationStatCard(Icons.military_tech, 'Belt Earned', _beltName),
                  const SizedBox(height: 32),
                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _exportCompletionStats();
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF764ba2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showWhatsNext();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text("What's Next?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _celebrationStatCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCompletionStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedCount = completedDays.length;
      final missedDays = <int>[];
      for (int i = 1; i <= 90; i++) {
        if (!completedDays.contains(i)) missedDays.add(i);
      }

      final backupData = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'p90x3_program': prefs.getString('p90x3_program'),
        'p90x3_current_day': prefs.getInt('p90x3_current_day'),
        'p90x3_completed': prefs.getStringList('p90x3_completed'),
        'p90x3_completed_ab': prefs.getStringList('p90x3_completed_ab'),
        'p90x3_ab_ripper': prefs.getStringList('p90x3_ab_ripper'),
        'p90x3_completed_elliptical': prefs.getStringList('p90x3_completed_elliptical'),
        'p90x3_align_rest_sunday': prefs.getBool('p90x3_align_rest_sunday'),
        'p90x3_start_date': prefs.getString('p90x3_start_date'),
        'p90x3_weights': prefs.getString('p90x3_weights'),
        'completion_summary': {
          'program': selectedProgram ?? '',
          'start_date': programStartDate?.toIso8601String().split('T')[0] ?? '',
          'end_date': DateTime.now().toIso8601String().split('T')[0],
          'days_completed': completedCount,
          'days_total': 90,
          'completion_percent': double.parse((completedCount / 90 * 100).toStringAsFixed(1)),
          'ab_ripper_sessions': completedAbRipper.length,
          'elliptical_sessions': completedElliptical.length,
          'total_workouts': completedCount + completedAbRipper.length + completedElliptical.length,
          'belt_earned': _beltName,
          'weights_logged': workoutWeights.map((k, v) => MapEntry(k.toString(), v)),
          'missed_days': missedDays,
        },
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final program = (selectedProgram ?? 'unknown').toLowerCase();
      final file = File('${downloadsDir.path}/excervids_completion_${program}_$timestamp.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completion report saved to: ${file.path}'),
            backgroundColor: P90X3Colors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== MAKEUP WEEK FEATURES ====================

  List<Map<String, dynamic>> _generateMakeupSchedule() {
    if (selectedProgram == null) return [];

    // Find all missed non-rest days
    final missedWorkouts = <Map<String, dynamic>>[];
    for (int day = 1; day <= 90; day++) {
      if (!completedDays.contains(day)) {
        final workout = _getWorkout(day);
        // Skip rest/Dynamix days
        if (workout.contains('Rest') || workout == 'Dynamix') continue;
        final hasAbRipper = daysWithAbRipper.contains(day);
        missedWorkouts.add({
          'workout': workout,
          'originalDay': day,
          'hasAbRipper': hasAbRipper,
        });
      }
    }

    // Pack into slots starting at day 91, Mon-Sat with Sunday rest
    final schedule = <Map<String, dynamic>>[];
    int makeupDay = 91;
    int slotInWeek = 0; // 0-5 = Mon-Sat, skip Sunday

    for (final missed in missedWorkouts) {
      // If we've filled 6 days (Mon-Sat), skip Sunday
      if (slotInWeek >= 6) {
        makeupDay++; // skip Sunday
        slotInWeek = 0;
      }
      schedule.add({
        'day': makeupDay,
        'workout': missed['workout'],
        'originalDay': missed['originalDay'],
        'hasAbRipper': missed['hasAbRipper'],
      });
      makeupDay++;
      slotInWeek++;
    }

    return schedule;
  }

  int _getMissedNonRestCount() {
    if (selectedProgram == null) return 0;
    int count = 0;
    for (int day = 1; day <= 90; day++) {
      if (!completedDays.contains(day)) {
        final workout = _getWorkout(day);
        if (!workout.contains('Rest') && workout != 'Dynamix') count++;
      }
    }
    return count;
  }

  void _startMakeupWeek() {
    final schedule = _generateMakeupSchedule();
    if (schedule.isEmpty) return;
    setState(() {
      isMakeupWeek = true;
      makeupSchedule = schedule;
      completedMakeupDays.clear();
      completedMakeupAbRipper.clear();
      completedMakeupElliptical.clear();
      currentMakeupIndex = 0;
    });
    _saveProgress();
  }

  void _exitMakeupWeek() {
    setState(() {
      isMakeupWeek = false;
      makeupSchedule.clear();
      completedMakeupDays.clear();
      completedMakeupAbRipper.clear();
      completedMakeupElliptical.clear();
      currentMakeupIndex = 0;
    });
    _saveProgress();
  }

  void _markMakeupDayComplete(int makeupDay) {
    setState(() {
      if (completedMakeupDays.contains(makeupDay)) {
        completedMakeupDays.remove(makeupDay);
      } else {
        completedMakeupDays.add(makeupDay);
        _animationController.forward(from: 0);
        // Advance to next incomplete makeup workout
        _advanceMakeupIndex();
      }
    });
    _saveProgress();

    // Check if all makeup workouts are done
    if (_allMakeupsDone()) {
      Future.microtask(() => _showMakeupComplete());
    }
  }

  void _toggleMakeupAbRipper(int makeupDay) {
    setState(() {
      if (completedMakeupAbRipper.contains(makeupDay)) {
        completedMakeupAbRipper.remove(makeupDay);
      } else {
        completedMakeupAbRipper.add(makeupDay);
        _animationController.forward(from: 0);
      }
    });
    _saveProgress();
  }

  void _toggleMakeupElliptical(int makeupDay) {
    setState(() {
      if (completedMakeupElliptical.contains(makeupDay)) {
        completedMakeupElliptical.remove(makeupDay);
      } else {
        completedMakeupElliptical.add(makeupDay);
        _animationController.forward(from: 0);
      }
    });
    _saveProgress();
  }

  void _advanceMakeupIndex() {
    for (int i = 0; i < makeupSchedule.length; i++) {
      if (!completedMakeupDays.contains(makeupSchedule[i]['day'])) {
        currentMakeupIndex = i;
        return;
      }
    }
    currentMakeupIndex = makeupSchedule.length; // all done
  }

  bool _allMakeupsDone() {
    return makeupSchedule.every((entry) => completedMakeupDays.contains(entry['day']));
  }

  void _showMakeupComplete() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('All Caught Up!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'ve completed all your makeup workouts!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${makeupSchedule.length} workouts made up',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitMakeupWeek();
              _showWhatsNext();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildMakeupWeekView() {
    final remainingCount = makeupSchedule.where(
      (e) => !completedMakeupDays.contains(e['day']),
    ).length;

    // Get current workout
    final currentEntry = currentMakeupIndex < makeupSchedule.length
        ? makeupSchedule[currentMakeupIndex]
        : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal, Colors.teal.shade700],
                          ),
                          borderRadius: BorderRadius.circular(16),
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
                              'Makeup Week',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '$remainingCount workouts remaining',
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
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Exit Makeup Week?'),
                              content: const Text('You can re-enter from the What\'s Next menu later.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _exitMakeupWeek();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Exit'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${completedMakeupDays.length} of ${makeupSchedule.length} complete',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          Text(
                            makeupSchedule.isNotEmpty
                                ? '${(completedMakeupDays.length / makeupSchedule.length * 100).toInt()}%'
                                : '0%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: makeupSchedule.isNotEmpty
                              ? completedMakeupDays.length / makeupSchedule.length
                              : 0,
                          minHeight: 8,
                          backgroundColor: Colors.teal.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Current workout card
                if (currentEntry != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getWorkoutColor(currentEntry['workout']),
                            _getWorkoutColor(currentEntry['workout']).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: _getWorkoutColor(currentEntry['workout']).withOpacity(0.4),
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
                                    _getWorkoutIcon(currentEntry['workout']),
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
                                        'MAKEUP WORKOUT',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      Text(
                                        'Originally Day ${currentEntry['originalDay']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Elliptical toggle
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: Text(
                                      completedMakeupElliptical.contains(currentEntry['day']) ? '⚡' : '⚪',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    onPressed: () => _toggleMakeupElliptical(currentEntry['day']),
                                    tooltip: 'Elliptical',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                if (completedMakeupDays.contains(currentEntry['day'])) ...[
                                  const SizedBox(width: 8),
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
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    currentEntry['workout'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (currentEntry['hasAbRipper'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text(
                                      '🥋',
                                      style: TextStyle(fontSize: 32),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Play buttons
                            if (currentEntry['hasAbRipper'] == true) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _playVideo(currentEntry['workout'], currentEntry['originalDay']),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                      label: const Text('MAIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _getWorkoutColor(currentEntry['workout']),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _playVideo('Ab Ripper X', currentEntry['originalDay']),
                                      icon: const Text('🥋', style: TextStyle(fontSize: 20)),
                                      label: const Text('AB RIPPER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Completion buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _markMakeupDayComplete(currentEntry['day']),
                                      icon: Icon(
                                        completedMakeupDays.contains(currentEntry['day'])
                                            ? Icons.check_circle_rounded
                                            : Icons.check_circle_outline_rounded,
                                      ),
                                      label: Text(
                                        completedMakeupDays.contains(currentEntry['day']) ? 'DONE' : 'MARK DONE',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: completedMakeupDays.contains(currentEntry['day'])
                                              ? Colors.green
                                              : Colors.white.withOpacity(0.5),
                                          width: 2,
                                        ),
                                        backgroundColor: completedMakeupDays.contains(currentEntry['day'])
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _toggleMakeupAbRipper(currentEntry['day']),
                                      icon: Icon(
                                        completedMakeupAbRipper.contains(currentEntry['day'])
                                            ? Icons.check_circle_rounded
                                            : Icons.check_circle_outline_rounded,
                                      ),
                                      label: Text(
                                        completedMakeupAbRipper.contains(currentEntry['day']) ? 'AB DONE' : 'AB MARK',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: completedMakeupAbRipper.contains(currentEntry['day'])
                                              ? Colors.orange
                                              : Colors.white.withOpacity(0.5),
                                          width: 2,
                                        ),
                                        backgroundColor: completedMakeupAbRipper.contains(currentEntry['day'])
                                            ? Colors.orange.withOpacity(0.3)
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Non-Ab Ripper day: single row
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _playVideo(currentEntry['workout'], currentEntry['originalDay']),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                      label: const Text('PLAY WORKOUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _getWorkoutColor(currentEntry['workout']),
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        completedMakeupDays.contains(currentEntry['day'])
                                            ? Icons.check_circle_rounded
                                            : Icons.check_circle_outline_rounded,
                                        size: 36,
                                      ),
                                      color: Colors.white,
                                      onPressed: () => _markMakeupDayComplete(currentEntry['day']),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // All done state (shouldn't normally show since dialog triggers)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
                          const SizedBox(height: 16),
                          const Text('All Caught Up!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              _exitMakeupWeek();
                              _showWhatsNext();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Remaining makeup workouts list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Makeup Schedule',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...makeupSchedule.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isDone = completedMakeupDays.contains(item['day']);
                        final isCurrent = index == currentMakeupIndex;
                        final workoutColor = _getWorkoutColor(item['workout']);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                currentMakeupIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green.withOpacity(0.08)
                                    : isCurrent
                                        ? workoutColor.withOpacity(0.08)
                                        : Colors.grey.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCurrent
                                      ? workoutColor.withOpacity(0.4)
                                      : isDone
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.1),
                                  width: isCurrent ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? Colors.green.withOpacity(0.15)
                                          : workoutColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: isDone
                                          ? const Icon(Icons.check_rounded, color: Colors.green, size: 20)
                                          : Icon(_getWorkoutIcon(item['workout']), color: workoutColor, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['workout'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                            color: isDone ? Colors.grey : null,
                                          ),
                                        ),
                                        Text(
                                          'Originally Day ${item['originalDay']}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item['hasAbRipper'] == true)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Text('🥋', style: TextStyle(fontSize: 16)),
                                    ),
                                  if (isCurrent && !isDone)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: workoutColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'NEXT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: workoutColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Done with makeups button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _exitMakeupWeek();
                        _showWhatsNext();
                      },
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text('Done with makeups'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== END MAKEUP WEEK FEATURES ====================

  void _showWhatsNext() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.explore_rounded, color: P90X3Colors.primary, size: 28),
            SizedBox(width: 12),
            Text("What's Next?", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _whatsNextOption(
              icon: Icons.replay_rounded,
              color: Colors.blue,
              title: 'Repeat ${selectedProgram ?? "Program"}',
              subtitle: 'Reset progress, same program, new start date',
              onTap: () {
                Navigator.pop(context);
                _restartProgram(selectedProgram!);
              },
            ),
            const SizedBox(height: 8),
            _whatsNextOption(
              icon: Icons.swap_horiz_rounded,
              color: Colors.orange,
              title: 'Try a different P90X3',
              subtitle: 'Switch to Classic, Lean, or Mass',
              onTap: () {
                Navigator.pop(context);
                _switchProgram();
              },
            ),
            const SizedBox(height: 8),
            _whatsNextOption(
              icon: Icons.hotel_rounded,
              color: Colors.purple,
              title: 'Take a rest week first',
              subtitle: '7-day rest, then choose a program',
              onTap: () {
                Navigator.pop(context);
                _startRestWeek();
              },
            ),
            // Makeup missed workouts option (only if there are missed non-rest days)
            if (isProgramComplete && _getMissedNonRestCount() > 0) ...[
              const SizedBox(height: 8),
              _whatsNextOption(
                icon: Icons.fitness_center_rounded,
                color: Colors.teal,
                title: 'Make up missed workouts',
                subtitle: 'Schedule ${_getMissedNonRestCount()} missed workouts into next week(s)',
                onTap: () {
                  Navigator.pop(context);
                  _startMakeupWeek();
                },
              ),
            ],
            const SizedBox(height: 8),
            _whatsNextOption(
              icon: Icons.merge_rounded,
              color: Colors.deepPurple,
              title: 'Create Hybrid Program',
              subtitle: 'Mix workouts from Classic, Lean & Mass',
              onTap: () {
                Navigator.pop(context);
                _showCombineRoutines();
              },
            ),
            const SizedBox(height: 8),
            _whatsNextOption(
              icon: Icons.history_rounded,
              color: Colors.blueGrey,
              title: 'View Past Programs',
              subtitle: 'See your workout history',
              onTap: () {
                Navigator.pop(context);
                _showProgramHistory();
              },
            ),
            const SizedBox(height: 8),
            _whatsNextOption(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              title: "I'm done for now",
              subtitle: 'Keep completed program visible',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whatsNextOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showProgramHistory() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: P90X3Colors.primary, size: 28),
            SizedBox(width: 12),
            Text('Program History', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: programHistory.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No completed programs yet.\nYour past programs will appear here when you finish or switch programs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: programHistory.length,
                  itemBuilder: (context, index) {
                    final entry = programHistory[index];
                    final startDate = DateTime.parse(entry['startDate']);
                    final endDate = DateTime.parse(entry['endDate']);
                    final daysCompleted = entry['daysCompleted'] as int;
                    final abSessions = entry['abRipperSessions'] as int;
                    final cardioSessions = entry['ellipticalSessions'] as int;
                    final belt = entry['beltEarned'] as String;
                    final pct = (daysCompleted / 90 * 100).toStringAsFixed(0);

                    Color beltColor;
                    switch (belt) {
                      case 'Platinum':
                        beltColor = const Color(0xFFF4F4F4);
                        break;
                      case 'Gold':
                        beltColor = const Color(0xFFFFD700);
                        break;
                      case 'Silver':
                        beltColor = const Color(0xFFC0C0C0);
                        break;
                      default:
                        beltColor = const Color(0xFFCD7F32);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: P90X3Colors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${entry['program']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: P90X3Colors.primary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: beltColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: beltColor),
                                  ),
                                  child: Text(
                                    '$belt 🥋',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: belt == 'Platinum' ? Colors.grey[700] : Colors.brown[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${startDate.month}/${startDate.day}/${startDate.year} — ${endDate.month}/${endDate.day}/${endDate.year}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _historyStatChip('💪 $daysCompleted/90', '$pct%'),
                                const SizedBox(width: 8),
                                _historyStatChip('🥋 $abSessions', 'abs'),
                                const SizedBox(width: 8),
                                _historyStatChip('⚡ $cardioSessions', 'cardio'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          if (programHistory.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text('This will permanently remove all program history.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => programHistory.clear());
                          _saveProgress();
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Clear History', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _historyStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _showCombineRoutines() {
    if (!mounted) return;
    // Build a list of all unique workouts from all 3 programs
    final allPrograms = ['Classic', 'Lean', 'Mass'];

    showDialog(
      context: context,
      builder: (context) {
        String block1 = selectedProgram ?? 'Classic';
        String block2 = selectedProgram ?? 'Classic';
        String block3 = selectedProgram ?? 'Classic';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.merge_rounded, color: Colors.deepPurple, size: 28),
                SizedBox(width: 12),
                Text('Create Hybrid', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick a program for each 4-week block:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _blockPicker('Block 1 (Wk 1-4)', block1, allPrograms, (v) {
                  setDialogState(() => block1 = v);
                }),
                const SizedBox(height: 12),
                _blockPicker('Block 2 (Wk 5-8)', block2, allPrograms, (v) {
                  setDialogState(() => block2 = v);
                }),
                const SizedBox(height: 12),
                _blockPicker('Block 3 (Wk 9-12+)', block3, allPrograms, (v) {
                  setDialogState(() => block3 = v);
                }),
                const SizedBox(height: 16),
                Text(
                  'This creates a 90-day hybrid mixing $block1 → $block2 → $block3',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startHybridProgram(block1, block2, block3);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start Hybrid'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blockPicker(String label, String current, List<String> options, ValueChanged<String> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current,
                isExpanded: true,
                items: options.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _startHybridProgram(String block1, String block2, String block3) {
    // Save current program to history first
    _saveToHistory();

    // Build hybrid schedule: weeks 1-4 from block1, 5-8 from block2, 9-13 from block3
    final schedule1 = P90X3Schedule.schedules[block1]!;
    final schedule2 = P90X3Schedule.schedules[block2]!;
    final schedule3 = P90X3Schedule.schedules[block3]!;

    // Each block is ~28 days (4 weeks), last block gets remaining
    final builtSchedule = <String>[];
    for (int i = 0; i < 90; i++) {
      if (i < 28) {
        builtSchedule.add(schedule1[i]);
      } else if (i < 56) {
        builtSchedule.add(schedule2[i]);
      } else {
        builtSchedule.add(schedule3[i]);
      }
    }

    // Store the hybrid info
    setState(() {
      selectedProgram = 'Hybrid ($block1/$block2/$block3)';
      hybridSchedule = builtSchedule;
      completedDays.clear();
      completedAbRipper.clear();
      completedElliptical.clear();
      workoutWeights.clear();
      currentDay = 1;
      displayDay = null;
      _celebrationShown = false;
      isRestWeek = false;
      restWeekStartDate = null;
      isMakeupWeek = false;
      makeupSchedule.clear();
      completedMakeupDays.clear();
      completedMakeupAbRipper.clear();
      completedMakeupElliptical.clear();
      currentMakeupIndex = 0;
      final today = DateTime.now();
      programStartDate = DateTime(today.year, today.month, today.day);
      // Enable Ab Ripper using Classic pattern (same for all)
      daysWithAbRipper.clear();
      final eligibleDays = P90X3Schedule.abRipperDays['Classic'] ?? [];
      daysWithAbRipper.addAll(eligibleDays);
    });
    _saveProgress();
  }

  void _saveToHistory() {
    if (selectedProgram == null || programStartDate == null) return;
    if (completedDays.isEmpty) return; // Don't save empty programs
    programHistory.add({
      'program': selectedProgram,
      'startDate': programStartDate!.toIso8601String(),
      'endDate': DateTime.now().toIso8601String(),
      'daysCompleted': completedDays.length,
      'abRipperSessions': completedAbRipper.length,
      'ellipticalSessions': completedElliptical.length,
      'completedDays': completedDays.toList(),
      'completedAbRipper': completedAbRipper.toList(),
      'completedElliptical': completedElliptical.toList(),
      'weights': Map<String, dynamic>.from(workoutWeights.map((k, v) => MapEntry(k.toString(), v))),
      'beltEarned': _beltName,
    });
  }

  Future<void> _restartProgram(String program) async {
    // Auto-export completion backup before reset
    _saveToHistory();
    await _exportCompletionStats();
    setState(() {
      completedDays.clear();
      completedAbRipper.clear();
      completedElliptical.clear();
      workoutWeights.clear();
      hybridSchedule = null;
      currentDay = 1;
      displayDay = null;
      _celebrationShown = false;
      isRestWeek = false;
      restWeekStartDate = null;
      isMakeupWeek = false;
      makeupSchedule.clear();
      completedMakeupDays.clear();
      completedMakeupAbRipper.clear();
      completedMakeupElliptical.clear();
      currentMakeupIndex = 0;
      final today = DateTime.now();
      programStartDate = DateTime(today.year, today.month, today.day);
      // Re-enable Ab Ripper for all eligible days
      daysWithAbRipper.clear();
      final eligibleDays = P90X3Schedule.abRipperDays[program] ?? [];
      daysWithAbRipper.addAll(eligibleDays);
    });
    _saveProgress();
  }

  Future<void> _switchProgram() async {
    // Auto-export completion backup before reset
    _saveToHistory();
    await _exportCompletionStats();
    setState(() {
      selectedProgram = null;
      completedDays.clear();
      completedAbRipper.clear();
      completedElliptical.clear();
      workoutWeights.clear();
      hybridSchedule = null;
      currentDay = 1;
      displayDay = null;
      programStartDate = null;
      _celebrationShown = false;
      isRestWeek = false;
      restWeekStartDate = null;
      isMakeupWeek = false;
      makeupSchedule.clear();
      completedMakeupDays.clear();
      completedMakeupAbRipper.clear();
      completedMakeupElliptical.clear();
      currentMakeupIndex = 0;
    });
    _saveProgress();
  }

  void _startRestWeek() {
    setState(() {
      isRestWeek = true;
      restWeekStartDate = DateTime.now();
    });
    _saveProgress();
  }

  void _endRestWeek() {
    setState(() {
      isRestWeek = false;
      restWeekStartDate = null;
    });
    _saveProgress();
    // After rest week, go to program selection
    Future.microtask(() => _switchProgram());
  }

  void _skipRestWeek() {
    setState(() {
      isRestWeek = false;
      restWeekStartDate = null;
    });
    _saveProgress();
    _showWhatsNext();
  }

  Widget _buildRestWeekView() {
    final daysSinceRest = restWeekStartDate != null
        ? DateTime.now().difference(restWeekStartDate!).inDays + 1
        : 1;
    final restDay = daysSinceRest.clamp(1, 7);
    final messages = [
      'Your body is recovering and growing stronger.',
      'Rest is when the real gains happen.',
      'Active recovery keeps you ready for what\'s next.',
      'Halfway through your rest week!',
      'Light stretching and walking are great today.',
      'Almost there - your next program awaits!',
      'Last rest day. Time to choose your next challenge!',
    ];
    final message = messages[(restDay - 1).clamp(0, 6)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hotel_rounded, size: 64, color: Colors.purple),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Rest Week',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Day $restDay of 7',
                    style: TextStyle(fontSize: 24, color: Colors.purple[700], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: restDay / 7,
                      minHeight: 8,
                      backgroundColor: Colors.purple.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _skipRestWeek,
                      icon: const Icon(Icons.flash_on_rounded),
                      label: const Text('Ready to go!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // ==================== END COMPLETION FEATURES ====================

  Widget _buildCalendarView() {
    if (programStartDate == null || selectedProgram == null) return const SizedBox();

    // Calculate how many months we need to show
    final lastDay = isMakeupWeek && makeupSchedule.isNotEmpty
        ? makeupSchedule.last['day'] as int
        : 90;
    final endDate = programStartDate!.add(Duration(days: lastDay - 1));
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
                      return Expanded(child: Container(height: 90));
                    }

                    final dayNumber = cellIndex - startOffset + 1;

                    // Empty cell after month ends
                    if (dayNumber > daysInMonth) {
                      return Expanded(child: Container(height: 90));
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

    if (p90x3Day < 1) return null;

    // Allow days > 90 when in makeup mode
    if (p90x3Day > 90) {
      if (isMakeupWeek && makeupSchedule.any((e) => e['day'] == p90x3Day)) {
        return p90x3Day;
      }
      return null;
    }

    return p90x3Day;
  }

  Widget _buildCalendarCell(DateTime date, int? p90x3Day) {
    final now = DateTime.now();
    final isActualToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (p90x3Day == null) {
      return Container(
        height: 90,
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
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ),
      );
    }

    final String workout;
    final bool isCompleted;
    final bool isToday;
    final bool isRest;
    final bool hasAbRipper;
    final bool abCompleted;
    final bool hasWeight;
    final bool cardioDone;

    if (p90x3Day > 90) {
      final makeupEntry = makeupSchedule.firstWhere(
        (e) => e['day'] == p90x3Day,
        orElse: () => <String, dynamic>{},
      );
      if (makeupEntry.isEmpty) return Container(height: 90);
      workout = makeupEntry['workout'] as String;
      isCompleted = completedMakeupDays.contains(p90x3Day);
      isToday = false;
      isRest = false;
      hasAbRipper = makeupEntry['hasAbRipper'] == true;
      abCompleted = completedMakeupAbRipper.contains(p90x3Day);
      hasWeight = false;
      cardioDone = completedMakeupElliptical.contains(p90x3Day);
    } else {
      workout = _getWorkout(p90x3Day);
      isCompleted = completedDays.contains(p90x3Day);
      isToday = p90x3Day == actualTodayP90X3Day;
      isRest = workout.contains('Rest') || workout.contains('Dynamix');
      hasAbRipper = daysWithAbRipper.contains(p90x3Day);
      abCompleted = completedAbRipper.contains(p90x3Day);
      hasWeight = workoutWeights.containsKey(p90x3Day);
      cardioDone = completedElliptical.contains(p90x3Day);
    }

    // Section tracking: main + cardio always, ab ripper on designated days
    final int sectionCount = hasAbRipper ? 3 : 2;
    int doneCount = 0;
    if (isCompleted) doneCount++;
    if (hasAbRipper && abCompleted) doneCount++;
    if (cardioDone) doneCount++;
    final bool allDone = doneCount == sectionCount;
    // Don't show blue "today" indicator once main workout is done
    final bool showAsToday = isToday && !isCompleted;

    return InkWell(
      onTap: p90x3Day > 90
          ? null
          : () => _showDayDialog(p90x3Day, workout, isCompleted, isRest),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 90,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActualToday
                ? Colors.orange
                : showAsToday
                    ? Colors.blue.shade300
                    : allDone
                        ? Colors.green.shade300
                        : Colors.grey.shade200,
            width: isActualToday ? 3 : (showAsToday ? 2 : 1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isActualToday ? 5 : 7),
          child: Column(
            children: [
              // Date row at top (not a section, just info)
              Container(
                height: hasWeight ? 28 : 20,
                color: allDone
                    ? Colors.green.shade600
                    : showAsToday
                        ? Colors.blue.shade500
                        : Colors.grey[50],
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4, top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              color: allDone || showAsToday ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (allDone)
                            Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          if (hasWeight)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: allDone || showAsToday
                                    ? Colors.white.withOpacity(0.25)
                                    : Colors.blue.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${workoutWeights[p90x3Day]}lb',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Cardio section (always present, topmost section)
              _buildCellSection('⚡', cardioDone, allDone, showAsToday),
              // Ab Ripper section (if applicable)
              if (hasAbRipper)
                _buildCellSection('🥋', abCompleted, allDone, showAsToday),
              // Main workout section (bottom, shows name instead of icon)
              _buildMainSection(
                _abbreviateWorkout(workout),
                isCompleted,
                allDone,
                showAsToday,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCellSection(String emoji, bool done, bool allDone, bool isToday) {
    Color bgColor;
    if (allDone) {
      bgColor = Colors.green.shade500;
    } else if (done) {
      bgColor = Colors.green.shade500;
    } else if (isToday) {
      bgColor = Colors.blue.shade800.withOpacity(0.3);
    } else {
      bgColor = Colors.grey.shade100;
    }
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(
              color: allDone
                  ? Colors.green.shade400.withOpacity(0.4)
                  : isToday
                      ? Colors.blue.shade300.withOpacity(0.2)
                      : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Center(
          child: Opacity(
            opacity: done ? 1.0 : 0.25,
            child: Text(emoji, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ),
    );
  }

  Widget _buildMainSection(String name, bool done, bool allDone, bool isToday) {
    Color bgColor;
    if (allDone) {
      bgColor = Colors.green.shade700;
    } else if (done) {
      bgColor = Colors.green.shade600;
    } else if (isToday) {
      bgColor = Colors.blue.shade900.withOpacity(0.35);
    } else {
      bgColor = Colors.grey.shade200;
    }
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(
              color: allDone
                  ? Colors.green.shade400.withOpacity(0.4)
                  : isToday
                      ? Colors.blue.shade300.withOpacity(0.2)
                      : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: done || allDone
                  ? Colors.white
                  : isToday
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey[800],
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
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
    // Show makeup week view if in makeup mode
    if (isMakeupWeek) {
      return _buildMakeupWeekView();
    }

    // Show rest week view if in rest week
    if (isRestWeek) {
      return _buildRestWeekView();
    }

    if (selectedProgram == null) {
      return _buildProgramSelection();
    }

    // Use displayDay if set, otherwise use actual today
    final currentDisplayDay = displayDay ?? actualTodayP90X3Day;
    final todayWorkout = _getWorkout(currentDisplayDay);
    final completedCount = completedDays.length;
    final progressPercent = completedCount / 90;
    final canHaveAbRipper = P90X3Schedule.canHaveAbRipper(selectedProgram!, currentDisplayDay);
    final hasAbRipper = daysWithAbRipper.contains(currentDisplayDay);

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
                      // Menu button
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) {
                          if (value == 'view_stats') {
                            _showCelebration();
                          } else if (value == 'export_completion') {
                            _exportCompletionStats();
                          } else if (value == 'whats_next') {
                            _showWhatsNext();
                          } else if (value == 'reset') {
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
                                        completedElliptical.clear(); // Add this line
                                        currentDay = 1;
                                        displayDay = null;
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
                          } else if (value == 'export') {
                            _exportBackup();
                          } else if (value == 'import') {
                            _importBackup();
                          } else if (value == 'history') {
                            _showProgramHistory();
                          } else if (value == 'hybrid') {
                            _showCombineRoutines();
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
                          if (isProgramComplete)
                            const PopupMenuItem(
                              value: 'view_stats',
                              child: Row(
                                children: [
                                  Icon(Icons.emoji_events_rounded, size: 20, color: Colors.amber),
                                  SizedBox(width: 12),
                                  Text('View Completion Stats'),
                                ],
                              ),
                            ),
                          if (isProgramComplete)
                            const PopupMenuItem(
                              value: 'export_completion',
                              child: Row(
                                children: [
                                  Icon(Icons.assessment_rounded, size: 20, color: Colors.purple),
                                  SizedBox(width: 12),
                                  Text('Export Completion Report'),
                                ],
                              ),
                            ),
                          if (isProgramComplete)
                            const PopupMenuItem(
                              value: 'whats_next',
                              child: Row(
                                children: [
                                  Icon(Icons.explore_rounded, size: 20, color: P90X3Colors.primary),
                                  SizedBox(width: 12),
                                  Text('Start New Program'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'history',
                            child: Row(
                              children: [
                                Icon(Icons.history_rounded, size: 20, color: Colors.deepPurple),
                                SizedBox(width: 12),
                                Text('Program History'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'hybrid',
                            child: Row(
                              children: [
                                Icon(Icons.merge_rounded, size: 20, color: Colors.deepPurple),
                                SizedBox(width: 12),
                                Text('Create Hybrid Program'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.upload_rounded, size: 20, color: P90X3Colors.primary),
                                SizedBox(width: 12),
                                Text('Export Backup'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'import',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded, size: 20, color: P90X3Colors.success),
                                SizedBox(width: 12),
                                Text('Import Backup'),
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
                        _buildCircularStat('Day', currentDisplayDay, 90, Colors.blue),
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

                const SizedBox(height: 12),

                // Program Complete Banner
                if (isProgramComplete)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF764ba2).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Program Complete!',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  '$_beltName Belt Earned',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _showWhatsNext,
                            child: const Text("What's Next?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (isProgramComplete) const SizedBox(height: 12),

                // Workout Completion Counters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                        _buildCompactCounter(
                          'Total',
                          completedDays.length + completedAbRipper.length + completedElliptical.length,
                          Icons.fitness_center,
                          Colors.deepPurple,
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[200]),
                        _buildCompactCounter(
                          'Ab Rippers',
                          completedAbRipper.length,
                          Icons.sports_martial_arts,
                          Colors.red,
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[200]),
                        _buildCompactCounter(
                          'Cardios',
                          completedElliptical.length,
                          Icons.directions_run,
                          Colors.teal,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // In the build method, update the Today's Workout Card section:

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
                                          () {
                                        // Calculate the difference between display day and actual today
                                        final diff = currentDisplayDay - actualTodayP90X3Day;
                                        if (diff == 0) return 'TODAY';
                                        if (diff == 1) return 'TOMORROW';
                                        if (diff == -1) return 'YESTERDAY';

                                        // Otherwise show the actual date
                                        if (programStartDate != null) {
                                          final date = programStartDate!.add(Duration(days: currentDisplayDay - 1));
                                          final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                                            'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                                          return '${months[date.month - 1]} ${date.day}';
                                        }
                                        return 'DAY';
                                      }(),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      'Day $currentDisplayDay of 90',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Elliptical checkbox (top right)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Text(
                                    completedElliptical.contains(currentDisplayDay) ? '⚡' : '⚪',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  onPressed: () => _toggleEllipticalComplete(currentDisplayDay),
                                  tooltip: 'Elliptical',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Main workout completion (was already here)
                              if (completedDays.contains(currentDisplayDay))
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
                          // ... rest of the card stays the same
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
                                  onPressed: currentDisplayDay > 1 ? _goToPreviousDay : null,
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
                                    _getDayOfWeek(currentDisplayDay),
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
                                  tooltip: 'Reset Day',
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
                                  onPressed: currentDisplayDay < 90 ? _goToNextDay : null,
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
                                        : () => _playVideo(todayWorkout, currentDisplayDay),
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
                                    onPressed: () => _playVideo('Ab Ripper X', currentDisplayDay),
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
                                        onPressed: () => _markDayComplete(currentDisplayDay),
                                        icon: Icon(
                                          completedDays.contains(currentDisplayDay)
                                              ? Icons.check_circle_rounded
                                              : Icons.check_circle_outline_rounded,
                                        ),
                                        label: Text(
                                          completedDays.contains(currentDisplayDay) ? 'DONE' : 'MARK DONE',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: completedDays.contains(currentDisplayDay)
                                                ? Colors.green
                                                : Colors.white.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          backgroundColor: completedDays.contains(currentDisplayDay)
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
                                        onPressed: () => _toggleAbRipperComplete(currentDisplayDay),
                                        icon: Icon(
                                          completedAbRipper.contains(currentDisplayDay)
                                              ? Icons.check_circle_rounded
                                              : Icons.check_circle_outline_rounded,
                                        ),
                                        label: Text(
                                          completedAbRipper.contains(currentDisplayDay) ? 'AB DONE' : 'AB MARK',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: completedAbRipper.contains(currentDisplayDay)
                                                ? Colors.orange
                                                : Colors.white.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          backgroundColor: completedAbRipper.contains(currentDisplayDay)
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
                                    onPressed: () {
                                      // Handle Rest or Dynamix
                                      if (todayWorkout.contains('Dynamix')) {
                                        _playVideo('Dynamix', currentDisplayDay);
                                      } else if (!todayWorkout.contains('Rest')) {
                                        _playVideo(todayWorkout, currentDisplayDay);
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                    label: Text(
                                      todayWorkout.contains('Dynamix') ? 'PLAY DYNAMIX' : 'PLAY WORKOUT',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: _getWorkoutColor(todayWorkout),
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
                                            completedDays.contains(currentDisplayDay)
                                                ? Icons.check_circle_rounded
                                                : Icons.check_circle_outline_rounded,
                                            size: 36,
                                          ),
                                          color: Colors.white,
                                          onPressed: () => _markDayComplete(currentDisplayDay),
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

  Widget _buildCompactCounter(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
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

// Update the HorizontalBeltPainter class:

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

    // Bottom belt - moved up from 0.70 to 0.55
    final bottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.60 - strokeWidth, size.width, strokeWidth),
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
      Offset(0, size.height * 0.60 - strokeWidth),
      Offset(size.width, size.height * 0.60 - strokeWidth),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
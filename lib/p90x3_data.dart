class P90X3Schedule {
  static final Map<String, List<String>> schedules = {
    'Classic': [
      'Total Synergistics', 'Agility X', 'X3 Yoga', 'The Challenge',
      'CVX', 'The Warrior', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'Eccentric Lower',
      'CVX', 'The Warrior', 'Rest or Dynamix',
      'Total Synergistics', 'Agility X', 'Isometrix', 'Incinerator',
      'MMX', 'Pilates X', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'Eccentric Lower',
      'CVX', 'Decelerator', 'Rest or Dynamix',
      'Transition Week: The Challenge, CVX, X3 Yoga, The Warrior, Dynamix, Pilates X, Rest',
      // Week 6-9 (Mass)
      'The Challenge', 'CVX', 'X3 Yoga', 'The Warrior',
      'Incinerator', 'MMX', 'Rest or Dynamix',
      'The Challenge', 'CVX', 'Isometrix', 'The Warrior',
      'Incinerator', 'Pilates X', 'Rest or Dynamix',
      'Accelerator', 'Decelerator', 'X3 Yoga', 'The Challenge',
      'CVX', 'Triometrics', 'Rest or Dynamix',
      'Accelerator', 'Decelerator', 'Isometrix', 'The Challenge',
      'CVX', 'MMX', 'Rest or Dynamix',
      'Transition Week: The Warrior, Accelerator, X3 Yoga, Decelerator, Dynamix, Pilates X, Rest',
      // Week 11-13 (Burn)
      'Total Synergistics', 'Agility X', 'X3 Yoga', 'The Challenge',
      'CVX', 'The Warrior', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'Isometrix', 'Eccentric Lower',
      'CVX', 'Triometrics', 'Rest or Dynamix',
      'Total Synergistics', 'Agility X', 'X3 Yoga', 'Incinerator',
      'MMX', 'Pilates X', 'Rest or Dynamix',
    ].expand((week) => week.contains('Transition') 
        ? week.replaceAll('Transition Week: ', '').split(', ')
        : [week]).toList(),
    
    'Lean': [
      'Total Synergistics', 'Agility X', 'X3 Yoga', 'CVX',
      'The Challenge', 'Dynamix', 'Rest',
      'Total Synergistics', 'CVX', 'X3 Yoga', 'Agility X',
      'The Challenge', 'Dynamix', 'Rest',
      'Total Synergistics', 'CVX', 'Isometrix', 'Agility X',
      'Incinerator', 'Pilates X', 'Rest',
      'Total Synergistics', 'CVX', 'X3 Yoga', 'Agility X',
      'The Challenge', 'Dynamix', 'Rest',
      'Transition Week: CVX, Agility X, X3 Yoga, The Challenge, Dynamix, Pilates X, Rest',
      // Continue with similar pattern for weeks 6-13
      'CVX', 'Agility X', 'X3 Yoga', 'The Challenge',
      'Incinerator', 'MMX', 'Rest',
      'CVX', 'Agility X', 'Isometrix', 'The Challenge',
      'Incinerator', 'Pilates X', 'Rest',
      'Accelerator', 'Decelerator', 'X3 Yoga', 'CVX',
      'The Challenge', 'Triometrics', 'Rest',
      'Accelerator', 'Decelerator', 'Isometrix', 'CVX',
      'The Challenge', 'MMX', 'Rest',
      'Transition Week: The Challenge, Accelerator, X3 Yoga, Decelerator, Dynamix, Pilates X, Rest',
      'Total Synergistics', 'CVX', 'X3 Yoga', 'Agility X',
      'The Challenge', 'Dynamix', 'Rest',
      'Total Synergistics', 'CVX', 'Isometrix', 'Agility X',
      'The Challenge', 'Triometrics', 'Rest',
      'Total Synergistics', 'CVX', 'X3 Yoga', 'Incinerator',
      'MMX', 'Pilates X', 'Rest',
    ].expand((week) => week.contains('Transition') 
        ? week.replaceAll('Transition Week: ', '').split(', ')
        : [week]).toList(),
    
    'Mass': [
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'The Challenge',
      'Eccentric Lower', 'The Warrior', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'The Challenge',
      'Eccentric Lower', 'The Warrior', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'Isometrix', 'Incinerator',
      'Eccentric Lower', 'Pilates X', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'The Challenge',
      'Eccentric Lower', 'The Warrior', 'Rest or Dynamix',
      'Transition Week: The Challenge, Eccentric Upper, X3 Yoga, Eccentric Lower, Dynamix, Pilates X, Rest',
      'The Challenge', 'Eccentric Upper', 'X3 Yoga', 'The Warrior',
      'Eccentric Lower', 'Incinerator', 'Rest or Dynamix',
      'The Challenge', 'Eccentric Upper', 'Isometrix', 'The Warrior',
      'Eccentric Lower', 'Incinerator', 'Rest or Dynamix',
      'Accelerator', 'The Challenge', 'X3 Yoga', 'Decelerator',
      'Eccentric Lower', 'Triometrics', 'Rest or Dynamix',
      'Accelerator', 'The Challenge', 'Isometrix', 'Decelerator',
      'Eccentric Lower', 'Incinerator', 'Rest or Dynamix',
      'Transition Week: The Warrior, Accelerator, X3 Yoga, Decelerator, Dynamix, Pilates X, Rest',
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'The Challenge',
      'Eccentric Lower', 'The Warrior', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'Isometrix', 'The Challenge',
      'Eccentric Lower', 'Triometrics', 'Rest or Dynamix',
      'Total Synergistics', 'Eccentric Upper', 'X3 Yoga', 'Incinerator',
      'Eccentric Lower', 'Pilates X', 'Rest or Dynamix',
    ].expand((week) => week.contains('Transition') 
        ? week.replaceAll('Transition Week: ', '').split(', ')
        : [week]).toList(),
  };

  static String getWorkoutForDay(String program, int dayNumber) {
    final schedule = schedules[program];
    if (schedule == null || dayNumber < 1 || dayNumber > 90) return 'Rest';
    return schedule[dayNumber - 1];
  }
}

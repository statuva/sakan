import '../models/family_moment.dart';
import '../models/member.dart';
import '../models/model_enums.dart';

/// Short, deterministic recommendation copy for one member and one Moment.
///
/// The first task is always the primary task. At most two supporting tasks are
/// returned. Remote AI may reword the explanation, but this role-safe task plan
/// remains deterministic.
class MemberMomentRecommendation {
  MemberMomentRecommendation({
    required this.summary,
    required List<String> tasks,
    required this.recommendsSimulation,
    this.scheduleNote,
  }) : assert(tasks.isNotEmpty),
       tasks = List<String>.unmodifiable(tasks.take(3));

  final String summary;
  final List<String> tasks;
  final bool recommendsSimulation;
  final String? scheduleNote;

  String get primaryTask => tasks.first;
  List<String> get secondaryTasks => tasks.skip(1).toList(growable: false);
}

abstract final class MemberMomentRecommendationBuilder {
  static MemberMomentRecommendation build({
    required Member member,
    required FamilyMoment moment,
    bool hasScheduleConflict = false,
    bool hasVerifiedFreeWindow = false,
    bool isDrifting = false,
  }) {
    final viewer = _viewerKind(member);
    final meaning = _meaningFor(moment);
    final isSubject = moment.isSubject(member.id);

    final tasks = isDrifting
        ? _driftingTasks(viewer, moment.title)
        : isSubject
        ? _subjectTasks(viewer, meaning, moment.title)
        : _participantTasks(viewer, meaning, moment);

    final mayUseSimulation =
        _isAdultOrAdmin(member) &&
        moment.type == MomentType.recurring &&
        (isDrifting || hasScheduleConflict);

    if (mayUseSimulation) {
      final simulationTask = isDrifting
          ? 'Try a What-if simulation before choosing the next time.'
          : 'Try a What-if simulation to compare a conflict-free time.';
      if (isDrifting) {
        _prependRequired(tasks, simulationTask);
      } else {
        _appendRequired(tasks, simulationTask);
      }
    } else if (hasScheduleConflict) {
      _appendRequired(
        tasks,
        switch (viewer) {
          _ViewerKind.adult =>
            'Confirm the fixed time and plan around the recorded conflict.',
          _ViewerKind.teen => 'Ask an adult to compare a different time.',
          _ViewerKind.child =>
            'Ask an adult when this Moment should happen.',
        },
      );
    }

    return MemberMomentRecommendation(
      summary: _summaryFor(
        viewer: viewer,
        meaning: meaning,
        title: moment.title,
        isSubject: isSubject,
        hasScheduleConflict: hasScheduleConflict,
        isDrifting: isDrifting,
      ),
      tasks: _unique(tasks),
      recommendsSimulation: mayUseSimulation,
      scheduleNote: hasScheduleConflict
          ? viewer == _ViewerKind.adult
                ? 'This Moment overlaps a recorded busy time for an expected family member.'
                : 'This Moment overlaps a busy time in your recorded schedule.'
          : hasVerifiedFreeWindow
          ? 'The suggested preparation time avoids your recorded busy times.'
          : null,
    );
  }

  static List<String> _participantTasks(
    _ViewerKind viewer,
    _MomentMeaning meaning,
    FamilyMoment moment,
  ) {
    final title = moment.title;

    return switch ((viewer, meaning)) {
      (_ViewerKind.adult, _MomentMeaning.meal) => <String>[
        'Choose the menu and check the ingredients.',
        'Assign one simple food or table task.',
        'Confirm the meal still fits the planned time.',
      ],
      (_ViewerKind.teen, _MomentMeaning.meal) => <String>[
        'Choose one dish you can help prepare.',
        'Check which ingredient is still missing.',
        'Be ready ten minutes before the meal.',
      ],
      (_ViewerKind.child, _MomentMeaning.meal) => <String>[
        'Choose one small table-setting job.',
        'Pick one food you can help with.',
        'Ask an adult when to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.birthday) => <String>[
        'Choose or order the birthday gift.',
        'Write the family card or message.',
        'Confirm the cake, travel, and arrival time.',
      ],
      (_ViewerKind.teen, _MomentMeaning.birthday) => <String>[
        'Write a personal birthday message.',
        'Choose a photo or song for the celebration.',
        'Check when you need to be ready.',
      ],
      (_ViewerKind.child, _MomentMeaning.birthday) => <String>[
        'Draw or sign the birthday card.',
        'Choose one kind thing to say.',
        'Ask an adult when to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.graduation) => <String>[
        'Choose or order the graduation gift.',
        'Write a short congratulatory message.',
        'Confirm the route and arrival time.',
      ],
      (_ViewerKind.teen, _MomentMeaning.graduation) => <String>[
        'Write a personal congratulations message.',
        'Choose a photo to share with the family.',
        'Check when you need to be ready.',
      ],
      (_ViewerKind.child, _MomentMeaning.graduation) => <String>[
        'Draw or sign a congratulations card.',
        'Practice one kind sentence to say.',
        'Ask an adult when to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.picnic) => <String>[
        'Choose the picnic spot and confirm the travel time.',
        'Check the shared food and outdoor essentials.',
        'Assign drinks, snacks, or one family game.',
      ],
      (_ViewerKind.teen, _MomentMeaning.picnic) => <String>[
        'Choose a game or playlist to bring.',
        'Help prepare one snack or drink.',
        'Check when you need to be ready.',
      ],
      (_ViewerKind.child, _MomentMeaning.picnic) => <String>[
        'Choose one outdoor game to bring.',
        'Pack water and a hat with an adult.',
        'Ask when you need to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.appointment) => <String>[
        'Gather the documents and questions to bring.',
        'Confirm the route and departure time.',
        'Put the appointment details in one place.',
      ],
      (_ViewerKind.teen, _MomentMeaning.appointment) => <String>[
        'Write down the questions you want to ask.',
        'Put the documents you need in your bag.',
        'Check the departure time with an adult.',
      ],
      (_ViewerKind.child, _MomentMeaning.appointment) => <String>[
        'Tell an adult any question you want to ask.',
        'Choose one comfort item to bring.',
        'Ask when you need to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.wedding) => <String>[
        'Choose the wedding gift.',
        'Write a short message for the couple.',
        'Confirm outfits, transport, and arrival time.',
      ],
      (_ViewerKind.teen, _MomentMeaning.wedding) => <String>[
        'Write or sign a message for the couple.',
        'Set aside what you plan to wear.',
        'Check the family departure time.',
      ],
      (_ViewerKind.child, _MomentMeaning.wedding) => <String>[
        'Draw or sign a card for the couple.',
        'Set aside what you will wear with an adult.',
        'Ask when you need to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.trip) => <String>[
        'Confirm the route, departure time, and transport.',
        'Check the shared packing list.',
        'Assign one travel item to each person.',
      ],
      (_ViewerKind.teen, _MomentMeaning.trip) => <String>[
        'Pack your personal essentials.',
        'Choose one useful travel item to carry.',
        'Check the family departure time.',
      ],
      (_ViewerKind.child, _MomentMeaning.trip) => <String>[
        'Pack one favorite item with an adult.',
        'Choose a snack or activity for the journey.',
        'Ask when you need to be ready.',
      ],
      (_ViewerKind.adult, _MomentMeaning.movie) => <String>[
        'Choose the movie and where the family will watch it.',
        'Check that the planned time works for everyone.',
        'Prepare one simple snack or drink.',
      ],
      (_ViewerKind.teen, _MomentMeaning.movie) => <String>[
        'Suggest one movie that fits the family.',
        'Help prepare a snack or the screen.',
        'Check when everyone plans to start.',
      ],
      (_ViewerKind.child, _MomentMeaning.movie) => <String>[
        'Choose one family-friendly movie suggestion.',
        'Pick a small snack with an adult.',
        'Be ready when the movie starts.',
      ],
      _ => _categoryTasks(viewer, moment.category, title),
    };
  }

  static List<String> _subjectTasks(
    _ViewerKind viewer,
    _MomentMeaning meaning,
    String title,
  ) {
    return switch ((viewer, meaning)) {
      (_, _MomentMeaning.appointment) => viewer == _ViewerKind.child
          ? <String>[
              'Tell an adult any question you want to ask.',
              'Choose one comfort item to bring.',
              'Ask when you need to be ready.',
            ]
          : <String>[
              'Write down the questions you want to ask.',
              'Gather the documents you need.',
              'Confirm when you need to leave.',
            ],
      (_, _MomentMeaning.graduation) => viewer == _ViewerKind.child
          ? <String>[
              'Tell an adult what you need for your graduation.',
              'Set aside what you will wear.',
              'Ask when you need to be ready.',
            ]
          : <String>[
              'Check the ceremony details and what you must bring.',
              'Set aside your outfit or required documents.',
              'Confirm when you need to leave.',
            ],
      (_, _MomentMeaning.birthday) => viewer == _ViewerKind.child
          ? <String>[
              'Tell an adult one thing you would enjoy.',
              'Choose what you want to wear.',
              'Ask when you need to be ready.',
            ]
          : <String>[
              'Share one preference for your celebration.',
              'Confirm when you need to be ready.',
              'Set aside anything you want to bring.',
            ],
      _ => viewer == _ViewerKind.child
          ? <String>[
              'Tell an adult what you need for $title.',
              'Set aside one thing you need to bring.',
              'Ask when you need to be ready.',
            ]
          : <String>[
              'Confirm what you need for $title.',
              'Set aside the main thing you need to bring.',
              'Check when you need to be ready.',
            ],
    };
  }

  static List<String> _categoryTasks(
    _ViewerKind viewer,
    MomentCategory category,
    String title,
  ) {
    return switch ((viewer, category)) {
      (_ViewerKind.adult, MomentCategory.milestone) => <String>[
        'Choose one personal way to mark $title.',
        'Write a short family message.',
        'Confirm the practical details and arrival time.',
      ],
      (_ViewerKind.teen, MomentCategory.milestone) => <String>[
        'Write one personal message for $title.',
        'Choose a photo or small contribution.',
        'Check when you need to be ready.',
      ],
      (_ViewerKind.child, MomentCategory.milestone) => <String>[
        'Draw or sign a card for $title.',
        'Choose one kind thing to say.',
        'Ask an adult when to be ready.',
      ],
      (_ViewerKind.adult, MomentCategory.care) => <String>[
        'Choose the support or item needed for $title.',
        'Confirm who will bring it.',
        'Check the travel or handoff time.',
      ],
      (_ViewerKind.teen, MomentCategory.care) => <String>[
        'Choose one helpful thing you can do for $title.',
        'Set aside the item you will bring.',
        'Check the time with an adult.',
      ],
      (_ViewerKind.child, MomentCategory.care) => <String>[
        'Choose one kind thing you can do for $title.',
        'Prepare one small item with an adult.',
        'Ask when you need to be ready.',
      ],
      (_ViewerKind.adult, MomentCategory.responsibility) => <String>[
        'Gather the main item needed for $title.',
        'Confirm who owns each part.',
        'Check that the planned time is still realistic.',
      ],
      (_ViewerKind.teen, MomentCategory.responsibility) => <String>[
        'Start the part of $title assigned to you.',
        'Gather the item you need.',
        'Check the deadline with an adult.',
      ],
      (_ViewerKind.child, MomentCategory.responsibility) => <String>[
        'Do one small part of $title with an adult.',
        'Put the item you need in one place.',
        'Ask when it needs to be finished.',
      ],
      (_ViewerKind.adult, MomentCategory.tradition) ||
      (_ViewerKind.adult, MomentCategory.familyTime) ||
      (_ViewerKind.adult, MomentCategory.memory) => <String>[
        'Choose the shared activity or item for $title.',
        'Confirm who plans to join.',
        'Check that the planned time still works.',
      ],
      (_ViewerKind.teen, MomentCategory.tradition) ||
      (_ViewerKind.teen, MomentCategory.familyTime) ||
      (_ViewerKind.teen, MomentCategory.memory) => <String>[
        'Choose one activity or item to contribute to $title.',
        'Ask what help is still needed.',
        'Check when you need to be ready.',
      ],
      _ => <String>[
        'Choose one small way to help with $title.',
        'Prepare one item with an adult.',
        'Ask when you need to be ready.',
      ],
    };
  }

  static List<String> _driftingTasks(_ViewerKind viewer, String title) {
    return switch (viewer) {
      _ViewerKind.adult => <String>[
        'Choose a realistic next date for $title.',
        'Check who can join before confirming it.',
      ],
      _ViewerKind.teen => <String>[
        'Tell an adult which upcoming time works for you.',
        'Choose one way you can help restart $title.',
      ],
      _ViewerKind.child => <String>[
        'Tell an adult when you would enjoy $title.',
        'Choose one small thing to bring next time.',
      ],
    };
  }

  static String _summaryFor({
    required _ViewerKind viewer,
    required _MomentMeaning meaning,
    required String title,
    required bool isSubject,
    required bool hasScheduleConflict,
    required bool isDrifting,
  }) {
    if (isDrifting) {
      return viewer == _ViewerKind.adult
          ? '$title needs a realistic next time before its rhythm can restart.'
          : '$title needs a new family plan before it can restart.';
    }
    if (hasScheduleConflict) {
      return viewer == _ViewerKind.adult
          ? '$title overlaps a recorded busy time, so prepare the urgent part and compare another time.'
          : '$title overlaps your recorded busy time, so prepare your part and ask an adult about timing.';
    }
    if (isSubject) {
      return 'This Moment is about you, so your task focuses on what you need rather than preparing for yourself.';
    }

    return switch (meaning) {
      _MomentMeaning.meal => 'A small food decision now can make $title easier to start on time.',
      _MomentMeaning.birthday => 'A personal message and one practical check will make the birthday plan clearer.',
      _MomentMeaning.graduation => 'A personal congratulations and arrival check are the useful preparations now.',
      _MomentMeaning.picnic => 'Choose the shared essentials before the picnic so the family can leave on time.',
      _MomentMeaning.appointment => 'Questions, documents, and departure time are the important details now.',
      _MomentMeaning.wedding => 'The gift, message, and travel details are the useful preparations now.',
      _MomentMeaning.trip => 'Packing and departure details are the useful preparations for $title.',
      _MomentMeaning.movie => 'One viewing choice and a simple setup are enough to prepare $title.',
      _MomentMeaning.generic => 'Choose one useful contribution for $title and check when it is needed.',
    };
  }

  static _ViewerKind _viewerKind(Member member) {
    if (_isAdultOrAdmin(member)) return _ViewerKind.adult;
    if (member.ageGroup == AgeGroup.teen) return _ViewerKind.teen;
    return _ViewerKind.child;
  }

  static bool _isAdultOrAdmin(Member member) {
    final hasAdultRole =
        member.role == FamilyRole.admin || member.role == FamilyRole.adult;
    final hasAdultAge =
        member.ageGroup == AgeGroup.adult ||
        member.ageGroup == AgeGroup.senior;
    return hasAdultRole && hasAdultAge;
  }

  static _MomentMeaning _meaningFor(FamilyMoment moment) {
    final title = moment.title.toLowerCase();

    if (_containsAny(title, const <String>[
      'lunch', 'lynch', 'dinner', 'breakfast', 'brunch', 'meal',
      'غداء', 'عشاء', 'فطور',
    ])) {
      return _MomentMeaning.meal;
    }
    if (_containsAny(title, const <String>[
      'birthday', 'عيد ميلاد', 'ميلاد',
    ])) {
      return _MomentMeaning.birthday;
    }
    if (_containsAny(title, const <String>[
      'graduation', 'graduate', 'تخرج', 'تخرّج',
    ])) {
      return _MomentMeaning.graduation;
    }
    if (_containsAny(title, const <String>['picnic', 'نزهة'])) {
      return _MomentMeaning.picnic;
    }
    if (_containsAny(title, const <String>[
      'appointment', 'doctor', 'clinic', 'hospital', 'موعد', 'طبيب', 'مستشفى',
    ])) {
      return _MomentMeaning.appointment;
    }
    if (_containsAny(title, const <String>[
      'wedding', 'زفاف', 'عرس',
    ])) {
      return _MomentMeaning.wedding;
    }
    if (_containsAny(title, const <String>[
      'trip', 'travel', 'flight', 'journey', 'رحلة', 'سفر',
    ])) {
      return _MomentMeaning.trip;
    }
    if (_containsAny(title, const <String>[
      'movie', 'film', 'cinema', 'فيلم', 'سينما',
    ])) {
      return _MomentMeaning.movie;
    }
    return _MomentMeaning.generic;
  }

  static bool _containsAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }

  static List<String> _unique(List<String> values) {
    final seen = <String>{};
    return values
        .where((value) => seen.add(value.trim().toLowerCase()))
        .take(3)
        .toList(growable: false);
  }

  static void _appendRequired(List<String> tasks, String task) {
    if (tasks.any((item) => item.toLowerCase() == task.toLowerCase())) return;
    while (tasks.length >= 3) {
      tasks.removeLast();
    }
    tasks.add(task);
  }

  static void _prependRequired(List<String> tasks, String task) {
    if (tasks.any((item) => item.toLowerCase() == task.toLowerCase())) return;
    tasks.insert(0, task);
    while (tasks.length > 3) {
      tasks.removeLast();
    }
  }
}

enum _ViewerKind { adult, teen, child }

enum _MomentMeaning {
  meal,
  birthday,
  graduation,
  picnic,
  appointment,
  wedding,
  trip,
  movie,
  generic,
}

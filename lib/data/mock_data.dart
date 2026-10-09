class MockCourse {
  final String id, title, educator, subject, thumbnail;
  final double rating;
  final double price;
  final bool free;
  const MockCourse(
    this.id,
    this.title,
    this.educator,
    this.subject,
    this.thumbnail,
    this.rating,
    this.price,
    this.free,
  );
}

class MockLecture {
  final String id, courseId, title;
  final int durationMin;
  final String videoUrl;
  const MockLecture(
    this.id,
    this.courseId,
    this.title,
    this.durationMin,
    this.videoUrl,
  );
}

class MockLiveClass {
  final String id, title, educator, subject;
  final DateTime startAt;
  final bool live;
  const MockLiveClass(
    this.id,
    this.title,
    this.educator,
    this.subject,
    this.startAt,
    this.live,
  );
}

class MockQuestion {
  final String id;
  final String text;
  final List<String> options;
  final int correct;
  final String subject;
  const MockQuestion(
    this.id,
    this.text,
    this.options,
    this.correct,
    this.subject,
  );
}

class MockTest {
  final String id, title, subject;
  final int durationMin, totalMarks;
  final String difficulty;
  final List<MockQuestion> questions;
  const MockTest(
    this.id,
    this.title,
    this.subject,
    this.durationMin,
    this.totalMarks,
    this.difficulty,
    this.questions,
  );
}

class MockNotification {
  final String id, title, body, type;
  final DateTime at;
  const MockNotification(this.id, this.title, this.body, this.type, this.at);
}

class MockData {
  static final courses = <MockCourse>[
    MockCourse(
      'c1',
      'JEE Main Physics 2026',
      'Dr. Vikram Thapar',
      'Physics',
      'https://picsum.photos/seed/c1/400/240',
      4.8,
      2999,
      false,
    ),
    MockCourse(
      'c2',
      'NEET Biology Crash Course',
      'Prof. Meera Iyer',
      'Biology',
      'https://picsum.photos/seed/c2/400/240',
      4.7,
      1999,
      false,
    ),
    MockCourse(
      'c3',
      'Class 12 Maths Boards',
      'Rajesh Sharma',
      'Mathematics',
      'https://picsum.photos/seed/c3/400/240',
      4.6,
      0,
      true,
    ),
    MockCourse(
      'c4',
      'Organic Chemistry Masterclass',
      'Dr. Anjali Rao',
      'Chemistry',
      'https://picsum.photos/seed/c4/400/240',
      4.9,
      2499,
      false,
    ),
    MockCourse(
      'c5',
      'JEE Advanced Problems',
      'Dr. Vikram Thapar',
      'Physics',
      'https://picsum.photos/seed/c5/400/240',
      4.8,
      3499,
      false,
    ),
    MockCourse(
      'c6',
      'NCERT Deep Dive',
      'Multiple educators',
      'All',
      'https://picsum.photos/seed/c6/400/240',
      4.5,
      0,
      true,
    ),
  ];

  static final lectures = <MockLecture>[
    MockLecture(
      'l1',
      'c1',
      'Kinematics — Part 1',
      42,
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    MockLecture(
      'l2',
      'c1',
      'Newton\'s Laws of Motion',
      51,
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    MockLecture(
      'l3',
      'c1',
      'Work, Energy and Power',
      38,
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ),
    MockLecture(
      'l4',
      'c2',
      'The Living World',
      29,
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    ),
  ];

  static final live = <MockLiveClass>[
    MockLiveClass(
      'lc1',
      'Thermodynamics — Live Doubt',
      'Dr. Vikram Thapar',
      'Physics',
      DateTime.now().add(const Duration(minutes: 45)),
      false,
    ),
    MockLiveClass(
      'lc2',
      'Cell Biology Session',
      'Prof. Meera Iyer',
      'Biology',
      DateTime.now().subtract(const Duration(minutes: 3)),
      true,
    ),
    MockLiveClass(
      'lc3',
      'Algebra Masterclass',
      'Rajesh Sharma',
      'Mathematics',
      DateTime.now().add(const Duration(hours: 3)),
      false,
    ),
    MockLiveClass(
      'lc4',
      'Organic Reactions',
      'Dr. Anjali Rao',
      'Chemistry',
      DateTime.now().add(const Duration(days: 1)),
      false,
    ),
  ];

  static final tests = <MockTest>[
    MockTest('t1', 'JEE Main Mock #12', 'Physics', 30, 30, 'Medium', [
      MockQuestion(
        'q1',
        'A body moves with uniform acceleration of 2 m/s². What is its velocity after 5 s from rest?',
        ['5 m/s', '10 m/s', '15 m/s', '20 m/s'],
        1,
        'Physics',
      ),
      MockQuestion(
        'q2',
        'The SI unit of force is:',
        ['Joule', 'Newton', 'Watt', 'Pascal'],
        1,
        'Physics',
      ),
      MockQuestion(
        'q3',
        'Which quantity is scalar?',
        ['Velocity', 'Acceleration', 'Speed', 'Displacement'],
        2,
        'Physics',
      ),
      MockQuestion(
        'q4',
        'g on Earth (m/s²)?',
        ['9.8', '8.9', '10.0', '12.1'],
        0,
        'Physics',
      ),
      MockQuestion(
        'q5',
        'Energy conservation applies when:',
        ['No friction', 'Closed system', 'Open system', 'Always'],
        1,
        'Physics',
      ),
    ]),
    MockTest('t2', 'NEET Biology Sprint', 'Biology', 20, 20, 'Easy', [
      MockQuestion(
        'q6',
        'Powerhouse of the cell is:',
        ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi'],
        1,
        'Biology',
      ),
      MockQuestion(
        'q7',
        'DNA stands for:',
        [
          'Deoxyribonucleic acid',
          'Dioxyribonucleic acid',
          'Deoxyribose acid',
          'Nucleic acid',
        ],
        0,
        'Biology',
      ),
    ]),
    MockTest(
      't3',
      'Class 12 Maths Board Practice',
      'Mathematics',
      45,
      40,
      'Hard',
      [
        MockQuestion(
          'q8',
          '∫ x dx =',
          ['x²/2 + C', 'x + C', '2x + C', '1'],
          0,
          'Mathematics',
        ),
      ],
    ),
  ];

  static final notifications = <MockNotification>[
    MockNotification(
      'n1',
      'Live class starting soon',
      'Thermodynamics with Dr. Vikram Thapar in 15 min',
      'live',
      DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    MockNotification(
      'n2',
      'New test available',
      'JEE Main Mock #12 is live — attempt now!',
      'test',
      DateTime.now().subtract(const Duration(hours: 1)),
    ),
    MockNotification(
      'n3',
      'Doubt replied',
      'Your doubt on projectile motion has been answered.',
      'doubt',
      DateTime.now().subtract(const Duration(hours: 5)),
    ),
    MockNotification(
      'n4',
      'Weekly streak',
      'You\'re on a 7-day streak. Keep it up!',
      'streak',
      DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

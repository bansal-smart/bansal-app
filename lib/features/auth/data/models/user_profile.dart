import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  // Representation of the profiles table.
  final String id;       // profiles.id (PK)
  final String userId;   // profiles.user_id (auth UID)
  final String? fullName;
  final String? email;
  final String? phone;
  final String? city;
  final String? country;
  final String? goal;
  final String? avatarUrl;
  final String? schoolId;
  final String? classLevel;
  final String? targetExam;
  final String? state;
  final String? fatherName;
  final String? parentPhone;
  final String? rollNumber;

  const UserProfile({
    required this.id,
    required this.userId,
    this.fullName,
    this.email,
    this.phone,
    this.city,
    this.state,
    this.country,
    this.goal,
    this.avatarUrl,
    this.schoolId,
    this.classLevel,
    this.targetExam,
    this.fatherName,
    this.parentPhone,
    this.rollNumber,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? json['id'] as String,
    fullName: json['full_name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
    country: json['country'] as String?,
    goal: json['goal'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    schoolId: json['school_id'] as String?,
    classLevel: json['class_level'] as String?,
    targetExam: json['target_exam'] as String?,
    fatherName: json['father_name'] as String?,
    parentPhone: json['parent_phone'] as String?,
    rollNumber: json['roll_number'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'phone': phone,
    'city': city,
    'state': state,
    'country': country,
    'goal': goal,
    'avatar_url': avatarUrl,
    'school_id': schoolId,
    'class_level': classLevel,
    'target_exam': targetExam,
    'father_name': fatherName,
    'parent_phone': parentPhone,
  };

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? city,
    String? state,
    String? country,
    String? goal,
    String? avatarUrl,
    Object? schoolId = _sentinel,
    Object? classLevel = _sentinel,
    Object? targetExam = _sentinel,
    String? fatherName,
    String? parentPhone,
  }) => UserProfile(
    id: id,
    userId: userId,
    fullName: fullName ?? this.fullName,
    email: email,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    goal: goal ?? this.goal,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    schoolId: schoolId == _sentinel ? this.schoolId : schoolId as String?,
    classLevel: classLevel == _sentinel ? this.classLevel : classLevel as String?,
    targetExam: targetExam == _sentinel ? this.targetExam : targetExam as String?,
    fatherName: fatherName ?? this.fatherName,
    parentPhone: parentPhone ?? this.parentPhone,
    rollNumber: rollNumber,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    fullName,
    email,
    phone,
    city,
    state,
    country,
    goal,
    avatarUrl,
    schoolId,
    classLevel,
    targetExam,
    fatherName,
    parentPhone,
    rollNumber,
  ];
}

// Sentinel for copyWith nullable field clearing
const Object _sentinel = Object();

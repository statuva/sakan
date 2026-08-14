import 'package:sakan/shared/models/app_user.dart';
import "package:sakan/shared/models/family.dart";
import 'package:sakan/shared/models/member.dart';

class DemoDataService {
  DemoDataService({DateTime? now}) : now = now ?? DateTime.now();
  final DateTime now;

  late final AppUser user;
  late final Family family;
  late final List<Member> members;

  void initialize() {
    // empty for now
  }
}

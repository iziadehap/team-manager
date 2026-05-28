import 'package:flutter_test/flutter_test.dart';
import 'package:team_manager/core/constants/app_constants.dart';

void main() {
  test('app name is TeamTask', () {
    expect(AppConstants.appName, 'TeamTask');
  });
}

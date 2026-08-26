import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppAuth activities share an isolated callback task affinity', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    final mainActivity = _activityDeclaration(manifest, '.MainActivity');
    expect(
      mainActivity,
      contains(r'android:taskAffinity="${applicationId}.auth"'),
      reason: 'the application must share the callback task',
    );
    expect(
      mainActivity,
      contains('android:launchMode="singleTask"'),
      reason: 'only one application callback task may own an auth flow',
    );

    for (final activity in <String>[
      'net.openid.appauth.AuthorizationManagementActivity',
      'net.openid.appauth.RedirectUriReceiverActivity',
    ]) {
      final declaration = _activityDeclaration(manifest, activity);
      expect(
        declaration,
        contains(r'android:taskAffinity="${applicationId}.auth"'),
        reason: '$activity must share the isolated callback task',
      );
      expect(
        declaration,
        contains('android:excludeFromRecents="true"'),
        reason: '$activity must not leave a user-visible authentication task',
      );
    }
  });
}

String _activityDeclaration(String manifest, String activity) {
  final declaration = RegExp(
    '<activity\\s+[^>]*android:name="${RegExp.escape(activity)}"[^>]*>',
    dotAll: true,
  ).firstMatch(manifest);

  expect(declaration, isNotNull, reason: '$activity must be declared');
  return declaration!.group(0)!;
}

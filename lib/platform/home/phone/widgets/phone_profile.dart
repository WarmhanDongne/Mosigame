import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:project00/platform/profile/providers/profile_update_controller.dart';
import 'package:project00/platform/profile/widgets/tablet_profile.dart';
import 'package:project00/platform/profile/widgets/phone_profile_menu.dart';

class PhoneProfile extends StatelessWidget {
  const PhoneProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = ProfileUpdateController.instance;
    return AnimatedBuilder(
      animation: updates,
      builder: (context, _) => StreamBuilder<User?>(
        stream: FirebaseBackend.auth.userChanges(),
        initialData: FirebaseBackend.auth.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final pending = updates.pendingFor(user?.uid);
          // 휴대폰은 프로필 자리에서 말풍선 메뉴가 펼쳐집니다(프로필 메뉴 시안).
          void openProfile() => showPhoneProfileMenu(context);
          return Semantics(
            button: true,
            label: context.l10n.openProfile,
            onTap: openProfile,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: openProfile,
              child: ProfileAvatar(
                user: user,
                size: 40,
                name: pending?.nickname,
                image: pending?.imageBytes == null
                    ? null
                    : MemoryImage(pending!.imageBytes!),
                syncing: pending != null && updates.isSaving,
                syncFailed: pending != null && updates.hasFailed,
              ),
            ),
          );
        },
      ),
    );
  }
}

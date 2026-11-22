import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/platform/announcements/models/platform_announcement.dart';
import 'package:project00/platform/announcements/services/platform_announcement_service.dart';
import 'package:project00/platform/announcements/widgets/platform_announcement_dialog.dart';

/// Shows the server-authored lobby announcement once for each update.
///
/// Maintenance takes precedence: its active state also blocks new rooms on the
/// server, so people should see that explanation instead of an unrelated notice.
class PlatformAnnouncementHost extends StatefulWidget {
  const PlatformAnnouncementHost({
    super.key,
    required this.child,
    this.onOpenStore,
    this.service,
  });

  final Widget child;
  final VoidCallback? onOpenStore;
  final PlatformAnnouncementService? service;

  @override
  State<PlatformAnnouncementHost> createState() =>
      _PlatformAnnouncementHostState();
}

class _PlatformAnnouncementHostState extends State<PlatformAnnouncementHost> {
  late final PlatformAnnouncementService _service =
      widget.service ?? PlatformAnnouncementService();
  StreamSubscription<List<PlatformAnnouncement>>? _subscription;
  String? _shownFingerprint;
  bool _dialogVisible = false;
  PlatformAnnouncement? _queued;

  @override
  void initState() {
    super.initState();
    _subscription = _service.watchActive().listen(
      _onAnnouncements,
      onError: (_) {
        // A lobby must remain usable if the optional announcement feed is down.
      },
    );
  }

  void _onAnnouncements(List<PlatformAnnouncement> announcements) {
    PlatformAnnouncement? selected;
    for (final announcement in announcements) {
      if (announcement.kind == PlatformAnnouncementKind.maintenance) {
        selected = announcement;
        break;
      }
      if (announcement.kind == PlatformAnnouncementKind.notice) {
        selected ??= announcement;
      }
    }
    if (selected == null) return;
    final fingerprint = _fingerprint(selected);
    if (fingerprint == _shownFingerprint) return;
    _queued = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showQueued());
    });
  }

  String _fingerprint(PlatformAnnouncement announcement) {
    final entries = announcement.localized.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final localized = entries
        .map((entry) => '${entry.key}:${entry.value.title}:${entry.value.body}')
        .join('|');
    return '${announcement.kind.name}:${announcement.maintenancePeriod}:$localized';
  }

  Future<void> _showQueued() async {
    if (_dialogVisible || !mounted || _queued == null) return;
    final announcement = _queued!;
    final fingerprint = _fingerprint(announcement);
    _dialogVisible = true;
    _shownFingerprint = fingerprint;
    _queued = null;
    await showPlatformAnnouncementDialog(
      context: context,
      announcement: announcement,
      onOpenStore: widget.onOpenStore,
    );
    _dialogVisible = false;
    if (_queued != null && mounted) unawaited(_showQueued());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

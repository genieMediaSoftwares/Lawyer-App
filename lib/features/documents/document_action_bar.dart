import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The View / Rename / Replace / Delete row shown under a document.
///
/// One widget for both document screens, so the client's and the advocate's
/// cards cannot drift apart on which actions exist, what they are called or
/// how they behave when the room runs out.
///
/// ## Why this is a Wrap and not a Row
///
/// The client card laid its actions out as
/// `Row(children: [View, Rename, Replace, Spacer, PopupMenuButton])`, with
/// every child unbounded. A Row hands each child all the width it asks for and
/// clips whatever does not fit, so the actions overflowed on every phone the
/// app runs on — measured at 107px past the right edge on a 360dp screen at
/// normal text size, 165px at the 1.3x text scale an accessibility setting
/// produces, and 147px on a 320dp device. What the user lost was the right-hand
/// end of the row: the labels first, then the overflow menu with Delete in it.
///
/// A [Wrap] cannot overflow. When the actions do not fit on one line they
/// continue onto the next, which is why this needs no breakpoints and no
/// hardcoded widths — it is correct at any width, any text scale and any
/// translation length, including the ones nobody thought to test.
///
/// ## Why there is no overflow menu any more
///
/// The card used to carry both three inline buttons AND a `⋮` menu repeating
/// the same four actions — the menu existed to hold what the Row could not
/// show. Wrapping shows all four directly, so the menu had nothing left to
/// reveal. Delete is no longer one level deeper than the action beside it;
/// [onDelete] still confirms before doing anything.
class DocumentActionBar extends StatelessWidget {
  const DocumentActionBar({
    super.key,
    required this.onView,
    this.onRename,
    this.onReplace,
    this.onDelete,
    this.busy = false,
  });

  /// Always present: reading a document is the one thing every viewer may do.
  final VoidCallback onView;

  /// Null hides the action outright.
  ///
  /// These are the owner-only operations. The backend refuses them for anyone
  /// but the owner (and admins), so an advocate looking at a client's evidence
  /// is shown no Rename button rather than one that always fails. Hiding is
  /// the UI agreeing with the server, not the UI enforcing anything: the
  /// refusal still comes from the backend either way.
  final VoidCallback? onRename;
  final VoidCallback? onReplace;
  final VoidCallback? onDelete;

  /// An operation is in flight; every action greys out so a second tap cannot
  /// start a duplicate rename or a second delete.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _DocumentAction(
          icon: Icons.visibility_outlined,
          label: 'View',
          onPressed: busy ? null : onView,
        ),
        if (onRename != null)
          _DocumentAction(
            icon: Icons.edit_outlined,
            label: 'Rename',
            onPressed: busy ? null : onRename,
          ),
        if (onReplace != null)
          _DocumentAction(
            icon: Icons.swap_horiz,
            label: 'Replace',
            onPressed: busy ? null : onReplace,
          ),
        if (onDelete != null)
          _DocumentAction(
            icon: Icons.delete_outline,
            label: 'Delete',
            onPressed: busy ? null : onDelete,
            danger: true,
          ),
      ],
    );
  }
}

/// One action: icon plus label, both part of the tap target.
class _DocumentAction extends StatelessWidget {
  const _DocumentAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Delete, drawn in the error colour so it is not mistaken for its
  /// neighbours at a glance.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = danger ? AppColors.error : theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '$label document',
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: colour,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          // 40dp tall: a thumb-sized target, and the label is inside it rather
          // than a caption beside a small icon.
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/place_model.dart';
import '../../providers/place_provider.dart';
import '../../repositories/place_repository.dart' show PlaceException;

/// Live city / locality autocomplete backed by the `/api/places` proxy.
///
/// **Used for every city/location input in the app** — Post a Case, and the
/// client and lawyer profile screens. A posted case has to resolve to a real
/// city so it can be routed to advocates by jurisdiction, and a profile
/// location feeds the same matching, so all of them constrain the user to a
/// real suggestion rather than free text.
///
/// Each host passes its own [fieldKey], so selections on one screen cannot
/// affect another.
///
/// Note this resolves *cities and localities* only (`types=(cities)` on the
/// server). A street or chamber address belongs in a plain text field —
/// `Lawyer.officeAddress` still uses one, and should.
///
/// Suggestions come from Google Places when the server has a key, otherwise
/// Photon (OpenStreetMap); a numeric query is routed to the India Post PIN code
/// lookup. There is no bundled city list — the provider is always live.
///
/// The API key lives in `backend/.env` and is never shipped to the app. Calling
/// Google directly from Flutter would require embedding the key in the binary,
/// where it is recoverable with `unzip`, and the Places web-service endpoints
/// cannot be restricted by app signature or bundle id.
///
/// Typical use:
/// ```dart
/// LocationAutocompleteField(
///   fieldKey: 'post_case',
///   initialText: _cityController.text,
///   onSelected: (place) => setState(() {
///     _city  = place.city;
///     _state = place.state;
///     _lat   = place.latitude;   // may be null — PIN lookups have no geometry
///   }),
/// )
/// ```
class LocationAutocompleteField extends ConsumerStatefulWidget {
  /// Distinguishes this field's selection state from other fields on other
  /// screens. Use a stable value such as `'post_case'` or `'profile'`.
  final String fieldKey;

  /// Pre-fills the input, e.g. a location already saved on the profile.
  final String? initialText;

  /// Floating label. Pass null when the host screen already renders its own
  /// heading above the field (the Post-a-Case form does), so no empty label
  /// reserves vertical space.
  final String? label;
  final String hintText;

  /// Fired once details for the tapped suggestion have resolved. The values are
  /// exactly what the provider returned.
  final ValueChanged<PlaceDetailsModel> onSelected;

  /// Fired when the user clears the field.
  final VoidCallback? onCleared;

  /// Shown beneath the field, e.g. a form validation message.
  final String? errorText;

  final bool enabled;

  const LocationAutocompleteField({
    super.key,
    required this.fieldKey,
    required this.onSelected,
    this.initialText,
    this.label = 'City / Location',
    this.hintText = 'Start typing a city, area or PIN code',
    this.onCleared,
    this.errorText,
    this.enabled = true,
  });

  @override
  ConsumerState<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends ConsumerState<LocationAutocompleteField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlay;
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_controller.text.trim().length >= 2) _showOverlay();
    } else {
      // Delay so a tap on a suggestion is registered before the list closes.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _onChanged(String value) {
    if (_suppressSearch) return;

    ref.read(placeSearchProvider.notifier).search(value);

    if (value.trim().length >= 2) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  Future<void> _onSuggestionTapped(PlaceSuggestionModel suggestion) async {
    // Fill the field immediately so the tap feels instant, and suppress the
    // change listener so writing the text does not kick off another search.
    _suppressSearch = true;
    _controller.text = suggestion.description;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _suppressSearch = false;

    _removeOverlay();
    _focusNode.unfocus();

    final place = await ref
        .read(selectedPlaceProvider(widget.fieldKey).notifier)
        .select(suggestion);

    if (!mounted) return;

    if (place != null) {
      widget.onSelected(place);
      return;
    }

    // Resolution failed — surface it rather than leaving a filled field that
    // is not actually backed by a selection.
    final error = ref.read(selectedPlaceProvider(widget.fieldKey)).error;
    final message = error is PlaceException
        ? error.message
        : 'Could not load details for that place. Please try again.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    _controller.clear();
    ref.read(placeSearchProvider.notifier).clear();
    ref.read(selectedPlaceProvider(widget.fieldKey).notifier).clear();
    _removeOverlay();
    widget.onCleared?.call();
    setState(() {});
  }

  void _showOverlay() {
    if (_overlay != null) return;

    _overlay = OverlayEntry(
      builder: (context) {
        // Sized and positioned against the field via CompositedTransformTarget,
        // so it tracks correctly during scroll on both platforms.
        return Positioned(
          width: _fieldWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 4),
            targetAnchor: Alignment.bottomLeft,
            child: _SuggestionsPanel(
              onTap: _onSuggestionTapped,
              onRetry: () => ref.read(placeSearchProvider.notifier).retry(),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  double get _fieldWidth {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? MediaQuery.sizeOf(context).width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = ref.watch(selectedPlaceProvider(widget.fieldKey));
    final isResolving = selected.isLoading;

    // Keeps placeSearchProvider alive for as long as this field is mounted.
    //
    // It is `autoDispose`, and the only other consumer is the suggestions
    // panel, which lives in a separate OverlayEntry subtree. Without a
    // listener here, the `ref.read(...).search(...)` call in `_onChanged`
    // created the notifier and then let Riverpod dispose it before the 350ms
    // debounce elapsed — `dispose()` cancelled the timer, so the HTTP request
    // was never sent, and the overlay went on to watch a brand-new notifier
    // sitting in `idle`. The dropdown rendered an empty list and no request
    // ever appeared in the network log. Covered by
    // test/place_search_notifier_test.dart.
    ref.watch(placeSearchProvider);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled && !isResolving,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            // Inherits the app's InputDecorationTheme, so it matches every
            // other field without restating colours here.
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText,
              errorText: widget.errorText,
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: isResolving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear location',
                            onPressed: widget.enabled ? _clear : null,
                          )
                        : null),
            ),
          ),

          // Confirmation of what was actually stored, including whether
          // coordinates came back.
          selected.maybeWhen(
            data: (place) => place == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      place.hasCoordinates
                          ? '${place.shortLabel} · ${place.latitude!.toStringAsFixed(4)}, ${place.longitude!.toStringAsFixed(4)}'
                          : '${place.shortLabel} · coordinates unavailable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Dropdown body. A separate consumer so suggestion updates repaint only the
/// panel, not the field or the surrounding form.
class _SuggestionsPanel extends ConsumerWidget {
  final ValueChanged<PlaceSuggestionModel> onTap;
  final VoidCallback onRetry;

  const _SuggestionsPanel({required this.onTap, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(placeSearchProvider);

    Widget body;

    if (state.hasError) {
      body = _Message(
        icon: Icons.cloud_off_rounded,
        text: state.errorMessage ?? 'Could not load city suggestions.',
        action: state.canRetry
            ? TextButton(onPressed: onRetry, child: const Text('Retry'))
            : null,
      );
    } else if (state.isEmpty) {
      body = const _Message(
        icon: Icons.search_off_rounded,
        text: 'No matching city found',
      );
    } else if (state.suggestions.isEmpty) {
      // Covers loading *and* idle. Previously only the loading case was
      // handled, so an `idle` state with no suggestions fell through to the
      // list branch below and rendered a zero-item ListView — an invisible,
      // silent panel. That turned the autoDispose bug above into "nothing
      // happens" instead of something diagnosable.
      body = _Message(
        icon: state.isLoading ? null : Icons.search_rounded,
        text: state.isLoading ? 'Searching…' : 'Keep typing to search',
        showSpinner: state.isLoading,
      );
    } else {
      body = ConstrainedBox(
        // Caps the dropdown so it never covers the whole screen on a small
        // device; the list scrolls inside.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.32,
        ),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: state.suggestions.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, index) {
            final suggestion = state.suggestions[index];
            return ListTile(
              dense: true,
              // 48dp minimum touch target.
              minVerticalPadding: 12,
              leading: Icon(
                Icons.place_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                suggestion.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onTap(suggestion),
            );
          },
        ),
      );
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin progress line while refreshing, so the existing list stays
            // readable instead of being replaced by a spinner.
            if (state.isLoading && state.suggestions.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            body,
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Widget? action;
  final bool showSpinner;

  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 18, color: theme.hintColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

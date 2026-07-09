import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_theme.dart';

class _ShimmerWrapper extends StatelessWidget {
  final Widget child;
  const _ShimmerWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: FxColors.surfaceContainerLow,
      highlightColor: FxColors.surfaceContainerHigh,
      child: child,
    );
  }
}

class _Block extends StatelessWidget {
  final double width, height, borderRadius;
  const _Block({this.width = double.infinity, required this.height, this.borderRadius = 8});
  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(borderRadius)),
  );
}

class _Circle extends StatelessWidget {
  final double size;
  const _Circle({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
  );
}

class _Pill extends StatelessWidget {
  final double width, height;
  const _Pill({this.width = 60, this.height = 22});
  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(height / 2)),
  );
}

// ---------------------------------------------------------------------------
// SCHEDULED RIDE CARD → matches _scheduledRideCard
// FxTonalCard → date label → time (icon + text) → pill → route timeline → buttons
// ---------------------------------------------------------------------------
class SkeletonRideCard extends StatelessWidget {
  final bool isHistory;
  const SkeletonRideCard({super.key, this.isHistory = false});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: date label + pill
            Row(
              children: [
                Expanded(child: _Block(width: 80, height: 11, borderRadius: 5)),
                const SizedBox(width: 12),
                _Pill(width: 70, height: 24),
              ],
            ),
            const SizedBox(height: 8),
            // Time row: icon + time
            Row(
              children: [
                _Circle(size: 18),
                const SizedBox(width: 8),
                _Block(width: 100, height: 20),
              ],
            ),
            const SizedBox(height: 20),
            // Route timeline
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  _Circle(size: 12),
                  Container(width: 2, height: 32, color: Colors.white),
                  _Circle(size: 12),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Block(width: 140, height: 12, borderRadius: 6),
                    const SizedBox(height: 28),
                    _Block(width: 110, height: 12, borderRadius: 6),
                  ]),
                ),
              ],
            ),
            // Action buttons (only for non-history rides)
            if (!isHistory) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  _Block(width: 80, height: 38, borderRadius: 12),
                  const SizedBox(width: 10),
                  _Block(width: 80, height: 38, borderRadius: 12),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOOKING DETAILS CARD → matches _mergedCard
// FxCard → Booking ID + pill → date → time+type → track button → timeline → map
// ---------------------------------------------------------------------------
class SkeletonBookingDetailsCard extends StatelessWidget {
  const SkeletonBookingDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Booking ID + status pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Block(width: 70, height: 11, borderRadius: 5),
                      const SizedBox(height: 6),
                      _Block(width: 130, height: 22, borderRadius: 8),
                    ],
                  ),
                ),
                _Pill(width: 80, height: 26),
              ],
            ),
            const SizedBox(height: 20),
            // Date row
            Row(
              children: [
                _Circle(size: 16),
                const SizedBox(width: 8),
                _Block(width: 180, height: 14, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 10),
            // Time + Type row
            Row(
              children: [
                _Circle(size: 16),
                const SizedBox(width: 8),
                _Block(width: 60, height: 16, borderRadius: 6),
                const SizedBox(width: 20),
                _Circle(size: 16),
                const SizedBox(width: 8),
                _Block(width: 50, height: 14, borderRadius: 6),
              ],
            ),
            // Track button
            const SizedBox(height: 20),
            _Block(height: 48, borderRadius: 14),
            const SizedBox(height: 24),
            // Route timeline
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  _Circle(size: 14),
                  Container(width: 2, height: 36, color: Colors.white),
                  _Circle(size: 14),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Block(width: 160, height: 13, borderRadius: 6),
                    const SizedBox(height: 32),
                    _Block(width: 120, height: 13, borderRadius: 6),
                  ]),
                ),
              ],
            ),
            // Map placeholder
            const SizedBox(height: 20),
            _Block(height: 160, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHIFT CARD → matches _buildShiftCard in select_shift_screen
// Container → login/logout badge → shift name → time row
// ---------------------------------------------------------------------------
class SkeletonShiftCard extends StatelessWidget {
  const SkeletonShiftCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge row: login/logout pill + check indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Pill(width: 70, height: 26),
                _Circle(size: 24),
              ],
            ),
            const SizedBox(height: 12),
            // Shift name
            _Block(width: 140, height: 18, borderRadius: 8),
            const SizedBox(height: 8),
            // Time row
            Row(
              children: [
                _Circle(size: 18),
                const SizedBox(width: 8),
                _Block(width: 80, height: 14, borderRadius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHIFT ROW → matches _shiftRow in edit_booking_screen
// Container → radio circle → icon + label + time → CURRENT pill
// ---------------------------------------------------------------------------
class SkeletonShiftRow extends StatelessWidget {
  const SkeletonShiftRow({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FxColors.surfaceContainerLow),
        ),
        child: Row(
          children: [
            // Radio circle
            _Circle(size: 22),
            const SizedBox(width: 14),
            // Icon + labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Circle(size: 16),
                      const SizedBox(width: 6),
                      _Block(width: 50, height: 12, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _Block(width: 70, height: 15, borderRadius: 6),
                ],
              ),
            ),
            // CURRENT pill
            _Pill(width: 64, height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ANNOUNCEMENT ROW → matches _announcementCard
// FxCard → 48×48 icon container → title row → body → date
// ---------------------------------------------------------------------------
class SkeletonAnnouncementRow extends StatelessWidget {
  const SkeletonAnnouncementRow({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + unread dot
                  Row(
                    children: [
                      Expanded(child: _Block(width: 160, height: 15, borderRadius: 6)),
                      const SizedBox(width: 6),
                      _Circle(size: 8),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Body line 1
                  _Block(height: 12, borderRadius: 6),
                  const SizedBox(height: 4),
                  // Body line 2 (shorter)
                  _Block(width: 200, height: 12, borderRadius: 6),
                  const SizedBox(height: 8),
                  // Date
                  _Block(width: 80, height: 10, borderRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NOTIFICATION ROW → matches notification card
// Similar to announcement but with time + unread indicator
// ---------------------------------------------------------------------------
class SkeletonNotificationRow extends StatelessWidget {
  const SkeletonNotificationRow({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 150, height: 14, borderRadius: 6),
                  const SizedBox(height: 6),
                  _Block(height: 12, borderRadius: 6),
                  const SizedBox(height: 8),
                  _Block(width: 60, height: 10, borderRadius: 5),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Circle(size: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CHAT BUBBLE → matches _messageBubble
// Aligned → Container with gradient/white → text lines → time
// ---------------------------------------------------------------------------
class SkeletonChatBubble extends StatelessWidget {
  final bool isSent;
  const SkeletonChatBubble({super.key, this.isSent = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.65;
    return _ShimmerWrapper(
      child: Container(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: size,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSent ? FxColors.primaryContainer : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSent ? 16 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Block(height: 13, borderRadius: 6),
              const SizedBox(height: 6),
              _Block(width: size * 0.5, height: 13, borderRadius: 6),
              const SizedBox(height: 6),
              _Block(width: 40, height: 9, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CALENDAR → matches the calendar page in create_booking_screen
// Mode selector → weekday labels → date grid → summary card
// ---------------------------------------------------------------------------
class SkeletonCalendar extends StatelessWidget {
  const SkeletonCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Column(
        children: [
          // Mode selector card
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(width: 100, height: 11, borderRadius: 5),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(2, (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                      height: 38,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Calendar card
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                // Month + nav arrows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Circle(size: 32),
                    _Block(width: 120, height: 18, borderRadius: 8),
                    _Circle(size: 32),
                  ],
                ),
                const SizedBox(height: 16),
                // Weekday labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) => _Block(width: 28, height: 12, borderRadius: 5)),
                ),
                const SizedBox(height: 12),
                // Date grid rows
                ...List.generate(5, (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (col) => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    )),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                _Block(width: 44, height: 44, borderRadius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Block(width: 120, height: 14, borderRadius: 6),
                      const SizedBox(height: 6),
                      _Block(width: 80, height: 12, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ALERT CARD → matches SOS alert list card
// Container → icon → severity + status → date
// ---------------------------------------------------------------------------
class SkeletonAlertCard extends StatelessWidget {
  const SkeletonAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 100, height: 14, borderRadius: 6),
                  const SizedBox(height: 6),
                  _Block(width: 140, height: 12, borderRadius: 6),
                  const SizedBox(height: 6),
                  _Block(width: 80, height: 10, borderRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NODAL ASSIGNMENT CARD → matches hub assignment card
// Card → hub icon + name → address
// ---------------------------------------------------------------------------
class SkeletonAssignmentCard extends StatelessWidget {
  const SkeletonAssignmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Block(width: 120, height: 16, borderRadius: 8),
                      const SizedBox(height: 6),
                      _Block(width: 180, height: 12, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAP PLACEHOLDER → used in booking details & track driver
// ---------------------------------------------------------------------------
class SkeletonMapPlaceholder extends StatelessWidget {
  const SkeletonMapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Center(
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DRIVER INFO CARD → matches track driver card
// Card → driver photo → name → phone → vehicle
// ---------------------------------------------------------------------------
class SkeletonDriverInfoCard extends StatelessWidget {
  const SkeletonDriverInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 130, height: 16, borderRadius: 8),
                  const SizedBox(height: 6),
                  _Block(width: 100, height: 12, borderRadius: 6),
                  const SizedBox(height: 6),
                  _Block(width: 80, height: 10, borderRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REVIEW FORM → matches review screen form
// Labels → star row → tag chips → text area → submit button
// ---------------------------------------------------------------------------
class SkeletonReviewForm extends StatelessWidget {
  const SkeletonReviewForm({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall rating
          _Block(width: 110, height: 15, borderRadius: 7),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _Block(width: 40, height: 40, borderRadius: 10),
            )),
          ),
          const SizedBox(height: 24),
          // Driver rating
          _Block(width: 100, height: 15, borderRadius: 7),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _Block(width: 36, height: 36, borderRadius: 9),
            )),
          ),
          const SizedBox(height: 20),
          // Driver tags
          _Block(width: 80, height: 13, borderRadius: 6),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (i) => _Block(width: 80, height: 32, borderRadius: 16)),
          ),
          const SizedBox(height: 20),
          // Driver comment
          _Block(width: 100, height: 13, borderRadius: 6),
          const SizedBox(height: 10),
          _Block(height: 100, borderRadius: 12),
          const SizedBox(height: 28),
          // Submit button
          _Block(height: 52, borderRadius: 14),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SOS DETAIL → matches sos_details body
// Alert card → map → timeline
// ---------------------------------------------------------------------------
class SkeletonSOSDetail extends StatelessWidget {
  const SkeletonSOSDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Circle(size: 14),
                    const SizedBox(width: 8),
                    _Block(width: 100, height: 14, borderRadius: 6),
                    const Spacer(),
                    _Pill(width: 70, height: 24),
                  ],
                ),
                const SizedBox(height: 12),
                _Block(height: 12, borderRadius: 6),
                const SizedBox(height: 8),
                _Block(width: 160, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Block(height: 200, borderRadius: 15),
        ],
      ),
    );
  }
}

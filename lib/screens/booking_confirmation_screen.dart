import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_model.dart';
import '../services/booking_service.dart';
import '../services/weekoff_service.dart';
import '../constants/app_colors.dart';
import 'booking_success_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Shift selectedShift;
  final List<String> weekoffDays;

  const BookingConfirmationScreen({
    super.key,
    required this.bookingData,
    required this.selectedShift,
    required this.weekoffDays,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final BookingService _bookingService = BookingService();
  bool _isLoading = false;
  String? _error;
  List<DateTime> _calculatedDates = [];

  @override
  void initState() {
    super.initState();
    _calculateDisplayDates();
  }

  bool _isWeekoff(DateTime date) {
    final dayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    final dayName = dayNames[date.weekday - 1]; 
    return widget.weekoffDays.contains(dayName);
  }

  void _calculateDisplayDates() {
    List<DateTime> dates = [];
    final selectionMode = widget.bookingData['selectionMode'];

    if (selectionMode == 'single') {
      dates = List<DateTime>.from(widget.bookingData['selectedDates']);
    } else {
      DateTime start = widget.bookingData['startDate'];
      DateTime end = widget.bookingData['endDate'];
      DateTime current = start;
      while (!current.isAfter(end)) {
        dates.add(current);
        current = current.add(const Duration(days: 1));
      }
    }
    
    // Filter weekoffs
    _calculatedDates = dates.where((d) => !_isWeekoff(d)).toList();
    _calculatedDates.sort();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
        final prefs = await SharedPreferences.getInstance();
        final tenantId = prefs.getString('tenant_id');
        final employeeId = prefs.getString('employee_id');

        if (tenantId == null || employeeId == null) {
            setState(() {
               _error = 'User session invalid. Please login again.';
               _isLoading = false;
            });
            return;
        }

        // Format dates as Strings YYYY-MM-DD
        final bookingDates = _calculatedDates.map((d) {
             final y = d.year;
             final m = d.month.toString().padLeft(2, '0');
             final day = d.day.toString().padLeft(2, '0');
             return '$y-$m-$day';
        }).toList();

        if (bookingDates.isEmpty) {
            setState(() {
               _error = 'No valid working days selected.';
               _isLoading = false;
            });
            return;
        }
        
        final result = await _bookingService.createBooking(
            tenantId: tenantId,
            employeeId: int.parse(employeeId),
            bookingDates: bookingDates,
            shiftId: widget.selectedShift.shiftId!,
        );

        if (result['success']) {
             final daysCount = bookingDates.length;
             
             if (mounted) {
                // Navigate to Success
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => BookingSuccessScreen(
                      bookingId: result['bookingId']?.toString(), 
                      status: 'Request', // Default
                      message: result['message'] ?? 'Booking created successfully',
                      daysCount: daysCount,
                  )),
                  (route) => route.settings.name == '/schedules' || route.isFirst, 
                  // Ideally remove until home/schedules
                );
             }
        } else {
            setState(() {
               _error = result['error'];
               _isLoading = false;
            });
        }

    } catch (e) {
        setState(() {
           _error = 'Booking failed: $e';
           _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionMode = widget.bookingData['selectionMode'];
    final shift = widget.selectedShift;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Confirm Booking', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
           children: [
              _buildHeader(),
              
              // Booking Summary
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     const Text('📅 Booking Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                     const Divider(height: 30),
                     
                     _buildRow('Type', selectionMode == 'single' ? 'Specific Dates' : 'Date Range'),
                     const SizedBox(height: 12),
                     _buildRow('Total Days', '${_calculatedDates.length} day${_calculatedDates.length != 1 ? 's' : ''}'),
                     
                     const SizedBox(height: 20),
                     
                     if (selectionMode == 'single') ...[
                        const Text('Selected Dates:', style: TextStyle(fontSize: 14, color: Color(0xFF636E72), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                           spacing: 8,
                           runSpacing: 8,
                           children: _calculatedDates.map((d) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(DateFormat('EEE, MMM d').format(d), style: const TextStyle(fontSize: 13, color: Color(0xFF2D3436))),
                           )).toList(),
                        )
                     ] else ...[
                        _buildRow('From', DateFormat('EEE, MMM d, yyyy').format(widget.bookingData['startDate'])),
                        const SizedBox(height: 12),
                        if (widget.bookingData['endDate'] != null)
                           _buildRow('To', DateFormat('EEE, MMM d, yyyy').format(widget.bookingData['endDate'])),
                     ]
                  ],
                ),
              ),

              // Shift Summary
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     const Text('🚗 Shift Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                     const Divider(height: 30),
                     
                     Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: shift.logType == 'IN' ? const Color(0xFFFFEAA7) : const Color(0xFF74B9FF),
                             borderRadius: BorderRadius.circular(20),
                           ),
                           child: Text(
                             shift.logType == 'IN' ? '🏠 Pickup' : '🏢 Drop',
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2D3436)),
                           ),
                        ),
                     ),
                     const SizedBox(height: 15),
                     
                     _buildRow('Shift Code', shift.shiftCode ?? '-'),
                     const SizedBox(height: 12),
                     _buildRow('Time', '⏰ ${shift.shiftTime ?? shift.startTime}'),
                     const SizedBox(height: 12),
                     _buildRow('Pickup Type', shift.pickupType ?? 'Standard'),
                  ],
                ),
              ),
              
              if (_error != null)
                 Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                       color: const Color(0xFFFFE5E5),
                       border: Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
                       borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                       children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                       ],
                    ),
                 ),

              const SizedBox(height: 100), // Spacing for fab/bottom bar
           ],
        ),
      ),
      bottomNavigationBar: Container(
         padding: const EdgeInsets.all(20),
         decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
         ),
         child: SafeArea(
           child: SizedBox(
             height: 55,
             child: ElevatedButton(
               onPressed: _isLoading ? null : _handleSubmit,
               style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
               ),
               child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
             ),
           ),
         ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Confirm Your Booking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
          SizedBox(height: 5),
          Text('Review your booking details before submitting', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
         Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF636E72), fontWeight: FontWeight.w600)),
         Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436), fontWeight: FontWeight.bold)),
      ],
    );
  }
}

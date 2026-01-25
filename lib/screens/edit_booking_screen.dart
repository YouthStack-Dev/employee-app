import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import '../services/booking_service.dart';
import '../services/shift_service.dart';
import '../constants/app_colors.dart';

class EditBookingScreen extends StatefulWidget {
  final int bookingId;
  const EditBookingScreen({super.key, required this.bookingId});

  @override
  State<EditBookingScreen> createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<EditBookingScreen> {
  final BookingService _bookingService = BookingService();
  final ShiftService _shiftService = ShiftService();

  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic>? _booking;
  List<Shift> _shifts = [];
  int? _selectedShiftId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Parallel fetch: Booking + Shifts
    final results = await Future.wait([
      _bookingService.getBookingDetails(widget.bookingId),
      _shiftService.fetchShifts(),
    ]);

    final bookingRes = results[0] as Map<String, dynamic>;
    final shiftRes = results[1] as Map<String, dynamic>;

    if (mounted) {
      if (bookingRes['success'] && shiftRes['success']) {
          // Booking Res 'data' is a Booking model or Map?
          // Service getBookingDetails returns Map with 'data' as Booking object.
          // Wait, let me check BookingService.getBookingDetails implementation.
          // It returns: return {'success': true, 'data': Booking.fromJson(data)};
          // So it is an object.
          
          final bookingObj = bookingRes['data']; // Type Booking
          // We need properties.
          
          // Flatten shifts
          List<Shift> inShifts = (shiftRes['shifts']['in'] as List).cast<Shift>();
          List<Shift> outShifts = (shiftRes['shifts']['out'] as List).cast<Shift>();
          
          setState(() {
            _booking = {
               'id': bookingObj.id,
               'booking_date': bookingObj.date, // Verify property name
               'shift_id': bookingObj.shiftId,
               'status': bookingObj.status,
            };
            _shifts = [...inShifts, ...outShifts];
            _selectedShiftId = bookingObj.shiftId;
            _isLoading = false;
          });
      } else {
         setState(() {
           _error = bookingRes['error'] ?? shiftRes['error'];
           _isLoading = false;
         });
      }
    }
  }

  Future<void> _handleUpdate() async {
     if (_selectedShiftId == null) return;
     if (_selectedShiftId == _booking!['shift_id']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a different shift')));
        return;
     }

     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Update Booking'),
           content: const Text('Are you sure you want to change the shift?'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
             TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
           ],
        ),
     );

     if (confirm == true) {
         setState(() => _isUpdating = true);
         
         final result = await _bookingService.updateBooking(widget.bookingId, {'shift_id': _selectedShiftId});
         
         if (mounted) {
             setState(() => _isUpdating = false);
             if (result['success']) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking updated successfully'), backgroundColor: Colors.green)
                 );
                 Navigator.pop(context, true); // Return true to refresh
             } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['error'] ?? 'Update failed'), backgroundColor: Colors.red)
                 );
             }
         }
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));

    final dateStr = _booking!['booking_date'];
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
    
    final currentShift = _shifts.firstWhere((s) => s.shiftId == _booking!['shift_id'], orElse: () => Shift(name: 'Unknown'));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Booking', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
         padding: const EdgeInsets.all(20),
         child: Column(
            children: [
               // Info Card
               Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        const Text('BOOKING ID', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text('#${_booking!['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     ],
                  ),
               ),
               const SizedBox(height: 16),
               
               // Date Card
               Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                  child: Column(
                     children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                             const Text('📅 Booking Date', style: TextStyle(fontWeight: FontWeight.bold)),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                               child: const Text('READ ONLY', style: TextStyle(fontSize: 10)),
                             )
                        ]),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                              borderRadius: BorderRadius.circular(4)
                           ),
                           child: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w600)),
                        )
                     ],
                  ),
               ),
               const SizedBox(height: 16),
               
               // Current Shift
               Container(
                   width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        const Text('🕐 Current Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                           width: double.infinity, 
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              border: Border(left: BorderSide(color: Colors.green, width: 3)),
                              borderRadius: BorderRadius.circular(4)
                           ),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                                Text(currentShift.shiftTime ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text(currentShift.logType == 'IN' ? 'Login' : 'Logout', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                             ],
                           )
                        )
                     ],
                   ),
               ),
               
               const SizedBox(height: 16),
               
               // Select Shift
               Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        const Text('🔄 Select Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._shifts.map((shift) {
                            final isSelected = _selectedShiftId == shift.shiftId;
                            final isCurrent = shift.shiftId == _booking!['shift_id'];
                            
                            return GestureDetector(
                              onTap: () => setState(() => _selectedShiftId = shift.shiftId),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                   color: isSelected ? const Color(0xFFF0EFFF) : Colors.white,
                                   border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!, width: isSelected ? 2 : 1),
                                   borderRadius: BorderRadius.circular(8)
                                ),
                                child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                      Row(children: [
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            width: 20, height: 20, 
                                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? AppColors.primary : Colors.grey)),
                                            child: isSelected ? Container(decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)) : null
                                          ),
                                          const SizedBox(width: 10),
                                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                             Text(shift.shiftTime ?? '-', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : Colors.black)),
                                             Text(shift.logType == 'IN' ? 'Login' : 'Logout', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ])
                                      ]),
                                      if (isCurrent)
                                         Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                                            child: const Text('Current', style: TextStyle(color: Colors.white, fontSize: 10)),
                                         )
                                   ],
                                ),
                              ),
                            );
                        })
                     ],
                  ),
               ),
               
               const SizedBox(height: 30),
               
               SizedBox(
                 width: double.infinity,
                 height: 50,
                 child: ElevatedButton(
                    onPressed: _isUpdating ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                       backgroundColor: AppColors.primary,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: _isUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                 ),
               )
            ],
         ),
      ),
    );
  }
}

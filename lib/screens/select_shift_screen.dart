import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_model.dart';
import '../services/shift_service.dart';
import '../services/booking_service.dart';
import '../services/weekoff_service.dart';
import '../constants/app_colors.dart';
import '../widgets/skeletons.dart';
import 'booking_confirmation_screen.dart';

class SelectShiftScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const SelectShiftScreen({super.key, required this.bookingData});

  @override
  State<SelectShiftScreen> createState() => _SelectShiftScreenState();
}

class _SelectShiftScreenState extends State<SelectShiftScreen> {
  final ShiftService _shiftService = ShiftService();
  final BookingService _bookingService = BookingService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  
  // Tab state
  String _shiftType = 'in'; // 'in' or 'out'
  List<Shift> _inShifts = [];
  List<Shift> _outShifts = [];
  List<String> _weekoffDays = [];
  Shift? _selectedShift;

  @override
  void initState() {
    super.initState();
    _fetchShiftsAndWeekoff();
  }

  Future<void> _fetchShiftsAndWeekoff() async {
    // Parallel fetch
    final shiftsFuture = _shiftService.fetchShifts();
    final weekoffFuture = WeekoffService().getWeekoffConfig();
    
    final results = await Future.wait([shiftsFuture, weekoffFuture]);
    final shiftResult = results[0];
    final weekoffResult = results[1];

    if (mounted) {
      // Handle Weekoff
      List<String> weekoffDays = [];
      if (weekoffResult['success'] == true) {
          weekoffDays = (weekoffResult['weekoffDays'] as List).cast<String>();
          print('Fetched Weekoff Days: $weekoffDays');
      }

      // Handle Shifts
      if (shiftResult['success']) {
        // Gender-based shift visibility (strict split): a female employee sees
        // only female-only shifts; everyone else sees all EXCEPT female-only.
        // Gender comes from the login profile (persisted to prefs at login).
        final prefs = await SharedPreferences.getInstance();
        final viewerIsFemale = Shift.genderIsFemale(prefs.getString('gender'));

        final inAll = (shiftResult['shifts']['in'] as List).cast<Shift>();
        final outAll = (shiftResult['shifts']['out'] as List).cast<Shift>();

        setState(() {
          _inShifts = Shift.visibleFor(inAll, viewerIsFemale: viewerIsFemale);
          _outShifts = Shift.visibleFor(outAll, viewerIsFemale: viewerIsFemale);
          _weekoffDays = weekoffDays;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = shiftResult['error'];
          _isLoading = false;
        });
      }
    }
  }

  bool _isWeekoff(DateTime date) {
      final dayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
      // DateTime.weekday: 1=Mon, 7=Sun
      final dayName = dayNames[date.weekday - 1]; 
      return _weekoffDays.contains(dayName);
  }

  void _switchTab(String type) {
    setState(() {
      _shiftType = type;
      _selectedShift = null; // Clear selection on tab switch
    });
  }

  void _handleSelectShift(Shift shift) {
    setState(() {
      _selectedShift = shift;
    });
  }

  void _handleConfirm() {
    if (_selectedShift == null) return;
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => BookingConfirmationScreen(
          bookingData: widget.bookingData,
          selectedShift: _selectedShift!,
          weekoffDays: _weekoffDays,
        )
      )
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final currentShifts = _shiftType == 'in' ? _inShifts : _outShifts;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shift', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(height: 60),
                  SkeletonShiftCard(),
                  SkeletonShiftCard(),
                  SkeletonShiftCard(),
                  SkeletonShiftCard(),
                ],
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                if (_error != null)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     child: Text(_error!, style: const TextStyle(color: Colors.red)),
                   ),
                _buildTabs(),
                 Expanded(
                   child: currentShifts.isEmpty 
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(15),
                          itemCount: currentShifts.length,
                          itemBuilder: (context, index) {
                             return _buildShiftCard(currentShifts[index]);
                          },
                        ),
                 ),
                 _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
      return Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text('Select Your Shift', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('Choose the shift timing for your ${widget.bookingData['daysCount']} day booking', 
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
          ),
      );
  }

  Widget _buildTabs() {
      return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
              children: [
                  _buildTabItem('Login', 'in', Icons.login_rounded),
                  _buildTabItem('Logout', 'out', Icons.logout_rounded),
              ],
          ),
      );
  }
  
  Widget _buildTabItem(String label, String type, IconData icon) {
      final isSelected = _shiftType == type;
      return Expanded(
          child: GestureDetector(
              onTap: () => _switchTab(type),
              child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                              label, 
                              style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                              ),
                          ),
                      ],
                  ),
              ),
          ),
      );
  }

  Widget _buildEmptyState() {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  Text('No ${_shiftType == 'in' ? 'login' : 'logout'} shifts available', 
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ],
          ),
      );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time;
  }

  String _formatGender(String? gender) {
    final g = (gender ?? '').trim().toLowerCase();
    if (g == 'male') return 'Male';
    if (g == 'female') return 'Female';
    return 'Both';
  }

  Widget _buildShiftCard(Shift shift) {
      final isSelected = _selectedShift?.shiftId == shift.shiftId;
      final isLogin = shift.logType == 'IN';
      
      return GestureDetector(
          onTap: () => _handleSelectShift(shift),
          child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0EFFF) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ]
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: isLogin ? const Color(0xFFFFEAA7) : const Color(0xFF74B9FF),
                                      borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                          Icon(isLogin ? Icons.login_rounded : Icons.logout_rounded, size: 14, color: Colors.black87),
                                          const SizedBox(width: 4),
                                          Text(
                                              isLogin ? 'Login' : 'Logout',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                  ),
                              ),
                              if (isSelected)
                                 const CircleAvatar(
                                     radius: 12,
                                     backgroundColor: AppColors.primary,
                                     child: Icon(Icons.check, size: 16, color: Colors.white),
                                 )
                          ],
                      ),
                      const SizedBox(height: 10),
                      Text(shift.shiftCode ?? shift.name ?? 'Shift', 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Row(
                          children: [
                              const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(_formatTime(shift.shiftTime ?? shift.startTime), 
                                  style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      Row(
                          children: [
                              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(_formatGender(shift.gender), style: TextStyle(color: Colors.grey[600])),
                          ],
                      ),
                  ],
              ),
          ),
      );
  }

  Widget _buildFooter() {
      return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                  onPressed: _selectedShift != null ? _handleConfirm : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                     ? const SizedBox() // Removed loading
                     : Text(
                         _selectedShift != null ? 'Book ${_selectedShift!.shiftCode}' : 'Select a Shift', 
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                     ),
              ),
          ),
      );
  }
}

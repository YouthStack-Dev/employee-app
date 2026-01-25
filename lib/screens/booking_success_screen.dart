import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'schedules_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String? bookingId;
  final String status;
  final String message;
  final int daysCount;

  const BookingSuccessScreen({
    super.key, 
    this.bookingId, 
    this.status = 'Request',
    this.message = 'Booking created successfully',
    this.daysCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B894).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Center(
                  child: Text('✓', style: TextStyle(fontSize: 60, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),

              // Title
              const Text(
                'Booking Submitted!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 10),

              // Booking ID Highlight
              if (bookingId != null)
                Text(
                  'Booking ID: #$bookingId',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              const SizedBox(height: 10),
              
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF636E72),
                ),
              ),
              const SizedBox(height: 30),

              // Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (bookingId != null) ...[
                      _buildDetailRow('Booking ID:', '#$bookingId'),
                      const SizedBox(height: 15),
                    ],
                    _buildDetailRow('Status:', status, isStatus: true),
                    const SizedBox(height: 15),
                    _buildDetailRow('Days Booked:', '$daysCount day${daysCount != 1 ? 's' : ''}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info Box
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: Color(0xFF00B894), width: 4)),
                ),
                child: const Text(
                  'ℹ️ Your booking request has been submitted successfully. You\'ll be notified once it\'s approved.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF2D3436), height: 1.5),
                ),
              ),
              const Spacer(),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Schedules/Home and clear stack
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SchedulesScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                  ),
                  child: const Text(
                    'View My Bookings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF636E72), fontWeight: FontWeight.w600),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(fontSize: 16, color: Color(0xFF2D3436), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}

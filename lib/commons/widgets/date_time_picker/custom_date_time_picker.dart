import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/helpers/helper_functions.dart';

class CustomDateTimePickerModal extends StatefulWidget {
  final DateTime? initialDateTime;
  final Function(DateTime?) onDateTimeSelected;

  const CustomDateTimePickerModal({
    super.key,
    this.initialDateTime,
    required this.onDateTimeSelected,
  });

  static Future<void> show({
    required BuildContext context,
    DateTime? initialDateTime,
    required Function(DateTime?) onDateTimeSelected,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomDateTimePickerModal(
        initialDateTime: initialDateTime,
        onDateTimeSelected: onDateTimeSelected,
      ),
    );
  }

  @override
  State<CustomDateTimePickerModal> createState() => _CustomDateTimePickerModalState();
}

class _CustomDateTimePickerModalState extends State<CustomDateTimePickerModal> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;
  bool _isImmediate = false;
  late ScrollController _timeScrollController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDateTime ?? DateTime.now();
    _focusedMonth = DateTime(initial.year, initial.month, 1);
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedHour = initial.hour;
    _selectedMinute = (initial.minute / 15).round() * 15 % 60;
    
    // Initial scroll position for time slots (96 total 15-min slots)
    final initialIndex = (_selectedHour * 4) + (_selectedMinute ~/ 15);
    _timeScrollController = ScrollController(
      initialScrollOffset: (initialIndex * 42.0).clamp(0.0, 96 * 42.0),
    );

    if (widget.initialDateTime == null) {
      _isImmediate = true;
    }
  }

  @override
  void dispose() {
    _timeScrollController.dispose();
    super.dispose();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final cardBg = darkMode ? AvailColors.dark : Colors.white;
    const primaryBlue = Color(0xFF0066FF); // Crisp blue brand accent

    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedHour,
      _selectedMinute,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPATCH SCHEDULE',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isImmediate
                          ? 'Immediate Dispatch (ASAP)'
                          : DateFormat('EEEE, MMM dd, yyyy • hh:mm a').format(selectedDateTime),
                      style: const TextStyle(fontSize: 11, color: primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Immediate Dispatch Radio Toggle
            GestureDetector(
              onTap: () {
                setState(() {
                  _isImmediate = !_isImmediate;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isImmediate ? primaryBlue.withOpacity(0.1) : (darkMode ? Colors.grey.shade900 : const Color(0xFFF8F9FA)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isImmediate ? primaryBlue : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isImmediate ? Iconsax.flash_15 : Iconsax.calendar_1,
                      color: _isImmediate ? primaryBlue : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dispatch Immediately (ASAP)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _isImmediate ? primaryBlue : (darkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    Switch(
                      value: _isImmediate,
                      onChanged: (val) {
                        setState(() {
                          _isImmediate = val;
                        });
                      },
                      activeColor: primaryBlue,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Dual Column Calendar & Exact Time Wheel (Side by Side)
            if (!_isImmediate)
              SizedBox(
                height: 310,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: Calendar View
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          // Calendar Header (Month + Nav Arrows) - Protected against overflow
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          DateFormat('MMMM yyyy').format(_focusedMonth),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward, size: 15),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _previousMonth,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward, size: 15),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _nextMonth,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Days of Week Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) {
                              return SizedBox(
                                width: 24,
                                child: Text(
                                  d,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 6),

                          // Month Days Grid
                          Expanded(
                            child: _buildMonthDaysGrid(primaryBlue, darkMode),
                          ),

                          // Quick Action Footer: Clear / Today
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isImmediate = true;
                                  });
                                },
                                child: const Text('Clear', style: TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    final now = DateTime.now();
                                    _focusedMonth = DateTime(now.year, now.month, 1);
                                    _selectedDate = DateTime(now.year, now.month, now.day);
                                  });
                                },
                                child: const Text('Today', style: TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // VERTICAL DIVIDER
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: darkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),

                    // RIGHT COLUMN: 15-Minute Exact Time Selector Wheel
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXACT TIME',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              controller: _timeScrollController,
                              itemCount: 96, // 24 hours * 4 quarters = 96 exact 15-min intervals
                              itemBuilder: (context, index) {
                                final hour = index ~/ 4;
                                final minute = (index % 4) * 15;
                                final isSelected = _selectedHour == hour && _selectedMinute == minute;

                                final dummyDate = DateTime(2026, 1, 1, hour, minute);
                                final formattedTime = DateFormat('hh:mm a').format(dummyDate);

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedHour = hour;
                                      _selectedMinute = minute;
                                    });
                                  },
                                  child: Container(
                                    height: 36,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? primaryBlue : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected ? null : Border.all(
                                        color: darkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : (darkMode ? Colors.grey.shade300 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Confirm Schedule Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_isImmediate) {
                    widget.onDateTimeSelected(null);
                  } else {
                    final selected = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      _selectedHour,
                      _selectedMinute,
                    );
                    widget.onDateTimeSelected(selected);
                  }
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'APPLY DISPATCH SCHEDULE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthDaysGrid(Color primaryBlue, bool darkMode) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final totalCells = startingWeekday + daysInMonth;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: (totalCells / 7).ceil() * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - startingWeekday + 1;

        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox();
        }

        final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
        final isSelected = _selectedDate.year == cellDate.year &&
            _selectedDate.month == cellDate.month &&
            _selectedDate.day == cellDate.day;

        final isToday = DateTime.now().year == cellDate.year &&
            DateTime.now().month == cellDate.month &&
            DateTime.now().day == cellDate.day;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
              _isImmediate = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected ? Border.all(color: primaryBlue, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : (darkMode ? Colors.grey.shade300 : Colors.black87),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

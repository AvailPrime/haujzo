import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../../data/repositories/bookings/booking_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';
import '../../controllers/customer/customer_home_controller.dart';
import '../../../personalization/controllers/localization_controller.dart';
import '../../models/booking_model.dart';
import '../chat/trip_chat_screen.dart';
import '../customer_home/job_dispatch_screen.dart';
import 'booking_details_screen.dart';
import 'widgets/cancel_refund_dialog.dart';
import '../../../../commons/widgets/images/driver_profile_avatar.dart';
import 'package:truck_booking/navigation_menu.dart';
import '../../../../routes/routes.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBookingDetails(BookingModel booking) {
    if (Get.isRegistered<NavigationController>()) {
      NavigationController.instance.openSubScreen(
        BookingDetailsScreen(booking: booking),
        title: 'Manifest Details',
      );
    } else {
      Get.toNamed(AvailRoutes.bookingDetails, arguments: booking);
    }
  }

  void _openJobDispatch() {
    if (Get.isRegistered<NavigationController>()) {
      NavigationController.instance.openSubScreen(
        const JobDispatchScreen(),
        title: 'Cargo Job Dispatch',
      );
    } else {
      Get.toNamed(AvailRoutes.jobDispatch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = AvailHelperFunctions.isDarkMode(context);
    final isWide = SiteLayout.isWideScreen(context);
    final isEmbedded = isWide && !Navigator.canPop(context);

    final tabView = TabBarView(
      children: [
        _buildFilteredList([]), // All
        _buildFilteredList(['pending']),
        _buildFilteredList(['confirmed', 'onTheWayToPickup', 'pickedUp', 'inTransit']),
        _buildFilteredList(['delivered']),
        _buildFilteredList(['cancelled']),
      ],
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: darkMode ? AvailColors.dark : const Color(0xFFF1F5F9),
        appBar: isEmbedded
            ? null
            : AppBar(
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0A1628),
                        Color(0xFF122F51),
                        Color(0xFF1A3E6B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                foregroundColor: Colors.white,
                elevation: 0,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AvailColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AvailColors.primary.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Icon(
                        Iconsax.truck_fast,
                        size: 16,
                        color: AvailColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FREIGHT MANIFESTS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 1.6,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Cargo Dispatch & Lifecycle Center',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                centerTitle: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(108),
                  child: Column(
                    children: [
                      // 1. Search Bar Input
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) =>
                                _searchQuery.value = val.toLowerCase().trim(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  'Search Manifest #, Route, Cargo, Driver...',
                              hintStyle: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                              prefixIcon: const Icon(
                                Iconsax.search_normal,
                                color: AvailColors.primary,
                                size: 18,
                              ),
                              suffixIcon: Obx(
                                () => _searchQuery.value.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchQuery.value = '';
                                        },
                                      )
                                    : const SizedBox(),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ),

                      // 2. Category TabBar
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        labelPadding: EdgeInsets.symmetric(horizontal: 14),
                        indicatorColor: AvailColors.primary,
                        indicatorWeight: 3.5,
                        dividerColor: Colors.transparent,
                        unselectedLabelColor: Colors.white60,
                        labelColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                        tabs: [
                          Tab(text: 'ALL JOBS'),
                          Tab(text: 'PENDING'),
                          Tab(text: 'IN TRANSIT'),
                          Tab(text: 'DELIVERED'),
                          Tab(text: 'CANCELLED'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        floatingActionButton: isEmbedded
            ? null
            : Tooltip(
                message: 'Create New Dispatch',
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: AvailColors.lineargradient,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AvailColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        if (!CustomerHomeController.instance
                            .checkShipperVerificationAndApproval()) {
                          return;
                        }
                        CustomerHomeController.instance.resetForm();
                        _openJobDispatch();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'New Dispatch',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 12.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        body: isEmbedded
            ? Column(
                children: [
                  _buildDesktopFilterHeader(darkMode),
                  Expanded(child: tabView),
                ],
              )
            : tabView,
      ),
    );
  }

  Widget _buildDesktopFilterHeader(bool darkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: BoxDecoration(
        color: darkMode ? AvailColors.dark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: darkMode
                ? const Color(0xFF1E3A5F)
                : AvailColors.borderprimary,
          ),
        ),
      ),
      child: ResponsiveCenter(
        maxWidth: 1320,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: darkMode
                          ? const Color(0xFF132238)
                          : const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: darkMode
                            ? const Color(0xFF1E3A5F)
                            : AvailColors.borderprimary,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          _searchQuery.value = val.toLowerCase().trim(),
                      style: TextStyle(
                        color: darkMode ? Colors.white : Colors.black87,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search Manifest #, Location, Cargo, Driver...',
                        hintStyle: const TextStyle(
                            color: Colors.grey, fontSize: 12.5),
                        prefixIcon: const Icon(
                          Iconsax.search_normal,
                          color: AvailColors.primary,
                          size: 18,
                        ),
                        suffixIcon: Obx(
                          () => _searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery.value = '';
                                  },
                                )
                              : const SizedBox(),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!CustomerHomeController.instance
                          .checkShipperVerificationAndApproval()) {
                        return;
                      }
                      CustomerHomeController.instance.resetForm();
                      _openJobDispatch();
                    },
                    icon: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'New Dispatch',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 12.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AvailColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                indicatorColor: AvailColors.primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                unselectedLabelColor:
                    darkMode ? Colors.white60 : Colors.grey.shade600,
                labelColor: AvailColors.primary,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
                tabs: const [
                  Tab(text: 'ALL MANIFESTS'),
                  Tab(text: 'PENDING'),
                  Tab(text: 'IN TRANSIT'),
                  Tab(text: 'DELIVERED'),
                  Tab(text: 'CANCELLED'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredList(List<String> statuses) {
    final repository = BookingRepository.instance;
    final darkMode = AvailHelperFunctions.isDarkMode(context);

    return StreamBuilder<List<BookingModel>>(
      stream: repository.getUserBookingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AvailColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.warning_2, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Communication Error: ${snapshot.error}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final allBookings = snapshot.data ?? [];

        // Apply status filter
        List<BookingModel> filtered = statuses.isEmpty
            ? allBookings
            : allBookings.where((b) => statuses.contains(b.status)).toList();

        // Apply search query filter
        return Obx(() {
          final query = _searchQuery.value;
          List<BookingModel> searchResults = filtered;

          if (query.isNotEmpty) {
            searchResults = filtered.where((b) {
              final id = b.bookingId.toLowerCase();
              final pickup = b.pickupAddress.toLowerCase();
              final dropoff = b.dropoffAddress.toLowerCase();
              final cargo = b.cargoType.toLowerCase();
              final driver = (b.driverName ?? '').toLowerCase();

              return id.contains(query) ||
                  pickup.contains(query) ||
                  dropoff.contains(query) ||
                  cargo.contains(query) ||
                  driver.contains(query);
            }).toList();
          }

          if (searchResults.isEmpty) {
            return _buildEmptyState(
              statuses.isEmpty ? 'all' : statuses.first,
              darkMode,
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final int cols = constraints.maxWidth >= 1400
                  ? 3
                  : (constraints.maxWidth >= 820 ? 2 : 1);
              final int rowCount = (searchResults.length / cols).ceil();
              final double horizontalPad =
                  constraints.maxWidth >= 820 ? 24 : AvailSizes.md;

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  16,
                  horizontalPad,
                  95,
                ),
                itemCount: rowCount + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ResponsiveCenter(
                      maxWidth: 1320,
                      child:
                          _buildLogisticsStatsOverview(allBookings, darkMode),
                    );
                  }

                  final rowIndex = index - 1;
                  if (cols == 1) {
                    final booking = searchResults[rowIndex];
                    return GestureDetector(
                      onTap: () => _openBookingDetails(booking),
                      child: _buildExecutiveManifestCard(
                          context, booking, darkMode),
                    );
                  }

                  return ResponsiveCenter(
                    maxWidth: 1320,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(cols, (c) {
                          final itemIndex = rowIndex * cols + c;
                          if (itemIndex >= searchResults.length) {
                            return const Expanded(child: SizedBox.shrink());
                          }
                          final booking = searchResults[itemIndex];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: c == 0 ? 0 : 8,
                                right: c == cols - 1 ? 0 : 8,
                              ),
                              child: GestureDetector(
                                onTap: () => _openBookingDetails(booking),
                                child: _buildExecutiveManifestCard(
                                    context, booking, darkMode),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              );
            },
          );
        });
      },
    );
  }

  /// -- Top Real-time Executive Logistics Telemetry Strip
  Widget _buildLogisticsStatsOverview(
      List<BookingModel> bookings, bool darkMode) {
    final int total = bookings.length;
    final int active = bookings
        .where((b) => [
              'confirmed',
              'pickedUp',
              'inTransit',
              'onTheWayToPickup'
            ].contains(b.status))
        .length;
    final double tons = bookings
        .where((b) => b.status == 'delivered')
        .fold(0.0, (prev, b) => prev + b.weight);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: darkMode
            ? const LinearGradient(
                colors: [Color(0xFF132238), Color(0xFF0E1B2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: darkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: 'MANIFESTS',
              value: '$total',
              subtitle: 'Total Jobs',
              icon: Iconsax.document_text5,
              color: const Color(0xFF0284C7),
              darkMode: darkMode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'IN TRANSIT',
              value: '$active',
              subtitle: 'Active Fleet',
              icon: Iconsax.truck_fast,
              color: AvailColors.primary,
              darkMode: darkMode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'DELIVERED',
              value: '${tons.toStringAsFixed(1)}T',
              subtitle: 'Cargo Hauled',
              icon: Iconsax.verify5,
              color: const Color(0xFF10B981),
              darkMode: darkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool darkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: darkMode ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: darkMode ? 0.28 : 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: darkMode ? Colors.white : AvailColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String status, bool darkMode) {
    String message = 'No Freight Manifests Found';
    String subMessage = 'Create a new dispatch job to get started';

    if (status == 'pending') {
      message = 'No Pending Dispatches';
      subMessage =
          'New cargo requests will appear here awaiting confirmation';
    } else if (status == 'inTransit' || status == 'confirmed') {
      message = 'No Cargo In Transit';
      subMessage = 'Currently active freight movements will show up here';
    } else if (status == 'delivered') {
      message = 'No Completed Deliveries';
      subMessage =
          'Delivered shipments and signed waybills will be archived here';
    } else if (status == 'cancelled') {
      message = 'No Cancelled Jobs';
      subMessage = 'Terminated freight jobs will be listed here';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: darkMode ? const Color(0xFF132238) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: darkMode
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: darkMode ? 0.25 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AvailColors.primary.withValues(alpha: 0.18),
                      AvailColors.primary.withValues(alpha: 0.06),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AvailColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Iconsax.radar5,
                  size: 48,
                  color: AvailColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: darkMode ? Colors.white : AvailColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subMessage,
                style: TextStyle(
                  color: darkMode
                      ? Colors.grey.shade400
                      : const Color(0xFF64748B),
                  fontSize: 12.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!CustomerHomeController.instance
                        .checkShipperVerificationAndApproval()) {
                      return;
                    }
                    CustomerHomeController.instance.resetForm();
                    _openJobDispatch();
                  },
                  icon: const Icon(Iconsax.add_circle,
                      color: Colors.white, size: 18),
                  label: const Text(
                    'DISPATCH CARGO JOB',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AvailColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// -- Executive Boarding-Pass Style Freight Manifest Card
  Widget _buildExecutiveManifestCard(
      BuildContext context, BookingModel booking, bool darkMode) {
    final cardColor = darkMode ? const Color(0xFF132238) : Colors.white;

    // Color-Coded Card Accents per Lifecycle Status
    Color statusColor = const Color(0xFFF59E0B); // Amber Pending
    if (booking.status == 'confirmed') {
      statusColor = const Color(0xFF2563EB); // Royal Blue
    } else if (booking.status == 'pickedUp' ||
        booking.status == 'inTransit' ||
        booking.status == 'onTheWayToPickup') {
      statusColor = const Color(0xFF4F46E5); // Indigo Transit
    } else if (booking.status == 'delivered') {
      statusColor = const Color(0xFF10B981); // Emerald Green
    } else if (booking.status == 'cancelled') {
      statusColor = const Color(0xFFEF4444); // Crimson Red
    }

    String displayId =
        booking.bookingId.isNotEmpty ? booking.bookingId : booking.id;
    if (!displayId.toUpperCase().startsWith('FT')) {
      displayId = "FT-$displayId";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: statusColor.withValues(alpha: darkMode ? 0.42 : 0.30),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: darkMode ? 0.14 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 1. Color-Coded Gradient Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: darkMode ? 0.22 : 0.14),
                  statusColor.withValues(alpha: darkMode ? 0.08 : 0.04),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: statusColor.withValues(alpha: 0.22),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Iconsax.document_text5,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '#$displayId',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                      fontFamily: 'monospace',
                                      color: darkMode
                                          ? Colors.white
                                          : AvailColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (booking.truckType.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: darkMode
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black
                                              .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      booking.truckType.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: darkMode
                                            ? Colors.white70
                                            : AvailColors.secondary,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Iconsax.calendar_1,
                                  size: 11,
                                  color: darkMode
                                      ? Colors.grey.shade400
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • HH:mm')
                                      .format(booking.timestamp),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: darkMode
                                        ? Colors.grey.shade400
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(booking.status, statusColor),
              ],
            ),
          ),

          /// 2. 5-Step Lifecycle Stepper Tracker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _buildStepTracker(booking.status, darkMode),
          ),

          /// 3. Inset Visual Route Timeline Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: darkMode
                  ? const Color(0xFF0C1829)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: darkMode
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 1.4,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 24,
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFFEF4444),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: const Color(0xFFEF4444),
                              width: 1.4,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'B',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PICKUP ORIGIN',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              if (booking.distance > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AvailColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${booking.distance.toStringAsFixed(1)} KM',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AvailColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.pickupAddress,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: darkMode
                                  ? Colors.white
                                  : AvailColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'DELIVERY DESTINATION',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.dropoffAddress,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: darkMode
                                  ? Colors.white
                                  : AvailColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (booking.stops.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.routing_2,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${booking.stops.length} Intermediate Waypoint Stop(s)',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// 4. Cargo Metrics & Handling Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildMetricChip(
                  icon: Iconsax.box,
                  label: booking.containerSize.isNotEmpty &&
                          booking.containerSize != 'None'
                      ? '${booking.cargoType} (${booking.containerSize})'
                      : booking.cargoType,
                  darkMode: darkMode,
                ),
                _buildMetricChip(
                  icon: Iconsax.weight,
                  label: '${booking.weight} Tons',
                  darkMode: darkMode,
                ),
                if (booking.isFragile)
                  _buildMetricChip(
                    icon: Iconsax.danger,
                    label: 'Fragile',
                    color: const Color(0xFFF59E0B),
                    darkMode: darkMode,
                  ),
                if (booking.isInsured)
                  _buildMetricChip(
                    icon: Iconsax.shield_tick,
                    label: 'Insured',
                    color: const Color(0xFF10B981),
                    darkMode: darkMode,
                  ),
              ],
            ),
          ),

          /// 5. Assigned Driver Telemetry Banner (if assigned)
          if (booking.driverName != null && booking.driverName!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0284C7)
                        .withValues(alpha: darkMode ? 0.2 : 0.10),
                    const Color(0xFF2563EB)
                        .withValues(alpha: darkMode ? 0.12 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  DriverProfileAvatar(
                    driverImage: booking.driverImage,
                    driverId: booking.driverId,
                    radius: 15,
                    fallbackWidget: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.user_tick,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.driverName!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: darkMode
                                ? Colors.white
                                : AvailColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Assigned Operator • ${booking.vehiclePlate ?? "Fleet Unit"}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: darkMode
                                ? Colors.lightBlue.shade200
                                : const Color(0xFF0284C7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (booking.canChatWithDriver) ...[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              Get.to(() => TripChatScreen(booking: booking)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AvailColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.messages_2,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'CHAT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: ShipperUnreadChatBadge(
                              booking: booking, compact: true),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    if (booking.driverPhone != null &&
                        booking.driverPhone!.isNotEmpty)
                      GestureDetector(
                        onTap: () => CustomerHomeController.instance
                            .callDriver(booking.driverPhone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.call5, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'CALL',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: (darkMode ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.lock,
                            size: 11,
                            color: darkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CHAT CLOSED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: darkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          /// 6. Bottom Financial & Action Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: darkMode
                  ? const Color(0xFF0D1829)
                  : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: darkMode
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL FREIGHT RATE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Obx(
                      () => Text(
                        LocalizationController.instance
                            .getFormattedPrice(booking.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          color: AvailColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: booking.isCancelled && booking.isPaidOnline
                            ? (booking.isRefunded
                                ? Colors.teal.withValues(alpha: 0.14)
                                : booking.isRefundFailed
                                    ? Colors.red.withValues(alpha: 0.14)
                                    : Colors.amber.withValues(alpha: 0.18))
                            : (booking.isPaidOnline
                                ? Colors.green.withValues(alpha: 0.14)
                                : (booking.requiresOnlinePaymentPrompt
                                    ? Colors.orange.withValues(alpha: 0.16)
                                    : Colors.grey.withValues(alpha: 0.12))),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.isCancelled && booking.isPaidOnline
                            ? (booking.isRefunded
                                ? 'REFUNDED ✓'
                                : booking.isRefundProcessing
                                    ? 'REFUND PROCESSING'
                                    : booking.isRefundRequested
                                        ? 'REFUND REQUESTED'
                                        : booking.isRefundFailed
                                            ? 'REFUND FAILED'
                                            : 'PAID ONLINE (CANCELLED)')
                            : (booking.isPaidOnline
                                ? 'PAID ONLINE ✓'
                                : (booking.requiresOnlinePaymentPrompt
                                    ? 'PAYMENT DUE ONLINE'
                                    : (booking.paymentMethod ??
                                            'CASH ON DELIVERY')
                                        .toUpperCase())),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: booking.isCancelled && booking.isPaidOnline
                              ? (booking.isRefunded
                                  ? Colors.teal.shade700
                                  : booking.isRefundFailed
                                      ? Colors.red.shade700
                                      : Colors.amber.shade900)
                              : (booking.isPaidOnline
                                  ? Colors.green.shade700
                                  : (booking.requiresOnlinePaymentPrompt
                                      ? Colors.orange.shade800
                                      : Colors.grey.shade700)),
                        ),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1-Tap Track Live Button for Active Dispatches
                      if ([
                        'confirmed',
                        'pickedUp',
                        'inTransit',
                        'onTheWayToPickup'
                      ].contains(booking.status))
                        ElevatedButton.icon(
                          onPressed: () {
                            CustomerHomeController.instance
                                .showJobOnMap(booking);
                            if (Get.isRegistered<NavigationController>()) {
                              NavigationController
                                  .instance.selectedIndex.value = 0;
                            }
                            if (Get.isOverlaysOpen) {
                              Get.back(closeOverlays: true);
                            }
                          },
                          icon: const Icon(Iconsax.radar5,
                              color: Colors.white, size: 13),
                          label: const Text(
                            'MAP TRACK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AvailColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                        ),

                      if (booking.status == 'pending')
                        TextButton.icon(
                          onPressed: () {
                            CustomerHomeController.instance
                                .populateForEditing(booking);
                            _openJobDispatch();
                          },
                          icon: const Icon(Iconsax.edit_2,
                              size: 12, color: AvailColors.primary),
                          label: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: AvailColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            backgroundColor:
                                AvailColors.primary.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                        ),

                      if (booking.canShipperCancelDirectly)
                        TextButton(
                          onPressed: () =>
                              CancelRefundDialog.show(context, booking),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            backgroundColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                          child: Text(
                            booking.isPaidOnline ? 'CANCEL / REFUND' : 'CANCEL',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        )
                      else if (booking.isCancelled &&
                          booking.isPaidOnline &&
                          !booking.isRefunded &&
                          !booking.isRefundRequested &&
                          !booking.isRefundProcessing)
                        TextButton(
                          onPressed: () =>
                              CancelRefundDialog.show(context, booking),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            backgroundColor:
                                Colors.orange.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                          child: Text(
                            'REQUEST REFUND',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),

                      OutlinedButton.icon(
                        onPressed: () => _openBookingDetails(booking),
                        icon: Icon(
                          Iconsax.arrow_right_3,
                          size: 13,
                          color: statusColor,
                        ),
                        label: Text(
                          'DETAILS',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(
                            color: statusColor.withValues(alpha: 0.65),
                          ),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
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

  /// -- 5-Step Lifecycle Progress Stepper Tracker with Labels
  Widget _buildStepTracker(String status, bool darkMode) {
    final stages = [
      {'key': 'pending', 'label': 'Pending', 'step': '1'},
      {'key': 'confirmed', 'label': 'Confirmed', 'step': '2'},
      {'key': 'pickedUp', 'label': 'Picked Up', 'step': '3'},
      {'key': 'inTransit', 'label': 'In Transit', 'step': '4'},
      {'key': 'delivered', 'label': 'Delivered', 'step': '5'},
    ];

    int activeIndex = 0;
    if (status == 'pending') {
      activeIndex = 0;
    } else if (status == 'confirmed' || status == 'onTheWayToPickup') {
      activeIndex = 1;
    } else if (status == 'pickedUp') {
      activeIndex = 2;
    } else if (status == 'inTransit') {
      activeIndex = 3;
    } else if (status == 'delivered') {
      activeIndex = 4;
    } else if (status == 'cancelled') {
      activeIndex = -1;
    }

    if (activeIndex == -1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            Icon(Iconsax.close_circle5, size: 15, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text(
              'Dispatch Terminated & Cancelled',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      );
    }

    final Color completedColor = const Color(0xFF10B981);
    final Color currentColor =
        activeIndex == 4 ? completedColor : AvailColors.primary;
    final Color inactiveLineColor = darkMode
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Stage count indicator and status pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIFECYCLE STAGE ${activeIndex + 1} OF 5',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color:
                        darkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: darkMode ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: currentColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                stages[activeIndex]['label']!.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: currentColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Perfectly Aligned Linear Lifecycle Stepper & Labels
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(stages.length, (index) {
            final bool isPassed = index < activeIndex;
            final bool isCurrent = index == activeIndex;

            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Node Row: Left connector line, Circle Node, Right connector line
                  SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        // Left Connector Line
                        Expanded(
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? Colors.transparent
                                  : (index <= activeIndex
                                      ? completedColor
                                      : inactiveLineColor),
                              borderRadius: index == 1
                                  ? const BorderRadius.horizontal(
                                      left: Radius.circular(2))
                                  : BorderRadius.zero,
                            ),
                          ),
                        ),

                        // Circle Node
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? completedColor
                                : (isCurrent
                                    ? currentColor
                                    : (darkMode
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC))),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPassed
                                  ? completedColor
                                  : (isCurrent
                                      ? currentColor
                                      : (darkMode
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1))),
                              width: isCurrent ? 2 : 1.2,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color:
                                          currentColor.withValues(alpha: 0.35),
                                      blurRadius: 7,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isPassed || (isCurrent && activeIndex == 4)
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  )
                                : Text(
                                    stages[index]['step']!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isCurrent
                                          ? Colors.white
                                          : (darkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade500),
                                    ),
                                  ),
                          ),
                        ),

                        // Right Connector Line
                        Expanded(
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: index == stages.length - 1
                                  ? Colors.transparent
                                  : (index < activeIndex
                                      ? completedColor
                                      : inactiveLineColor),
                              borderRadius: index == stages.length - 2
                                  ? const BorderRadius.horizontal(
                                      right: Radius.circular(2))
                                  : BorderRadius.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Status Label - Exactly centered directly under its node circle
                  Container(
                    height: 26,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      stages[index]['label']!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        height: 1.15,
                        fontWeight: isCurrent
                            ? FontWeight.w900
                            : (isPassed ? FontWeight.w700 : FontWeight.w500),
                        color: isCurrent
                            ? currentColor
                            : (isPassed
                                ? (darkMode
                                    ? Colors.grey.shade200
                                    : const Color(0xFF1E293B))
                                : (darkMode
                                    ? Colors.grey.shade500
                                    : const Color(0xFF94A3B8))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required bool darkMode,
    Color? color,
  }) {
    final accent = color ?? AvailColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: darkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: accent.withValues(alpha: darkMode ? 0.3 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    String label = status.toUpperCase();

    if (status == 'pending') {
      label = 'PENDING';
    } else if (status == 'confirmed') {
      label = 'CONFIRMED';
    } else if (status == 'inTransit' ||
        status == 'pickedUp' ||
        status == 'onTheWayToPickup') {
      label = 'IN TRANSIT';
    } else if (status == 'delivered') {
      label = 'DELIVERED';
    } else if (status == 'cancelled') {
      label = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../commons/widgets/appBar/appbar.dart';
import '../../../../commons/widgets/layouts/app_page_layout.dart';
import '../../../../commons/widgets/layouts/site_layout.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/helpers/helper_functions.dart';

class TermsOfServiceScreen extends StatefulWidget {
  final int initialTabIndex;
  const TermsOfServiceScreen({super.key, this.initialTabIndex = 0});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final int targetIndex =
        (Get.arguments is int) ? (Get.arguments as int) : widget.initialTabIndex;
    _tabController =
        TabController(length: 4, vsync: this, initialIndex: targetIndex.clamp(0, 3));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    final bgColor = dark ? AvailColors.dark : const Color(0xFFF8FAFC);
    final cardColor = dark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = dark ? const Color(0xFF334155) : Colors.grey.shade200;
    final titleColor = dark ? Colors.white : Colors.black87;
    final bodyColor = dark ? Colors.grey.shade300 : Colors.grey.shade800;
    final isWide = SiteLayout.isWideScreen(context);

    final tabs = const [
      Tab(icon: Icon(Iconsax.user, size: 17), text: 'Shipper & Platform'),
      Tab(icon: Icon(Iconsax.buildings, size: 17), text: 'Corporate & KYB'),
      Tab(icon: Icon(Iconsax.box_tick, size: 17), text: 'Cargo & Demurrage'),
      Tab(icon: Icon(Iconsax.shield_cross, size: 17), text: 'Anti-Fraud & Refunds'),
    ];

    return AppPageLayout(
      title: 'Terms of Service & Agreements',
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isWide
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: dark ? const Color(0xFF132238) : Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AvailColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AvailColors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: tabs,
                  ),
                ),
              )
            : AvailAppbar(
                title: const Text(
                  'Terms of Service & Agreements',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                ),
                showBackArrow: true,
                showBackgroundColor: true,
                backArrowColor: Colors.white,
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: AvailColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: tabs,
                ),
              ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildShipperTerms(dark, cardColor, borderColor, titleColor, bodyColor),
            _buildCorporateTerms(dark, cardColor, borderColor, titleColor, bodyColor),
            _buildCargoDemurrageTerms(dark, cardColor, borderColor, titleColor, bodyColor),
            _buildAntiFraudRefundsTerms(dark, cardColor, borderColor, titleColor, bodyColor),
          ],
        ),
      ),
    );
  }

  /// TAB 1: SHIPPER & PLATFORM MASTER TERMS
  Widget _buildShipperTerms(
    bool dark,
    Color cardColor,
    Color borderColor,
    Color titleColor,
    Color bodyColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveCenter(
        maxWidth: 920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLegalHeaderCard(
              title: 'Haujzo Shipper Master Terms of Service',
              version: 'Version 2.0 • Effective: November 17, 2026',
              summary:
                  'Binding commercial agreement governing individual shippers, cargo owners, and authorized dispatchers booking commercial road freight transportation on Haujzo.',
              accent: AvailColors.primary,
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: '1. Technology Marketplace Role (Not a Motor Carrier)',
              icon: Iconsax.hierarchy,
              content:
                  'Haujzo ("Platform") provides digital freight-matching, route estimation, live GPS telematics, waybill generation, and payment settlement software connecting cargo Shippers (on Haujzo) with independent commercial drivers and fleet carriers (operating on Haujzo Pro).\n\n'
                  'Haujzo is strictly a technology intermediary—NOT a motor carrier of record, common carrier, freight forwarder, customs broker, bailee, warehouseman, or direct insurer. Haujzo never takes physical possession, custody, or title to any cargo. Physical carriage is performed solely by the matched independent carrier.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '2. Dual-Gate Eligibility, Didit KYC & Discretionary Access',
              icon: Iconsax.verify,
              content:
                  'To book trucks on Haujzo, you must be at least 18 years old, possess legal capacity to contract, and maintain accurate account credentials. Shippers must complete BOTH: (a) automated identity and biometric liveness verification via Didit Protocol (valid National ID, Passport, Driver License, or Voter ID), AND (b) operational approval by Haujzo Portal.\n\n'
                  'Haujzo reserves sole, unilateral discretion to decline, suspend, restrict, or revoke account access at any time—including upon ID expiry, payment reversals, chargebacks, or risk alerts—without liability for business interruption.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '3. Binding Freight Manifests, Weight & Container Declarations',
              icon: Iconsax.weight,
              content:
                  'You represent and warrant that every manifest detail—including cargo category (Container, General Freight, Bulk / Loose Material, Heavy Machinery, or Refrigerated Goods), ISO container size and status (20ft, 40ft, Twin 20ft; Loaded, 1 Loaded + 1 Empty, or Empty Return), container serial number, gross weight, itemized inventory, pickup/intermediate stop/dropoff coordinates, and consignor/consignee contacts—is true, lawful, and complete.\n\n'
                  'Under-declaring gross weight or misrepresenting cargo dimensions or hazardous nature makes the Shipper strictly liable for axle-overload fines, weighbridge penalties, vehicle structural damage, escort/offloading costs, and upward fare adjustments.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '4. Dynamic Pricing, FX Conversion & Mandatory Payment Rules',
              icon: Iconsax.wallet_money,
              content:
                  '• Transparent Pre-Dispatch Quotes: Fares are computed dynamically from vehicle class, corridor distance tier, single or round-trip leg mode, ISO container multipliers or empty-return discounts, excess weight, road allowances, and optional fragile, hazardous, or loading crew selections.\n'
                  '• Multi-Currency & GHS Settlement: Base pricing runs in USD and converts into your chosen Display Currency (e.g., GHS, USD, NGN, EUR, GBP) using live or fallback FX rates. All online Paystack charges and refunds settle in GHS (or active gateway currency) at prevailing conversion rates; minor FX rounding variances create no claim against Haujzo.\n'
                  '• Loaded-on-Truck Online Payment Rule: You may choose "Cash on Delivery (POD)" or "Paystack (Online)" at booking. However, once the driver marks cargo as Loaded / Picked Up / In Transit, any unpaid booking triggers an urgent online payment prompt—settling via Paystack secures confirmed payment status across Haujzo, Haujzo Pro, and Haujzo Portal.\n'
                  '• Anti-Double-Payment Rule: Once a trip is marked "PAID ONLINE", drivers are strictly forbidden from demanding cash. If you hand physical cash to a driver on an online-paid trip without written Haujzo Portal authorization, you do so at your sole risk.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '5. Manifest Edits, Cancellation Cutoff & Post-Pickup Lock',
              icon: Iconsax.card_tick,
              content:
                  '• Manifest Edits: You may edit route, cargo, or contact details only while the booking status remains "Pending" prior to driver confirmation.\n'
                  '• Self-Cancellation Cutoff: You may cancel directly in-app only before cargo is picked up or loaded onto the truck ("Pending", "Confirmed", or "On the Way to Pickup"). Cancelling after a driver is confirmed/en route—or failing to present cargo within thirty (30) minutes of driver arrival inside the pickup geofence—subjects you to mobilization and deadhead cancellation charges.\n'
                  '• Strict Lock Once Loaded / In Transit: Once cargo is marked Picked Up, Loaded, or In Transit, self-cancellation is strictly locked to prevent mid-transit payment evasion or carrier/shipper fraud. Any emergency termination or dispute after pickup requires Haujzo Portal Admin review.\n'
                  '• Driver Release Protection: If an assigned driver cancels before pickup, your booking returns automatically to dispatch, and any online Paystack payment remains fully protected—you may await reassignment or cancel and request a full refund.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '6. Consignee Inspection, 500m Geofenced POD & Waybills',
              icon: Iconsax.box_tick,
              content:
                  'You must ensure an authorized Consignee is present at the designated dropoff location to inspect and receive the cargo. Haujzo Pro enforces strict sequential stages and 500-meter GPS geofence verification before a driver can mark delivery complete.\n\n'
                  'Any visible external damage, broken container seals, moisture ingress, or count shortage MUST be photographed and recorded at the time of handover before confirming receipt. Accepting delivery without immediate written exception creates a binding prima facie presumption that the cargo was delivered complete and in good order.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '7. Broad Indemnification & Limitation of Liability',
              icon: Iconsax.shield_security,
              content:
                  'TO THE MAXIMUM EXTENT PERMITTED BY LAW, YOU AGREE TO DEFEND, INDEMNIFY, AND HOLD HARMLESS HAUJZO, ITS AFFILIATES, OFFICERS, EMPLOYEES, AND DISPATCHERS FROM ALL CLAIMS, LOSSES, REGULATORY FINES, CUSTOMS SEIZURES, THIRD-PARTY BODILY INJURY, DEATH, PROPERTY DAMAGE, AXLE-OVERLOAD PENALTIES, OR LEGAL COSTS ARISING OUT OF YOUR CARGO, MISDECLARATIONS, IMPROPER PACKAGING/LOADING, OR BREACH OF THESE TERMS.\n\n'
                  'THE HAUJZO PLATFORM AND ROUTING TOOLS ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT IMPLIED WARRANTIES. HAUJZO SHALL NEVER BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR LOST-PROFIT DAMAGES. HAUJZO\'S MAXIMUM AGGREGATE LIABILITY FOR ANY CLAIM SHALL NOT EXCEED THE PLATFORM SERVICE FEES RETAINED BY HAUJZO FOR THE SPECIFIC DISPUTED SHIPMENT.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '8. Telemetry Evidence, 14-Day Claim Window & Arbitration',
              icon: Iconsax.judge,
              content:
                  'Platform GPS coordinates, 500m geofence entry/dwell timestamps, sequential stage logs, uploaded waybills/documents, Paystack records, and support tickets constitute conclusive prima facie evidence in any fare, demurrage, cancellation, or refund dispute.\n\n'
                  'Any billing, fare adjustment, demurrage, or refund dispute must be submitted in writing via Support Ticket within fourteen (14) calendar days of trip completion or cancellation; claims raised thereafter are permanently waived. Unresolved disputes undergo Haujzo Portal Operations Adjudication for thirty (30) days, followed by binding commercial arbitration under applicable commercial and transport laws.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// TAB 2: CORPORATE / BUSINESS SHIPPER TERMS
  Widget _buildCorporateTerms(
    bool dark,
    Color cardColor,
    Color borderColor,
    Color titleColor,
    Color bodyColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveCenter(
        maxWidth: 920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNoticeBanner(
              title: 'Business & Corporate Shipper Master Agreement',
              subtitle:
                  'Applies to registered companies, manufacturers, freight forwarders, importers/exporters, and commercial enterprises operating Business Shipper accounts.',
              icon: Iconsax.buildings,
              color: dark ? Colors.amber.shade200 : Colors.amber.shade900,
              bgColor: dark ? Colors.amber.shade900.withValues(alpha: 0.25) : Colors.amber.shade50,
              subtitleColor: bodyColor,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '1. Corporate Representation & Binding Authority',
              icon: Iconsax.briefcase,
              content:
                  'Any individual registering or operating a Business Shipper account on Haujzo represents and warrants full legal authority to bind the corporate entity to these Terms, authorize commercial truck dispatches, execute manifests, and incur freight, demurrage, and cancellation liabilities.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '2. Didit KYB Verification & Portal Compliance Audits',
              icon: Iconsax.security_card,
              content:
                  'Business Shipper accounts must complete Know Your Business (KYB) verification via Didit Protocol and receive Haujzo Portal Operations approval before dispatching freight. Required disclosures include registered legal company name, Tax Identification Number (TIN) or business registration number, verifiable corporate physical address, and authorized representative credentials. Haujzo may require updated corporate filings at any time.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '3. Vicarious Liability for Staff, Agents & Consignees',
              icon: Iconsax.profile_2user,
              content:
                  'The Business Shipper is 100% jointly and vicariously liable for every freight manifest submitted, intermediate stop instruction issued, document/invoice uploaded, payment authorized, and Proof of Delivery (POD) confirmation executed by its employees, warehouse personnel, brokers, or designated consignees.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '4. Port Clearances, Customs & Shipping Line Container Demurrage',
              icon: Iconsax.ship,
              content:
                  'For port-to-warehouse, bonded, or ISO container movements (20ft, 40ft, or Twin 20ft), the Business Shipper is solely responsible for securing customs releases, terminal gate passes, shipping line Equipment Interchange Receipts (EIR), and empty container return deadlines unless expressly agreed otherwise in writing.\n\n'
                  'Shipping line container detention, terminal storage rent, and port-gate queuing delays caused by shipper paperwork or customs holds remain the Shipper\'s sole financial responsibility.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '5. Commercial Waybills, Set-Off & Settlement Standing',
              icon: Iconsax.receipt_2_1,
              content:
                  'Digital manifests, itemized fare breakdowns, Paystack receipts, and downloadable PDF Waybills generated through Haujzo constitute valid commercial dispatch records. Any reversed payments, payment gateway chargebacks, or unpaid detention/demurrage balances authorize Haujzo to suspend corporate dispatch privileges immediately and set off balances against any pending credits or refunds until settled in full.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// TAB 3: CARGO CARRIAGE, DEMURRAGE & CLAIMS POLICY
  Widget _buildCargoDemurrageTerms(
    bool dark,
    Color cardColor,
    Color borderColor,
    Color titleColor,
    Color bodyColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveCenter(
        maxWidth: 920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNoticeBanner(
              title: 'Cargo Carriage, Demurrage & Claims Policy',
              subtitle:
                  'Loading windows, GPS-audited detention billing, labor duties, packaging rules, transit insurance boundaries, and the 48-hour claims protocol.',
              icon: Iconsax.box_tick,
              color: dark ? Colors.green.shade200 : Colors.green.shade900,
              bgColor: dark ? Colors.green.shade900.withValues(alpha: 0.25) : Colors.green.shade50,
              subtitleColor: bodyColor,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '1. Standard 120-Minute Loading & Offloading Windows',
              icon: Iconsax.clock,
              content:
                  'Every Haujzo freight booking includes a free waiting window of two (2) hours (120 minutes) for loading at origin and two (2) hours (120 minutes) for offloading at destination. The waiting clock starts when the assigned driver enters the verified 500-meter GPS geofence and updates arrival status in Haujzo Pro.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '2. Verifiable Hourly Demurrage & Detention Charges',
              icon: Iconsax.money_change,
              content:
                  'If loading or offloading delays caused by the Shipper, consignor, warehouse, port terminal, or Consignee exceed the free 120-minute window, detention/demurrage charges accrue automatically on an hourly basis according to vehicle class (e.g., Rigid / Medium Truck: \$15/hr equivalent; Articulated / Flatbed / Heavy Duty Trailer: \$25/hr equivalent, subject to live platform schedule).\n\n'
                  'GPS geofence dwell logs audited by Haujzo Portal govern detention billing. Unpaid demurrage balances may be charged to the Shipper or trigger account suspension.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '3. Loading & Offloading Labor Responsibility',
              icon: Iconsax.people,
              content:
                  'Unless you explicitly select and pay for "Loading & Offloading Crew" assistance during booking, the Shipper and Consignee are solely responsible for providing safe labor, forklifts, cranes, or dock equipment to load and offload cargo. Drivers are responsible for vehicle positioning and load securing (straps/twist locks), not manual warehouse stevedoring.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '4. Prohibited & Unmanifested Hazardous Cargo',
              icon: Iconsax.danger,
              content:
                  'Shippers are strictly prohibited from tendering: unlicensed firearms or ammunition, Class 1 explosives, radioactive substances, illegal narcotics or contraband, stolen property, sanctioned goods, undeclared cash/bullion, or protected wildlife.\n\n'
                  'Regulated hazardous materials may only be shipped if explicitly flagged as "Hazardous / Dangerous Goods" in the booking form and accompanied by lawful Material Safety Data Sheets (MSDS) and statutory transport permits. Concealing hazardous or contraband cargo voids all insurance/claims and exposes the Shipper to full civil, regulatory, and criminal liability.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '5. Packaging, Fragile, Cold-Chain & Transit Insurance Limits',
              icon: Iconsax.shield_tick,
              content:
                  '• Packaging & Fragile Goods: Shippers must ensure cargo is properly palletized, crated, weather-sealed, and labeled prior to loading. Fragile goods must be flagged "Fragile / Delicate Cargo", and temperature-sensitive goods must be booked on a Refrigerated Truck when active. Loss from inadequate packaging or inherent vice of goods is strictly excluded.\n'
                  '• Transit Insurance ("isInsured"): Optional Goods-in-Transit (GIT) protection applies ONLY when Transit Insurance is enabled on the booking and an accurate Cargo Value is declared prior to dispatch, subject to applicable underwriting limits, deductibles, and exclusions. Uninsured shipments and losses resulting from misdeclaration or Force Majeure travel strictly at the Shipper\'s risk.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '6. Strict 48-Hour Cargo Claims Protocol & Force Majeure',
              icon: Iconsax.radar,
              content:
                  'Any claim for cargo loss, shortage, or transit damage must be submitted in writing within forty-eight (48) hours of delivery (or scheduled delivery) via Help & Support Ticket or support@haujzo.com, accompanied by the Manifest ID, downloadable Waybill PDF, delivery exception notes, and timestamped photographic evidence.\n\n'
                  'Failure to inspect cargo at handover or submit a documented claim within 48 hours constitutes a permanent waiver of the claim. Neither Haujzo nor carriers are liable for delays or losses caused by Force Majeure events (severe weather, bridge/road collapse, civil unrest, port strikes, or statutory security checkpoints).',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// TAB 4: ANTI-FRAUD, REFUNDS & ENFORCEMENT RULES
  Widget _buildAntiFraudRefundsTerms(
    bool dark,
    Color cardColor,
    Color borderColor,
    Color titleColor,
    Color bodyColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveCenter(
        maxWidth: 920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNoticeBanner(
              title: 'Refunds, Anti-Fraud & Enforcement Policy',
              subtitle:
                  'Paystack refund verification rules, chargeback abuse defense, anti-circumvention covenants, and zero-tolerance platform security.',
              icon: Iconsax.shield_cross,
              color: dark ? Colors.red.shade200 : Colors.red.shade900,
              bgColor: dark ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.red.shade50,
              subtitleColor: bodyColor,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '1. Paystack Online Refund Eligibility & Name-Match Rules',
              icon: Iconsax.money_recive,
              content:
                  'Refunds apply exclusively to cancelled bookings that were verified as "Paid Online" via Paystack and where carrier payout has not already been disbursed. Once submitted via the Cancel & Request Refund flow, Haujzo Portal Finance verifies transaction status before executing settlement.\n\n'
                  '• Refund Destination: Refunds are processed back to the Original Paystack Source (Card/MoMo) OR to your verified saved Mobile Money / Bank wallet—which STRICTLY requires an Account Holder Name matching the verified account resolution on Paystack. Bank/gateway settlement takes 3 to 10 business days depending on your provider.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '2. Chargeback Abuse & Payment Reversal Remedies',
              icon: Iconsax.card_slash,
              content:
                  'Initiating an unverified bank card chargeback or Mobile Money reversal after cargo has been loaded, transported, or delivered—or bypassing the mandatory 30-day Haujzo Portal Dispute Adjudication process—constitutes material breach and payment fraud.\n\n'
                  'Haujzo reserves the immediate right to submit GPS route logs, 500m geofence POD records, Waybills, and Didit KYC/KYB files to payment processors and card networks to contest illegitimate chargebacks, permanently terminate the Shipper account, and recover the disputed amount plus gateway dispute fees and legal costs.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '3. Strict Anti-Circumvention & 12-Month Non-Solicitation',
              icon: Iconsax.forbidden_2,
              content:
                  'For twelve (12) months following any dispatch or carrier introduction made through Haujzo, you shall not directly or indirectly solicit, hire, quote, or book that Haujzo Pro driver or Fleet Carrier off-platform to evade platform service fees, safety tracking, or compliance oversight.\n\n'
                  'Breach of this covenant entitles Haujzo to immediate permanent account suspension, forfeiture of any pending credits or promotional balances as reasonable liquidated damages, and full legal recovery of evaded platform fees.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            _buildSectionCard(
              title: '4. Zero-Tolerance Offenses & Final Operational Determination',
              icon: Iconsax.close_square,
              content:
                  'Haujzo Portal Operations enforces immediate suspension or permanent termination without prior notice for: (a) submitting forged IDs, fake TINs, or bypassing Didit biometric liveness checks; (b) falsifying manifests, weights, or POD claims; (c) tampering with GPS coordinates, payment webhooks, or app integrity; or (d) engaging in abusive, threatening, or coercive conduct toward drivers or dispatch staff.\n\n'
                  'Suspended Shippers may submit a written appeal with supporting records within seven (7) calendar days via Support Ticket or support@haujzo.com. Haujzo Portal Compliance\'s written determination regarding platform access privileges is final.',
              cardColor: cardColor,
              borderColor: borderColor,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalHeaderCard({
    required String title,
    required String version,
    required String summary,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AvailColors.navyGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AvailColors.secondary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.document_text, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      version,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String content,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AvailColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AvailColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.8, color: titleColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: TextStyle(fontSize: 12.5, color: bodyColor, height: 1.48)),
        ],
      ),
    );
  }
}

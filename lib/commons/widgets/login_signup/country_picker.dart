import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../utils/constants/country_codes.dart';
import '../../../../utils/constants/sizes.dart';

class AvailCountryPicker extends StatelessWidget {
  const AvailCountryPicker({
    super.key,
    required this.onCountrySelected,
    this.selectedCountry,
    this.countries,
  });

  final Function(AvailCountry) onCountrySelected;
  final AvailCountry? selectedCountry;
  final List<AvailCountry>? countries;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCountrySearch(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AvailSizes.md, horizontal: AvailSizes.sm),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(AvailSizes.inputfieldradius),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.global, color: Colors.grey),
            const SizedBox(width: AvailSizes.spacebtwitems),
            Expanded(
              child: Text(
                selectedCountry != null
                    ? '${selectedCountry!.flag}  ${selectedCountry!.name}'
                    : 'Select Country of Origin',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: selectedCountry == null ? Colors.grey : null,
                    ),
              ),
            ),
            const Icon(Iconsax.arrow_down_1, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCountrySearch(BuildContext context) {
    final searchQuery = ''.obs;
    final List<AvailCountry> sourceList = countries ?? AvailCountry.africanCountries;
    final filteredCountries = sourceList.obs;

    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        padding: const EdgeInsets.all(AvailSizes.defaultspace),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AvailSizes.cardradiuslg),
            topRight: Radius.circular(AvailSizes.cardradiusmd),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Text('Select Country',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AvailSizes.spacebtwsections),
              TextFormField(
                onChanged: (value) {
                  searchQuery.value = value;
                  filteredCountries.value = sourceList
                      .where((c) =>
                          c.name.toLowerCase().contains(value.toLowerCase()))
                      .toList();
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Iconsax.search_normal),
                  hintText: 'Search country...',
                ),
              ),
              const SizedBox(height: AvailSizes.spacebtwitems),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      return ListTile(
                        leading: Text(country.flag,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(country.name),
                        trailing: Text(country.phoneCode,
                            style: const TextStyle(color: Colors.grey)),
                        onTap: () {
                          onCountrySelected(country);
                          Get.back();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

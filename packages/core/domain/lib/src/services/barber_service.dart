enum ServiceFailure implements Exception {
  format,
  fields,
  permission,
  network,
  operation,
}

class ServiceDetails {
  const ServiceDetails({
    required this.name,
    required this.priceCents,
    required this.durationMinutes,
  });

  static const maxNameLength = 120;
  static const maxPricePesos = 1000000000;
  static const minDuration = 5;
  static const maxDuration = 240;

  final String name;
  final int priceCents;
  final int durationMinutes;

  static final _pricePattern = RegExp(r'^([0-9]+)(?:[.,]([0-9]{1,2}))?$');

  static int? parsePriceCents(String text) {
    final match = _pricePattern.firstMatch(text.trim());
    if (match == null) return null;
    final pesos = int.tryParse(match[1]!);
    if (pesos == null || pesos > maxPricePesos) return null;
    final cents = int.parse((match[2] ?? '').padRight(2, '0'));
    final price = pesos * 100 + cents;
    return price <= maxPricePesos * 100 ? price : null;
  }

  String get priceInput =>
      '${priceCents ~/ 100}.${(priceCents % 100).toString().padLeft(2, '0')}';
}

class BarberService {
  const BarberService({
    required this.id,
    required this.details,
    required this.active,
  });

  final String id;
  final ServiceDetails details;
  final bool active;
}

abstract interface class BarberServiceRepository {
  String newServiceId();
  Future<List<BarberService>> loadOwnServices();
  Future<void> save(String id, ServiceDetails details, {required bool create});
  Future<void> setActive(String id, bool active);
}

class SaveBarberService {
  const SaveBarberService(this.repository);

  final BarberServiceRepository repository;

  Future<void> call({
    required String id,
    required bool create,
    required String name,
    required String price,
    required String duration,
  }) async {
    final normalizedName = name.trim();
    final priceCents = ServiceDetails.parsePriceCents(price);
    final minutes = int.tryParse(duration.trim(), radix: 10);
    if (priceCents == null || minutes == null) throw ServiceFailure.format;
    if (normalizedName.isEmpty ||
        normalizedName.length > ServiceDetails.maxNameLength ||
        minutes < ServiceDetails.minDuration ||
        minutes > ServiceDetails.maxDuration) {
      throw ServiceFailure.fields;
    }
    await repository.save(
      id,
      ServiceDetails(
        name: normalizedName,
        priceCents: priceCents,
        durationMinutes: minutes,
      ),
      create: create,
    );
  }
}

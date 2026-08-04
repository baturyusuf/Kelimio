final class Energy {
  const Energy({
    required this.balance,
    required this.maximum,
    required this.unlimited,
    required this.asOf,
    this.nextRegenerationAt,
  });

  final int balance;
  final int maximum;
  final bool unlimited;
  final DateTime? nextRegenerationAt;
  final DateTime asOf;
}

abstract interface class EnergyRepository {
  Future<Energy> getEnergy();
}

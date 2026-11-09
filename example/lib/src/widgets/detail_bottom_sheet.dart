part of '../../main.dart';

/// A bottom sheet listing every field of a single [HealthDataPoint].
extension _DetailBottomSheet on HealthAppState {
  /// Display bottom sheet dialog of selected HealthDataPoint
  void openDetailBottomSheet(BuildContext context, HealthDataPoint? healthPoint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) => _detailedBottomSheet(healthPoint: healthPoint),
    );
  }

  Widget _detailedBottomSheet({HealthDataPoint? healthPoint}) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (BuildContext listContext, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Health Data Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              healthPoint == null
                  ? const Text('UUID Not Found!')
                  : Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: healthPoint.toJson().entries.length,
                        itemBuilder: (context, index) {
                          String key = healthPoint.toJson().keys.elementAt(index);
                          var value = healthPoint.toJson()[key];

                          return ListTile(
                            title: Text(
                              key.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(value.toString()),
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

part of '../../main.dart';

/// Checkboxes that filter the fetched data and the step count by recording method.
extension _RecordingMethodFilters on HealthAppState {
  Widget get _dataFiltration => Column(
    children: [
      Wrap(
        children: [
          for (final method
              in Platform.isAndroid
                  ? [RecordingMethod.manual, RecordingMethod.automatic, RecordingMethod.active, RecordingMethod.unknown]
                  : [RecordingMethod.automatic, RecordingMethod.manual])
            SizedBox(
              width: 150,
              child: CheckboxListTile(
                title: Text('${method.name[0].toUpperCase()}${method.name.substring(1)} entries'),
                value: !recordingMethodsToFilter.contains(method),
                onChanged: (value) {
                  setState(() {
                    if (value!) {
                      recordingMethodsToFilter.remove(method);
                    } else {
                      recordingMethodsToFilter.add(method);
                    }
                    fetchData();
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          // Add other entries here if needed
        ],
      ),
      const Divider(thickness: 3),
    ],
  );

  Widget get _stepsFiltration => Column(
    children: [
      Wrap(
        children: [
          for (final method in [RecordingMethod.manual])
            SizedBox(
              width: 150,
              child: CheckboxListTile(
                title: Text('${method.name[0].toUpperCase()}${method.name.substring(1)} entries'),
                value: !recordingMethodsToFilter.contains(method),
                onChanged: (value) {
                  setState(() {
                    if (value!) {
                      recordingMethodsToFilter.remove(method);
                    } else {
                      recordingMethodsToFilter.add(method);
                    }
                    fetchStepData();
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          // Add other entries here if needed
        ],
      ),
      const Divider(thickness: 3),
    ],
  );
}

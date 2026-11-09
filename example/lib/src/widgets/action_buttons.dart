part of '../../main.dart';

/// The buttons that run the actions; which ones are shown depends on the platform and Health Connect's status.
extension _ActionButtons on HealthAppState {
  Widget get _actionButtons => Wrap(
    spacing: 10,
    children: [
      if (Platform.isAndroid)
        TextButton(
          onPressed: getHealthConnectSdkStatus,
          style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
          child: const Text("Check Health Connect Status", style: TextStyle(color: Colors.white)),
        ),
      if (Platform.isAndroid && health.healthConnectSdkStatus != HealthConnectSdkStatus.sdkAvailable)
        TextButton(
          onPressed: installHealthConnect,
          style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
          child: const Text("Install Health Connect", style: TextStyle(color: Colors.white)),
        ),
      if (Platform.isIOS || Platform.isAndroid && health.healthConnectSdkStatus == HealthConnectSdkStatus.sdkAvailable)
        Wrap(
          spacing: 10,
          children: [
            TextButton(
              onPressed: authorize,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Authenticate", style: TextStyle(color: Colors.white)),
            ),
            if (Platform.isAndroid)
              TextButton(
                onPressed: getSkinTemperatureFeatureStatus,
                style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                child: const Text("Check Skin Temp Feature", style: TextStyle(color: Colors.white)),
              ),
            TextButton(
              onPressed: fetchData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Fetch Data", style: TextStyle(color: Colors.white)),
            ),
            if (Platform.isAndroid)
              TextButton(
                onPressed: createChangesToken,
                style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                child: const Text("Create Changes Token", style: TextStyle(color: Colors.white)),
              ),
            if (Platform.isAndroid)
              TextButton(
                onPressed: fetchChanges,
                style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                child: const Text("Get Changes", style: TextStyle(color: Colors.white)),
              ),
            TextButton(
              onPressed: addData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Add Data", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: addSingleHealthData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Add Steps Data", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: addSingleWorkoutData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Add Running Data", style: TextStyle(color: Colors.white)),
            ),
            if (Platform.isIOS || Platform.isAndroid)
              TextButton(
                onPressed: writeWorkoutRoute,
                style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                child: const Text("Write Workout Route", style: TextStyle(color: Colors.white)),
              ),
            TextButton(
              onPressed: deleteData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Delete Data", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: fetchStepData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Fetch Step Data", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: revokeAccess,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text("Revoke Access", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: getIntervalBasedData,
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: const Text('Get Interval Data (7 days)', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
    ],
  );
}

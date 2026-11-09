part of '../../main.dart';

/// The fetched data points; tapping one opens its details.
extension _HealthDataList on HealthAppState {
  Widget get _contentDataReady => Builder(
    builder: (context) {
      return ListView.builder(
        itemCount: _healthDataList.length,
        itemBuilder: (_, index) {
          // filter out manual entires if not wanted
          if (recordingMethodsToFilter.contains(_healthDataList[index].recordingMethod)) {
            return Container();
          }

          HealthDataPoint p = _healthDataList[index];
          if (p.value is AudiogramHealthValue) {
            return ListTile(
              title: Text("${p.typeString}: ${p.value}"),
              trailing: Text(p.unitString),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}\n${p.recordingMethod}'),
              onTap: () {
                fetchDataByUUID(context, uuid: p.uuid, type: p.type);
              },
            );
          }
          if (p.value is WorkoutHealthValue) {
            return ListTile(
              title: Text(
                "${p.typeString}: ${(p.value as WorkoutHealthValue).totalEnergyBurned} ${(p.value as WorkoutHealthValue).totalEnergyBurnedUnit?.name}",
              ),
              trailing: Text((p.value as WorkoutHealthValue).workoutActivityType.name),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}\n${p.recordingMethod}'),
              onTap: () {
                fetchDataByUUID(context, uuid: p.uuid, type: p.type);
              },
            );
          }
          if (p.value is NutritionHealthValue) {
            return ListTile(
              title: Text(
                "${p.typeString} ${(p.value as NutritionHealthValue).mealType}: ${(p.value as NutritionHealthValue).name}",
              ),
              trailing: Text('${(p.value as NutritionHealthValue).calories} kcal'),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}\n${p.recordingMethod}'),
              onTap: () {
                fetchDataByUUID(context, uuid: p.uuid, type: p.type);
              },
            );
          }
          return ListTile(
            title: Text("${p.typeString}: ${p.value}"),
            trailing: Text(p.unitString),
            subtitle: Text('${p.dateFrom} - ${p.dateTo}\n${p.recordingMethod}'),
            onTap: () {
              fetchDataByUUID(context, uuid: p.uuid, type: p.type);
            },
          );
        },
      );
    },
  );
}

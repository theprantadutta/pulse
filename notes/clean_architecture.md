Following **Clean Architecture** principles in your Flutter project ensures separation of concerns, testability, and maintainability. For **Just Pulse**, here’s how you can structure your project:

---

### **File Structure for Clean Architecture**
```
lib/
│
├── core/                  # Core functionality and shared utilities
│   ├── constants/         # App-wide constants (e.g., strings, colors)
│   ├── errors/            # Custom exceptions and failure handling
│   ├── network/           # Network-related utilities (e.g., dio, connectivity)
│   ├── utils/             # Helper functions and utilities
│   └── widgets/           # Reusable widgets shared across the app
│
├── data/                  # Data layer (repositories, data sources)
│   ├── datasources/       # Data sources (local and remote)
│   │   ├── local/        # Local data sources (e.g., shared preferences, Hive)
│   │   └── remote/       # Remote data sources (e.g., APIs, network calls)
│   ├── models/           # Data models (DTOs - Data Transfer Objects)
│   └── repositories/     # Repository implementations
│
├── domain/                # Domain layer (business logic)
│   ├── entities/          # Business entities (e.g., PingResult, NetworkInfo)
│   ├── repositories/     # Repository interfaces (abstract classes)
│   └── usecases/         # Use cases (business logic for specific features)
│
├── presentation/          # Presentation layer (UI and state management)
│   ├── blocs/            # BLoCs or state management logic (if using BLoC)
│   ├── cubits/           # Cubits for simpler state management
│   ├── navigation/       # Navigation-related files (e.g., routes, app_navigation.dart)
│   ├── pages/            # Screens/pages of the app
│   │   ├── ping/         # Ping tab UI and logic
│   │   ├── network_info/ # Network info tab UI and logic
│   │   ├── diagnostics/  # Diagnostics tab UI and logic
│   │   └── tools/        # Tools tab UI and logic
│   ├── widgets/          # UI components specific to the presentation layer
│   └── theme/            # App theme and styling
│
└── main.dart              # App entry point
```

---

### **Explanation of Each Layer**

#### **1. Core Layer**
- Contains shared utilities, constants, and reusable widgets.
- **Example**:
  - `core/constants/app_strings.dart`: App-wide strings.
  - `core/utils/date_utils.dart`: Helper functions for date formatting.
  - `core/widgets/custom_button.dart`: A reusable button widget.

#### **2. Data Layer**
- Handles data retrieval and storage.
- **Example**:
  - `data/datasources/remote/ping_remote_data_source.dart`: Fetches ping results from the network.
  - `data/models/ping_result_model.dart`: Data model for ping results.
  - `data/repositories/ping_repository_impl.dart`: Implements the repository interface.

#### **3. Domain Layer**
- Contains business logic and use cases.
- **Example**:
  - `domain/entities/ping_result.dart`: Business entity for ping results.
  - `domain/repositories/ping_repository.dart`: Abstract class defining repository methods.
  - `domain/usecases/get_ping_result.dart`: Use case for fetching ping results.

#### **4. Presentation Layer**
- Handles UI and state management.
- **Example**:
  - `presentation/pages/ping/ping_page.dart`: UI for the Ping tab.
  - `presentation/blocs/ping/ping_bloc.dart`: BLoC for managing ping state.
  - `presentation/widgets/ping_result_widget.dart`: Widget to display ping results.

---

### **Example Implementation**

#### **Domain Layer**
```dart
// domain/entities/ping_result.dart
class PingResult {
  final String ip;
  final int responseTime;
  final bool isSuccess;

  PingResult({required this.ip, required this.responseTime, required this.isSuccess});
}

// domain/repositories/ping_repository.dart
abstract class PingRepository {
  Future<PingResult> ping(String ip);
}

// domain/usecases/get_ping_result.dart
class GetPingResult {
  final PingRepository repository;

  GetPingResult(this.repository);

  Future<PingResult> call(String ip) async {
    return await repository.ping(ip);
  }
}
```

#### **Data Layer**
```dart
// data/models/ping_result_model.dart
class PingResultModel {
  final String ip;
  final int responseTime;
  final bool isSuccess;

  PingResultModel({required this.ip, required this.responseTime, required this.isSuccess});

  factory PingResultModel.fromJson(Map<String, dynamic> json) {
    return PingResultModel(
      ip: json['ip'],
      responseTime: json['responseTime'],
      isSuccess: json['isSuccess'],
    );
  }
}

// data/datasources/remote/ping_remote_data_source.dart
class PingRemoteDataSource {
  Future<PingResultModel> ping(String ip) async {
    // Simulate a network call
    await Future.delayed(Duration(seconds: 1));
    return PingResultModel(ip: ip, responseTime: 50, isSuccess: true);
  }
}

// data/repositories/ping_repository_impl.dart
class PingRepositoryImpl implements PingRepository {
  final PingRemoteDataSource remoteDataSource;

  PingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<PingResult> ping(String ip) async {
    final result = await remoteDataSource.ping(ip);
    return PingResult(ip: result.ip, responseTime: result.responseTime, isSuccess: result.isSuccess);
  }
}
```

#### **Presentation Layer**
```dart
// presentation/blocs/ping/ping_bloc.dart
class PingBloc extends Bloc<PingEvent, PingState> {
  final GetPingResult getPingResult;

  PingBloc({required this.getPingResult}) : super(PingInitial());

  @override
  Stream<PingState> mapEventToState(PingEvent event) async* {
    if (event is PingRequested) {
      yield PingLoading();
      final result = await getPingResult(event.ip);
      yield PingSuccess(result);
    }
  }
}

// presentation/pages/ping/ping_page.dart
class PingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PingBloc(getPingResult: GetPingResult(PingRepositoryImpl(remoteDataSource: PingRemoteDataSource()))),
      child: Scaffold(
        appBar: AppBar(title: Text('Ping')),
        body: PingView(),
      ),
    );
  }
}
```

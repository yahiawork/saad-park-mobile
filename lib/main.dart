import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultBaseUrl = String.fromEnvironment(
  'SAADPARK_API_BASE',
  defaultValue: 'https://saadpark.pythonanywhere.com',
);

void main() {
  runApp(const SaadParkMobileApp());
}

class SaadParkMobileApp extends StatefulWidget {
  const SaadParkMobileApp({super.key});

  @override
  State<SaadParkMobileApp> createState() => _SaadParkMobileAppState();
}

class _SaadParkMobileAppState extends State<SaadParkMobileApp> {
  late final ApiClient api;
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    api = ApiClient(defaultBaseUrl);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await api.loadToken();
    setState(() {
      loggedIn = api.hasToken;
      loading = false;
    });
  }

  Future<void> _onLogin(String token) async {
    await api.saveToken(token);
    setState(() => loggedIn = true);
  }

  Future<void> _onLogout() async {
    await api.clearToken();
    setState(() => loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saad Park',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1.5,
          shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEFF6FF),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: loading
          ? const SplashScreen()
          : loggedIn
              ? HomeScreen(api: api, onLogout: _onLogout)
              : LoginScreen(api: api, onLogin: _onLogin),
    );
  }
}

class ApiClient {
  ApiClient(String baseUrl) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;
  String? token;

  bool get hasToken => token != null && token!.isNotEmpty;

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $token',
      };

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('saadpark_mobile_token');
  }

  Future<void> saveToken(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saadpark_mobile_token', value);
  }

  Future<void> clearToken() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saadpark_mobile_token');
  }

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, String>? query}) async {
    return _send(() => http.get(uri(path, query), headers: headers));
  }

  Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> data) async {
    return _send(
      () => http.post(uri(path), headers: headers, body: jsonEncode(data)),
    );
  }

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> data) async {
    return _send(
      () => http.patch(uri(path), headers: headers, body: jsonEncode(data)),
    );
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    return _send(() => http.delete(uri(path), headers: headers));
  }

  Future<Map<String, dynamic>> uploadDate(XFile image) async {
    final request =
        http.MultipartRequest('POST', uri('/api/mobile/extract-date'));
    if (hasToken) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );
    return _send(() async => http.Response.fromStream(await request.send()));
  }

  Future<Map<String, dynamic>> extractCarteGrise(
      XFile front, XFile back) async {
    final request =
        http.MultipartRequest('POST', uri('/api/mobile/carte-grise/extract'));
    if (hasToken) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'front_image',
        await front.readAsBytes(),
        filename: front.name,
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'back_image',
        await back.readAsBytes(),
        filename: back.name,
      ),
    );
    return _send(() async => http.Response.fromStream(await request.send()));
  }

  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function() request) async {
    try {
      return _decode(await request());
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Impossible de se connecter au serveur. Vérifiez l’adresse API et la connexion.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic body = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'Réponse serveur invalide (${response.statusCode}). Vérifiez que l’API Flask est bien déployée.',
        );
      }
    }
    if (response.statusCode >= 400) {
      final error = body is Map<String, dynamic> ? body['error'] : null;
      throw ApiException(error?.toString() ?? 'Erreur serveur');
    }
    if (body is Map<String, dynamic>) return body;
    return <String, dynamic>{'data': body};
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLogin});

  final ApiClient api;
  final ValueChanged<String> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'admin@saadpark.local');
  final password = TextEditingController(text: 'Admin@12345');
  bool loading = false;

  Future<void> submit() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.postJson('/api/mobile/login', {
        'email': email.text,
        'password': password.text,
      });
      widget.onLogin(response['token'].toString());
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/icon.png', width: 62, height: 62),
                      const SizedBox(height: 18),
                      Text(
                        'Connexion',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Connectez-vous avec un compte créé depuis le site web.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Mot de passe'),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Se connecter'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'La création de compte se fait uniquement sur le site web Saad Park.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Color(0xFF065F46), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Conçu par Abdurazzak Saad',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(api: widget.api),
      VehiclesPage(api: widget.api),
      DeadlinesPage(api: widget.api),
      ScannerPage(api: widget.api),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/icon.png', width: 34, height: 34),
            const SizedBox(width: 10),
            const Text('Saad Park'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: pages[index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.directions_car_outlined), label: 'Véhicules'),
          NavigationDestination(
              icon: Icon(Icons.event_busy_outlined), label: 'Échéances'),
          NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined), label: 'Scanner'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      data = await widget.api.getJson('/api/mobile/dashboard');
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final stats = (data?['stats'] ?? {}) as Map<String, dynamic>;
    final recent = listOfMaps(data?['recent_vehicles']);

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatTile(label: 'Véhicules', value: stats['vehicles']),
              StatTile(label: 'Valides', value: stats['valid_documents']),
              StatTile(label: 'Bientôt', value: stats['soon_documents']),
              StatTile(label: 'Expirés', value: stats['expired_documents']),
            ],
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Véhicules récents',
            child: Column(
              children: recent.isEmpty
                  ? [const EmptyText('Aucun véhicule.')]
                  : recent
                      .map((vehicle) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                Text(vehicle['matricule']?.toString() ?? '-'),
                            subtitle: Text(
                                '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'
                                    .trim()),
                          ))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> vehicles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.getJson(
        '/api/mobile/vehicles',
        query: search.text.trim().isEmpty ? null : {'q': search.text.trim()},
      );
      vehicles = listOfMaps(response['vehicles']);
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addVehicle() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VehicleFormPage(api: widget.api)),
    );
    if (saved == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: search,
              onSubmitted: (_) => refresh(),
              decoration: InputDecoration(
                labelText: 'Rechercher par matricule',
                suffixIcon: IconButton(
                    onPressed: refresh, icon: const Icon(Icons.search)),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: vehicles.isEmpty ? 1 : vehicles.length,
                      itemBuilder: (context, i) {
                        if (vehicles.isEmpty) {
                          return const EmptyText('Aucun véhicule trouvé.');
                        }
                        final vehicle = vehicles[i];
                        return Card(
                          child: ListTile(
                            title:
                                Text(vehicle['matricule']?.toString() ?? '-'),
                            subtitle: Text(
                                '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'
                                    .trim()),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VehicleDetailPage(
                                      api: widget.api,
                                      vehicleId: vehicle['id'] as int),
                                ),
                              );
                              refresh();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage(
      {super.key, required this.api, required this.vehicleId});
  final ApiClient api;
  final int vehicleId;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  Map<String, dynamic>? vehicle;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final response =
          await widget.api.getJson('/api/mobile/vehicles/${widget.vehicleId}');
      vehicle = response['vehicle'] as Map<String, dynamic>;
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addDocument() async {
    final saved =
        await showDocumentSheet(context, widget.api, widget.vehicleId);
    if (saved == true) refresh();
  }

  Future<void> deleteVehicle() async {
    await widget.api.deleteJson('/api/mobile/vehicles/${widget.vehicleId}');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle?['matricule']?.toString() ?? 'Véhicule'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await deleteVehicle();
              } on ApiException catch (error) {
                if (context.mounted) {
                  showMessage(context, error.message);
                }
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addDocument,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Document'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                SectionCard(
                  title: 'Informations',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoLine('Matricule', vehicle?['matricule']),
                      InfoLine('Marque', vehicle?['brand']),
                      InfoLine('Modèle', vehicle?['model']),
                      InfoLine('N° Châssis', vehicle?['chassis_number']),
                      InfoLine('Propriétaire', vehicle?['owner_name']),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Documents',
                  child: Column(
                    children: listOfMaps(vehicle?['documents']).isEmpty
                        ? [const EmptyText('Aucun document.')]
                        : listOfMaps(vehicle?['documents'])
                            .map((doc) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(doc['type']?.toString() ?? '-'),
                                  subtitle: Text(
                                      'Expiration: ${doc['expiry_date_fr'] ?? '-'}'),
                                  trailing: StatusChip(
                                      status: doc['status']
                                          as Map<String, dynamic>?),
                                ))
                            .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class VehicleFormPage extends StatefulWidget {
  const VehicleFormPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final controllers = <String, TextEditingController>{
    'matricule': TextEditingController(),
    'old_matricule': TextEditingController(),
    'brand': TextEditingController(),
    'model': TextEditingController(),
    'chassis_number': TextEditingController(),
    'first_use_date': TextEditingController(),
    'owner_name': TextEditingController(),
    'fuel_type': TextEditingController(),
    'fiscal_power': TextEditingController(),
    'genre': TextEditingController(),
  };
  bool saving = false;

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.api.postJson('/api/mobile/vehicles', {
        for (final entry in controllers.entries) entry.key: entry.value.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau véhicule')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in vehicleFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[item.key],
                decoration: InputDecoration(labelText: item.label),
              ),
            ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class DeadlinesPage extends StatefulWidget {
  const DeadlinesPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<DeadlinesPage> createState() => _DeadlinesPageState();
}

class _DeadlinesPageState extends State<DeadlinesPage> {
  List<Map<String, dynamic>> documents = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.getJson('/api/mobile/deadlines');
      documents = listOfMaps(response['documents']);
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: documents.isEmpty ? 1 : documents.length,
        itemBuilder: (context, i) {
          if (documents.isEmpty) {
            return const EmptyText('Aucune échéance critique.');
          }
          final doc = documents[i];
          return Card(
            child: ListTile(
              title: Text(
                  '${doc['vehicle_matricule'] ?? '-'} - ${doc['type'] ?? '-'}'),
              subtitle: Text('Expiration: ${doc['expiry_date_fr'] ?? '-'}'),
              trailing:
                  StatusChip(status: doc['status'] as Map<String, dynamic>?),
            ),
          );
        },
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final picker = ImagePicker();
  XFile? front;
  XFile? back;
  Map<String, dynamic>? dateResult;
  Map<String, dynamic>? carteGriseResult;
  bool loading = false;

  Future<void> pickDateImage() async {
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    setState(() => loading = true);
    try {
      dateResult = await widget.api.uploadDate(image);
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> extractCarteGrise() async {
    if (front == null || back == null) {
      showMessage(context, 'Choisissez les images recto et verso.');
      return;
    }
    setState(() => loading = true);
    try {
      carteGriseResult = await widget.api.extractCarteGrise(front!, back!);
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveCarteGrise() async {
    if (carteGriseResult == null) return;
    setState(() => loading = true);
    try {
      await widget.api
          .postJson('/api/mobile/carte-grise/save', carteGriseResult!);
      if (mounted) {
        showMessage(context, 'Véhicule et Carte Grise enregistrés.');
        setState(() {
          front = null;
          back = null;
          carteGriseResult = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (loading) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Scanner date',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: loading ? null : pickDateImage,
                icon: const Icon(Icons.image_search_outlined),
                label: const Text('Choisir image date'),
              ),
              if (dateResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                      'Date: ${dateResult!['raw_date']} → ${dateResult!['normalized_date']}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Carte Grise recto / verso',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        front = await picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 85);
                        setState(() {});
                      },
                icon: const Icon(Icons.credit_card),
                label:
                    Text(front == null ? 'Choisir recto' : 'Recto sélectionné'),
              ),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        back = await picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 85);
                        setState(() {});
                      },
                icon: const Icon(Icons.credit_card),
                label:
                    Text(back == null ? 'Choisir verso' : 'Verso sélectionné'),
              ),
              FilledButton(
                onPressed: loading ? null : extractCarteGrise,
                child: const Text('Extraire données'),
              ),
              if (carteGriseResult != null) ...[
                const Divider(height: 24),
                Text(
                    'Matricule: ${carteGriseResult!['vehicle']?['matricule'] ?? '-'}'),
                Text(
                    'Marque: ${carteGriseResult!['vehicle']?['brand'] ?? '-'}'),
                Text(
                    'Modèle: ${carteGriseResult!['vehicle']?['model'] ?? '-'}'),
                Text(
                    'Châssis: ${carteGriseResult!['vehicle']?['chassis_number'] ?? '-'}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: loading ? null : saveCarteGrise,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer dans le backend'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});
  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Text(
                '${value ?? 0}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final Map<String, dynamic>? status;

  @override
  Widget build(BuildContext context) {
    final key = status?['key']?.toString() ?? 'missing';
    final label = status?['label']?.toString() ?? '-';
    final color = switch (key) {
      'valid' => const Color(0xFF16A34A),
      'expired' => const Color(0xFFDC2626),
      'today' || 'soon' => const Color(0xFFD97706),
      _ => const Color(0xFF6B7280),
    };
    return Chip(
      label: Text(label),
      labelStyle:
          TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide.none,
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.value, {super.key});
  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child:
                Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          Expanded(
              child: Text(value?.toString().isNotEmpty == true
                  ? value.toString()
                  : '-')),
        ],
      ),
    );
  }
}

class EmptyText extends StatelessWidget {
  const EmptyText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
      ),
    );
  }
}

class FieldInfo {
  const FieldInfo(this.key, this.label);
  final String key;
  final String label;
}

const vehicleFields = [
  FieldInfo('matricule', 'Matricule'),
  FieldInfo('old_matricule', 'Ancien matricule'),
  FieldInfo('brand', 'Marque'),
  FieldInfo('model', 'Modèle'),
  FieldInfo('chassis_number', 'N° Châssis'),
  FieldInfo('first_use_date', 'Date première circulation'),
  FieldInfo('owner_name', 'Propriétaire'),
  FieldInfo('fuel_type', 'Carburant'),
  FieldInfo('fiscal_power', 'Puissance fiscale'),
  FieldInfo('genre', 'Genre'),
];

const documentTypes = [
  'Carte Grise',
  'Assurance',
  'Visite Technique',
  'Taxe',
  'Autorisation',
  'Contrat',
  'Autre',
];

Future<bool?> showDocumentSheet(
    BuildContext context, ApiClient api, int vehicleId) {
  final number = TextEditingController();
  final issueDate = TextEditingController();
  final expiryDate = TextEditingController();
  final notes = TextEditingController();
  var type = documentTypes.first;
  var saving = false;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            setModalState(() => saving = true);
            try {
              await api.postJson('/api/mobile/vehicles/$vehicleId/documents', {
                'type': type,
                'document_number': number.text,
                'issue_date': issueDate.text,
                'expiry_date': expiryDate.text,
                'notes': notes.text,
              });
              if (context.mounted) Navigator.of(context).pop(true);
            } on ApiException catch (error) {
              if (context.mounted) {
                showMessage(context, error.message);
              }
            } finally {
              if (context.mounted) {
                setModalState(() => saving = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration:
                        const InputDecoration(labelText: 'Type document'),
                    items: documentTypes
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: number,
                      decoration:
                          const InputDecoration(labelText: 'N° document')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: issueDate,
                      decoration:
                          const InputDecoration(labelText: 'Date émission')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: expiryDate,
                      decoration:
                          const InputDecoration(labelText: 'Date expiration')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes')),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

List<Map<String, dynamic>> listOfMaps(Object? value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

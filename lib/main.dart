import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_patcher runtime and crash-protection rollback
  try {
    await FlutterPatcher.init();
    debugPrint('[FlutterPatcher] Initialized successfully');
  } catch (e) {
    debugPrint('[FlutterPatcher] Initialization error (safe fallback to baseline): $e');
  }

  runApp(const FlutterRemoteDevApp());
}

class FlutterRemoteDevApp extends StatelessWidget {
  const FlutterRemoteDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Remote Dev OTA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Default URL of the Cloudflare Worker streaming GitHub's /lastpatch
  final TextEditingController _urlController = TextEditingController(
    text: 'https://flutter-remote-dev-patch-worker.mobin-devx.workers.dev',
  );

  bool _isChecking = false;
  String _statusMessage = 'Idle. Ready to check for remote patches.';
  final List<String> _logs = [];

  // Edit this block in Dart to verify OTA patches work instantly!
  // =============================================================
  static const String dartCodeVersion = "1.0.0-h1 (OTA Hotfix Live! 🎉)";
  static const String hotfixMessage = "Hotfix delivered dynamically from Cloudflare Worker without native compile!";
  static const Color themeAccentColor = Colors.teal;
  // =============================================================

  @override
  void initState() {
    super.initState();
    _addLog("App started. FlutterPatcher active.");
    _addLog("Dart Code Version: $dartCodeVersion");
  }

  void _addLog(String log) {
    setState(() {
      _logs.add("[${DateTime.now().toIso8601String().substring(11, 19)}] $log");
      _statusMessage = log;
    });
  }

  Future<void> _checkForUpdates() async {
    final baseUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (baseUrl.isEmpty) {
      _addLog("Error: Worker URL cannot be empty.");
      return;
    }

    setState(() => _isChecking = true);
    _addLog("Connecting to Cloudflare Worker at: $baseUrl");

    try {
      final manifestUri = Uri.parse('$baseUrl/manifest.json');
      _addLog("Fetching manifest: $manifestUri");

      final response = await http.get(manifestUri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        _addLog("Failed to fetch manifest (HTTP ${response.statusCode})");
        return;
      }

      final Map<String, dynamic> manifest = jsonDecode(response.body);
      _addLog("Manifest received: ${jsonEncode(manifest)}");

      final bool hasUpdate = manifest['has_update'] == true;
      final String? version = manifest['version']?.toString();
      String? patchUrl = manifest['patch_url']?.toString();
      final String? expectedMd5 = manifest['md5']?.toString();
      final int targetVersionCode = (manifest['target_version_code'] as num?)?.toInt() ?? 1;

      if (!hasUpdate || patchUrl == null || version == null) {
        _addLog("No new patch available. App is already up-to-date!");
        return;
      }

      // If patchUrl is relative (e.g. /patch.zip), resolve with baseUrl
      if (patchUrl.startsWith('/')) {
        patchUrl = '$baseUrl$patchUrl';
      } else if (!patchUrl.startsWith('http://') && !patchUrl.startsWith('https://')) {
        patchUrl = '$baseUrl/$patchUrl';
      }

      _addLog("New patch discovered: Version $version");
      _addLog("Patch download URL: $patchUrl");
      _addLog("Target Version Code: $targetVersionCode");

      // Download patch file
      _addLog("Streaming patch payload from Worker...");
      final patchUri = Uri.parse(patchUrl);
      final patchResponse = await http.get(patchUri).timeout(
        const Duration(seconds: 45),
      );

      if (patchResponse.statusCode != 200) {
        _addLog("Error downloading patch file (HTTP ${patchResponse.statusCode})");
        return;
      }

      final patchBytes = patchResponse.bodyBytes;
      _addLog("Downloaded ${patchBytes.length} bytes successfully.");

      // Verify MD5 checksum if provided
      if (expectedMd5 != null && expectedMd5.isNotEmpty) {
        final computedMd5 = md5.convert(patchBytes).toString().toLowerCase();
        _addLog("Verifying MD5: computed=$computedMd5 vs expected=$expectedMd5");
        if (computedMd5 != expectedMd5.toLowerCase()) {
          _addLog("MD5 Checksum mismatch! Patch corrupted or untrusted. Aborting.");
          return;
        }
        _addLog("MD5 verification passed!");
      }

      // Build PatchInfo object for FlutterPatcher
      final patchInfo = PatchInfo(
        version: version,
        patchUrl: patchUrl,
        md5: expectedMd5 ?? '',
        targetVersionCode: targetVersionCode,
      );

      _addLog("Applying patch via FlutterPatcher...");
      final result = await FlutterPatcher.applyPatch(patchInfo);
      _addLog("Patch apply result: $result");
      _addLog("SUCCESS! 🎉 Hotfix applied to device storage.");
      _addLog("Please close the app from Android Recents and re-open to load the new Dart code!");

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Patch Applied! 🎉"),
            content: Text(
              "Patch $version has been successfully installed.\n\n"
              "Please close the app from your Recent Apps switcher and open it again to boot into the updated version.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      _addLog("Exception during patch update: $e");
      debugPrint("Stack: $stack");
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Remote Dev OTA'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code version card (Demonstrates OTA updates visually)
            Card(
              elevation: 3,
              color: themeAccentColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: themeAccentColor, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.bolt, size: 40, color: themeAccentColor),
                    const SizedBox(height: 8),
                    Text(
                      dartCodeVersion,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hotfixMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Worker URL configuration
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cloudflare Worker OTA Endpoint',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This endpoint streams /lastpatch directly from your GitHub repo.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Worker Base URL',
                        hintText: 'https://your-worker.workers.dev',
                        prefixIcon: Icon(Icons.cloud_sync),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkForUpdates,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt),
                      label: Text(_isChecking ? 'Checking...' : 'Check & Apply Patch'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Logs / Status window
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'OTA Execution Logs',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Clear Logs',
                          onPressed: () {
                            setState(() => _logs.clear());
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latest status: $_statusMessage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(),
                    Container(
                      height: 220,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs recorded yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, idx) {
                                return SelectableText(
                                  _logs[idx],
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

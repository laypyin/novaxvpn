import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const NovaXVpnApp());
}

class NovaXVpnApp extends StatelessWidget {
  const NovaXVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NovaX VPN',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
      ),
      home: const VPNHomeScreen(),
    );
  }
}

class ServerNode {
  final String remark;
  final String uri;
  final String protocol;

  ServerNode({required this.remark, required this.uri, required this.protocol});
}

class VPNHomeScreen extends StatefulWidget {
  const VPNHomeScreen({super.key});

  @override
  State<VPNHomeScreen> createState() => _VPNHomeScreenState();
}

class _VPNHomeScreenState extends State<VPNHomeScreen> {
  late final FlutterV2ray flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      setState(() {
        v2rayStatus = status;
      });
    },
  );

  V2RayStatus v2rayStatus = V2RayStatus();

  List<ServerNode> serverList = [];
  int selectedServerIndex = 0;
  String savedSubLink = "";
  
  double usedGb = 0.0;
  double totalGb = 0.0;
  String dataTrafficInfo = "Unlimited Data";
  double dataProgress = 0.0;

  int currentPing = -1;
  bool isLoading = false;

  // Luxury Black & Gold Theme Colors
  static const Color bgDark = Color(0xFF0A0A0C);
  static const Color cardDark = Color(0xFF141418);
  static const Color innerCardDark = Color(0xFF1C1C22);
  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFDF73);
  static const Color greenActive = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    flutterV2ray.initializeV2Ray();
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final sub = prefs.getString('saved_sub') ?? '';
    if (sub.isNotEmpty) {
      setState(() {
        savedSubLink = sub;
      });
      await processSubscription(sub, showMessage: false);
    }
  }

  // One-Tap Paste Subscription Function
  Future<void> pasteAndImportSub() async {
    final clipData = await Clipboard.getData('text/plain');
    final text = clipData?.text?.trim() ?? '';

    if (text.isEmpty) {
      showSnack("Clipboard ထဲတွင် Copy ကူးထားသော Link မရှိပါ။", isError: true);
      return;
    }

    await processSubscription(text, showMessage: true);
  }

  // Marzban Subscription Link ဖတ်ရှုခြင်း
  Future<void> processSubscription(String input, {bool showMessage = true}) async {
    input = input.trim();
    if (input.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      List<ServerNode> parsedServers = [];
      double uGb = 0.0;
      double tGb = 0.0;
      String trafficStr = "Unlimited Plan";
      double progress = 0.0;

      if (input.startsWith("http://") || input.startsWith("https://")) {
        final response = await http.get(Uri.parse(input)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          String? userInfo = response.headers['subscription-userinfo'];
          if (userInfo != null) {
            final parts = userInfo.split(';');
            int upload = 0, download = 0, total = 0;
            for (var p in parts) {
              final kv = p.trim().split('=');
              if (kv.length == 2) {
                if (kv[0] == 'upload') upload = int.tryParse(kv[1]) ?? 0;
                if (kv[0] == 'download') download = int.tryParse(kv[1]) ?? 0;
                if (kv[0] == 'total') total = int.tryParse(kv[1]) ?? 0;
              }
            }
            uGb = (upload + download) / (1024 * 1024 * 1024);
            if (total > 0) {
              tGb = total / (1024 * 1024 * 1024);
              trafficStr = "${uGb.toStringAsFixed(2)} GB / ${tGb.toStringAsFixed(1)} GB";
              progress = (uGb / tGb).clamp(0.0, 1.0);
            } else {
              trafficStr = "Used: ${uGb.toStringAsFixed(2)} GB (Unlimited)";
              progress = 0.2;
            }
          }

          String body = response.body.trim();
          String decodedBody = body;
          if (!body.contains("://")) {
            try {
              String normalized = base64.normalize(body.replaceAll('\n', '').replaceAll('\r', ''));
              decodedBody = utf8.decode(base64.decode(normalized));
            } catch (_) {}
          }

          final lines = decodedBody.split(RegExp(r'[\r\n]+'));
          for (var line in lines) {
            line = line.trim();
            if (line.startsWith("vless://") ||
                line.startsWith("vmess://") ||
                line.startsWith("trojan://") ||
                line.startsWith("ss://")) {
              final node = parseSingleUri(line);
              if (node != null) parsedServers.add(node);
            }
          }
        } else {
          throw Exception("Subscription link ချိတ်ဆက်မရပါ (HTTP ${response.statusCode})");
        }
      } else {
        final lines = input.split(RegExp(r'[\r\n]+'));
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty) {
            final node = parseSingleUri(line);
            if (node != null) parsedServers.add(node);
          }
        }
      }

      if (parsedServers.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_sub', input);

        setState(() {
          savedSubLink = input;
          serverList = parsedServers;
          selectedServerIndex = 0;
          usedGb = uGb;
          totalGb = tGb;
          dataTrafficInfo = trafficStr;
          dataProgress = progress;
        });

        checkServerPing();

        if (showMessage) {
          showSnack("Server (${parsedServers.length}) ခု အောင်မြင်စွာ ထည့်သွင်းပြီးပါပြီ။");
        }
      } else {
        throw Exception("အကျုံးဝင်သော Subscription Link မဟုတ်ပါ။");
      }
    } catch (e) {
      if (showMessage) {
        showSnack("မှားယွင်းနေပါသည် - Subscription Link ကို ပြန်စစ်ပေးပါ။", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  ServerNode? parseSingleUri(String uri) {
    try {
      final parsed = FlutterV2ray.parseFromURL(uri);
      String proto = uri.split("://").first.toUpperCase();
      String remark = parsed.remark.isNotEmpty ? parsed.remark : "NovaX $proto Server";
      return ServerNode(remark: remark, uri: uri, protocol: proto);
    } catch (e) {
      return null;
    }
  }

  Future<void> checkServerPing() async {
    if (serverList.isEmpty) return;
    setState(() {
      currentPing = -1;
    });
    try {
      final parsed = FlutterV2ray.parseFromURL(serverList[selectedServerIndex].uri);
      final delay = await flutterV2ray.getServerDelay(config: parsed.getFullConfiguration());
      if (mounted) {
        setState(() {
          currentPing = delay;
        });
      }
    } catch (_) {}
  }

  void toggleConnection() async {
    if (v2rayStatus.state == "CONNECTED") {
      flutterV2ray.stopV2Ray();
    } else {
      if (serverList.isEmpty) {
        showSnack("ကျေးဇူးပြု၍ 'Paste Plan' ကိုနှိပ်ပြီး Link အရင်ထည့်ပါ။", isError: true);
        return;
      }
      if (await flutterV2ray.requestPermission()) {
        final currentServer = serverList[selectedServerIndex];
        final parsedConfig = FlutterV2ray.parseFromURL(currentServer.uri);
        flutterV2ray.startV2Ray(
          remark: currentServer.remark,
          config: parsedConfig.getFullConfiguration(),
        );
      }
    }
  }

  Future<void> openTelegramBot() async {
    final Uri url = Uri.parse("https://t.me/NovaxAppBot");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      showSnack("Telegram Bot ဖွင့်၍မရပါ။", isError: true);
    }
  }

  void showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showManualInputDialog() {
    final controller = TextEditingController(text: savedSubLink);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: goldPrimary, width: 1),
        ),
        title: const Text("Subscription Link", style: TextStyle(color: goldLight, fontSize: 18)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: "https://...",
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: innerCardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: goldPrimary),
            onPressed: () {
              Navigator.pop(context);
              processSubscription(controller.text);
            },
            child: const Text("IMPORT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void showServerSelector() {
    if (serverList.isEmpty) {
      pasteAndImportSub();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Select NovaX Server",
                style: TextStyle(color: goldLight, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: serverList.length,
                itemBuilder: (context, index) {
                  final node = serverList[index];
                  final isSelected = index == selectedServerIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? goldPrimary : innerCardDark,
                      child: Icon(Icons.public, color: isSelected ? Colors.black : goldLight),
                    ),
                    title: Text(
                      node.remark,
                      style: TextStyle(
                        color: isSelected ? goldLight : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text("Protocol: ${node.protocol}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: goldPrimary) : null,
                    onTap: () {
                      setState(() {
                        selectedServerIndex = index;
                      });
                      Navigator.pop(context);
                      checkServerPing();
                      if (v2rayStatus.state == "CONNECTED") {
                        flutterV2ray.stopV2Ray();
                        Future.delayed(const Duration(milliseconds: 500), () => toggleConnection());
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = v2rayStatus.state == "CONNECTED";

    final currentServerName = serverList.isNotEmpty
        ? serverList[selectedServerIndex].remark
        : "No Plan Active (Paste Plan နှိပ်ပါ)";

    final currentProtocol = serverList.isNotEmpty
        ? serverList[selectedServerIndex].protocol
        : "VLESS / V2RAY";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: goldPrimary, size: 30),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "NovaX",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21, letterSpacing: 0.8),
            ),
            const Text(
              " VPN",
              style: TextStyle(color: goldPrimary, fontWeight: FontWeight.bold, fontSize: 21, letterSpacing: 0.8),
            ),
          ],
        ),
        actions: [
          // One-Tap Paste Plan ခလုတ်
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: pasteAndImportSub,
              style: ElevatedButton.styleFrom(
                backgroundColor: goldPrimary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.content_paste, size: 16),
              label: const Text("Paste Plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: cardDark,
            onSelected: (value) {
              if (value == 'manual') showManualInputDialog();
              if (value == 'clear') {
                SharedPreferences.getInstance().then((p) => p.remove('saved_sub'));
                setState(() {
                  savedSubLink = "";
                  serverList.clear();
                  dataTrafficInfo = "Unlimited Data";
                  dataProgress = 0.0;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'manual', child: Text("Manual Link Input")),
              const PopupMenuItem(value: 'clear', child: Text("Clear Saved Plan")),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: goldPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
              child: Column(
                children: [
                  // ၁။ အပေါ်ပိုင်း Status & Speed Cards (Layout အသစ်)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isConnected ? greenActive.withOpacity(0.5) : goldPrimary.withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isConnected ? greenActive : Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isConnected ? "CONNECTED" : "DISCONNECTED",
                                  style: TextStyle(
                                    color: isConnected ? greenActive : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              v2rayStatus.duration,
                              style: const TextStyle(
                                color: goldLight,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: innerCardDark,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_downward_rounded, color: greenActive, size: 22),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("DOWNLOAD", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                        Text(
                                          "${v2rayStatus.downloadSpeed} B/s",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: innerCardDark,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_upward_rounded, color: goldLight, size: 22),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("UPLOAD", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                        Text(
                                          "${v2rayStatus.uploadSpeed} B/s",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ၂။ အလယ်ပိုင်း Golden Shield Power ခလုတ်ကြီး
                  GestureDetector(
                    onTap: toggleConnection,
                    child: Container(
                      width: 175,
                      height: 175,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isConnected
                              ? [greenActive.withOpacity(0.25), cardDark]
                              : [goldPrimary.withOpacity(0.22), cardDark],
                        ),
                        border: Border.all(
                          color: isConnected ? greenActive : goldPrimary,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isConnected ? greenActive.withOpacity(0.35) : goldPrimary.withOpacity(0.25),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isConnected ? Icons.gpp_good_rounded : Icons.power_settings_new_rounded,
                            size: 68,
                            color: isConnected ? greenActive : goldLight,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isConnected ? "TAP TO STOP" : "TAP TO START",
                            style: TextStyle(
                              color: isConnected ? greenActive : goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ၃။ Server ရွေးချယ်သည့် ကဒ်
                  GestureDetector(
                    onTap: showServerSelector,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: goldPrimary.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: innerCardDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.public, color: goldPrimary, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: goldPrimary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        currentProtocol,
                                        style: const TextStyle(color: goldLight, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      currentPing > 0 ? "$currentPing ms" : "High Speed",
                                      style: const TextStyle(color: greenActive, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentServerName,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_right_rounded, color: goldLight, size: 28),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ၄။ Data Usage Bar နှင့် Telegram Bot ခလုတ်များ (Time Remaining အစားထိုးထားသည့်အပိုင်း)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.data_usage_rounded, color: goldPrimary, size: 18),
                                SizedBox(width: 6),
                                Text("DATA USAGE", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                              dataTrafficInfo,
                              style: const TextStyle(color: goldLight, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: dataProgress,
                            minHeight: 7,
                            backgroundColor: innerCardDark,
                            valueColor: const AlwaysStoppedAnimation<Color>(goldPrimary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (savedSubLink.isNotEmpty) {
                                    processSubscription(savedSubLink);
                                  } else {
                                    pasteAndImportSub();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: goldPrimary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.sync_rounded, color: goldLight, size: 18),
                                label: const Text("Update Sub", style: TextStyle(color: goldLight, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: openTelegramBot,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0088CC),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.telegram, size: 18),
                                label: const Text("Buy / Bot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

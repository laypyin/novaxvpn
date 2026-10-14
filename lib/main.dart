import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PNT VPN',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0A1A),
      ),
      home: const VPNHomeScreen(),
    );
  }
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
  
  // စမ်းသပ်ရန် သင့်ရဲ့ Marzban Vless Link တစ်ခုကို ဒီမှာ ထည့်ထားနိုင်ပါတယ်
  String vlessLink = "vless://your-uuid@your-server-ip:443?security=reality&sni=www.google.com&fp=chrome&pbk=your-public-key&type=tcp&headerType=none#Thailand-23";

  @override
  void initState() {
    super.initState();
    flutterV2ray.initializeV2Ray();
  }

  void toggleConnection() async {
    if (v2rayStatus.state == "CONNECTED") {
      flutterV2ray.stopV2Ray();
    } else {
      if (await flutterV2ray.requestPermission()) {
        final parsedConfig = FlutterV2ray.parseFromURL(vlessLink);
        flutterV2ray.startV2Ray(
          remark: parsedConfig.remark,
          config: parsedConfig.getFullConfiguration(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = v2rayStatus.state == "CONNECTED";
    
    const cardColor = Color(0xFF151925);
    const innerCardColor = Color(0xFF1D2230);
    const redDisconnect = Color(0xFFE53935);
    const greenConnect = Color(0xFF43A047);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        title: const Text(
          "PNT VPN",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            
            // ၁။ အလယ်က Power ခလုတ်ကြီး
            GestureDetector(
              onTap: toggleConnection,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF161B2E),
                  border: Border.all(color: const Color(0xFF1F3A60), width: 6),
                ),
                child: Icon(
                  Icons.power_settings_new,
                  size: 64,
                  color: isConnected ? greenConnect : redDisconnect,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ၂။ Status (Disconnected / Connected)
            Text(
              isConnected ? "Connected" : "Disconnected",
              style: TextStyle(
                color: isConnected ? greenConnect : redDisconnect,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ၃။ Upload / Timer / Download ပြသသည့်အပိုင်း
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Icon(Icons.cloud_upload, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    Text("${v2rayStatus.uploadSpeed} B", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(width: 32),
                Text(
                  v2rayStatus.duration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 32),
                Column(
                  children: [
                    const Icon(Icons.cloud_download, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    Text("${v2rayStatus.downloadSpeed} B", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // ၄။ အောက်ဘက်ရှိ Main Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262C3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Header
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Location", style: TextStyle(color: Colors.white70, fontSize: 15)),
                      Text("Config Version: 22", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Location Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerCardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blueAccent,
                          child: Text("🇹🇭", style: TextStyle(fontSize: 20)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Thailand - 23", style: TextStyle(color: Colors.white, fontSize: 16)),
                              Text("Ping: 80 ms", style: TextStyle(color: greenConnect, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, color: Color(0xFF42A5F5)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text("Protocol", style: TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 8),
                  
                  // Protocol Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerCardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.shield, color: Colors.blueAccent),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("V2Ray", style: TextStyle(color: Colors.white, fontSize: 16)),
                              Text("Good for Game🎮", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, color: Color(0xFF42A5F5)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text("Time Remaining", style: TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 8),
                  
                  // Time Remaining Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerCardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timer, color: Color(0xFF42A5F5), size: 32),
                            SizedBox(width: 10),
                            Text(
                              "0d:0h:59m:42s",
                              style: TextStyle(
                                color: Color(0xFFFFA726),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () {
                            // Telegram Bot သို့ ညွှန်းရန် သို့မဟုတ် Subscription ထည့်ရန်
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF26415E)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("ADD TIME", style: TextStyle(color: Color(0xFF29B6F6), fontSize: 12)),
                        ),
                      ],
                    ),
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

// ----------------------------------------------------------
// SOLAR MEDIC — FINAL ICON VERSION (NO NETWORK IMAGES)
// ----------------------------------------------------------

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ----------------------------------------------------------
// CONFIG
// ----------------------------------------------------------
const String API_KEY = ""; // <-- ADD GEMINI KEY HERE

const Color bgTop = Color(0xFF4A1F8E);
const Color bgBottom = Color(0xFF1A0A3A);

// ----------------------------------------------------------
void main() => runApp(const SolarMedicApp());

class SolarMedicApp extends StatelessWidget {
  const SolarMedicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Medic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
        useMaterial3: true,
      ),
      home: const SolarMedicScreen(),
    );
  }
}

// ----------------------------------------------------------
// MAIN SCREEN
// ----------------------------------------------------------
class SolarMedicScreen extends StatefulWidget {
  const SolarMedicScreen({super.key});
  @override
  State<SolarMedicScreen> createState() => _SolarMedicScreenState();
}

class _SolarMedicScreenState extends State<SolarMedicScreen> {
  // Location
  String locationText = "Locating...";
  double lat = 18.52;
  double lon = 73.85;

  // Data
  double currentUV = 0;
  double currentTemp = 0;
  String currentTithi = "--";
  String currentNakshatra = "--";

  // AI UI
  final TextEditingController _condition = TextEditingController();
  String aiResponse = "";
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ----------------------------------------------------------
  // TOAST
  // ----------------------------------------------------------
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ----------------------------------------------------------
  // LOCATION
  // ----------------------------------------------------------
  Future<void> _initLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      locationText = "GPS Disabled";
      _fetchData();
      return;
    }

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }

    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      locationText = "GPS Denied";
      _fetchData();
      return;
    }

    Position pos = await Geolocator.getCurrentPosition();
    setState(() {
      lat = pos.latitude;
      lon = pos.longitude;
      locationText =
          "Lat ${lat.toStringAsFixed(2)}, Lon ${lon.toStringAsFixed(2)}";
    });

    _fetchData();
  }

  // ----------------------------------------------------------
  // WEATHER + PANCHANG
  // ----------------------------------------------------------
  Future<void> _fetchData() async {
    // Panchang
    final p = PanchangCalculator.calculate(DateTime.now());
    setState(() {
      currentTithi = p["tithi"]!;
      currentNakshatra = p["nakshatra"]!;
    });

    // Weather
    try {
      final url = Uri.parse(
          "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=uv_index,temperature_2m&timezone=auto");

      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() {
          currentUV = data["current"]["uv_index"];
          currentTemp = data["current"]["temperature_2m"];
        });
      }
    } catch (_) {}
  }

  // ----------------------------------------------------------
  // GEMINI AI
  // ----------------------------------------------------------
  Future<void> _getAdvice(String mode) async {
    if (_condition.text.trim().isEmpty) {
      _toast("Describe your condition first.");
      return;
    }
    if (API_KEY.isEmpty) {
      _toast("Add Gemini API Key.");
      return;
    }

    setState(() => isAnalyzing = true);

    String prompt = mode == "quick"
        ? """
Act as a heliotherapist.
Condition: "${_condition.text}"
UV: $currentUV, Temp: $currentTemp, Tithi: $currentTithi, Nakshatra: $currentNakshatra.
Give short advice:
1. Is sunlight safe right now?
2. Tithi effect
3. Precautions
"""
        : """
Act as an Ayurvedic Doctor.
Condition: "${_condition.text}"
Give a daily routine using Tithi $currentTithi and Nakshatra $currentNakshatra.
Include sun exposure + diet + restrictions.
""";

    try {
      final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$API_KEY");

      final r = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        aiResponse = data["candidates"][0]["content"]["parts"][0]["text"];
      } else {
        aiResponse = "AI Error.";
      }
    } catch (e) {
      aiResponse = "Connection Error: $e";
    }

    setState(() => isAnalyzing = false);
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [bgTop, bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),

              _header(),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _card(
                        title: "UV Index",
                        subtitle:
                            "$currentUV • ${_uvDesc(currentUV)}",
                        icon: LucideIcons.sun),

                    _card(
                        title: "Temperature",
                        subtitle: "$currentTemp°C • Ambient",
                        icon: LucideIcons.thermometer),

                    _card(
                        title: "Tithi",
                        subtitle: currentTithi,
                        icon: LucideIcons.moon),

                    _card(
                        title: "Nakshatra",
                        subtitle: currentNakshatra,
                        icon: LucideIcons.star),

                    const SizedBox(height: 20),
                    _inputSection(),
                    const SizedBox(height: 20),

                    if (isAnalyzing)
                      const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                    if (!isAnalyzing && aiResponse.isNotEmpty) _result(),

                    const SizedBox(height: 20),
                    _researchBox(),
                    const SizedBox(height: 20),
                    _disclaimer(),
                    const SizedBox(height: 30),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // HEADER ---------------------------------------------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.arrow_back_ios, color: Colors.white),
          const Text("Solar Medic",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Icon(Icons.settings, color: Colors.white),
        ],
      ),
    );
  }

  // CARD -----------------------------------------------------
  Widget _card(
      {required String title,
      required String subtitle,
      required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16)
        ],
      ),
    );
  }

  // INPUT ----------------------------------------------------
  Widget _inputSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Describe Your Condition",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          TextField(
            controller: _condition,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. Psoriasis, Vitamin D deficiency...",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(.04),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _getAdvice("quick"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Instant Advice"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _getAdvice("routine"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Cosmic Routine"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // RESULT ---------------------------------------------------
  Widget _result() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: Text(
        aiResponse,
        style: const TextStyle(color: Colors.white70, height: 1.5),
      ),
    );
  }

  // RESEARCH -------------------------------------------------
  Widget _researchBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CLINICAL REFERENCE",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "Phototherapy and Environmental UV Effects on Human Skin.\n"
            "Journal: Science of the Total Environment (Elsevier).",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(
                  "https://www.sciencedirect.com/science/article/pii/S0160412024001211"),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text("Open Research Paper",
                  style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  // DISCLAIMER ----------------------------------------------
  Widget _disclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        "⚠️ This app provides general heliotherapy advice only. "
        "It is NOT a medical diagnosis or professional replacement.",
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
            fontSize: 11),
      ),
    );
  }

  // UV DESC --------------------------------------------------
  String _uvDesc(double uv) {
    if (uv < 3) return "Low (Safe)";
    if (uv < 6) return "Moderate";
    return "High (Caution)";
  }
}

// ----------------------------------------------------------
// PANCHANG CALCULATOR
// ----------------------------------------------------------
class PanchangCalculator {
  static double deg2rad(double d) => d * math.pi / 180;
  static double norm(double x) {
    x %= 360;
    return x < 0 ? x + 360 : x;
  }

  static Map<String, String> calculate(DateTime date) {
    DateTime utc = date.toUtc();

    int Y = utc.year;
    int M = utc.month;
    double D =
        utc.day + utc.hour / 24 + utc.minute / 1440 + utc.second / 86400;

    if (M <= 2) {
      Y--;
      M += 12;
    }

    int A = (Y / 100).floor();
    int B = 2 - A + (A / 4).floor();

    double JD = (365.25 * (Y + 4716)).floor() +
        (30.6001 * (M + 1)).floor() +
        D +
        B -
        1524.5;

    double T = JD - 2451545.0;

    // Sun
    double g = norm(357.529 + 0.98560028 * T);
    double L = norm(280.459 + 0.98564736 * T);
    double lambdaSun =
        norm(L + 1.915 * math.sin(deg2rad(g)) + 0.020 * math.sin(deg2rad(2 * g)));

    // Moon
    double Lm = norm(218.316 + 13.176396 * T);
    double Mm = norm(134.963 + 13.064993 * T);
    double lambdaMoon =
        norm(Lm + 6.289 * math.sin(deg2rad(Mm)));

    // Ayanamsa (approx Lahiri)
    double ay = 24.0 + (utc.year - 2000) * 0.014;

    double sidSun = norm(lambdaSun - ay);
    double sidMoon = norm(lambdaMoon - ay);

    // Tithi
    double elong = norm(sidMoon - sidSun);
    int tNo = (elong / 12).floor() + 1;
    tNo = tNo.clamp(1, 30);

    const names = [
      "Pratipada",
      "Dwitiya",
      "Tritiya",
      "Chaturthi",
      "Panchami",
      "Shashthi",
      "Saptami",
      "Ashtami",
      "Navami",
      "Dashami",
      "Ekadashi",
      "Dwadashi",
      "Trayodashi",
      "Chaturdashi",
      "Purnima/Amavasya"
    ];

    String tithi =
        tNo <= 15 ? "Shukla ${names[tNo - 1]}" : "Krishna ${names[tNo - 16]}";

    // Nakshatra
    int index = (sidMoon / (360 / 27)).floor() % 27;
    const nak = [
      "Ashwini",
      "Bharani",
      "Krittika",
      "Rohini",
      "Mrigashirsha",
      "Ardra",
      "Punarvasu",
      "Pushya",
      "Ashlesha",
      "Magha",
      "Purva Phalguni",
      "Uttara Phalguni",
      "Hasta",
      "Chitra",
      "Swati",
      "Vishakha",
      "Anuradha",
      "Jyeshtha",
      "Mula",
      "Purva Ashadha",
      "Uttara Ashadha",
      "Shravana",
      "Dhanishta",
      "Shatabhisha",
      "Purva Bhadrapada",
      "Uttara Bhadrapada",
      "Revati"
    ];

    return {"tithi": tithi, "nakshatra": nak[index]};
  }
}

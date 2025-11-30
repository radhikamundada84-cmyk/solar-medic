// ----------------------------------------------------------
// SOLAR MEDIC — FULL PROFESSIONAL VERSION (WITH RESEARCH PAPER + DISCLAIMER)
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
const String API_KEY = "AIzaSyDC6zPeu-RHNCd0n5yeds-UmqsDfv0Rtko"; // <-- YOUR GEMINI API KEY

const Color primaryPurple = Color(0xFF7C3AED);
const Color secondaryPurple = Color(0xFFA78BFA);
const Color bgDark = Color(0xFF0F0518);

// ----------------------------------------------------------
void main() => runApp(const SolarMedicApp());

class SolarMedicApp extends StatelessWidget {
  const SolarMedicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Medic',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDark,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SolarMedicScreen(),
    );
  }
}

// ----------------------------------------------------------
// SCREEN
// ----------------------------------------------------------
class SolarMedicScreen extends StatefulWidget {
  const SolarMedicScreen({super.key});
  @override
  State<SolarMedicScreen> createState() => _SolarMedicScreenState();
}

class _SolarMedicScreenState extends State<SolarMedicScreen> {
  // Location
  String locationText = "Locating...";
  double lat = 18.5204;
  double lon = 73.8567;

  // Data
  double currentUV = 0;
  double currentTemp = 0;
  String currentTithi = "--";
  String currentNakshatra = "--";

  // UI
  final TextEditingController _condition = TextEditingController();
  String aiResponse = "";
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ----------------------------------------------------------
  // 1. LOCATION INIT
  // ----------------------------------------------------------
  Future<void> _initLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      locationText = "GPS Disabled";
      _fetchData();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      locationText = "GPS Denied";
      _fetchData();
      return;
    }

    Position p = await Geolocator.getCurrentPosition();
    setState(() {
      lat = p.latitude;
      lon = p.longitude;
      locationText = "${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}";
    });

    _fetchData();
  }

  // ----------------------------------------------------------
  // 2. FETCH PANCHANG + WEATHER
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
          "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,uv_index&timezone=auto");

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
  // 3. AI ADVICE
  // ----------------------------------------------------------
  Future<void> _getAdvice(String mode) async {
    if (_condition.text.trim().isEmpty) {
      _toast("Please describe your condition.");
      return;
    }

    if (API_KEY.isEmpty) {
      _toast("Please add Gemini API Key.");
      return;
    }

    setState(() => isAnalyzing = true);

    String prompt = mode == "quick"
        ? """
Act as an Ayurvedic Heliotherapist.
Condition: "${_condition.text}"
Live Data: UV $currentUV, Temp $currentTemp, Tithi $currentTithi, Nakshatra $currentNakshatra.
Give:
1. Is sunlight safe RIGHT NOW?
2. How Tithi affects it?
3. Precautions?
"""
        : """
Act as an Ayurvedic Doctor.
Condition: "${_condition.text}"
Tithi: $currentTithi, Nakshatra: $currentNakshatra.
Give a structured daily routine (Dinacharya) including:
• Sun exposure time
• Diet
• Restrictions
• Reasoning
""";

    try {
      final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$API_KEY");

      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt}
                ]
              }
            ]
          }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          aiResponse = data["candidates"][0]["content"]["parts"][0]["text"];
        });
      } else {
        aiResponse = "Error fetching AI result.";
      }
    } catch (e) {
      aiResponse = "Connection failed: $e";
    }

    setState(() => isAnalyzing = false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ----------------------------------------------------------
  // BUILD UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.4,
            colors: [Color(0xFF2E1065), Colors.black],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 10),

                _header(),

                const SizedBox(height: 20),

                _locationChip(),

                const SizedBox(height: 30),

                _metricsGrid(),

                const SizedBox(height: 30),

                _inputSection(),

                const SizedBox(height: 30),

                if (isAnalyzing)
                  const CircularProgressIndicator(color: secondaryPurple),

                if (!isAnalyzing && aiResponse.isNotEmpty) _resultBox(),

                const SizedBox(height: 30),

                researchPaperBox(),

                const SizedBox(height: 20),

                _disclaimerBox(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // HEADER ---------------------------------------------------
  Widget _header() {
    return Column(
      children: [
        Container(
          width: 85,
          height: 85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [secondaryPurple, primaryPurple],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 45,
                color: secondaryPurple.withOpacity(.4),
              )
            ],
          ),
          child: const Icon(LucideIcons.sun, size: 50),
        ),
        const SizedBox(height: 12),
        Text(
          "SOLAR MEDIC",
          style: GoogleFonts.cinzel(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        Text(
          "ADVANCED HELIOTHERAPY ADVISOR",
          style: TextStyle(
              color: secondaryPurple.withOpacity(.8),
              fontSize: 12,
              letterSpacing: 1.5),
        ),
      ],
    );
  }

  // LOCATION -------------------------------------------------
  Widget _locationChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.mapPin, color: Colors.green, size: 14),
          const SizedBox(width: 6),
          Text(locationText,
              style: const TextStyle(color: Colors.grey, fontSize: 12))
        ],
      ),
    );
  }

  // METRICS GRID ---------------------------------------------
  Widget _metricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _metric("UV Index", "$currentUV",
            currentUV < 3 ? "Low" : currentUV < 6 ? "Moderate" : "High", Colors.orange),
        _metric("Temp", "$currentTemp°C", "Ambient", Colors.blue),
        _metric("Tithi", currentTithi, "Vedic", primaryPurple),
        _metric("Nakshatra", currentNakshatra, "Constellation",
            Colors.yellow),
      ],
    );
  }

  // SINGLE METRIC --------------------------------------------
  Widget _metric(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  // INPUT SECTION ---------------------------------------------
  Widget _inputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Describe Your Condition",
              style: TextStyle(
                  color: secondaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _condition,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. Psoriasis, Vitamin D Deficiency, Eczema",
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white.withOpacity(.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _gradientButton(
                  "Instant Advice",
                  LucideIcons.zap,
                  [primaryPurple, const Color(0xFF4338CA)],
                  () => _getAdvice("quick"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _gradientButton(
                  "Cosmic Routine",
                  LucideIcons.calendarClock,
                  [Colors.white, Colors.grey.shade300],
                  () => _getAdvice("routine"),
                  textColor: Colors.black,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // BUTTON ----------------------------------------------------
  Widget _gradientButton(String label, IconData icon, List<Color> colors,
      VoidCallback onTap,
      {Color textColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // RESULT ----------------------------------------------------
  Widget _resultBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: primaryPurple, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.clipboardCheck,
                  color: secondaryPurple, size: 18),
              SizedBox(width: 8),
              Text("Result",
                  style: TextStyle(
                      color: secondaryPurple,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(aiResponse,
              style: const TextStyle(color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // RESEARCH PAPER BOX
  // ----------------------------------------------------------
  Widget researchPaperBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: secondaryPurple.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.fileText, color: secondaryPurple, size: 18),
              SizedBox(width: 8),
              Text(
                "CLINICAL REFERENCE",
                style: TextStyle(
                  color: secondaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            "TITLE:\nPhototherapy and Environmental UV Effects on Human Skin",
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),

          const SizedBox(height: 10),

          const Text(
            "JOURNAL:\nScience of the Total Environment (Elsevier)",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),

          const SizedBox(height: 10),

          const Text(
            "SUMMARY:\nThis study examines UV light therapy, environmental UV exposure, "
            "and their effects on skin diseases like psoriasis, vitiligo, and "
            "UV-based cancer therapies.",
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: () => launchUrl(Uri.parse(
                "https://www.sciencedirect.com/science/article/pii/S0160412024001211")),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "Open Research Paper",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  SizedBox(width: 6),
                  Icon(LucideIcons.externalLink,
                      size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // DISCLAIMER
  // ----------------------------------------------------------
  Widget _disclaimerBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        "⚠️ This app provides general heliotherapy advice only. "
        "It is NOT a medical diagnosis or a substitute for professional treatment.",
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ----------------------------------------------------------
// PANCHANG CALCULATOR (FIXED)
// ----------------------------------------------------------
class PanchangCalculator {
  static double deg2rad(double d) => d * math.pi / 180.0;

  static double norm(double a) {
    a %= 360;
    if (a < 0) a += 360;
    return a;
  }

  static Map<String, String> calculate(DateTime date) {
    DateTime utc = date.toUtc();

    int Y = utc.year;
    int M = utc.month;
    double D =
        utc.day + utc.hour / 24 + utc.minute / 1440 + utc.second / 86400;

    if (M <= 2) {
      Y -= 1;
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
    double lambdaMoon = norm(Lm + 6.289 * math.sin(deg2rad(Mm)));

    // Ayanamsa (approx Lahiri)
    double ay = 24.0 + (utc.year - 2000) * 0.014;

    // Sidereal
    double sidSun = norm(lambdaSun - ay);
    double sidMoon = norm(lambdaMoon - ay);

    // TITHI
    double elong = norm(sidMoon - sidSun);
    int tNo = (elong / 12).floor() + 1;
    if (tNo > 30) tNo = 30;

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

    String tithi = tNo <= 15
        ? "Shukla ${names[tNo - 1]}"
        : "Krishna ${names[tNo - 16]}";

    // NAKSHATRA
    int nIndex = (sidMoon / (360 / 27)).floor() % 27;

    const nakList = [
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

    return {"tithi": tithi, "nakshatra": nakList[nIndex]};
  }
}

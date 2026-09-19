import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:signature/signature.dart';
import 'package:shared_preferences/shared_preferences.dart'; // IP-címek tartós mentéséhez

// Globális változók, amiket az app használ
String baseUrl = "";
String nyomtatoIp = "127.0.0.1";

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
  home: const FomenuOldal(),
));

class FomenuOldal extends StatefulWidget {
  const FomenuOldal({super.key});
  @override
  State<FomenuOldal> createState() => _FomenuOldalState();
}

class _FomenuOldalState extends State<FomenuOldal> {
  String? _logoB64;
  final _passwordController = TextEditingController();
  bool _isConfigured = false; // Figyeli, hogy van-e már mentett IP cím

  @override 
  void initState() { 
    super.initState(); 
    _checkAndLoadSettings(); 
  }
  
  // Ellenőrzi az első indítást: ha van mentett IP, betölti, ha nincs, feldobja a kérő ablakot
  Future<void> _checkAndLoadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString('baseUrl');
    
    if (savedBaseUrl == null || savedBaseUrl.isEmpty) {
      // Első indítás: Nincs mentett IP, megmutatjuk a beállító ablakot
      if (!mounted) return;
      _showFirstRunDialog();
    } else {
      // Már konfigurált app: Betöltjük a mentett értékeket
      setState(() {
        baseUrl = savedBaseUrl;
        nyomtatoIp = prefs.getString('nyomtatoIp') ?? "127.0.0.1";
        _isConfigured = true;
      });
      _getLogo();
    }
  }
  
  // Első indításkor felugró, kikerülhetetlen IP és Port kérő ablak
  void _showFirstRunDialog() {
    final ipController = TextEditingController(text: "192.168.1.74");
    final portController = TextEditingController(text: "5000");
    
    showDialog(
      context: context,
      barrierDismissible: false, // Nem lehet mellékattintással bezárni
      builder: (context) => AlertDialog(
        title: const Text('Első Indítás: Szerver Beállítás\nFirst Run: Server Config', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kérjük, adja meg a NAS / Szerver IP-címét és portját a csatlakozáshoz:', textAlign: TextAlign.center),
            const SizedBox(height: 15),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(labelText: 'Szerver IP címe / Server IP', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns)),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port (alapértelmezett: 5000)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.adjust)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Mentés és Indítás / Save & Start'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: () async {
              if (ipController.text.trim().isEmpty || portController.text.trim().isEmpty) return;
              
              String ip = ipController.text.trim();
              String port = portController.text.trim();
              if (!ip.startsWith('http://') && !ip.startsWith('https://')) {
                ip = 'http://$ip';
              }
              final finalUrl = "$ip:$port";
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('baseUrl', finalUrl);
              await prefs.setString('nyomtatoIp', '127.0.0.1'); // Alapértelmezett nyomtató IP
              
              setState(() {
                baseUrl = finalUrl;
                nyomtatoIp = "127.0.0.1";
                _isConfigured = true;
              });
              
              if (!mounted) return;
              Navigator.pop(context);
              _getLogo();
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _getLogo() async {
    try { 
      final r = await http.get(Uri.parse('$baseUrl/logo')).timeout(const Duration(seconds: 2)); 
      if (r.statusCode == 200) {
        final adatok = jsonDecode(r.body);
        if (adatok['status'] == 'megvan') setState(() => _logoB64 = adatok['kep_b64']);
      }
    } catch (_) {}
  }

  void _showPasswordDialog() {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) => ScaffoldMessenger(
        child: Builder(
          builder: (scaffoldContext) => AlertDialog(
            title: const Text('Rendszergazda Belépés / Admin Login', textAlign: TextAlign.center),
            content: TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Jelszó / Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mégse / Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (_passwordController.text == 'mttb6668!') {
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BeallitasokOldal())).then((_) => _getLogo());
                  } else {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      const SnackBar(content: Text('Hibás jelszó! / Wrong password!'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Belépés / Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget btn(BuildContext c, String t, IconData i, Color cl, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: ElevatedButton.icon(
      icon: Icon(i, size: 28), 
      label: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      style: ElevatedButton.styleFrom(backgroundColor: cl, minimumSize: const Size(390, 85)),
      onPressed: _isConfigured ? onTap : null, // Ha nincs konfigurálva, le vannak tiltva a gombok a háttérben
    ),
  );

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Céges Beléptető Kapu / Visitor Gate'), centerTitle: true),
      body: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _logoB64 != null 
          ? Image.memory(base64Decode(_logoB64!), height: 110) 
          : Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.location_city, size: 70, color: Colors.blue)),
        const SizedBox(height: 25),
        btn(context, 'LÁTOGATÓ BEJELENTKEZÉS /\nVISITOR CHECK-IN', Icons.login, Colors.green.shade100, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisztracioOldal()))),
        btn(context, 'LÁTOGATÓ KIJELENTKEZÉS /\nVISITOR CHECK-OUT', Icons.logout, Colors.red.shade100, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KijelentkezoOldal()))),
        btn(context, 'LÁTOGATÓ KERESÉSE /\nSEARCH VISITOR', Icons.search, Colors.blue.shade100, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KeresoOldal()))),
        btn(context, 'BEÁLLÍTÁSOK /\nSETTINGS', Icons.admin_panel_settings, Colors.orange.shade100, _showPasswordDialog),
      ]))),
    );
  }
}

class RegisztracioOldal extends StatefulWidget { const RegisztracioOldal({super.key}); @override State<RegisztracioOldal> createState() => _RegState(); }
class _RegState extends State<RegisztracioOldal> {
  final _n = TextEditingController(), _c = TextEditingController(), _r = TextEditingController(), _card = TextEditingController();
  String _host = ""; String? _qr; List<dynamic> _dl = []; String _txt = "Betöltés... / Loading...";
  final SignatureController _sig = SignatureController(penStrokeWidth: 4, penColor: Colors.black, exportBackgroundColor: Colors.white);
  
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _n.dispose(); _c.dispose(); _r.dispose(); _card.dispose(); _sig.dispose(); super.dispose(); }
  
  Future<void> _load() async {
    try { final r1 = await http.get(Uri.parse('$baseUrl/dolgozok')); if (r1.statusCode == 200) _dl = jsonDecode(r1.body); } catch(_){}
    try { final r2 = await http.get(Uri.parse('$baseUrl/nyilatkozat')); if (r2.statusCode == 200) setState(() => _txt = jsonDecode(r2.body)['szoveg']); } catch(_){}
  }
  
  Future<void> _save() async {
    if (_n.text.isEmpty || _c.text.isEmpty || _host.isEmpty || _sig.isEmpty) return;
    
    // Ha beírtak egyedi kártyaszámot, azt használjuk, különben generálunk egy időbélyeges ID-t
    final id = _card.text.trim().isNotEmpty ? _card.text.trim() : 'QR_${DateTime.now().millisecondsSinceEpoch}';
    final img = await _sig.toPngBytes();
    try {
      await http.post(
        Uri.parse('$baseUrl/uj_vendeg'), 
        headers: {"Content-Type": "application/json"}, 
        body: jsonEncode({
          'id': id, 
          'nev': _n.text, 
          'ceg': _c.text, 
          'rendszam': _r.text, 
          'vendeglato': _host, 
          'kartya_szama': _card.text.trim(),
          'alairas_kep': base64Encode(img!)
        })
      );
      setState(() => _qr = id);
    } catch (_) { setState(() => _qr = id); }
  }
  
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regisztráció / Registration')),
      body: Padding(
        padding: const EdgeInsets.all(20), 
        child: _qr != null 
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 15),
              const Text('Sikeres Regisztráció!\nKártya nyomtatása folyamatban...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 25),
              QrImageView(data: _qr!, size: 200),
              const SizedBox(height: 10),
              Text('ID: $_qr', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 35),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Vissza a főmenübe / Back'))
            ]))
          : SingleChildScrollView(child: Column(children: [
              TextField(controller: _n, decoration: const InputDecoration(labelText: 'Látogató Neve *', border: OutlineInputBorder())), const SizedBox(height: 12),
              TextField(controller: _c, decoration: const InputDecoration(labelText: 'Küldő Cég *', border: OutlineInputBorder())), const SizedBox(height: 12),
              TextField(controller: _r, decoration: const InputDecoration(labelText: 'Rendszám (Opcionális)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car))), const SizedBox(height: 12),
              
              // --- ÚJ OPCIONÁLIS MEZŐ: BELÉPTETŐ KÁRTYA SZÁMA ---
              TextField(controller: _card, decoration: const InputDecoration(labelText: 'Beléptető kártya száma (Opcionális)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.credit_card))), const SizedBox(height: 12),
              
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (o) => o['nev'],
                optionsBuilder: (v) => v.text.isEmpty ? const [] : _dl.where((o) => o['nev'].toString().toLowerCase().contains(v.text.toLowerCase()) || o['beosztas'].toString().toLowerCase().contains(v.text.toLowerCase())).map((o) => Map<String, dynamic>.from(o)),
                onSelected: (s) => _host = "${s['nev']} (${s['beosztas']})",
                fieldViewBuilder: (ctx, ctrl, fn, onSubmit) => TextField(controller: ctrl, focusNode: fn, onChanged: (t)=>_host=t, decoration: const InputDecoration(labelText: 'Kit keres? (Név vagy Beosztás) *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search))),
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(elevation: 4, child: SizedBox(width: 390, height: 200, child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (ctx, idx) {
                    final o = options.elementAt(idx);
                    return ListTile(title: Text(o['nev'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(o['beosztas'], style: const TextStyle(color: Colors.blueGrey, fontSize: 13)), onTap: () => onSelected(o));
                  }))),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 150, width: double.infinity, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(child: Text(_txt, style: const TextStyle(fontSize: 13))),
              ),
              const SizedBox(height: 15),
              const Align(alignment: Alignment.centerLeft, child: Text('Aláírás / Signature *', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                child: Signature(controller: _sig, height: 150, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                TextButton.icon(icon: const Icon(Icons.clear, color: Colors.red), label: const Text('Törlés / Clear', style: TextStyle(color: Colors.red)), onPressed: () => _sig.clear()),
                ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text('Mentés és Nyomtatás'), onPressed: _save),
              ])
            ]))
      ),
    );
  }
}
// --- INTELLIGENS LÁTOGATÓ KIJELENTKEZÉS OLDAL ---
class KijelentkezoOldal extends StatefulWidget {
  const KijelentkezoOldal({super.key});
  @override
  State<KijelentkezoOldal> createState() => _KijelentkezoOldalState();
}

class _KijelentkezoOldalState extends State<KijelentkezoOldal> {
  final _checkoutController = TextEditingController();
  List<dynamic> _bentLevok = []; // Tárolja a gyárban lévőket
  String _kivalasztottId = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBentLevok();
  }

  // Lekéri a szerverről a jelenleg bent tartózkodók listáját
  Future<void> _loadBentLevok() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/bent_levok'));
      if (r.statusCode == 200) {
        setState(() => _bentLevok = jsonDecode(r.body));
      }
    } catch (_) {}
  }

  Future<void> _checkout() async {
    final veglegesId = _kivalasztottId.isNotEmpty ? _kivalasztottId : _checkoutController.text.trim();
    if (veglegesId.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/kilepes'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'id': veglegesId}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sikeres kijelentkezés! / Successful check-out!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        final hiba = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: ${hiba['message']}'), backgroundColor: Colors.red));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Szerver nem elérhető! / Server unreachable!'), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kijelentkezés / Check-out')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 70, color: Colors.red),
            const SizedBox(height: 20),
            
            // --- AUTOMATIKUS KITÖLTÉS A BENT LÉVŐK ALAPJÁN ---
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (o) => "${o['nev']} (ID: ${o['id']})",
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _bentLevok.map((o) => Map<String, dynamic>.from(o));
                }
                return _bentLevok
                    .where((o) => o['nev'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()) || o['id'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()))
                    .map((o) => Map<String, dynamic>.from(o));
              },
              onSelected: (Map<String, dynamic> selection) {
                _kivalasztottId = selection['id'].toString();
                _checkoutController.text = selection['id'].toString();
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                textEditingController.addListener(() {
                  _checkoutController.text = textEditingController.text;
                });
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Név vagy Kártyaszám (Bent lévők közül...) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_search),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 40,
                    height: 200,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final o = options.elementAt(index);
                        return ListTile(
                          title: Text(o['nev'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Kártyaszám / ID: ${o['id']}', style: const TextStyle(color: Colors.redAccent)),
                          onTap: () => onSelected(o),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  icon: const Icon(Icons.run_circle),
                  label: const Text('Kijelentkezés / Check-out', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.red.shade100),
                  onPressed: _checkout,
                ),
          ],
        ),
      ),
    );
  }
}
// --- INTELLIGENS LÁTOGATÓ KERESÉSE OLDAL ---
class KeresoOldal extends StatefulWidget {
  const KeresoOldal({super.key});
  @override
  State<KeresoOldal> createState() => _KeresoOldalState();
}

class _KeresoOldalState extends State<KeresoOldal> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  final bool _isLoading = false;

  // Ez a függvény küldi a kérést a Python szervernek gépelés közben
  Future<List<Map<String, dynamic>>> _fetchLiveSearch(String text) async {
    if (text.trim().isEmpty) return [];
    try {
      final r = await http.get(Uri.parse('$baseUrl/kereses/${text.trim()}'));
      if (r.statusCode == 200) {
        final adatok = jsonDecode(r.body);
        return List<Map<String, dynamic>>.from(adatok['eredmenyek']);
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keresés / Search Visitor')),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // --- ÉLŐ KERESŐ MEZŐ AUTOMATIKUS AJÁNLÁSSAL ---
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (o) => o['nev'],
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.trim().length < 2) {
                  return const []; // Csak akkor kezd el keresni, ha legalább 2 karaktert beírtak
                }
                return await _fetchLiveSearch(textEditingValue.text);
              },
              onSelected: (Map<String, dynamic> selection) {
                // Amikor rákattint egy névre, azonnal beteszi a találati listába a részletes adatokat
                setState(() => _results = [selection]);
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Kezd el írni a nevet, ID-t vagy kártyaszámot...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 30,
                    height: 200,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final o = options.elementAt(index);
                        return ListTile(
                          title: Text(o['nev'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Cég: ${o['ceg']} | Kártya: ${o['kartya_szama']}', style: const TextStyle(fontSize: 13)),
                          onTap: () => onSelected(o),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // --- KIVÁLASZTOTT LÁTOGATÓ RÉSZLETES ADATAI ---
            Expanded(
              child: _results.isEmpty 
                ? const Center(child: Text('Nincs kiválasztott találat.\nGépelj a fenti mezőben az ajánlásokhoz! [CORS / Mixed Content]', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final v = _results[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: ListTile(
                            title: Text(v['nev'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                            subtitle: Text(
                              '\n🆔 ID / QR Kód: ${v['id']}'
                              '\n💳 Kártyaszám: ${v['kartya_szama']}'
                              '\n🏢 Küldő Cég: ${v['ceg']}'
                              '\n👤 Vendéglátó: ${v['vendeglato']}'
                              '\n🚗 Rendszám: ${v['rendszam']}'
                              '\n🟢 Belépett: ${v['belepes']}'
                              '\n🔴 Kilépett: ${v['kilepes']}'
                              '\n📊 Státusz: ${v['statusz']}',
                              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DINAMIKUS ADMIN BEÁLLÍTÁSOK OLDAL ---
class BeallitasokOldal extends StatefulWidget {
  const BeallitasokOldal({super.key});
  @override
  State<BeallitasokOldal> createState() => _BeallitasokOldalState();
}

class _BeallitasokOldalState extends State<BeallitasokOldal> {
  final _serverUrlController = TextEditingController(text: baseUrl);
  final _printerIpController = TextEditingController(text: nyomtatoIp);

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String formattedUrl = _serverUrlController.text.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }

    await prefs.setString('baseUrl', formattedUrl);
    await prefs.setString('nyomtatoIp', _printerIpController.text.trim());

    setState(() {
      baseUrl = formattedUrl;
      nyomtatoIp = _printerIpController.text.trim();
    });

    try {
      await http.post(
        Uri.parse('$baseUrl/set_nyomtato'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'zebra_ip': nyomtatoIp}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beállítások sikeresen mentve!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rendszerbeállítások / Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(labelText: 'Python API Szerver címe (pl. http://192.168.1.74:5000)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _printerIpController,
              decoration: const InputDecoration(labelText: 'Zebra Nyomtató IP-címe (pl. 192.168.1.150)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.print)),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('MINDEN MENTÉSE', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.orange.shade100),
              onPressed: _saveSettings,
            )
          ],
        ),
      ),
    );
  }
}

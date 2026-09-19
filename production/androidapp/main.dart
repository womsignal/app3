import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = "http://192.168.1.74:5000";

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
  @override void initState() { super.initState(); _getLogo(); }
  Future<void> _getLogo() async {
    try { 
      final r = await http.get(Uri.parse('$baseUrl/logo')).timeout(const Duration(seconds: 2)); 
      if (r.statusCode == 200) {
        final adatok = jsonDecode(r.body);
        if (adatok['status'] == 'megvan') setState(() => _logoB64 = adatok['kep_b64']);
      }
    } catch (_) {}
  }
  Widget btn(BuildContext c, String t, IconData i, Color cl, Widget p) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: ElevatedButton.icon(
      icon: Icon(i, size: 28), label: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      style: ElevatedButton.styleFrom(backgroundColor: cl, minimumSize: const Size(390, 85)),
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (c) => p)),
    ),
  );
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Céges Beléptető Kapu / Visitor Gate'), centerTitle: true),
      body: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _logoB64 != null ? Image.memory(base64Decode(_logoB64!), height: 110) : Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.location_city, size: 70, color: Colors.blue)),
        const SizedBox(height: 25),
        btn(context, 'LÁTOGATÓ BEJELENTKEZÉS /\nVISITOR CHECK-IN', Icons.login, Colors.green.shade100, const RegisztracioOldal()),
        btn(context, 'LÁTOGATÓ KIJELENTKEZÉS /\nVISITOR CHECK-OUT', Icons.logout, Colors.red.shade100, const KijelentkezoOldal()),
        btn(context, 'LÁTOGATÓ KERESÉSE /\nSEARCH VISITOR', Icons.search, Colors.blue.shade100, const KeresoOldal()),
        btn(context, 'EGYÉB MENÜ /\nOTHER OPTIONS', Icons.settings, Colors.orange.shade100, const EgyebMenyuOldal()),
      ]))),
    );
  }
}

class EgyebMenyuOldal extends StatelessWidget {
  const EgyebMenyuOldal({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Egyéb Menü / Other Options')),
      body: Center(child: ElevatedButton.icon(icon: const Icon(Icons.table_view, size: 30), label: const Text('EXCEL FÁJL EXPORTÁLÁS /\nEXPORT EXCEL LOG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), backgroundColor: Colors.grey.shade200, minimumSize: const Size(400, 90)), onPressed: () async { try { await launchUrl(Uri.parse('$baseUrl/export_excel'), mode: LaunchMode.externalApplication); } catch(_){} })),
    );
  }
}
class RegisztracioOldal extends StatefulWidget { const RegisztracioOldal({super.key}); @override State<RegisztracioOldal> createState() => _RegState(); }
class _RegState extends State<RegisztracioOldal> {
  final _n = TextEditingController(), _c = TextEditingController(), _r = TextEditingController();
  String _host = ""; String? _qr; List<dynamic> _dl = []; String _txt = "Betöltés... / Loading...";
  final SignatureController _sig = SignatureController(penStrokeWidth: 4, penColor: Colors.black, exportBackgroundColor: Colors.white);
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _sig.dispose(); super.dispose(); }
  Future<void> _load() async {
    try { final r1 = await http.get(Uri.parse('$baseUrl/dolgozok')); if (r1.statusCode == 200) _dl = jsonDecode(r1.body); } catch(_){}
    try { final r2 = await http.get(Uri.parse('$baseUrl/nyilatkozat')); if (r2.statusCode == 200) setState(() => _txt = jsonDecode(r2.body)['szoveg']); } catch(_){}
  }
  Future<void> _save() async {
    if (_n.text.isEmpty || _c.text.isEmpty || _host.isEmpty || _sig.isEmpty) return;
    final id = 'QR_${DateTime.now().millisecondsSinceEpoch}';
    final img = await _sig.toPngBytes();
    try {
      await http.post(Uri.parse('$baseUrl/uj_vendeg'), headers: {"Content-Type": "application/json"}, body: jsonEncode({'id': id, 'nev': _n.text, 'ceg': _c.text, 'rendszam': _r.text, 'vendeglato': _host, 'alairas_kep': base64Encode(img!)}));
      setState(() => _qr = id);
    } catch (_) { setState(() => _qr = id); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regisztráció / Registration')),
      body: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(children: [
        TextField(controller: _n, decoration: const InputDecoration(labelText: 'Látogató Neve *', border: OutlineInputBorder())), const SizedBox(height: 12),
        TextField(controller: _c, decoration: const InputDecoration(labelText: 'Küldő Cég *', border: OutlineInputBorder())), const SizedBox(height: 12),
        TextField(controller: _r, decoration: const InputDecoration(labelText: 'Rendszám (Opcionális)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car))), const SizedBox(height: 12),
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
        const SizedBox(height: 20), Container(height: 110, width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5), color: Colors.grey.shade100), child: SingleChildScrollView(child: Text(_txt))),
        const SizedBox(height: 15), Container(decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade300, width: 2), borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Signature(controller: _sig, height: 110, backgroundColor: Colors.white))),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.clear, color: Colors.red), label: const Text('Törlés'), onPressed: () => _sig.clear())),
        ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55)), child: const Text('Mentés / Save')),
        if (_qr != null) ...[
          const SizedBox(height: 20), Container(padding: const EdgeInsets.all(12), width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.green.shade300), borderRadius: BorderRadius.circular(8), color: Colors.green.shade50), child: Column(children: [Text(_n.text.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('Cég: ${_c.text}'), SelectableText('ID: $_qr', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))])),
          const SizedBox(height: 15), QrImageView(data: _qr!, size: 170),
        ]
      ]))),
    );
  }
}
class KijelentkezoOldal extends StatefulWidget { const KijelentkezoOldal({super.key}); @override State<KijelentkezoOldal> createState() => _KilepState(); }
class _KilepState extends State<KijelentkezoOldal> {
  String _id = ""; List<dynamic> _list = [];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await http.get(Uri.parse('$baseUrl/bent_levok')); if (r.statusCode == 200) setState(() => _list = jsonDecode(r.body)); } catch (_) {} }
  Future<void> _out() async { if (_id.isEmpty) return; try { await http.post(Uri.parse('$baseUrl/kilepes'), headers: {"Content-Type": "application/json"}, body: jsonEncode({'id': _id})); Navigator.pop(context); } catch (_) {} }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kijelentkezés / Check-out')),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Kezdje el beírni a nevét a kijelentkezéshez:', style: TextStyle(fontSize: 16)), const SizedBox(height: 20),
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (o) => o['nev'],
          optionsBuilder: (v) => v.text.isEmpty ? const [] : _list.where((o) => o['nev'].toString().toLowerCase().contains(v.text.toLowerCase())).map((o) => Map<String, dynamic>.from(o)),
          onSelected: (s) => _id = s['id'],
          fieldViewBuilder: (ctx, ctrl, fn, onSubmit) => TextField(controller: ctrl, focusNode: fn, decoration: const InputDecoration(labelText: 'Írja be a nevét...', border: OutlineInputBorder())),
        ),
        const SizedBox(height: 30), ElevatedButton(onPressed: _out, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55), backgroundColor: Colors.red.shade100), child: const Text('Kijelentkezés / Check-out'))
      ])),
    );
  }
}

// --- FRISSÍTVE: INTELLIGENS KERESŐ OLDAL (NÉV GÉPELÉS + QR KÓD BEOLVASÁS IS MŰKÖDIK!) ---
class KeresoOldal extends StatefulWidget { const KeresoOldal({super.key}); @override State<KeresoOldal> createState() => _KeresoOldalState(); }
class _KeresoOldalState extends State<KeresoOldal> {
  List<dynamic> _bentLister = []; List<dynamic> _talalatokCard = [];
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _getBentLevok(); }
  Future<void> _getBentLevok() async { try { final r = await http.get(Uri.parse('$baseUrl/bent_levok')); if (r.statusCode == 200) setState(() => _bentLister = jsonDecode(r.body)); } catch (_) {} }
  
  Future<void> _keres(String szoveg) async { 
    if (szoveg.isEmpty) return;
    try { 
      final r = await http.get(Uri.parse('$baseUrl/kereses/$szoveg')); 
      if (r.statusCode == 200) setState(() { _talalatokCard = jsonDecode(r.body)['eredmenyek']; }); 
    } catch (_) {} 
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Látogató Keresése / Search Visitor')),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (o) => o['nev'],
          optionsBuilder: (v) {
            // HA QR-KÓDOT SZKENNELNEK VAGY ÍRNAK BE (QR_ KORREKCIÓ), AZONNAL ELINDÍTJA A DIREKT KERESÉST
            if (v.text.toUpperCase().startsWith('QR_')) {
              _keres(v.text.trim());
              return const Iterable.empty();
            }
            if (v.text.isEmpty) return const Iterable.empty();
            return _bentLister.where((o) => o['nev'].toString().toLowerCase().contains(v.text.toLowerCase())).map((o) => Map<String, dynamic>.from(o));
          },
          onSelected: (s) {
            _searchCtrl.text = s['nev'];
            _keres(s['nev']);
          },
          fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
            // Összekötjük a vezérlőt, hogy a kézi gépelés és a QR-olvasó is aktiválni tudja a keresést
            ctrl.addListener(() {
              if (ctrl.text.toUpperCase().startsWith('QR_')) {
                _keres(ctrl.text.trim());
              }
            });
            return TextField(
              controller: ctrl, focusNode: fn, 
              decoration: const InputDecoration(labelText: 'Gépelje be a nevet vagy olvassa be a QR-kódot... *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.qr_code_scanner)),
            );
          },
        ),
        const SizedBox(height: 20),
        Expanded(child: ListView.builder(itemCount: _talalatokCard.length, itemBuilder: (ctx, idx) {
          final t = _talalatokCard[idx]; final bool b = t['statusz'].toString().contains('Bent');
          return Card(child: Column(children: [
            ListTile(leading: Icon(Icons.person, color: b ? Colors.green : Colors.blue), title: Text(t['nev'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Text(t['statusz'], style: TextStyle(fontWeight: FontWeight.bold, color: b ? Colors.green : Colors.blue)), subtitle: Text("Cég: ${t['ceg']} | Autó: ${t['rendszam']}\nHázigazda: ${t['vendeglato']}\nBe: ${t['belepes']} | Ki: ${t['kilepes']}")),
            if (t['alairas'] != null && t['alairas'].toString().isNotEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Align(alignment: Alignment.centerLeft, child: Text("Látogató Aláírása:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))),
              Container(margin: const EdgeInsets.all(10), height: 55, width: 180, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), color: Colors.white, borderRadius: BorderRadius.circular(5)), child: Image.memory(base64Decode(t['alairas'])))
            ]
          ]));
        }))
      ])),
    );
  }
}

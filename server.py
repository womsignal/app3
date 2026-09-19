from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import pandas as pd
from datetime import datetime
import json
import os
import base64
import socket  # Szükséges a Zebra hálózati kiküldéséhez
from docx import Document

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

ADATBAZIS_FAJL = 'latogatok.json'
DOLGOZOK_EXCEL = 'dolgozok.xlsx'
ALAIRASOK_MAPPA = 'alairasok'
CONFIG_FAJL = 'nyomtato_config.json'
EXPORT_EXCEL_FAJL = 'latogato_riport.xlsx'

if not os.path.exists(ALAIRASOK_MAPPA):
    os.makedirs(ALAIRASOK_MAPPA)

def adatok_betoltese(fajlnav):
    if os.path.exists(fajlnav):
        with open(fajlnav, 'r', encoding='utf-8') as f:
            try: return json.load(f)
            except: return []
    return []

def adatok_mentese(fajlnav, adatok):
    with open(fajlnav, 'w', encoding='utf-8') as f:
        json.dump(adatok, f, ensure_ascii=False, indent=4)

# --- AUTOMATIKUS EXCEL SABLON LÉTREHOZÁS ---
if not os.path.exists(DOLGOZOK_EXCEL):
    alap_adatok = [
        {"Név": "Kovács Gábor", "Beosztás": "Ügyvezető / CEO"},
        {"Név": "Nagy Tímea", "Beosztás": "HR Menedzser"},
        {"Név": "Kiss Attila", "Beosztás": "IT Csoportvezető"},
        {"Név": "Szabó Péter", "Beosztás": "Logisztikai Vezető"}
    ]
    df_sablon = pd.DataFrame(alap_adatok)
    df_sablon.to_excel(DOLGOZOK_EXCEL, index=False)

# --- NYOMTATÓ IP CÍM LEKÉRÉSE A MENTÉSBŐL ---
def nyomtato_ip_lekeres():
    if os.path.exists(CONFIG_FAJL):
        try:
            with open(CONFIG_FAJL, 'r') as f:
                return json.load(f).get('zebra_ip', '127.0.0.1')
        except: pass
    return '127.0.0.1'

# --- BIZTONSÁGOS ZEBRA NYOMTATÓ MOTOR ---
def kuldj_zebrara(nev, ceg, qr_id):
    zebra_ip = nyomtato_ip_lekeres()
    port = 9100
    
    zpl_adat = f"""
    ^XA
    ^FO50,40^A0N,35,35^FDLATOGATO / VISITOR^FS
    ^FO50,90^A0N,45,45^FD{nev}^FS
    ^FO50,140^A0N,30,30^FD{ceg}^FS
    ^FO50,190^BQN,2,6^FDQA,{qr_id}^FS
    ^XZ
    """
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2.0)
        s.connect((zebra_ip, port))
        s.sendall(zpl_adat.encode('utf-8'))
        s.close()
        print(f"-> [Zebra] Kártya sikeresen kiküldve: {zebra_ip} ({nev})")
    except Exception as e:
        print(f"-> [Zebra] Nyomtatás kihagyva ({zebra_ip} nem érhető el: {e})")

@app.route('/get_nyomtato', methods=['GET'])
def get_nyomtato():
    return jsonify({"zebra_ip": nyomtato_ip_lekeres()}), 200

@app.route('/set_nyomtato', methods=['POST'])
def set_nyomtato():
    uj_ip = request.json.get('zebra_ip', '127.0.0.1').strip()
    with open(CONFIG_FAJL, 'w') as f:
        json.dump({"zebra_ip": uj_ip}, f)
    return jsonify({"status": "sikeres", "uzenet": f"Nyomtató IP módosítva: {uj_ip}"}), 200

@app.route('/logo', methods=['GET'])
def get_logo():
    if os.path.exists('ceglogo.png'):
        try:
            with open('ceglogo.png', "rb") as image_file:
                encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
                return jsonify({"status": "megvan", "kep_b64": encoded_string}), 200
        except: pass
    return jsonify({"status": "nincs_logo"}), 404

@app.route('/bent_levok', methods=['GET'])
def get_bent_levok():
    adatok = adatok_betoltese(ADATBAZIS_FAJL)
    bent_levok = [{"id": v['id'], "nev": v['nev']} for v in adatok if v.get('kilepes_ideje') is None]
    return jsonify(bent_levok), 200

@app.route('/nyilatkozat', methods=['GET'])
def get_nyilatkozat():
    if os.path.exists('nyilatkozat.docx'):
        try:
            doc = Document('nyilatkozat.docx')
            teljes_szoveg = [para.text for para in doc.paragraphs]
            return jsonify({"szoveg": "\n".join(teljes_szoveg)}), 200
        except: pass
    if os.path.exists('nyilatkozat.txt'):
        with open('nyilatkozat.txt', 'r', encoding='utf-8') as f:
            return jsonify({"szoveg": f.read()}), 200
    return jsonify({"szoveg": "1. Előírásokat betartom.\n2. Titkokat megőrzöm."}), 200

@app.route('/dolgozok', methods=['GET'])
def get_dolgozok():
    if os.path.exists(DOLGOZOK_EXCEL):
        try:
            df = pd.read_excel(DOLGOZOK_EXCEL)
            lista = []
            for _, row in df.iterrows():
                lista.append({
                    "nev": str(row.get('Név', row.get('név', ''))).strip(),
                    "beosztas": str(row.get('Beosztás', row.get('beosztás', ''))).strip()
                })
            return jsonify(lista), 200
        except: pass
    return jsonify([]), 200

@app.route('/uj_vendeg', methods=['POST'])
def uj_vendeg():
    adatok = adatok_betoltese(ADATBAZIS_FAJL)
    uj_adat = request.json
    
    # KÁRTYASZÁM LOGIKA: Ha a portás beírta, ez lesz a QR-kód és a rendszer ID-ja is
    kezileg_beirt_kartya = uj_adat.get('kartya_szama', '').strip()
    if kezileg_beirt_kartya:
        uj_adat['id'] = kezileg_beirt_kartya
    
    alairas_b64 = uj_adat.get('alairas_kep')
    uj_adat['alairas_fajl'] = None
    if alairas_b64:
        try:
            kep_adatok = base64.b64decode(alairas_b64.split(',')[-1])
            fajlnav = f"{ALAIRASOK_MAPPA}/{uj_adat['id']}.png"
            with open(fajlnav, "wb") as fh: fh.write(kep_adatok)
            uj_adat['alairas_fajl'] = fajlnav
        except: pass
        
    if 'alairas_kep' in uj_adat: del uj_adat['alairas_kep']
    uj_adat['belepes_ideje'] = datetime.now().isoformat()
    uj_adat['kilepes_ideje'] = None
    
    adatok.append(uj_adat)
    adatok_mentese(ADATBAZIS_FAJL, adatok)
    
    # Zebra nyomtatás indítása a végleges kártyaszámmal/ID-val
    kuldj_zebrara(uj_adat['nev'], uj_adat['ceg'], uj_adat['id'])
    
    return jsonify({"status": "sikeres"}), 200

@app.route('/kilepes', methods=['POST'])
def kilepes():
    adatok = adatok_betoltese(ADATBAZIS_FAJL)
    qr_id = request.json.get('id')
    talalat = False
    for v in adatok:
        if v['id'] == qr_id and v['kilepes_ideje'] is None:
            v['kilepes_ideje'] = datetime.now().isoformat()
            talalat = True
            break
    if talalat:
        adatok_mentese(ADATBAZIS_FAJL, adatok)
        return jsonify({"status": "sikeres"}), 200
    return jsonify({"status": "hiba", "message": "Nem található aktív látogató"}), 400

@app.route('/kereses/<szoveg>', methods=['GET'])
def kereses(szoveg):
    adatok = adatok_betoltese(ADATBAZIS_FAJL)
    keresett = szoveg.strip().lower()
    talalatok = []
    for v in adatok:
        if v['id'].lower() == keresett or keresett in v['nev'].lower() or keresett in v.get('kartya_szama', '').lower():
            b_ido = datetime.fromisoformat(v['belepes_ideje']).strftime('%Y.%m.%d. %H:%M') if v['belepes_ideje'] else "-"
            k_ido = datetime.fromisoformat(v['kilepes_ideje']).strftime('%Y.%m.%d. %H:%M') if v['kilepes_ideje'] else "Bent van / Still inside"
            rendszam = v.get('rendszam', '').strip()
            if not rendszam: rendszam = "Gyalog / On foot"
            alairas_kep_b64 = ""
            if v.get('alairas_fajl') and os.path.exists(v['alairas_fajl']):
                with open(v['alairas_fajl'], "rb") as image_file:
                    alairas_kep_b64 = base64.b64encode(image_file.read()).decode('utf-8')
            talalatok.append({
                "id": v['id'], "nev": v['nev'], "ceg": v['ceg'], "vendeglato": v['vendeglato'],
                "rendszam": rendszam, "belepes": b_ido, "kilepes": k_ido, 
                "statusz": "Kijelentkezett" if v['kilepes_ideje'] else "Bent tartózkodik", "alairas": alairas_kep_b64,
                "kartya_szama": v.get('kartya_szama', '-')
            })
    return jsonify({"status": "megtalalva", "eredmenyek": talalatok}), 200

@app.route('/export_excel', methods=['GET'])
def export_excel():
    adatok = adatok_betoltese(ADATBAZIS_FAJL)
    if not adatok: return "Nincs adat", 400
    feldolgozott = []
    for v in adatok:
        b_ido = datetime.fromisoformat(v['belepes_ideje']).strftime('%Y.%m.%d. %H:%M') if v['belepes_ideje'] else ""
        k_ido = datetime.fromisoformat(v['kilepes_ideje']).strftime('%Y.%m.%d. %H:%M') if v['kilepes_ideje'] else "Még bent van"
        rendszam = v.get('rendszam', '').strip()
        if not rendszam: rendszam = "-"
        feldolgozott.append({
            'Azonosító / QR ID': v['id'], 
            'Látogató Neve': v['nev'], 
            'Küldő Cég': v['ceg'],
            'Vendéglátó': v['vendeglato'],
            'Rendszám': rendszam,
            'Belépés Ideje': b_ido,
            'Kilépés Ideje': k_ido,
            'Beléptető Kártya Száma': v.get('kartya_szama', '-')
        })
    df = pd.DataFrame(feldolgozott)
    df.to_excel(EXPORT_EXCEL_FAJL, index=False)
    return send_file(EXPORT_EXCEL_FAJL, as_attachment=True)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

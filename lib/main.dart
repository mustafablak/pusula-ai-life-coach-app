import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

// --- ROTA (GROQ API & HIVE CACHE) SERVİSİ ---
class RotaServis {
  static const String _apiKey = 'Your Groq Api Key';
  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<void> initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('pusula_box');
  }

  static Future<String> getGununSozu(String kullaniciAdi, String dil) async {
    var box = Hive.box('pusula_box');
    String bugunTarih = DateTime.now().toString().split(' ')[0];
    String kayitliTarih = box.get('soz_tarihi', defaultValue: '');
    String kayitliSoz = box.get('gunun_sozu', defaultValue: '');

    if (kayitliTarih == bugunTarih && kayitliSoz.isNotEmpty) {
      return kayitliSoz;
    }

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": dil == 'tr' 
                  ? "Sen Rota'sin. Samimi, esprili bir yaşam koçusun. Türkçe motive edici, tatlı ve içinde 1 emoji olan bir günün sözünü kur."
                  : "You are Rota, a friendly life coach. Write a motivating, sweet sentence with 1 emoji."
            },
            {
              "role": "user",
              "content": "Kullanici adi: $kullaniciAdi"
            }
          ],
          "temperature": 0.8,
          "max_tokens": 120,
        }),
      );

      if (response.statusCode == 200) {
        var decoded = utf8.decode(response.bodyBytes);
        var data = jsonDecode(decoded);
        String yeniSoz = data['choices'][0]['message']['content'].trim();
        await box.put('soz_tarihi', bugunTarih);
        await box.put('gunun_sozu', yeniSoz);
        return yeniSoz;
      } else {
        return dil == 'tr' ? 'Bugün kendi enerjine güven kanka! 🚀' : 'Trust your own energy today buddy! 🚀';
      }
    } catch (e) {
      return dil == 'tr' ? 'Bugün harika bir gün olacak! ✨' : 'Today will be a great day! ✨';
    }
  }

  static Future<String> mesajGonder(String kullaniciMesaji, String dil) async {
    String hedeflerDetayi = GlobalVeriler.hedefler.map((h) {
      String baslik = h['isKey'] ? c(h['baslik']) : h['baslik'];
      String durum = h['tamamlandi'] ? (dil == 'tr' ? 'Tamamlandı' : 'Completed') : (dil == 'tr' ? 'Tamamlanmadı' : 'Not completed');
      return "- $baslik ($durum)";
    }).join("\n");

    int su = GlobalVeriler.icilenSuBardak;
    int suHedef = GlobalVeriler.suHedefi;
    int vaha = VahaYoneticisi.instance.value;

    String anlikVerilerTr = "Kullanıcının Hedef Listesi:\n$hedeflerDetayi\nSu: $su/$suHedef bardak, Vaha: $vaha damla.";
    String anlikVerilerEn = "User's Goal List:\n$hedeflerDetayi\nWater: $su/$suHedef glasses, Oasis: $vaha drops.";

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": dil == 'tr' 
                  ? "Sen Rota'sin. Pusula uygulamasının zeki ve samimi yapay zeka dostusun. "
                    "Kullanıcıya akıcı, samimi ve kanka tarzında yardımcı ol. Kullanıcının HEDEF LİSTESİNİ biliyorsun, gelen sorularda bu hedeflerin adını ve durumunu doğrudan söyleyerek rehberlik et. "
                    "GÜVENLİK: Uygulama dışı (yemek tarifi, hava durumu vb.) sorular sorulursa, kanka dilini bozmadan nazikçe reddet ve konuyu hedeflere getir."
                    "\n$anlikVerilerTr"
                  : "You are Rota, the AI buddy of Pusula. "
                    "You know the user's GOAL LIST, use their exact titles and statuses when answering. "
                    "SECURITY: If off-topic, politely decline and steer back to app goals."
                    "\n$anlikVerilerEn"
            },
            {
              "role": "user",
              "content": kullaniciMesaji
            }
          ],
          "temperature": 0.7,
          "max_tokens": 250,
        }),
      );

      if (response.statusCode == 200) {
        var decoded = utf8.decode(response.bodyBytes);
        var data = jsonDecode(decoded);
        return data['choices'][0]['message']['content'].trim();
      } else {
        return dil == 'tr' ? 'Kısa devre yaptım kanka, tekrar dener misin? 🤖' : 'Short circuited buddy, try again? 🤖';
      }
    } catch (e) {
      return dil == 'tr' ? 'İnternet bağlantını kontrol edebilir misin kanka? 🌍' : 'Can you check your internet connection buddy? 🌍';
    }
  }
}
Future<void> checkAndResetDailyStats() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  DateTime now = DateTime.now();
  DateTime virtualToday = now.subtract(const Duration(hours: 3));

  String? lastResetString = prefs.getString('lastResetDate');
  bool needsReset = false;

  if (lastResetString == null) {
    needsReset = true;
  } else {
    DateTime lastResetDate = DateTime.parse(lastResetString);
    if (virtualToday.day != lastResetDate.day ||
        virtualToday.month != lastResetDate.month ||
        virtualToday.year != lastResetDate.year) {
      needsReset = true;
    }
  }

  if (needsReset) {
    var box = Hive.box('pusula_box');
    box.put('icilenSuBardak', 0);
    box.put('atilanAdim', 0);
    box.put('vahaPuani', 0);
    List<dynamic> rawHedefler = box.get('hedefler', defaultValue: []);
    List<Map<String, dynamic>> hedefler = rawHedefler.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (var hedef in hedefler) {
      hedef['tamamlandi'] = false;
    }
    box.put('hedefler', hedefler);
    await prefs.setString('lastResetDate', virtualToday.toIso8601String());
    print("Gece 3 Sıfırlaması Yapıldı!");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RotaServis.initHive();
  await checkAndResetDailyStats();
  GlobalVeriler.verileriYukle();
  runApp(const PusulaApp());
}

// Global Dil Yönetimi
class DilYoneticisi extends ValueNotifier<String> {
  DilYoneticisi() : super('tr');
  static final DilYoneticisi instance = DilYoneticisi();
}

// Global Vaha Yönetimi
class VahaYoneticisi extends ValueNotifier<int> {
  VahaYoneticisi() : super(0);
  static final VahaYoneticisi instance = VahaYoneticisi();
  
  void suEkle(BuildContext context, int miktar) {
    int eskiPuan = value;
    int yeniPuan = value + miktar;
    if (yeniPuan < 0) yeniPuan = 0; 
    value = yeniPuan;

    if (eskiPuan < 100 && yeniPuan >= 100) {
      GlobalVeriler.vahaMaxSeviyeGun++;
    } else if (eskiPuan >= 100 && yeniPuan < 100) {
      GlobalVeriler.vahaMaxSeviyeGun--;
    }
    GlobalVeriler.verileriKaydet();
    RozetYoneticisi.kontrolEt(context);
  }
}

// --- GLOBAL VERİ VE KALICI HAFIZA YÖNETİMİ ---
class GlobalVeriler {
  static List<Map<String, dynamic>> hedefler = [];
  static List<Map<String, String>> gunlukler = [];
  static List<Map<String, String>> kitaplar = [];
  static int icilenSuBardak = 0;
  static int suHedefi = 8;
  static int atilanAdim = 0;
  static int adimHedefi = 10000;
  static String secilenSesKodu = 'ses1';
  static double secilenDakika = 25.0;
  static bool odakAktif = false;
  static bool odakDuraklatildi = false;
  static int kalanSaniye = 0;
  static int vahaMaxSeviyeGun = 0; 
  static int toplamOdaklanmaDk = 0;
  static int toplamTamamlananGorev = 0;
  static int toplamSuHedefiUlasma = 0;
  static int toplamAdimIstatisigi = 0;
  static Set<String> kazanilanRozetler = {}; 
  static int kesintisizSeri = 0;

  // VERİLERİ KALICI HAFIZAYA KAYDET
  static void verileriKaydet() {
    var box = Hive.box('pusula_box');
    box.put('icilenSuBardak', icilenSuBardak);
    box.put('suHedefi', suHedefi);
    box.put('atilanAdim', atilanAdim);
    box.put('adimHedefi', adimHedefi);
    box.put('vahaMaxSeviyeGun', vahaMaxSeviyeGun);
    box.put('toplamOdaklanmaDk', toplamOdaklanmaDk);
    box.put('toplamTamamlananGorev', toplamTamamlananGorev);
    box.put('toplamSuHedefiUlasma', toplamSuHedefiUlasma);
    box.put('toplamAdimIstatisigi', toplamAdimIstatisigi);
    box.put('kazanilanRozetler', kazanilanRozetler.toList());
    box.put('vahaPuani', VahaYoneticisi.instance.value);
    box.put('hedefler', hedefler.map((e) => Map<String, dynamic>.from(e)).toList());
    box.put('gunlukler', gunlukler.map((e) => Map<String, String>.from(e)).toList());
    box.put('kitaplar', kitaplar.map((e) => Map<String, String>.from(e)).toList());
  }

  // KALICI HAFIZADAN VERİLERİ ÇEK
  static void verileriYukle() {
    var box = Hive.box('pusula_box');
    icilenSuBardak = box.get('icilenSuBardak', defaultValue: 0);
    suHedefi = box.get('suHedefi', defaultValue: 8);
    atilanAdim = box.get('atilanAdim', defaultValue: 0);
    adimHedefi = box.get('adimHedefi', defaultValue: 10000);
    vahaMaxSeviyeGun = box.get('vahaMaxSeviyeGun', defaultValue: 0);
    toplamOdaklanmaDk = box.get('toplamOdaklanmaDk', defaultValue: 0);
    toplamTamamlananGorev = box.get('toplamTamamlananGorev', defaultValue: 0);
    toplamSuHedefiUlasma = box.get('toplamSuHedefiUlasma', defaultValue: 0);
    toplamAdimIstatisigi = box.get('toplamAdimIstatisigi', defaultValue: 0);
    
    List<dynamic> rawKazanilan = box.get('kazanilanRozetler', defaultValue: []);
    kazanilanRozetler = rawKazanilan.map((e) => e.toString()).toSet();
    
    VahaYoneticisi.instance.value = box.get('vahaPuani', defaultValue: 0);

    List<dynamic> rawHedefler = box.get('hedefler', defaultValue: []);
    hedefler = rawHedefler.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    List<dynamic> rawGunlukler = box.get('gunlukler', defaultValue: []);
    gunlukler = rawGunlukler.map((e) => Map<String, String>.from(e as Map)).toList();

    List<dynamic> rawKitaplar = box.get('kitaplar', defaultValue: []);
    kitaplar = rawKitaplar.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  // GÜNLÜK SIFIRLAMALARI VE SERİYİ KONTROL ET 
  static void seriKontrolEt() {
    var box = Hive.box('pusula_box');
    DateTime virtualToday = DateTime.now().subtract(const Duration(hours: 3));
    String bugun = virtualToday.toString().split(' ')[0];
    
    String kayitliSonTarih = box.get('son_aktif_tarih', defaultValue: '');
    int mevcutSeri = box.get('kesintisiz_seri', defaultValue: 0);

    verileriYukle();

    if (kayitliSonTarih.isEmpty) {
      box.put('son_aktif_tarih', bugun);
      box.put('kesintisiz_seri', 0); // İlk girişte seriyi 0'den başlat
      kesintisizSeri = 0;
    } else if (kayitliSonTarih != bugun) {
      DateTime sonTarih = DateTime.parse(kayitliSonTarih);
      DateTime bugunTarihObj = DateTime.parse(bugun);
      int farkGun = bugunTarihObj.difference(sonTarih).inDays;

      if (farkGun == 1) {
        mevcutSeri++; // Her gün girerse seriyi artır
      } else if (farkGun > 1) {
        mevcutSeri = 0; 
      }
      
      box.put('kesintisiz_seri', mevcutSeri);
      box.put('son_aktif_tarih', bugun);
      kesintisizSeri = mevcutSeri;
      verileriKaydet();
    } else {
      kesintisizSeri = mevcutSeri;
    }
  }
}

// --- ROZET YÖNETİCİSİ ---
class RozetYoneticisi {
  static const Map<String, String> ikonlar = {
    'badge_vaha1': '🏝️', 'badge_vaha2': '🌴', 'badge_vaha3': '👑',
    'badge_zaman1': '⏳', 'badge_zaman2': '⌛', 'badge_zaman3': '🌌',
    'badge_yazar1': '📝', 'badge_yazar2': '✍️', 'badge_yazar3': '📜',
    'badge_su1': '💧', 'badge_su2': '🌊', 'badge_su3': '🧜‍♀️',
    'badge_adim1': '👟', 'badge_adim2': '🏃', 'badge_adim3': '⚡',
    'badge_kitap1': '📖', 'badge_kitap2': '📚', 'badge_kitap3': '🦉',
    'badge_gorev1': '🎯', 'badge_gorev2': '🔥', 'badge_gorev3': '🏅',
  };

  static void kontrolEt(BuildContext context) {
    Map<String, bool> durumlar = {
      'badge_vaha1': GlobalVeriler.vahaMaxSeviyeGun >= 2,
      'badge_vaha2': GlobalVeriler.vahaMaxSeviyeGun >= 5,
      'badge_vaha3': GlobalVeriler.vahaMaxSeviyeGun >= 15,
      'badge_zaman1': GlobalVeriler.toplamOdaklanmaDk >= 100,
      'badge_zaman2': GlobalVeriler.toplamOdaklanmaDk >= 500,
      'badge_zaman3': GlobalVeriler.toplamOdaklanmaDk >= 1500,
      'badge_yazar1': GlobalVeriler.gunlukler.length >= 3,
      'badge_yazar2': GlobalVeriler.gunlukler.length >= 10,
      'badge_yazar3': GlobalVeriler.gunlukler.length >= 30,
      'badge_su1': GlobalVeriler.toplamSuHedefiUlasma >= 3,
      'badge_su2': GlobalVeriler.toplamSuHedefiUlasma >= 10,
      'badge_su3': GlobalVeriler.toplamSuHedefiUlasma >= 30,
      'badge_adim1': GlobalVeriler.toplamAdimIstatisigi >= 10000,
      'badge_adim2': GlobalVeriler.toplamAdimIstatisigi >= 50000,
      'badge_adim3': GlobalVeriler.toplamAdimIstatisigi >= 150000,
      'badge_kitap1': GlobalVeriler.kitaplar.isNotEmpty,
      'badge_kitap2': GlobalVeriler.kitaplar.length >= 5,
      'badge_kitap3': GlobalVeriler.kitaplar.length >= 20,
      'badge_gorev1': GlobalVeriler.toplamTamamlananGorev >= 10,
      'badge_gorev2': GlobalVeriler.toplamTamamlananGorev >= 50,
      'badge_gorev3': GlobalVeriler.toplamTamamlananGorev >= 150,
    };

    for (var entry in durumlar.entries) {
      if (entry.value == true && !GlobalVeriler.kazanilanRozetler.contains(entry.key)) {
        GlobalVeriler.kazanilanRozetler.add(entry.key);
        GlobalVeriler.verileriKaydet();
        _kutlamaGoster(context, entry.key);
      }
    }
  }

  static void _kutlamaGoster(BuildContext context, String badgeKey) {
    String ikon = ikonlar[badgeKey] ?? '🏆';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 600), 
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut), 
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(c('yeniRozetKazanildi'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber.shade100),
                  child: Text(ikon, style: const TextStyle(fontSize: 60)),
                ),
                const SizedBox(height: 20),
                Text(c(badgeKey), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.amber.shade800), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(c('${badgeKey}_desc'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity, height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.pop(context),
                    child: Text(c('harika'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ]
            )
          )
        );
      }
    );
  }
}

class PusulaApp extends StatelessWidget {
  const PusulaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: DilYoneticisi.instance,
      builder: (context, dilKodu, child) {
        return MaterialApp(
          title: 'Pusula',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFF5F7F8),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD8E9F0)),
            textTheme: GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme).apply(bodyColor: const Color(0xFF2D3436)),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// --- ÇEVİRİ SÖZLÜĞÜ ---
Map<String, Map<String, String>> metinler = {
  'tr': {
    'appTitle': 'Pusula',
    'splashSub': 'Hayatına yön veren dijital rehber.',
    'onboardingTitle': 'Seni Tanıyalım 👋',
    'onboardingSub': 'Rehberini sana özel hale getirebilmemiz için birkaç ufak detaya ihtiyacımız var.',
    'nameLabel': 'Adın Ne?',
    'ageLabel': 'Kaç Yaşındasın?',
    'boyLabel': 'Boy (cm)',
    'kiloLabel': 'Kilo (kg)',
    'durumSoru': 'Şu anki durumun nedir?',
    'gelisimSoru': 'Hangi alanlarda gelişmek istiyorsun?',
    'startBtn': 'Pusula\'yı Başlat',
    'navHome': 'Ana Sayfa',
    'navModules': 'Modüller',
    'navProfile': 'Profil',
    'modulesTitle': 'Modüller',
    'modulesSub': 'İhtiyacına göre Pusula\'yı şekillendir.',
    'activeModules': 'Aktif Modüller',
    'aiCoach': 'Rota',
    'aiWelcome': 'Selam! Ben Rota, yol arkadaşın. Nasıl yardımcı olabilirim?',
    'todayGoals': 'Bugünkü Hedeflerin',
    'profileTitle': 'Profilim',
    'editProfile': 'Profili Düzenle',
    'selectedInterests': 'Seçilen İlgi Alanların',
    'appVersion': 'Uygulama Sürümü',
    'languageSettings': 'Uygulama Dili',
    'odakBaslik': 'Odaklanma',
    'odakAciklama': 'Süre ayarla ve dinlen',
    'kitapBaslik': 'Kitap Takibi',
    'kitapAciklama': 'Okuma süreleri',
    'saglikBaslik': 'Sağlık & Su',
    'saglikAciklama': 'Su, adım ve VKİ',
    'gunlukBaslik': 'Günlük',
    'gunlukAciklama': 'Düşüncelerini yaz',
    'ogrenci': 'Öğrenci',
    'yeniMezun': 'Yeni Mezun',
    'calisan': 'Çalışan',
    'diger': 'Diğer',
    'kaydet': 'Kaydet',
    'iptal': 'İptal',
    'kapat': 'Kapat',
    'ekle': 'Ekle',
    'guncelle': 'Güncelle',
    'tesekkurler': 'Teşekkürler ✨',
    'yeniRozetKazanildi': 'Yeni Rozet Kazandın! 🎉',
    'harika': 'Harika! ✨',
    'gun': 'Gün',
    'kesintisizSeri': 'Kesintisiz Seri',
    'gunlukIlerleme': 'Günlük İlerleme',
    'hedefEmpty': 'Henüz bir hedef eklemedin. (+) butonuna basarak ilk hedefini ekle!',
    'yeniHedefEkle': 'Yeni Hedef Ekle',
    'hedefHint': 'Örn: 20 dakika kitap oku',
    'profilDuzenleBaslik': 'Profili ve Fiziksel Bilgileri Düzenle',
    'adSoyad': 'Ad Soyad',
    'yas': 'Yaş',
    'yasinda': 'yaşında',
    'boyText': 'Boy',
    'kiloText': 'Kilo',
    'avatarSec': 'Profil Avatarını Seç',
    'rehberYorumuBaslik': 'Rotanın Günlük Fısıltısı 🌟',
    'rehberYorumuAlt': 'Bugünkü enerjini keşfetmek için dokun.',
    'rehberYorumuModal': 'Rotanın Günlük Fısıltısı',
    'hedefSure': 'Hedef Süre (dk)',
    'sureyiKaydir': 'Süreyi Seç: ',
    'dakika': ' Dakika',
    'rahatlaticiSes': 'Arka Plan Sesi',
    'odaklanmayiBaslat': 'Başlat 🚀',
    'seansDuraklatildi': 'DURAKLATILDI ⏸️',
    'odaklanmaAkisi': 'ODAKLANMA 🎯',
    'sesBeklemede': 'Beklemede...',
    'arkaPlanOynatiliyor': 'Oynatılıyor:',
    'devamEt': 'Devam Et  ▶️',
    'devamEtModal': 'Devam Et ✨',
    'seansiDuraklat': 'Duraklat ⏸️',
    'odaklanmayiDurdur': 'Durdur 🛑',
    'seansiDurdurBaslik': 'Seansı Durdur',
    'seansCik': 'Evet, Çık',
    'mot1': 'Harika gidiyorsun, bu ivmeyi sakın kaybetme! ✨',
    'mot2': 'Zirveye giden yolda her saniye altın değerinde. 🚀',
    'mot3': 'Odaklanman efsane, şimdi bırakmak için çok erken! 🔥',
    'mot4': 'Küçük adımlar devasa dağları devirir, devam! 🌟',
    'mot5': 'Bugün kendin için harika bir şey yapıyorsun koçum. 🎯',
    'mot6': 'Pes etmek yok, hedefine tırmanıyorsun! 💪',
    'mot7': 'Şu an döktüğün her damla ter, yarınki başarının temeli olacak. 🌻',
    'mot8': 'Azıcık daha dişini sık, ödül muhteşem olacak! 🏆',
    'okumaListem': 'Okuma Listem',
    'yeniKitapEkle': 'Yeni Kitap Ekle',
    'kitapAdiHint': 'Kitap Adı',
    'yazarHint': 'Yazar',
    'listeyeEkle': 'Listeye Ekle',
    'kitapEmpty': 'Henüz kitap eklemedin.',
    'boyKiloGuncelle': 'Boy ve Kilo Güncelle',
    'suHedefiBelirle': 'Su Hedefi Belirle',
    'hedefBardak': 'Hedef Bardak',
    'suEkleBtn': 'Su Ekle',
    'kacBardak': 'Kaç bardak?',
    'suyuEkle': 'Suyu Ekle 💧',
    'adimHedefiBelirle': 'Adım Hedefi Belirle',
    'yeniHedefAdim': 'Yeni Adım Hedefi',
    'adimEkleBtn': 'Adım Ekle',
    'kacAdim': 'Kaç adım?',
    'adimlariEkle': 'Adımları Ekle 🚀',
    'vkiBaslik': 'Vücut Kitle İndeksi',
    'vkiZayif': 'Zayıf 🦴',
    'vkiIdeal': 'İdeal Kilo ✨',
    'vkiHafif': 'Hafif Kilolu ⚖️',
    'vkiObez': 'Obezite ⚠️',
    'hedefiDegistir': 'Değiştir',
    'bardak': 'Bardak',
    'adim': 'Adım',
    'suIlerleme': 'Su İlerlemesi',
    'adimIlerleme': 'Yürüyüş İlerlemesi',
    'anilarinNotlarin': 'Notların',
    'gunlukEmpty': 'Henüz günlük yazmadın.',
    'gunlukYaz': 'Günlük Yaz',
    'gunlukBaslikHint': 'Başlık',
    'gunlukTarihHint': 'Tarih',
    'gunlukIcerikHint': 'Neler hissettin?',
    'gunlugeKaydet': 'Kaydet 📖',
    'benimVaham': 'Benim Vaham 🗺️',
    'vahaKurak': 'Çorak Toprak|🌵',
    'vahaFiliz': 'Filizlenen Tohum|🌱',
    'vahaFidan': 'Yeşeren Fidan|🌿',
    'vahaOrman': 'Görkemli Vaha|🌳',
    'vahaBilgi': 'Hedeflerini tamamlayarak vahanı sula!',
    'damla': 'Damla',
    'pomodoroVaha': 'Tebrikler kanka! Vahanı suladın! 💧🌿',
    'hedefTamamVaha': 'Harika! Vahanı suladın! 💧🌿',
    'vahaYolculugu': 'Vaha Yolculuğun 🗺️',
    'vahaYolculuguBilgi': 'Hedeflerini başardıkça vahan yeşerir:',
    'rozetlerim': 'Rozetlerim 🏆',
    'badge_vaha1': 'Vahadör I', 'badge_vaha1_desc': '2 kere vahanı max yap.',
    'badge_vaha2': 'Vahadör II', 'badge_vaha2_desc': '5 kere vahanı max yap.',
    'badge_vaha3': 'Vahadör III', 'badge_vaha3_desc': '15 kere vahanı max yap.',
    'badge_zaman1': 'Zaman Bükücü I', 'badge_zaman1_desc': '100 Dk odaklan.',
    'badge_zaman2': 'Zaman Bükücü II', 'badge_zaman2_desc': '500 Dk odaklan.',
    'badge_zaman3': 'Zaman Bükücü III', 'badge_zaman3_desc': '1500 Dk odaklan.',
    'badge_yazar1': 'Çaylak Yazar I', 'badge_yazar1_desc': '3 günlük yaz.',
    'badge_yazar2': 'Kıdemli Yazar II', 'badge_yazar2_desc': '10 günlük yaz.',
    'badge_yazar3': 'Başyazar III', 'badge_yazar3_desc': '30 günlük yaz.',
    'badge_su1': 'Su Perisi I', 'badge_su1_desc': '3 gün su hedefine ulaş.',
    'badge_su2': 'Su Perisi II', 'badge_su2_desc': '10 gün su hedefine ulaş.',
    'badge_su3': 'Su Perisi III', 'badge_su3_desc': '30 gün su hedefine ulaş.',
    'badge_adim1': 'Maratoncu I', 'badge_adim1_desc': '10.000 adım at.',
    'badge_adim2': 'Maratoncu II', 'badge_adim2_desc': '50.000 adım at.',
    'badge_adim3': 'Maratoncu III', 'badge_adim3_desc': '150.000 adım at.',
    'badge_kitap1': 'Okur I', 'badge_kitap1_desc': '1 kitap ekle.',
    'badge_kitap2': 'Kitapkurdu II', 'badge_kitap2_desc': '5 kitap ekle.',
    'badge_kitap3': 'Bilge Baykuş III', 'badge_kitap3_desc': '20 kitap ekle.',
    'badge_gorev1': 'Görev Avcısı I', 'badge_gorev1_desc': '10 görev tamamla.',
    'badge_gorev2': 'Görev Avcısı II', 'badge_gorev2_desc': '50 görev tamamla.',
    'badge_gorev3': 'Görev Avcısı III', 'badge_gorev3_desc': '150 görev tamamla.',
    'ilgi_egitim': '📚 Eğitim', 'ilgi_guzellik': '✨ Güzellik', 'ilgi_saglik': '💪 Sağlık', 'ilgi_kitap': '📖 Kitap',
    'ilgi_gelisim': '🧠 Gelişim', 'ilgi_ruh': '😊 Ruh Hali', 'ilgi_yazilim': '💻 Yazılım', 'ilgi_sanat': '🎨 Sanat', 'ilgi_spor': '🏃 Spor',
    'task_egitim': 'Ders notlarını tekrar et', 'task_guzellik': 'Cilt bakımını yap', 'task_saglik': 'Bol su iç',
    'task_kitap': '20 sayfa kitap oku', 'task_gelisim': 'Bugünün planını yap', 'task_ruh': '15 dk dinlen',
    'task_yazilim': '1 saat kodlama yap', 'task_sanat': 'Yeni bir parça keşfet', 'task_spor': '10.000 adım at',
    'defaultTask1': 'Güne 1 bardak su ile başla', 'defaultTask2': 'Bugünün planını yap',
    // YENİ: Temkinli VKI tavsiyeleri
    'vkiTavsiyeZayif': 'BMI sonucunuz Zayıf aralığında. Sağlık hedefleriniz için bir sağlık profesyoneline danışabilirsiniz.',
    'vkiTavsiyeIdeal': 'BMI değeriniz sağlıklı kilo aralığında. BMI yalnızca genel bir değerlendirme ölçütüdür ve sağlık durumunuzun tamamını göstermez.',
    'vkiTavsiyeHafif': 'BMI değeriniz fazla kilolu aralığında. Beslenme ve fiziksel aktivite konusunda kişiselleştirilmiş bilgi için bir sağlık profesyoneline danışabilirsiniz.',
    'vkiTavsiyeObez': 'BMI değeriniz obezite aralığında. Kişisel sağlık hedefleriniz hakkında bilgi almak için bir sağlık profesyoneline danışabilirsiniz.',
    'ses1': 'Yağmur 🌧️', 'ses2': 'Nehir 🌊', 'ses3': 'Kuşlar 🍃', 'ses4': 'Şömine 🔥', 'ses5': 'Ses Yok 🔇',
  },
  'en': {
    'appTitle': 'Pusula',
    'splashSub': 'Your digital guide shaping life.',
    'onboardingTitle': 'Let Us Know You 👋',
    'onboardingSub': 'We need a few details.',
    'nameLabel': 'Name?',
    'ageLabel': 'Age?',
    'boyLabel': 'Height (cm)',
    'kiloLabel': 'Weight (kg)',
    'durumSoru': 'Current status?',
    'gelisimSoru': 'Areas to improve?',
    'startBtn': 'Start',
    'navHome': 'Home',
    'navModules': 'Modules',
    'navProfile': 'Profile',
    'modulesTitle': 'Modules',
    'modulesSub': 'Shape Pusula.',
    'activeModules': 'Active Modules',
    'aiCoach': 'Rota',
    'aiWelcome': 'Hey! I am Rota.',
    'todayGoals': "Today's Goals",
    'profileTitle': 'My Profile',
    'editProfile': 'Edit Profile',
    'selectedInterests': 'Interests',
    'appVersion': 'Version',
    'guide': 'Guide',
    'languageSettings': 'Language',
    'odakBaslik': 'Focus',
    'odakAciklama': 'Set timer',
    'kitapBaslik': 'Books',
    'kitapAciklama': 'Reading times',
    'saglikBaslik': 'Health & Water',
    'saglikAciklama': 'Water & steps',
    'gunlukBaslik': 'Journal',
    'gunlukAciklama': 'Write down',
    'ogrenci': 'Student',
    'yeniMezun': 'New Graduate',
    'calisan': 'Employee',
    'diger': 'Other',
    'kaydet': 'Save',
    'iptal': 'Cancel',
    'kapat': 'Close',
    'ekle': 'Add',
    'guncelle': 'Update',
    'tesekkurler': 'Thanks ✨',
    'yeniRozetKazanildi': 'New Badge! 🎉',
    'harika': 'Awesome! ✨',
    'gun': 'Days',
    'kesintisizSeri': 'Streak',
    'gunlukIlerleme': 'Progress',
    'hedefEmpty': 'No goals yet.',
    'yeniHedefEkle': 'Add Goal',
    'hedefHint': 'Ex: Read book',
    'profilDuzenleBaslik': 'Edit Profile',
    'adSoyad': 'Full Name',
    'yas': 'Age',
    'yasinda': 'years old',
    'boyText': 'Height',
    'kiloText': 'Weight',
    'avatarSec': 'Avatar',
    'rehberYorumuBaslik': 'Daily Whisper 🌟',
    'rehberYorumuAlt': 'Tap for inspiration.',
    'rehberYorumuModal': 'Daily Whisper',
    'hedefSure': 'Goal Time (min)',
    'sureyiKaydir': 'Set Timer: ',
    'dakika': ' Min',
    'rahatlaticiSes': 'Sound',
    'odaklanmayiBaslat': 'Start 🚀',
    'seansDuraklatildi': 'PAUSED ⏸️',
    'odaklanmaAkisi': 'FOCUS 🎯',
    'sesBeklemede': 'Standby...',
    'arkaPlanOynatiliyor': 'Playing:',
    'devamEt': 'Continue  ▶️',
    'devamEtModal': 'Continue ✨',
    'seansiDuraklat': 'Pause ⏸️',
    'odaklanmayiDurdur': 'Stop 🛑',
    'seansiDurdurBaslik': 'Stop',
    'seansCik': 'Yes',
    'mot1': 'Great progress! ✨',
    'mot2': 'Precious seconds. 🚀',
    'mot3': 'Keep going! 🔥',
    'mot4': 'Small steps! 🌟',
    'mot5': 'Doing great! 🎯',
    'mot6': 'Don\'t give up! 💪',
    'mot7': 'Future success. 🌻',
    'mot8': 'Worth it! 🏆',
    'okumaListem': 'Reading List',
    'yeniKitapEkle': 'Add Book',
    'kitapAdiHint': 'Title',
    'yazarHint': 'Author',
    'listeyeEkle': 'Add',
    'kitapEmpty': 'No books.',
    'boyKiloGuncelle': 'Update Height/Weight',
    'suHedefiBelirle': 'Water Goal',
    'hedefBardak': 'Glasses',
    'suEkleBtn': 'Add Water',
    'kacBardak': 'Glasses?',
    'suyuEkle': 'Add 💧',
    'adimHedefiBelirle': 'Step Goal',
    'yeniHedefAdim': 'New Step',
    'adimEkleBtn': 'Add Steps',
    'kacAdim': 'Steps?',
    'adimlariEkle': 'Add 🚀',
    'vkiBaslik': 'BMI',
    'vkiZayif': 'Underweight 🦴',
    'vkiIdeal': 'Ideal ✨',
    'vkiHafif': 'Overweight ⚖️',
    'vkiObez': 'Obese ⚠️',
    'hedefiDegistir': 'Change',
    'bardak': 'Glasses',
    'adim': 'Steps',
    'suIlerleme': 'Water Progress',
    'adimIlerleme': 'Walking Progress',
    'anilarinNotlarin': 'Notes',
    'gunlukEmpty': 'No entries.',
    'gunlukYaz': 'Write',
    'gunlukBaslikHint': 'Title',
    'gunlukTarihHint': 'Date',
    'gunlukIcerikHint': 'How did you feel?',
    'gunlugeKaydet': 'Save 📖',
    'benimVaham': 'My Oasis 🗺️',
    'vahaKurak': 'Barren Land|🌵',
    'vahaFiliz': 'Sprouting Seed|🌱',
    'vahaFidan': 'Green Sapling|🌿',
    'vahaOrman': 'Glorious Oasis|🌳',
    'vahaBilgi': 'Water your oasis!',
    'damla': 'Drops',
    'pomodoroVaha': 'Watered oasis! 💧🌿',
    'hedefTamamVaha': 'Watered oasis! 💧🌿',
    'vahaYolculugu': 'Oasis Journey 🗺️',
    'vahaYolculuguBilgi': 'Progress:',
    'rozetlerim': 'Badges 🏆',
    'badge_vaha1': 'Master I', 'badge_vaha1_desc': 'Max 2 times.',
    'badge_vaha2': 'Master II', 'badge_vaha2_desc': 'Max 5 times.',
    'badge_vaha3': 'Master III', 'badge_vaha3_desc': 'Max 15 times.',
    'badge_zaman1': 'Bender I', 'badge_zaman1_desc': 'Focus 100m.',
    'badge_zaman2': 'Bender II', 'badge_zaman2_desc': 'Focus 500m.',
    'badge_zaman3': 'Bender III', 'badge_zaman3_desc': 'Focus 1500m.',
    'badge_yazar1': 'Writer I', 'badge_yazar1_desc': '3 entries.',
    'badge_yazar2': 'Writer II', 'badge_yazar2_desc': '10 entries.',
    'badge_yazar3': 'Writer III', 'badge_yazar3_desc': '30 entries.',
    'badge_su1': 'Spirit I', 'badge_su1_desc': 'Water goal 3d.',
    'badge_su2': 'Spirit II', 'badge_su2_desc': 'Water goal 10d.',
    'badge_su3': 'Spirit III', 'badge_su3_desc': 'Water goal 30d.',
    'badge_adim1': 'Marathoner I', 'badge_adim1_desc': '10k steps.',
    'badge_adim2': 'Marathoner II', 'badge_adim2_desc': '50k steps.',
    'badge_adim3': 'Marathoner III', 'badge_adim3_desc': '150k steps.',
    'badge_kitap1': 'Reader I', 'badge_kitap1_desc': '1 book.',
    'badge_kitap2': 'Bookworm II', 'badge_kitap2_desc': '5 books.',
    'badge_kitap3': 'Wise Owl III', 'badge_kitap3_desc': '20 books.',
    'badge_gorev1': 'Hunter I', 'badge_gorev1_desc': '10 tasks.',
    'badge_gorev2': 'Hunter II', 'badge_gorev2_desc': '50 tasks.',
    'badge_gorev3': 'Hunter III', 'badge_gorev3_desc': '150 tasks.',
    'ilgi_egitim': '📚 Education', 'ilgi_guzellik': '✨ Beauty', 'ilgi_saglik': '💪 Health', 'ilgi_kitap': '📖 Books',
    'ilgi_gelisim': '🧠 Growth', 'ilgi_ruh': '😊 Mood', 'ilgi_yazilim': '💻 Coding', 'ilgi_sanat': '🎨 Art', 'ilgi_spor': '🏃 Sports',
    'task_egitim': 'Review notes', 'task_guzellik': 'Skincare', 'task_saglik': 'Drink water',
    'task_kitap': 'Read 20 pages', 'task_gelisim': 'Daily plan', 'task_ruh': 'Relax 15m',
    'task_yazilim': 'Code 1h', 'task_sanat': 'New track', 'task_spor': '10k steps',
    'defaultTask1': 'Water glass', 'defaultTask2': 'Plan day',
    'vkiTavsiyeZayif': 'Your BMI falls within the Underweight range. For personalized health advice, consider consulting a qualified healthcare professional.',
    'vkiTavsiyeIdeal': 'Your BMI falls within the Healthy Weight range. BMI is only one general measure and does not provide a complete assessment of your health.',
    'vkiTavsiyeHafif': 'Your BMI falls within the Overweight range. For personalized guidance about nutrition and physical activity, consider consulting a qualified healthcare professional.',
    'vkiTavsiyeObez': 'Your BMI falls within the Obesity range. For personalized health guidance, consider consulting a qualified healthcare professional.',
    
    'ses1': 'Rain 🌧️', 'ses2': 'River 🌊', 'ses3': 'Birds 🍃', 'ses4': 'Fire 🔥', 'ses5': 'None 🔇',
  }
};

String c(String anahtar) {
  String dil = DilYoneticisi.instance.value;
  return metinler[dil]?[anahtar] ?? metinler['tr']![anahtar] ?? anahtar;
}

final List<String> ilgiAlaniAnahtarlari = [
  'ilgi_egitim', 'ilgi_guzellik', 'ilgi_saglik', 'ilgi_kitap', 'ilgi_gelisim',
  'ilgi_ruh', 'ilgi_yazilim', 'ilgi_sanat', 'ilgi_spor'
];

// --- AÇILIŞ KONTROLÜ VE SPLASH EKRANI ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _yonlendir();
  }

void _yonlendir() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    var box = Hive.box('pusula_box');
    String kayitliIsim = box.get('kullanici_adi', defaultValue: '');

    if (kayitliIsim.isNotEmpty) {
      List<String> alanlar = List<String>.from(box.get('kullanici_alanlar', defaultValue: []));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AnaSayfa(
            ilgiAlanlariAnahtarlari: alanlar,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.compass_calibration_rounded, size: 100, color: Color(0xFFC4DBE0)),
            const SizedBox(height: 20),
            Text(c('appTitle'), style: GoogleFonts.nunito(fontSize: 40, fontWeight: FontWeight.w900, color: const Color(0xFF2D3436), letterSpacing: 2)),
            const SizedBox(height: 10),
            Text(c('splashSub'), style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Color(0xFFC4DBE0)),
          ],
        ),
      ),
    );
  }
}

// --- ONBOARDING EKRANI ---
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _yasController = TextEditingController();
  final TextEditingController _boyController = TextEditingController();
  final TextEditingController _kiloController = TextEditingController();
  
  String _seciliMeslekKodu = 'ogrenci';
  final Map<String, bool> _seciliAlanlar = {};

  @override
  void initState() {
    super.initState();
    for (var key in ilgiAlaniAnahtarlari) {
      _seciliAlanlar[key] = false;
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _yasController.dispose();
    _boyController.dispose();
    _kiloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> meslekKodlari = ['ogrenci', 'yeniMezun', 'calisan', 'diger'];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      c('onboardingTitle'), 
                      style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownButton<String>(
                    value: DilYoneticisi.instance.value,
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('🇹🇷 TR')),
                      DropdownMenuItem(value: 'en', child: Text('🇬🇧 EN')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          DilYoneticisi.instance.value = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(c('onboardingSub'), style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5)),
              const SizedBox(height: 25),
              
              TextField(
                controller: _adController,
                decoration: InputDecoration(
                  labelText: c('nameLabel'), filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _yasController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: c('ageLabel'), filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.cake_outlined, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _boyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: c('boyLabel'), filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.height, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _kiloController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: c('kiloLabel'), filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.monitor_weight_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Text(c('durumSoru'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true, 
                    value: _seciliMeslekKodu,
                    items: meslekKodlari.map((String kod) {
                      return DropdownMenuItem<String>(
                        value: kod, 
                        child: Text(c(kod))
                      );
                    }).toList(),
                    onChanged: (String? yeni) { if (yeni != null) setState(() => _seciliMeslekKodu = yeni); },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(c('gelisimSoru'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ilgiAlaniAnahtarlari.map((String key) {
                  return FilterChip(
                    label: Text(c(key)), selected: _seciliAlanlar[key]!,
                    selectedColor: const Color(0xFFC4DBE0), checkmarkColor: Colors.white, backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: _seciliAlanlar[key]! ? Colors.white : Colors.grey.shade700, fontWeight: _seciliAlanlar[key]! ? FontWeight.bold : FontWeight.normal),
                    onSelected: (bool secildiMi) { setState(() => _seciliAlanlar[key] = secildiMi); },
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3436),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    String girilenIsim = _adController.text.trim();
                    if (girilenIsim.isEmpty) girilenIsim = 'Yolcu';

                    String girilenYas = _yasController.text.trim();
                    if (girilenYas.isEmpty) girilenYas = '21';

                    double girilenBoy = double.tryParse(_boyController.text.trim()) ?? 175.0;
                    double girilenKilo = double.tryParse(_kiloController.text.trim()) ?? 70.0;

                    List<String> secilenler = _seciliAlanlar.entries
                        .where((element) => element.value == true)
                        .map((e) => e.key)
                        .toList();
                    
                    var box = Hive.box('pusula_box');
                    await box.put('kullanici_adi', girilenIsim);
                    await box.put('kullanici_yas', int.tryParse(girilenYas) ?? 21);
                    await box.put('kullanici_boy', girilenBoy);
                    await box.put('kullanici_kilo', girilenKilo);
                    await box.put('kullanici_meslek', _seciliMeslekKodu);
                    await box.put('kullanici_alanlar', secilenler);

                    GlobalVeriler.seriKontrolEt();

                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => AnaSayfa(
                          ilgiAlanlariAnahtarlari: secilenler,
                        )
                      )
                    );
                  },
                  child: Text(c('startBtn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ANA SAYFA ---
class AnaSayfa extends StatefulWidget {
  final List<String> ilgiAlanlariAnahtarlari;
  
  const AnaSayfa({
    super.key, 
    required this.ilgiAlanlariAnahtarlari
  });

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _seciliSekme = 0;

  @override
  void initState() {
    super.initState();
    GlobalVeriler.seriKontrolEt();

    if (GlobalVeriler.hedefler.isEmpty) {
      if (widget.ilgiAlanlariAnahtarlari.isEmpty) {
        GlobalVeriler.hedefler.add({'baslik': 'defaultTask1', 'tamamlandi': false, 'isKey': true});
        GlobalVeriler.hedefler.add({'baslik': 'defaultTask2', 'tamamlandi': false, 'isKey': true});
      } else {
        for (String key in widget.ilgiAlanlariAnahtarlari) {
          String taskKey = key.replaceFirst('ilgi_', 'task_');
          GlobalVeriler.hedefler.add({'baslik': taskKey, 'tamamlandi': false, 'isKey': true});
        }
      }
      GlobalVeriler.verileriKaydet();
    }
  }

  void _ekraniTazele() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> sayfalar = [
      DashboardGorunumu(ilgiAlanlari: widget.ilgiAlanlariAnahtarlari), 
      ModullerSayfasi(onBilgiGuncellendi: _ekraniTazele), 
      ProfilSayfasi(
        ilgiAlanlariAnahtarlari: widget.ilgiAlanlariAnahtarlari,
        onBilgiGuncellendi: _ekraniTazele
      ),
    ];

    return Scaffold(
      body: sayfalar[_seciliSekme],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSekme,
        onTap: (index) => setState(() => _seciliSekme = index),
        selectedItemColor: const Color(0xFF2D3436), 
        unselectedItemColor: Colors.grey.shade400,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: c('navHome')),
          BottomNavigationBarItem(icon: const Icon(Icons.grid_view_rounded), label: c('navModules')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: c('navProfile')),
        ],
      ),
    );
  }
}

// --- DASHBOARD ---
class DashboardGorunumu extends StatefulWidget {
  final List<String> ilgiAlanlari;
  
  const DashboardGorunumu({super.key, required this.ilgiAlanlari});

  @override
  State<DashboardGorunumu> createState() => _DashboardGorunumuState();
}

class _DashboardGorunumuState extends State<DashboardGorunumu> {
  int get ilerlemeYuzdesi {
    if (GlobalVeriler.hedefler.isEmpty) return 0;
    int tamamlanan = GlobalVeriler.hedefler.where((hedef) => hedef['tamamlandi'] == true).length;
    return ((tamamlanan / GlobalVeriler.hedefler.length) * 100).toInt();
  }

  void _yeniHedefEklePenceresi() {
    final TextEditingController hedefController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('yeniHedefEkle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: hedefController,
                autofocus: true, 
                decoration: InputDecoration(
                  hintText: c('hedefHint'),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true, fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    if (hedefController.text.trim().isNotEmpty) {
                      setState(() {
                        GlobalVeriler.hedefler.add({'baslik': hedefController.text.trim(), 'tamamlandi': false, 'isKey': false});
                        GlobalVeriler.verileriKaydet();
                      });
                      Navigator.pop(sheetContext); 
                    }
                  },
                  child: Text(c('ekle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  String _selamlamaMesajiGetir() {
    final saat = DateTime.now().hour;
    if (saat >= 5 && saat < 12) return DilYoneticisi.instance.value == 'tr' ? 'Günaydın' : 'Good Morning';
    if (saat >= 12 && saat < 18) return DilYoneticisi.instance.value == 'tr' ? 'İyi Günler' : 'Good Afternoon';
    if (saat >= 18 && saat < 23) return DilYoneticisi.instance.value == 'tr' ? 'İyi Akşamlar' : 'Good Evening';
    return DilYoneticisi.instance.value == 'tr' ? 'İyi Geceler' : 'Good Night';
  }

String _saatEmojisiGetir() {
    final saat = DateTime.now().hour;
    if (saat >= 5 && saat < 12) return '🌅'; 
    if (saat >= 12 && saat < 18) return '☀️'; 
    if (saat >= 18 && saat < 23) return '🌙'; 
    return '🌙'; 
  }

  void _aiKocSohbetAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RotaSohbetPenceresi(),
    );
  }

  void _vahaYolculugunuGoster(BuildContext context, int mevcutPuan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c('vahaYolculugu'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(c('vahaYolculuguBilgi'), style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
              const SizedBox(height: 30),
              _yolculukAdimi(c('vahaKurak').split('|')[0], 0, mevcutPuan, Colors.orange.shade100, Icons.landscape_rounded),
              _yolculukAdimi(c('vahaFiliz').split('|')[0], 20, mevcutPuan, Colors.lightGreen.shade200, Icons.eco_outlined),
              _yolculukAdimi(c('vahaFidan').split('|')[0], 50, mevcutPuan, Colors.green.shade200, Icons.park_outlined),
              _yolculukAdimi(c('vahaOrman').split('|')[0], 100, mevcutPuan, Colors.green.shade400, Icons.forest_rounded, isLast: true),
              const SizedBox(height: 30),
            ],
          ),
        );
      }
    );
  }

  Widget _yolculukAdimi(String baslik, int hedefPuan, int mevcutPuan, Color renk, IconData ikon, {bool isLast = false}) {
    bool ulasildi = mevcutPuan >= hedefPuan;
    bool sonrakiUlasildi = mevcutPuan >= (hedefPuan == 0 ? 20 : (hedefPuan == 20 ? 50 : 100));
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: ulasildi ? renk : Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: ulasildi ? Colors.green.shade700 : Colors.transparent, width: 2)),
              child: Icon(ikon, color: ulasildi ? Colors.black87 : Colors.grey, size: 24),
            ),
            if (!isLast)
              Container(width: 6, height: 40, decoration: BoxDecoration(color: ulasildi && sonrakiUlasildi ? Colors.green.shade400 : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)))
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ulasildi ? Colors.black87 : Colors.grey)),
                const SizedBox(height: 4),
                Text('$hedefPuan ${c('damla')}', style: TextStyle(color: ulasildi ? Colors.green.shade700 : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String guncelAd = Hive.box('pusula_box').get('kullanici_adi', defaultValue: 'Yolcu');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_selamlamaMesajiGetir()} $guncelAd ${_saatEmojisiGetir()}', style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Text('🔥 ${GlobalVeriler.kesintisizSeri} ${c('gun')}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(c('kesintisizSeri'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(width: 50, height: 50, child: CircularProgressIndicator(value: ilerlemeYuzdesi / 100, backgroundColor: Colors.grey.shade100, color: const Color(0xFFC4DBE0), strokeWidth: 5)),
                            Text('%$ilerlemeYuzdesi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3436))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(c('gunlukIlerleme'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            ValueListenableBuilder<int>(
              valueListenable: VahaYoneticisi.instance,
              builder: (context, vahaPuani, child) {
                String vahaHam = c('vahaKurak');
                Color vahaRenk = Colors.orange.shade100;
                double progress = vahaPuani / 100.0;
                if (progress > 1.0) progress = 1.0;

                if (vahaPuani >= 100) {
                  vahaHam = c('vahaOrman');
                  vahaRenk = Colors.green.shade400;
                } else if (vahaPuani >= 50) {
                  vahaHam = c('vahaFidan');
                  vahaRenk = Colors.green.shade200;
                } else if (vahaPuani >= 20) {
                  vahaHam = c('vahaFiliz');
                  vahaRenk = Colors.lightGreen.shade200;
                }
                
                List<String> vahaParts = vahaHam.split('|');
                String vahaBaslik = vahaParts[0];
                String vahaIkon = vahaParts.length > 1 ? vahaParts[1] : '';

                return GestureDetector(
                  onTap: () => _vahaYolculugunuGoster(context, vahaPuani),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(c('benimVaham'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2D3436))),
                            Text('$vahaPuani ${c('damla')} 💧', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(color: vahaRenk, shape: BoxShape.circle),
                              child: Center(child: Text(vahaIkon, style: const TextStyle(fontSize: 30))),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vahaBaslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 5),
                                  LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, color: Colors.green, minHeight: 8, borderRadius: BorderRadius.circular(10)),
                                  const SizedBox(height: 5),
                                  Text(c('vahaBilgi'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 25),

            GestureDetector(
              onTap: _aiKocSohbetAc,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFC4DBE0), Color(0xFFD8E9F0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/rota.gif', width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.smart_toy_rounded, size: 40, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c('aiCoach'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3436))),
                          const SizedBox(height: 5),
                          Text(
                            DilYoneticisi.instance.value == 'tr' 
                              ? 'Selam! Ben Rota, yol arkadaşın. Sohbet etmek için dokun 🧭' 
                              : 'Hey! I am Rota, your buddy. Tap to chat 🧭',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436), height: 1.4, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c('todayGoals'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _yeniHedefEklePenceresi, icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2D3436), size: 28))
              ],
            ),
            const SizedBox(height: 10),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: GlobalVeriler.hedefler.isEmpty 
              ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(c('hedefEmpty'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14))))
              : Column(
                  children: GlobalVeriler.hedefler.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> hedef = entry.value;
                    String baslikMetni = hedef['isKey'] ? c(hedef['baslik']) : hedef['baslik'];

                    return Column(
                      children: [
                        Dismissible(
                          key: UniqueKey(),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: const BoxDecoration(color: Color(0xFFFF6B6B), borderRadius: BorderRadius.all(Radius.circular(15))),
                            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) {
                            setState(() {
                              GlobalVeriler.hedefler.removeAt(index);
                              GlobalVeriler.verileriKaydet();
                            });
                          },
                          child: CheckboxListTile(
                            title: Text(baslikMetni, style: TextStyle(decoration: hedef['tamamlandi'] ? TextDecoration.lineThrough : null, color: hedef['tamamlandi'] ? Colors.grey : Colors.black)),
                            value: hedef['tamamlandi'], 
                            activeColor: const Color(0xFFC4DBE0),
                            onChanged: (val) {
                              setState(() {
                                GlobalVeriler.hedefler[index]['tamamlandi'] = val!;
                              });
                              if (val == true) {
                                VahaYoneticisi.instance.suEkle(context, 10);
                                GlobalVeriler.toplamTamamlananGorev++; 
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c('hedefTamamVaha')), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
                              } else {
                                VahaYoneticisi.instance.suEkle(context, -10);
                                GlobalVeriler.toplamTamamlananGorev--; 
                              }
                              GlobalVeriler.verileriKaydet();
                              RozetYoneticisi.kontrolEt(context);
                            },
                          ),
                        ),
                        if (index != GlobalVeriler.hedefler.length - 1)
                          const Divider(height: 1, indent: 20, endIndent: 20),
                      ],
                    );
                  }).toList(),
                ),
            )
          ],
        ),
      ),
    );
  }
}

// --- ROTA CHATBOT SOHBET EKRANI ---
class RotaSohbetPenceresi extends StatefulWidget {
  const RotaSohbetPenceresi({super.key});

  @override
  State<RotaSohbetPenceresi> createState() => _RotaSohbetPenceresiState();
}

class _RotaSohbetPenceresiState extends State<RotaSohbetPenceresi> {
  final TextEditingController _mesajController = TextEditingController();
  final List<Map<String, dynamic>> _mesajlar = [];
  bool _yaziyor = false;

  @override
  void initState() {
    super.initState();
    bool tr = DilYoneticisi.instance.value == 'tr';
    _mesajlar.add({'isUser': false, 'text': tr ? 'Selam kanka! Ben Rota. Hedeflerin veya odaklanma seansların hakkında bana yazabilirsin.' : 'Hey buddy! I am Rota. Ask me anything about your goals or focus sessions.'});
  }

  void _mesajGonder() async {
    String text = _mesajController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _mesajlar.add({'isUser': true, 'text': text});
      _yaziyor = true;
    });
    _mesajController.clear();

    String dil = DilYoneticisi.instance.value;
    String aiYaniti = await RotaServis.mesajGonder(text, dil);

    if (!mounted) return;
    setState(() {
      _yaziyor = false;
      _mesajlar.add({'isUser': false, 'text': aiYaniti});
    });
  }

  @override
  Widget build(BuildContext context) {
    bool tr = DilYoneticisi.instance.value == 'tr';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Color(0xFFF5F7F8), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/rota.gif', width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.smart_toy_rounded, size: 40))),
                const SizedBox(width: 15),
                Text(tr ? 'Rota (Yapay Zeka Dostun)' : 'Rota (AI Buddy)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _mesajlar.length,
              itemBuilder: (context, index) {
                bool isUser = _mesajlar[index]['isUser'];
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2D3436) : Colors.white,
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0), bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20)),
                      boxShadow: [if (!isUser) BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
                    ),
                    child: Text(_mesajlar[index]['text'], style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          if (_yaziyor)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(alignment: Alignment.centerLeft, child: Text(tr ? 'Rota düşünüyor...' : 'Rota is thinking...', style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajController,
                    decoration: InputDecoration(
                      hintText: tr ? 'Rotaya bir şeyler sor...' : 'Ask Rota something...',
                      filled: true, fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onSubmitted: (value) => _mesajGonder(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _mesajGonder,
                  child: Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Color(0xFFC4DBE0), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Color(0xFF2D3436))),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- MODÜLLER EKRANI ---
class ModullerSayfasi extends StatelessWidget {
  final Function() onBilgiGuncellendi;

  const ModullerSayfasi({super.key, required this.onBilgiGuncellendi});

  void _gununRehberYorumunuGoster(BuildContext context) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFC4DBE0))),
    );

    String dil = DilYoneticisi.instance.value;
    String guncelAd = Hive.box('pusula_box').get('kullanici_adi', defaultValue: 'Yolcu');
    String gununFisiltisi = await RotaServis.getGununSozu(guncelAd, dil);

    if (!context.mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFC4DBE0)), 
              const SizedBox(width: 10), 
              Text(c('rehberYorumuModal'), style: const TextStyle(fontSize: 18))
            ],
          ),
          content: Text(
            '"$gununFisiltisi"', 
            style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF2D3436), fontStyle: FontStyle.italic),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(c('tesekkurler'), style: const TextStyle(color: Color(0xFF2D3436), fontWeight: FontWeight.bold))
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> moduller = [
      {'baslik': c('odakBaslik'), 'aciklama': c('odakAciklama'), 'ikon': Icons.timer_rounded, 'renk': const Color(0xFFC4DBE0), 'sayfa': const OdakModuluSayfasi()},
      {'baslik': c('kitapBaslik'), 'aciklama': c('kitapAciklama'), 'ikon': Icons.book_rounded, 'renk': const Color(0xFFD8E9F0), 'sayfa': const KitapTakibiSayfasi()},
      {'baslik': c('saglikBaslik'), 'aciklama': c('saglikAciklama'), 'ikon': Icons.favorite_rounded, 'renk': const Color(0xFFFFD3B6), 'sayfa': SaglikSuSayfasi(onBilgiGuncellendi: onBilgiGuncellendi)},
      {'baslik': c('gunlukBaslik'), 'aciklama': c('gunlukAciklama'), 'ikon': Icons.edit_note_rounded, 'renk': const Color(0xFFDCEDC1), 'sayfa': const GunlukYazmaSayfasi()},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c('modulesTitle'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(c('modulesSub'), style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: () => _gununRehberYorumunuGoster(context),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2D3436), Color(0xFF636e72)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny_rounded, size: 40, color: Colors.white),
                    const SizedBox(width: 15),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c('rehberYorumuBaslik'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)), const SizedBox(height: 5), Text(c('rehberYorumuAlt'), style: const TextStyle(fontSize: 13, color: Colors.white70))])),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(c('activeModules'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.05),
              itemCount: moduller.length,
              itemBuilder: (context, index) {
                var modul = moduller[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => modul['sayfa'])),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, spreadRadius: 1, offset: const Offset(0, 3))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: modul['renk'], borderRadius: BorderRadius.circular(12)), child: Icon(modul['ikon'], color: const Color(0xFF2D3436), size: 24)),
                        const SizedBox(height: 12),
                        Text(modul['baslik'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(modul['aciklama'], style: TextStyle(color: Colors.grey.shade600, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- ODAKLANMA (POMODORO) SAYFASI ---
class OdakModuluSayfasi extends StatefulWidget {
  const OdakModuluSayfasi({super.key});

  @override
  State<OdakModuluSayfasi> createState() => _OdakModuluSayfasiState();
}

class _OdakModuluSayfasiState extends State<OdakModuluSayfasi> {
  Timer? _geriSayimTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _geriSayimTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _odaklanmayiBaslat() {
    setState(() {
      GlobalVeriler.odakAktif = true;
      GlobalVeriler.odakDuraklatildi = false;
      GlobalVeriler.kalanSaniye = (GlobalVeriler.secilenDakika.toInt()) * 60;
    });

    _arkaPlanSesiniOynat();

    _geriSayimTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!GlobalVeriler.odakDuraklatildi) {
        setState(() {
          if (GlobalVeriler.kalanSaniye > 0) {
            GlobalVeriler.kalanSaniye--;
          } else {
            _timerDurdur();
            GlobalVeriler.odakAktif = false;
            VahaYoneticisi.instance.suEkle(context, 25);
            GlobalVeriler.toplamOdaklanmaDk += GlobalVeriler.secilenDakika.toInt(); 
            GlobalVeriler.verileriKaydet();
            RozetYoneticisi.kontrolEt(context);
            
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c('pomodoroVaha')), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
          }
        });
      }
    });
  }

  void _arkaPlanSesiniOynat() async {
    if (GlobalVeriler.secilenSesKodu == 'ses5') return;
    
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    Map<String, String> sesDosyalari = {
      'ses1': 'sounds/yagmur.mp3',
      'ses2': 'sounds/nehir.mp3',
      'ses3': 'sounds/kuslar.mp3',
      'ses4': 'sounds/somine.mp3',
    };
    
    String? yol = sesDosyalari[GlobalVeriler.secilenSesKodu];
    if (yol != null) {
      await _audioPlayer.play(AssetSource(yol));
    }
  }

  void _timerDurdur() {
    _geriSayimTimer?.cancel();
    _geriSayimTimer = null;
    _audioPlayer.stop();
  }

  void _duraklatVeyaDevamEt() {
    setState(() {
      GlobalVeriler.odakDuraklatildi = !GlobalVeriler.odakDuraklatildi;
      if (GlobalVeriler.odakDuraklatildi) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.resume();
      }
    });
  }

  void _cikisOnayiIste() {
    List<String> motivasyonAnahtarlari = ['mot1', 'mot2', 'mot3', 'mot4', 'mot5', 'mot6', 'mot7', 'mot8'];
    String rastgeleAnahtar = motivasyonAnahtarlari[Random().nextInt(motivasyonAnahtarlari.length)];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(c('seansiDurdurBaslik')),
          content: Text(c(rastgeleAnahtar), style: const TextStyle(fontSize: 16, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(c('devamEtModal'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            TextButton(onPressed: () { Navigator.pop(context); setState(() { _timerDurdur(); GlobalVeriler.odakAktif = false; }); }, child: Text(c('seansCik'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
        );
      },
    );
  }

  String _formatKalanSure() {
    int dakika = GlobalVeriler.kalanSaniye ~/ 60;
    int saniye = GlobalVeriler.kalanSaniye % 60;
    return '${dakika.toString().padLeft(2, '0')}:${saniye.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (GlobalVeriler.odakAktif) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(GlobalVeriler.odakDuraklatildi ? c('seansDuraklatildi') : c('odaklanmaAkisi'), style: TextStyle(color: GlobalVeriler.odakDuraklatildi ? Colors.amber : Colors.redAccent, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.volume_up_rounded, color: GlobalVeriler.odakDuraklatildi ? Colors.grey : Colors.greenAccent, size: 18), const SizedBox(width: 8), Text(GlobalVeriler.odakDuraklatildi ? c('sesBeklemede') : '${c('arkaPlanOynatiliyor')} ${c(GlobalVeriler.secilenSesKodu)}', style: const TextStyle(color: Colors.white70, fontSize: 14))]),
                const SizedBox(height: 60),
                Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GlobalVeriler.odakDuraklatildi ? Colors.amber : Colors.red, width: 4), boxShadow: [BoxShadow(color: (GlobalVeriler.odakDuraklatildi ? Colors.amber : Colors.red).withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)]),
                  child: Center(child: Text(_formatKalanSure(), style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: GlobalVeriler.odakDuraklatildi ? Colors.amber : Colors.red, letterSpacing: 2))),
                ),
                const SizedBox(height: 60),
                SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: GlobalVeriler.odakDuraklatildi ? Colors.green : Colors.amber.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _duraklatVeyaDevamEt, child: Text(GlobalVeriler.odakDuraklatildi ? c('devamEt') : c('seansiDuraklat'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
                const SizedBox(height: 15),
                SizedBox(width: double.infinity, height: 55, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _cikisOnayiIste, child: Text(c('odaklanmayiDurdur'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)))),
              ],
            ),
          ),
        ),
      );
    }

    List<String> sesKodlari = ['ses1', 'ses2', 'ses3', 'ses4', 'ses5'];

    return Scaffold(
      appBar: AppBar(title: Text(c('odakBaslik'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), backgroundColor: const Color(0xFFF5F7F8), elevation: 0, foregroundColor: const Color(0xFF2D3436)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 15, spreadRadius: 5)]),
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${GlobalVeriler.secilenDakika.toInt()}:00', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF2D3436))), const SizedBox(height: 5), Text(c('hedefSure'), style: const TextStyle(color: Colors.grey, fontSize: 14))])),
            ),
            const SizedBox(height: 30),
            Align(alignment: Alignment.centerLeft, child: Text('${c('sureyiKaydir')}${GlobalVeriler.secilenDakika.toInt()}${c('dakika')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 10),
            Slider(value: GlobalVeriler.secilenDakika, min: 1, max: 120, divisions: 119, activeColor: const Color(0xFF2D3436), inactiveColor: Colors.grey.shade300, label: '${GlobalVeriler.secilenDakika.toInt()} dk', onChanged: (double yeniDeger) { setState(() { GlobalVeriler.secilenDakika = yeniDeger; }); }),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerLeft, child: Text(c('rahatlaticiSes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true, value: GlobalVeriler.secilenSesKodu,
                  items: sesKodlari.map((kod) => DropdownMenuItem(value: kod, child: Text(c(kod)))).toList(),
                  onChanged: (yeniKodu) { if (yeniKodu != null) setState(() => GlobalVeriler.secilenSesKodu = yeniKodu); },
                ),
              ),
            ),
            const Spacer(),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _odaklanmayiBaslat, child: Text(c('odaklanmayiBaslat'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- KİTAP TAKİBİ MODÜLÜ ---
class KitapTakibiSayfasi extends StatefulWidget {
  const KitapTakibiSayfasi({super.key});

  @override
  State<KitapTakibiSayfasi> createState() => _KitapTakibiSayfasiState();
}

class _KitapTakibiSayfasiState extends State<KitapTakibiSayfasi> {
  void _kitapEklePenceresi() {
    final TextEditingController isimController = TextEditingController();
    final TextEditingController yazarController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('yeniKitapEkle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: isimController, decoration: InputDecoration(hintText: c('kitapAdiHint'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              TextField(controller: yazarController, decoration: InputDecoration(hintText: c('yazarHint'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    if (isimController.text.trim().isNotEmpty) {
                      setState(() {
                        GlobalVeriler.kitaplar.add({'isim': isimController.text.trim(), 'yazar': yazarController.text.trim().isEmpty ? 'Bilinmiyor' : yazarController.text.trim()});
                        GlobalVeriler.verileriKaydet();
                      });
                      Navigator.pop(sheetContext);
                      RozetYoneticisi.kontrolEt(context);
                    }
                  },
                  child: Text(c('listeyeEkle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(c('kitapBaslik'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFFF5F7F8), elevation: 0, foregroundColor: const Color(0xFF2D3436)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c('okumaListem'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _kitapEklePenceresi, icon: const Icon(Icons.add_circle_outline, size: 28)),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: GlobalVeriler.kitaplar.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book_rounded, size: 60, color: Colors.grey.shade400), const SizedBox(height: 10), Text(c('kitapEmpty'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4))]))
                  : ListView.builder(
                      itemCount: GlobalVeriler.kitaplar.length,
                      itemBuilder: (context, index) {
                        var kitap = GlobalVeriler.kitaplar[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: const Icon(Icons.book, color: Color(0xFF2D3436), size: 30),
                            title: Text(kitap['isim']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text('${c('yazarHint')}: ${kitap['yazar']}', style: TextStyle(color: Colors.grey.shade600)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey), 
                              onPressed: () => setState(() {
                                GlobalVeriler.kitaplar.removeAt(index);
                                GlobalVeriler.verileriKaydet();
                              })
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

// --- SAĞLIK, SU, ADIM VE VKİ ---
class SaglikSuSayfasi extends StatefulWidget {
  final Function() onBilgiGuncellendi;

  const SaglikSuSayfasi({super.key, required this.onBilgiGuncellendi});

  @override
  State<SaglikSuSayfasi> createState() => _SaglikSuSayfasiState();
}

class _SaglikSuSayfasiState extends State<SaglikSuSayfasi> {
  double get _vkiHesapla {
    double anlikBoy = Hive.box('pusula_box').get('kullanici_boy', defaultValue: 175.0);
    double anlikKilo = Hive.box('pusula_box').get('kullanici_kilo', defaultValue: 70.0);
    if (anlikBoy <= 0) return 0;
    double boyMetre = anlikBoy / 100.0;
    return anlikKilo / (boyMetre * boyMetre);
  }

  String _vkiDurumuGetir(double vki) {
    if (vki < 18.5) return c('vkiZayif');
    if (vki >= 18.5 && vki < 25) return c('vkiIdeal');
    if (vki >= 25 && vki < 30) return c('vkiHafif');
    return c('vkiObez');
  }

  String _vkiTavsiyesiGetir(double vki) {
    if (vki < 18.5) return c('vkiTavsiyeZayif');
    if (vki >= 18.5 && vki < 25) return c('vkiTavsiyeIdeal');
    if (vki >= 25 && vki < 30) return c('vkiTavsiyeHafif');
    return c('vkiTavsiyeObez');
  }

  void _fizikselBilgileriGuncellePenceresi() {
    double anlikBoy = Hive.box('pusula_box').get('kullanici_boy', defaultValue: 175.0);
    double anlikKilo = Hive.box('pusula_box').get('kullanici_kilo', defaultValue: 70.0);
    
    final TextEditingController boyController = TextEditingController(text: anlikBoy.toInt().toString());
    final TextEditingController kiloController = TextEditingController(text: anlikKilo.toInt().toString());

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('boyKiloGuncelle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: boyController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: c('boyText'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              TextField(controller: kiloController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: c('kiloText'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    double yeniBoy = double.tryParse(boyController.text.trim()) ?? anlikBoy;
                    double yeniKilo = double.tryParse(kiloController.text.trim()) ?? anlikKilo;
                    Hive.box('pusula_box').put('kullanici_boy', yeniBoy);
                    Hive.box('pusula_box').put('kullanici_kilo', yeniKilo);
                    
                    setState(() {});
                    widget.onBilgiGuncellendi();
                    Navigator.pop(sheetContext);
                  },
                  child: Text(c('guncelle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _suHedefiBelirlePenceresi() {
    final TextEditingController hedefController = TextEditingController(text: GlobalVeriler.suHedefi.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(c('suHedefiBelirle')),
          content: TextField(controller: hedefController, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: c('hedefBardak'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(c('iptal'), style: const TextStyle(color: Colors.grey))),
            TextButton(onPressed: () { 
              int yeniHedef = int.tryParse(hedefController.text.trim()) ?? 8; 
              setState(() { GlobalVeriler.suHedefi = yeniHedef; }); 
              GlobalVeriler.verileriKaydet();
              Navigator.pop(context); 
            }, child: Text(c('kaydet'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3436)))),
          ],
        );
      },
    );
  }

  void _suEklePenceresi() {
    final TextEditingController suController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('suEkleBtn'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: suController, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: c('kacBardak'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    int eklenenSu = int.tryParse(suController.text.trim()) ?? 0;
                    if (eklenenSu > 0) {
                      int eskiSu = GlobalVeriler.icilenSuBardak;
                      setState(() { GlobalVeriler.icilenSuBardak += eklenenSu; });
                      if (eskiSu < GlobalVeriler.suHedefi && GlobalVeriler.icilenSuBardak >= GlobalVeriler.suHedefi) {
                        GlobalVeriler.toplamSuHedefiUlasma++; 
                      }
                      GlobalVeriler.verileriKaydet();
                      Navigator.pop(sheetContext);
                      RozetYoneticisi.kontrolEt(context);
                    }
                  },
                  child: Text(c('suyuEkle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _adimHedefiBelirlePenceresi() {
    final TextEditingController hedefController = TextEditingController(text: GlobalVeriler.adimHedefi.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(c('adimHedefiBelirle')),
          content: TextField(controller: hedefController, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: c('yeniHedefAdim'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(c('iptal'), style: const TextStyle(color: Colors.grey))),
            TextButton(onPressed: () { 
              int yeniHedef = int.tryParse(hedefController.text.trim()) ?? 10000; 
              setState(() { GlobalVeriler.adimHedefi = yeniHedef; }); 
              GlobalVeriler.verileriKaydet();
              Navigator.pop(context); 
            }, child: Text(c('kaydet'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3436)))),
          ],
        );
      },
    );
  }

  void _adimEklePenceresi() {
    final TextEditingController adimController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('adimEkleBtn'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: adimController, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(hintText: c('kacAdim'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    int eklenenAdim = int.tryParse(adimController.text.trim()) ?? 0;
                    if (eklenenAdim > 0) {
                      setState(() { GlobalVeriler.atilanAdim += eklenenAdim; GlobalVeriler.toplamAdimIstatisigi += eklenenAdim; });
                      GlobalVeriler.verileriKaydet();
                      Navigator.pop(sheetContext);
                      RozetYoneticisi.kontrolEt(context);
                    }
                  },
                  child: Text(c('adimlariEkle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double vkiDegeri = _vkiHesapla;
    String vkiDurum = _vkiDurumuGetir(vkiDegeri);
    String vkiTavsiye = _vkiTavsiyesiGetir(vkiDegeri);
    
    double anlikBoy = Hive.box('pusula_box').get('kullanici_boy', defaultValue: 175.0);
    double anlikKilo = Hive.box('pusula_box').get('kullanici_kilo', defaultValue: 70.0);

    return Scaffold(
      appBar: AppBar(title: Text(c('saglikBaslik'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFFF5F7F8), elevation: 0, foregroundColor: const Color(0xFF2D3436)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _fizikselBilgileriGuncellePenceresi,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFD8E9F0), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.monitor_weight_rounded, size: 30, color: Color(0xFF2D3436))),
                        const SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c('vkiBaslik'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text('${vkiDegeri.toStringAsFixed(1)} ($vkiDurum)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text('${c('boyText')}: ${anlikBoy.toInt()} cm • ${c('kiloText')}: ${anlikKilo.toInt()} kg', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                    const Divider(height: 25),
                    Text(vkiTavsiye, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.water_drop, size: 40, color: Colors.blueAccent), OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2D3436), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onPressed: _suHedefiBelirlePenceresi, icon: const Icon(Icons.tune, size: 16, color: Colors.blueAccent), label: Text(c('hedefiDegistir'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))]),
                  const SizedBox(height: 10),
                  Text('${GlobalVeriler.icilenSuBardak} / ${GlobalVeriler.suHedefi} ${c('bardak')}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4), Text(c('suIlerleme'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _suEklePenceresi, icon: const Icon(Icons.add, color: Colors.white), label: Text(c('suEkleBtn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.directions_walk_rounded, size: 40, color: Colors.orangeAccent), OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2D3436), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onPressed: _adimHedefiBelirlePenceresi, icon: const Icon(Icons.tune, size: 16, color: Colors.orangeAccent), label: Text(c('hedefiDegistir'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))]),
                  const SizedBox(height: 10),
                  Text('${GlobalVeriler.atilanAdim} / ${GlobalVeriler.adimHedefi} ${c('adim')}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4), Text(c('adimIlerleme'), style: const TextStyle(color: Colors.grey),),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _adimEklePenceresi, icon: const Icon(Icons.add, color: Colors.white), label: Text(c('adimEkleBtn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- GÜNLÜK MODÜLÜ ---
class GunlukYazmaSayfasi extends StatefulWidget {
  const GunlukYazmaSayfasi({super.key});

  @override
  State<GunlukYazmaSayfasi> createState() => _GunlukYazmaSayfasiState();
}

class _GunlukYazmaSayfasiState extends State<GunlukYazmaSayfasi> {
  void _yeniGunlukEklePenceresi() {
    final TextEditingController baslikController = TextEditingController();
    final TextEditingController icerikController = TextEditingController();
    final TextEditingController tarihController = TextEditingController(text: '${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('gunlukYaz'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: baslikController, decoration: InputDecoration(hintText: c('gunlukBaslikHint'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              TextField(controller: tarihController, decoration: InputDecoration(hintText: c('gunlukTarihHint'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.calendar_today_rounded, color: Colors.grey))),
              const SizedBox(height: 15),
              TextField(controller: icerikController, maxLines: 4, decoration: InputDecoration(hintText: c('gunlukIcerikHint'), hintStyle: TextStyle(color: Colors.grey.shade400), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    if (baslikController.text.trim().isNotEmpty && icerikController.text.trim().isNotEmpty) {
                      setState(() {
                        GlobalVeriler.gunlukler.add({'baslik': baslikController.text.trim(), 'icerik': icerikController.text.trim(), 'tarih': tarihController.text.trim().isEmpty ? 'Bugün' : tarihController.text.trim()});
                        GlobalVeriler.verileriKaydet();
                      });
                      Navigator.pop(sheetContext);
                      RozetYoneticisi.kontrolEt(context);
                    }
                  },
                  child: Text(c('gunlugeKaydet'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(c('gunlukBaslik'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFFF5F7F8), elevation: 0, foregroundColor: const Color(0xFF2D3436)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c('anilarinNotlarin'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _yeniGunlukEklePenceresi, icon: const Icon(Icons.add_circle_outline, size: 28)),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: GlobalVeriler.gunlukler.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.book_outlined, size: 60, color: Colors.grey.shade400), const SizedBox(height: 10), Text(c('gunlukEmpty'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4))]))
                  : ListView.builder(
                      itemCount: GlobalVeriler.gunlukler.length,
                      itemBuilder: (context, index) {
                        var gunluk = GlobalVeriler.gunlukler[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF2D3436)),
                            title: Text(gunluk['baslik']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(gunluk['tarih']!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey), 
                              onPressed: () => setState(() {
                                GlobalVeriler.gunlukler.removeAt(index);
                                GlobalVeriler.verileriKaydet();
                              })
                            ),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GunlukDetaySayfasi(baslik: gunluk['baslik']!, tarih: gunluk['tarih']!, icerik: gunluk['icerik']!))),
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

// --- GÜNLÜK DETAY SAYFASI ---
class GunlukDetaySayfasi extends StatelessWidget {
  final String baslik;
  final String tarih;
  final String icerik;

  const GunlukDetaySayfasi({super.key, required this.baslik, required this.tarih, required this.icerik});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(''), backgroundColor: const Color(0xFFF5F7F8), elevation: 0, foregroundColor: const Color(0xFF2D3436)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF2D3436))),
            const SizedBox(height: 10),
            Text(tarih, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const Divider(height: 30),
            Text(icerik, style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF2D3436))),
          ],
        ),
      ),
    );
  }
}

// --- PROFİL SAYFASI ---
class ProfilSayfasi extends StatefulWidget {
  final Function() onBilgiGuncellendi;
  final List<String> ilgiAlanlariAnahtarlari;

  const ProfilSayfasi({
    super.key,
    required this.onBilgiGuncellendi, 
    required this.ilgiAlanlariAnahtarlari
  });

  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final List<String> _avatarListesi = ['🦊', '🐼', '🦁', '🐰', '🦉', '🐨', '🐯', '🦄'];

  void _avatarSecimPenceresi() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('avatarSec'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 15, runSpacing: 15,
                children: _avatarListesi.map((avatar) {
                  return GestureDetector(
                    onTap: () { 
                      Hive.box('pusula_box').put('kullanici_avatar', avatar);
                      setState(() {});
                      widget.onBilgiGuncellendi();
                      Navigator.pop(context); 
                    },
                    child: CircleAvatar(radius: 30, backgroundColor: const Color(0xFFD8E9F0), child: Text(avatar, style: const TextStyle(fontSize: 28))),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _profilDuzenlePenceresi() {
    var box = Hive.box('pusula_box');
    String mevcutAd = box.get('kullanici_adi', defaultValue: 'Yolcu');
    int mevcutYas = box.get('kullanici_yas', defaultValue: 21);
    double mevcutBoy = box.get('kullanici_boy', defaultValue: 175.0);
    double mevcutKilo = box.get('kullanici_kilo', defaultValue: 70.0);

    final TextEditingController adController = TextEditingController(text: mevcutAd);
    final TextEditingController yasController = TextEditingController(text: mevcutYas.toString());
    final TextEditingController boyController = TextEditingController(text: mevcutBoy.toInt().toString());
    final TextEditingController kiloController = TextEditingController(text: mevcutKilo.toInt().toString());

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c('profilDuzenleBaslik'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: adController, decoration: InputDecoration(labelText: c('adSoyad'), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              TextField(controller: yasController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: c('yas'), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: TextField(controller: boyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${c('boyText')} (cm)', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
                  const SizedBox(width: 15),
                  Expanded(child: TextField(controller: kiloController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${c('kiloText')} (kg)', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    box.put('kullanici_adi', adController.text.trim().isEmpty ? 'Yolcu' : adController.text.trim());
                    box.put('kullanici_yas', int.tryParse(yasController.text.trim()) ?? 21);
                    box.put('kullanici_boy', double.tryParse(boyController.text.trim()) ?? 175.0);
                    box.put('kullanici_kilo', double.tryParse(kiloController.text.trim()) ?? 70.0);
                    
                    setState(() {}); 
                    widget.onBilgiGuncellendi();
                    Navigator.pop(sheetContext);
                  },
                  child: Text(c('kaydet'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _rozetDetayGoster(BuildContext context, String badgeKey, String iconStr, bool ulasildi, double progress, int current, int target) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [Text(iconStr, style: const TextStyle(fontSize: 30)), const SizedBox(width: 10), Expanded(child: Text(c(badgeKey), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
          content: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c('${badgeKey}_desc'), style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, color: ulasildi ? Colors.green : Colors.blueAccent, minHeight: 8, borderRadius: BorderRadius.circular(10)),
              const SizedBox(height: 8),
              Text('$current / $target', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c('kapat'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)))],
        );
      }
    );
  }

  Widget _rozetKarti(BuildContext context, String badgeKey, String iconStr, int current, int target, Color renk) {
    bool ulasildi = current >= target;
    double progress = current / target;
    if (progress > 1.0) progress = 1.0;

    return GestureDetector(
      onTap: () => _rozetDetayGoster(context, badgeKey, iconStr, ulasildi, progress, current, target),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, spreadRadius: 1)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 50, height: 50, decoration: BoxDecoration(color: ulasildi ? renk : Colors.grey.shade100, shape: BoxShape.circle), child: Center(child: Text(iconStr, style: TextStyle(fontSize: 24, color: ulasildi ? Colors.black87 : Colors.grey.shade400)))),
                if (!ulasildi) Icon(Icons.lock, color: Colors.grey.shade600, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(c(badgeKey), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ulasildi ? Colors.black87 : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, color: ulasildi ? renk : Colors.grey.shade400, minHeight: 5, borderRadius: BorderRadius.circular(10)),
            const SizedBox(height: 4),
            Text('$current / $target', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var box = Hive.box('pusula_box');
    String guncelAd = box.get('kullanici_adi', defaultValue: 'Yolcu');
    int guncelYas = box.get('kullanici_yas', defaultValue: 21);
    double guncelBoy = box.get('kullanici_boy', defaultValue: 175.0);
    double guncelKilo = box.get('kullanici_kilo', defaultValue: 70.0);
    String guncelMeslek = box.get('kullanici_meslek', defaultValue: 'ogrenci');
    String kayitliAvatar = box.get('kullanici_avatar', defaultValue: '🦊');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(c('profileTitle'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _avatarSecimPenceresi,
                        child: CircleAvatar(radius: 50, backgroundColor: const Color(0xFFD8E9F0), child: Text(kayitliAvatar, style: const TextStyle(fontSize: 50))),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _avatarSecimPenceresi,
                          child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF2D3436), shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(guncelAd, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('$guncelYas ${c('yasinda')} • ${c(guncelMeslek)}', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                  const SizedBox(height: 5),
                  Text('${c('boyText')}: ${guncelBoy.toInt()} cm • ${c('kiloText')}: ${guncelKilo.toInt()} kg', style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2D3436), side: const BorderSide(color: Color(0xFF2D3436), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                    onPressed: _profilDuzenlePenceresi,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(c('editProfile'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(c('rozetlerim'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            SizedBox(
              height: 160, 
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_vaha1', '🏝️', GlobalVeriler.vahaMaxSeviyeGun, 2, Colors.green.shade300)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_vaha2', '🌴', GlobalVeriler.vahaMaxSeviyeGun, 5, Colors.green.shade400)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_vaha3', '👑', GlobalVeriler.vahaMaxSeviyeGun, 15, Colors.green.shade600)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_zaman1', '⏳', GlobalVeriler.toplamOdaklanmaDk, 100, Colors.blue.shade300)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_zaman2', '⌛', GlobalVeriler.toplamOdaklanmaDk, 500, Colors.blue.shade400)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_zaman3', '🌌', GlobalVeriler.toplamOdaklanmaDk, 1500, Colors.blue.shade600)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_yazar1', '📝', GlobalVeriler.gunlukler.length, 3, Colors.purple.shade200)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_yazar2', '✍️', GlobalVeriler.gunlukler.length, 10, Colors.purple.shade300)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_yazar3', '📜', GlobalVeriler.gunlukler.length, 30, Colors.purple.shade500)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_su1', '💧', GlobalVeriler.toplamSuHedefiUlasma, 3, Colors.cyan.shade200)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_su2', '🌊', GlobalVeriler.toplamSuHedefiUlasma, 10, Colors.cyan.shade400)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_su3', '🧜‍♀️', GlobalVeriler.toplamSuHedefiUlasma, 30, Colors.cyan.shade600)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_adim1', '👟', GlobalVeriler.toplamAdimIstatisigi, 10000, Colors.orange.shade300)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_adim2', '🏃', GlobalVeriler.toplamAdimIstatisigi, 50000, Colors.orange.shade400)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_adim3', '⚡', GlobalVeriler.toplamAdimIstatisigi, 150000, Colors.orange.shade600)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_kitap1', '📖', GlobalVeriler.kitaplar.length, 1, Colors.brown.shade300)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_kitap2', '📚', GlobalVeriler.kitaplar.length, 5, Colors.brown.shade400)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_kitap3', '🦉', GlobalVeriler.kitaplar.length, 20, Colors.brown.shade600)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_gorev1', '🎯', GlobalVeriler.toplamTamamlananGorev, 10, Colors.red.shade300)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_gorev2', '🔥', GlobalVeriler.toplamTamamlananGorev, 50, Colors.red.shade400)),
                  const SizedBox(width: 15),
                  SizedBox(width: 140, child: _rozetKarti(context, 'badge_gorev3', '🏅', GlobalVeriler.toplamTamamlananGorev, 150, Colors.red.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(c('selectedInterests'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            widget.ilgiAlanlariAnahtarlari.isEmpty
                ? const Text('Henüz bir ilgi alanı seçilmemiş.', style: TextStyle(color: Colors.grey))
                : Wrap(
                    spacing: 10, runSpacing: 10,
                    children: widget.ilgiAlanlariAnahtarlari.map((key) {
                      return Chip(
                        label: Text(c(key)), backgroundColor: Colors.white,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFC4DBE0), width: 1.5)),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: Color(0xFF2D3436)),
                    title: Text(c('languageSettings'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: DropdownButton<String>(
                      value: DilYoneticisi.instance.value,
                      underline: const SizedBox(),
                      items: const [DropdownMenuItem(value: 'tr', child: Text('Türkçe 🇹🇷')), DropdownMenuItem(value: 'en', child: Text('English 🇬🇧'))],
                      onChanged: (val) { if (val != null) { setState(() { DilYoneticisi.instance.value = val; }); } },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Color(0xFF2D3436)),
                    title: Text(c('appVersion'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('v1.0.0 (Alpha)', style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
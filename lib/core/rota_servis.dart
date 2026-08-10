import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class RotaServis {
  static const String _apiKey = 'BURAYA_GROQ_API_ANAHTARINI_YAZ';
  static const String _url = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<void> initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('pusula_box');
  }

  static Future<String> getGununSozu(String kullaniciAdi, String ilgiAlanlari) async {
    var box = Hive.box('pusula_box');
    String bugunTarih = DateTime.now().toString().split(' ')[0];
    String kayitliTarih = box.get('soz_tarihi', defaultValue: '');
    String kayitliSoz = box.get('gunun_sozu', defaultValue: '');

    if (kayitliTarih == bugunTarih && kayitliSoz.isNotEmpty) {
      return kayitliSoz;
    }

    if (_apiKey.contains('BURAYA')) {
      return 'Selam $kullaniciAdi! Ben Rota. Groq API anahtarını eklemediğin için şimdilik modum düşük ama kankayız unutma! 😎';
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
              "content": "Senin adin Rota. Kullanicinin samimi, esprili ve tatli bir kanka yol arkadasisin. Turkce yanit ver."
            },
            {
              "role": "user",
              "content": "Kullanicinin adi: $kullaniciAdi. Ilgi alanlari: $ilgiAlanlari. Ona bugün motive olmasi için esprili, samimi ve içinde 1 adet emoji olan tek cümlelik harika bir günün sözünü üret."
            }
          ],
          "temperature": 0.8,
          "max_tokens": 100,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        String yeniSoz = data['choices'][0]['message']['content'].trim();
        
        await box.put('soz_tarihi', bugunTarih);
        await box.put('gunun_sozu', yeniSoz);
        
        return yeniSoz;
      } else {
        return 'Yolculukta bazen sinyaller zayiflar kanka, bugün kendi enerjine güven! 🚀';
      }
    } catch (e) {
      return 'Küçük bir türbulansa girdik ama rota degismedi, devam! 🧭';
    }
  }

  static Future<String> mesajGonder(String kullaniciMesaji) async {
    if (_apiKey.contains('BURAYA')) {
      return 'Kanka API anahtarini henüz girmedin! Beni tam anlamıyla uyandirmak için servise anahtar eklemelisin. 😉';
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
              "content": "Sen Rota'sin. 'Pusula' adli kisisel gelisim uygulamasinin zeki, esprili ve samimi yapay zeka dostusun. Kullanicilara kanka havasinda, kisa ve motive edici yanitlar ver."
            },
            {
              "role": "user",
              "content": kullaniciMesaji
            }
          ],
          "temperature": 0.7,
          "max_tokens": 200,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'].trim();
      } else {
        return 'Aklim kisa devre yapti kanka, bir daha saksana? 🤖';
      }
    } catch (e) {
      return 'Baglanti kopuklugu yasiyoruz sanirim, rotadan sapmayalim! 🌍';
    }
  }
}
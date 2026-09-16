# Maraş Cream

Godot 4.7 ile geliştirilen, külahı dengede tutarken sipariş hazırladığın ve müşterilere Maraş dondurması şovları yaptığın oyun.

`project.godot` dosyasını Godot ile açıp **F5** ile çalıştır.

## Şov ve teslim

- **Sağ tık / Q:** Kepçe doluysa dondurmayı külaha aktarır; kepçe boşsa külahı uzatıp kaçırma şovu yapar.
- **F:** Külahı ters çevirir. Çok eğik bir kuleyle başlatılamaz.
- **A / D:** Külahı dengeler. Düşme uyarısı çıktığında düşüş yönünün tersine basarak kurtarabilirsin.
- **E:** Müşteriye bakarken tamamlanmış siparişi teslim eder. Eldeki hareketin bitmesi gerekir.

Şov bonusu başarılı hareketin sonunda birikir, **sipariş tesliminde ödenir**. Külah düşerse veya çöpe atılırsa o külahın bonusu kaybolur. Aynı hareketin tekrarı daha az kazandırır; üçüncü tekrar bonus vermez. Kurtarma bonusu müşteri başına bir defadır. Müşteri türü, farklı hareketler ve sipariş kalitesi ödülü etkiler.

Sipariş kartı gerçek teslim hesabını gösterir: ürün bedeli, müşteri ve geliştirme çarpanlı bahşiş, ikram ve şov. Puan düştükçe tahmin güncellenir. Gün sonu raporu şov gelirini ayrı toplar.

## Doğrulama

İlk kurulumda projeyi editörde bir kez aç veya kaynakları içe aktar:

```bash
godot --headless --editor --import --path . --quit
bash tests/run.sh
```

Testler gerçek ana sahneyi yükler; şov, iptal, kurtarma girdisi, ödeme ve on müşterilik gün → mağaza → ikinci gün akışını çalıştırır. Kayıtlar `/tmp/maras-tests.*` altında tutulur. Betik çalışma zamanı hatalarında veya başarısız kontrolde sıfırdan farklı kodla çıkar.

[Denge kuralları ve test kapsamı](docs/SHOW_SYSTEM.md)

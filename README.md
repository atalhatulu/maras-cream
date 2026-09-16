# Maraş Cream

Godot 4.7 ile geliştirilen, külahı dengede tutarken sipariş hazırladığın ve müşterilere Maraş dondurması şovları yaptığın oyun.

`project.godot` dosyasını Godot ile açıp **F5** ile çalıştır.

## Şov ve teslim

- **Sağ tık / Q:** Kepçe doluysa dondurmayı külaha aktarır; kepçe boşsa külahı uzatıp kaçırma şovu yapar.
- **F:** Külahı ters çevirir. Çok eğik bir kuleyle başlatılamaz.
- **R:** Külahı kendi ekseninde 360 derece fırıldak gibi çevirir. Kule çok eğikken başlatılamaz.
- **A / D:** Külahı dengeler. Düşme uyarısı çıktığında düşüş yönünün tersine basarak kurtarabilirsin.
- **E:** Müşteriye bakarken tamamlanmış siparişi teslim eder. Eldeki hareketin bitmesi gerekir.

Şov bonusu başarılı hareketin sonunda birikir, **sipariş tesliminde ödenir**. Külah düşerse veya çöpe atılırsa o külahın bonusu kaybolur. Aynı hareketin tekrarı daha az kazandırır; üçüncü tekrar bonus vermez. Kurtarma bonusu müşteri başına bir defadır. Müşteri türü, farklı hareketler ve sipariş kalitesi ödülü etkiler.

Sipariş kartı gerçek teslim hesabını gösterir: ürün bedeli, müşteri ve geliştirme çarpanlı bahşiş, ikram ve şov. Puan düştükçe tahmin güncellenir. Gün sonu raporu şov gelirini ayrı toplar.

## Günlük olaylar

İlk beş gün sırasıyla açılış, sıcak hava dalgası, turist kafilesi, çocuk şenliği ve gurme teftişidir. Sonraki günlerde olaylar rastgele seçilir; aynı olay üst üste gelmez. Günün kuralı ekranda görünür.

- **Sıcak hava:** Top başına +$1; güvenli denge açısı %10 daralır.
- **Turist kafilesi:** Daha çok turist gelir. Turistlerin bahşişi %25 artar; yeni şov çeşitlerine +$1, müşteri başına şov sınırına +$2 eklenir.
- **Çocuk şenliği:** Daha çok çocuk gelir; mevcutsa iki farklı açık sos isterler. Çocuklara fazladan sos ikramı %50 daha fazla kazandırır; şovlarla sabır durdurma bütçesi 2 saniye artar.
- **Gurme teftişi:** Daha çok gurme gelir. Gurmenin doğru siparişini en az 4,5 puanla, o müşteri sırasında külah düşürmeden veya çöpe atmadan teslim etmek +$8 ve +3 itibar kazandırır. Prim sipariş kartında ve gün sonu raporunda görünür.

## Doğrulama

İlk kurulumda projeyi editörde bir kez aç veya kaynakları içe aktar:

```bash
godot --headless --editor --import --path . --quit
bash tests/run.sh
```

Testler gerçek ana sahneyi yükler; şov, iptal, kurtarma girdisi, günlük olay siparişleri ve ödemeleri, teftiş koşulları ve on müşterilik gün → mağaza → ikinci gün akışını çalıştırır. Kayıtlar `/tmp/maras-tests.*` altında tutulur. Betik çalışma zamanı hatalarında veya başarısız kontrolde sıfırdan farklı kodla çıkar.

[Denge kuralları ve test kapsamı](docs/SHOW_SYSTEM.md)

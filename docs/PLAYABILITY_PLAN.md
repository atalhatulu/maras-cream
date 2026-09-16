# Oynanabilirlik çalışması — 17 Eylül 2026

## Tamamlanma ölçütleri

1. Tezgâh: tat ve sos etiketleri kendi alanında kalır; hedef ürünün adı, kilidi ve yapılabilir eylemi okunur. Sayfa değişimi, satın alma ve el durumu değişince hedefi değiştirmeden açıklama yenilenir. 1280×720 ve daha dar pencerede görsel doğrulama yapılır.
2. Öğretici: ilk gün gerçek külah alma, fareyle kepçeleme, aktarma, A/D ile dengeleme, soslama ve teslim adımlarını izler. Yanlış tarif/külah kaybından dönüş, atlama ve yeniden yardım açma çalışır. Öğrenme sırasında zaman baskısı yoktur; normal oyunda bu koruma kalkar. Tamamlanma bilgisi yeniden başlatmada korunur.
3. Denge: gerçek girdi yoluyla siparişler hazırlanır; erken bırakma, hızlı tekrar ve menü/fokus kesintileri doğrulanır. Hazırlama süresi, müşteri sabrı, 2–14 toplu kulelerin kontrol edilebilirliği ve ilk günlerin satın alma gücü ölçülür. Ayarlar ve ölçümler belgelenir; otomasyon insan oynanış değerlendirmesi gibi sunulmaz.
4. Kaynak temizliği: sesler açıkken doğal kapanış, yoğun ses kullanımı ve sahne değişimi kontrol edilir. Sızıntı logu kaynağıyla birlikte incelenir; sadece uyarıyı gizleyen çözüm kullanılmaz. Regresyon komutu kaynak sızıntısını da başarısızlık sayar.

## İncelemede bulunanlar

- Tezgâh etiketleri fiziksel ürün aralığından daha geniş; şişeler varsayılan Label3D piksel ölçeğini kullanıyor.
- Hedef açıklaması yalnızca bakılan nesne değişince yenileniyor; aynı müşteri veya değiştirilen tat sayfasında eski metin kalabiliyor.
- Kepçeyi giriş animasyonunda bırakmak iptal edilmiyor; animasyon bitince fare tekrar çekilebiliyor.
- Müşteri türlerinin `patience_grace_time` değeri yerine herkeste 14 saniye kullanılıyor.
- Mevcut `project.godot` içindeki R / `spin_cone` değişikliği bu çalışmadan önce mevcut; korunacak.

## Kanıtlar

Uygulama ve doğrulama sonuçları çalışma tamamlandıkça buraya eklenecek.

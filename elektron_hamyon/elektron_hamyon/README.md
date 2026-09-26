# Elektron Hamyon (iOS, Flutter + Codemagic)

## Ilova nima qiladi

Har safar pul qo'shganingizda summa avtomatik 4 qismga bo'linadi:

| Ulush | Foiz | Vazifasi |
|---|---|---|
| Kunlik xarajat | **50%** | 30 kunga bo'linib, har kuni sarflash uchun limit hisoblanadi |
| Jamg'arma | **25%** | alohida "cho'ntak" sifatida saqlanadi |
| Zaxira | **15%** | alohida "cho'ntak" sifatida saqlanadi |
| Boshqa ehtiyojlar | **10%** | alohida "cho'ntak" sifatida saqlanadi |

**Kunlik 50% qismning mantig'i:**
- Byudjet 30 kunga bo'linadi -> `kunlik limit = byudjet / 30`.
- Har kuni sarflagan summangizni kiritasiz. Agar kunlik limitdan **oshib ketsangiz**, ilova buni "limitdan oshgan" deb ko'rsatib boradi.
- Agar kun oxirigacha limitni **to'liq sarflamasangiz**, qolgan mablag' yig'ilib boraveradi (bekor bo'lib ketmaydi).
- 30 kun tugagach, o'sha davrdan **qolgan summa** avtomatik yangi 30 kunlik davrga o'tadi va xuddi shu tarzda qaytadan 30 kunga bo'linadi.
- Davr davomida yangi pul qo'shsangiz, u faqat **joriy 30 kunlik davr** byudjetiga qo'shiladi (limit shu davr uchun qayta hisoblanadi); kelgusi davr tugagach xuddi shu uslub bilan (qolgan + yangi tushum) qaytadan taqsimlanadi.

**Dizayn:** to'q yashil (`#0B4D2C`) + oq fon, iOS uslubidagi toza interfeys.

## Loyiha tuzilishi

```
elektron_hamyon/
  pubspec.yaml          -> paketlar (shared_preferences, intl)
  lib/
    main.dart           -> interfeys (UI), rang sxemasi
    wallet_engine.dart   -> butun hisob-kitob mantig'i va saqlash
  codemagic.yaml         -> Codemagic uchun iOS build sozlamasi
```

> Eslatma: bu paket `ios/` Xcode loyihasi papkasini o'z ichiga olmaydi -
> chunki u ko'plab avtomatik generatsiya qilinadigan fayllardan iborat.
> `codemagic.yaml`dagi birinchi skript build boshlanishida
> `flutter create --platforms=ios .` buyrug'ini avtomatik ishga tushirib,
> shu papkani o'zi yaratib beradi. Agar mahalliy kompyuteringizda
> (yoki Mac'da) ishlashni xohlasangiz, shu papka ichida
> `flutter create --platforms=ios .` buyrug'ini bir marta qo'lda ishga
> tushiring.

## Codemagic'da sozlash qadamlari

1. https://codemagic.io saytida ro'yxatdan o'ting va GitHub/GitLab/Bitbucket
   orqali shu loyihani (bu papkani) reponi ulang.
2. Loyihani import qilganda Codemagic `codemagic.yaml` faylini avtomatik
   topib, "ios-workflow" ish oqimini ko'rsatadi.
3. **Code signing** (App Store'ga chiqarish uchun majburiy):
   - Apple Developer akkountingiz bo'lishi kerak (yillik $99).
   - Codemagic -> Team settings -> Integrations -> **App Store Connect**
     bo'limida Apple API kalitini ulang.
   - Keyin loyiha sozlamalarida (Workflow -> Code signing -> iOS) avtomatik
     signing'ni yoqing - Codemagic sertifikat va provisioning profilni
     o'zi yaratadi.
   - `codemagic.yaml`dagi `BUNDLE_ID` va `bundle_identifier` qiymatini
     (`com.woodera.elektronhamyon`) o'zingizning Apple Developer
     akkountingizdagi App ID bilan mos qiling.
4. `publishing -> email -> recipients` qatoridagi email manzilni
   o'zingiznikiga almashtiring (build tugagach xabar keladi).
5. "Start new build" tugmasini bosing - Codemagic Flutter va Xcode
   muhitini o'zi tayyorlab, `.ipa` faylini yig'ib beradi.
6. Tayyor `.ipa` faylni TestFlight orqali telefoningizga o'rnatishingiz
   yoki (ixtiyoriy) `app_store_connect` bo'limini yoqib, to'g'ridan-to'g'ri
   TestFlight'ga avtomatik yuklashingiz mumkin.

## Eslatma

- Ma'lumotlar hozircha faqat telefon xotirasida (`shared_preferences`)
  saqlanadi - internetga ulanish shart emas.
- Agar 30 kunlik davr oxirida byudjetdan **oshib ketilgan** bo'lsa
  (manfiy qoldiq), yangi davr 0 dan boshlanadi va "Oldingi davrda
  limitdan oshgan summa" sifatida bosh sahifada ko'rsatiladi.

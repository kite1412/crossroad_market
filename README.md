# Crossroad Market

## Deskripsi

Crossroad Market adalah playable vertical slice 2D RPG pixel art yang dibangun di Godot 4. Game ini berfokus pada dua pilar utama: **store survival** dan **community building**.

Player mengambil alih sebuah toko kecil warisan selama 6 hari in-game. Tujuan utamanya bukan sekadar mencari profit, melainkan membuktikan bahwa sistem toko dan hubungan sosial dapat saling memperkuat. Cara player bermain selama 6 hari menentukan bagaimana mereka memulai babak berikutnya.

---

## Genre & Platform

| Atribut | Detail |
|---|---|
| Genre | 2D RPG, Cozy Shop Sim |
| Engine | Godot 4 |
| Resolusi | 480 x 270 (upscale ke 1080p) |
| Render Mode | Viewport stretch, pixel perfect |
| Target Platform | PC (Windows) |
| Durasi In-Game | 6 hari |
| Target Produksi | 8 minggu |

---

## Konsep Utama

Toko lama Crossroad Market tidak bisa diselamatkan. Izin usaha tidak dapat diperpanjang karena masih terikat catatan kepemilikan lama atas nama ibu player. Player tidak bisa mengubah keputusan itu.

Yang bisa player ubah adalah **bagaimana mereka menutupnya** — dengan profit yang cukup untuk modal baru, dengan dukungan dari komunitas, atau sendirian.

---

## Core Mechanic

| Mechanic | Keterangan |
|---|---|
| Movement | 4 arah, collision, camera follow |
| Interaction | Tombol interaksi untuk shelf, NPC, dan item |
| Shelf Management | 6 slot, masing-masing menampilkan satu jenis item |
| Restock | Pindahkan barang dari inventory ke shelf |
| NPC Purchase | NPC datang, cari item, ambil dari shelf, bayar di kasir |
| Checkout | Satu tombol untuk melayani semua NPC antrian |
| Ordering | Pesan barang malam hari, tiba pagi berikutnya |
| Daily Report | Ringkasan revenue, cost, profit, fee, dan trust harian |
| Store Fee | Tekanan biaya harian agar player tidak statis |
| Relationship | Trust 0–100 untuk Irene dan Gooby |
| Request Item | NPC meminta item spesifik, player harus order dan pajang |
| Dialogue Branch | Dialog berubah berdasarkan trust, item, dan story flag |
| Ending Branch | Hari ke-6 menentukan varian akhir berdasarkan profit dan trust |

---

## Area / Map

| Area | Fungsi |
|---|---|
| Toko Utama | Area inti gameplay, tempat shelf, kasir, dan interaksi NPC |
| Greenhouse Kecil | Terkait dengan advanced event Irene |
| Gudang Tua | Scene ending dan titik awal toko baru |

---

## NPC

### NPC Utama (2 NPC)

#### Irene

| Atribut | Detail |
|---|---|
| Kategori | Manusia |
| Profil | Greenhouse worker, pendiam, lembut, rajin, tidak suka merepotkan |
| Waktu Datang | Sore hari |
| Item Favorit | Bandage, Painkiller, Energy Drink, Work Gloves |
| Request | Work Gloves (hari tertentu) |
| Story Hook | Mengapa Irene sering membutuhkan perban dan sarung tangan kerja |
| Trust Effect | Trust naik jika item favorit tersedia; request selesai membuka advanced event |
| Advanced Event | Greenhouse event — terbuka jika trust cukup tinggi |
| Ending Support | Trust ≥ 70 atau greenhouse event selesai |

#### Gooby The Phantom

| Atribut | Detail |
|---|---|
| Kategori | Ghost customer |
| Profil | Ceria, aneh, pelupa, dan nostalgis terhadap toko lama |
| Waktu Datang | Saat toko sepi |
| Item Favorit | Phantom Ice Cream, Spirit Water |
| Request | Shiny Object |
| Story Hook | Mengapa Gooby terasa familiar dengan toko lama dan siapa dia sebelum menjadi hantu |
| Trust Effect | Trust naik jika item favorit tersedia; request selesai membuka event pencarian benda |
| Advanced Event | Event pencarian benda lama di toko |
| Ending Support | Trust ≥ 70 atau search object event selesai |

### NPC Normal (4–8 NPC, jika waktu produksi cukup)

NPC normal berfungsi untuk memberi revenue harian, menguji shelf, dan membuat toko terasa aktif. Tidak memiliki trust kompleks atau story arc.

| Atribut | Detail |
|---|---|
| Item yang Dibeli | Bread, Water, Basic Snack |
| Waktu Datang | Siang hari |
| Fungsi Utama | Revenue dan uji shelf |
| Relationship | Tidak ada trust khusus |

---

## Daftar Item (10–12 Item)

| Item ID | Nama | Fungsi Desain | Favorit Untuk |
|---|---|---|---|
| bread | Bread | Revenue stabil | — |
| water | Water | Revenue stabil | — |
| basic_snack | Basic Snack | Revenue pendukung | — |
| bandage | Bandage | Trust Irene | Irene |
| painkiller | Painkiller | Trust Irene | Irene |
| energy_drink | Energy Drink | Trust Irene | Irene |
| work_gloves | Work Gloves | Request Irene, trust naik besar | Irene |
| phantom_ice_cream | Phantom Ice Cream | Trust Gooby | Gooby |
| spirit_water | Spirit Water | Trust Gooby | Gooby |
| shiny_object | Shiny Object | Request Gooby, story hook | Gooby |

---

## Sistem Toko

### Shelf

- 6 slot tersedia
- Setiap slot menampilkan satu jenis item
- Barang tidak terpajang tidak bisa dibeli NPC
- Stok berkurang saat NPC mengambil item
- Player harus memilih item mana yang dipajang (trade-off profit vs trust)

### Checkout

- Player menekan satu tombol untuk melayani NPC yang menunggu
- Revenue bertambah setelah transaksi selesai
- Trust berubah jika item favorit atau request terpenuhi

### Ordering

- Dilakukan malam hari lewat ordering UI
- Mengurangi uang sebagai product cost
- Barang tiba pagi hari berikutnya di inventory
- Mendukung request NPC dan perencanaan shelf

### Daily Report

Muncul setiap akhir hari dan menampilkan:

- Revenue harian
- Product cost
- Net profit
- Store fee
- Uang akhir
- Perubahan trust Irene dan Gooby
- Progress request
- Barang yang habis
- Order yang akan datang besok

---

## Flow Harian

| Sesi | Aktivitas |
|---|---|
| Pagi | Order semalam tiba di inventory; player mengisi shelf |
| Siang | NPC normal datang, mencari item, bayar di kasir |
| Sore | Irene atau Gooby datang; trust berubah berdasarkan ketersediaan item |
| Malam | Toko tutup; daily report muncul; store fee dibayar; player order untuk besok |

---

## Sistem Relationship

| Level | Trust Range |
|---|---|
| Low | 0 – 29 |
| Regular | 30 – 69 |
| Friend | 70 – 100 |

### Trust Gain

| Kondisi | Trust |
|---|---|
| Beli item favorit | +5 hingga +10 |
| Request selesai | +15 hingga +25 |
| Advanced event selesai | +20 hingga +30 |
| Item favorit tidak tersedia | 0 (tidak ada penalti) |
| Request diabaikan | Progress tertahan |

---

## Ending (Hari Ke-6)

### Alasan Penutupan Toko Lama

Izin usaha toko lama tidak bisa diperpanjang karena masih terikat catatan kepemilikan atas nama ibu player. Ini bukan akibat performa player selama 6 hari.

### Support Flag

| NPC | Kondisi Support (Prototype) |
|---|---|
| Irene | Trust ≥ 70 ATAU greenhouse event selesai |
| Gooby | Trust ≥ 70 ATAU search object event selesai |

### Varian Ending Utama

| Variant ID | Kondisi | Rasa Ending |
|---|---|---|
| ending_both_support | Irene support + Gooby support | Hangat, komunitas terbentuk |
| ending_irene_support | Hanya Irene support | Human connection kuat |
| ending_gooby_support | Hanya Gooby support | Supernatural bond kuat |
| ending_alone | Tidak ada support | Sepi, tetapi tetap lanjut |

### Flavor Opsional

| Flavor ID | Kondisi |
|---|---|
| rich_but_alone | Uang akhir tinggi + tidak ada support |
| poor_but_supported | Uang akhir rendah + ada support |
| balanced_start | Kondisi default |

### Starting Capital Toko Baru

```
starting_capital = base (50) + profit_bonus + community_bonus

profit_bonus:
  - final_money >= 180 → +70
  - final_money >= 100 → +40
  - final_money < 100  → +15

community_bonus:
  - Irene support → +15
  - Gooby support → +15
```

Player tidak pernah mulai dari nol. Ending selalu memberi harapan.

---

## Struktur Folder

```
crossroad_market/
├── assets/       # Sprite, audio, font, dan resource visual
├── scenes/       # File .tscn Godot (scene toko, NPC, UI, ending)
├── scripts/      # File .gd GDScript (manager, NPC, shelf, economy)
└── project.godot # Konfigurasi project Godot 4
```

---

## Rencana Aktivitas Pengembangan

### Fondasi & Setup
- Setup project Godot 4 (resolusi, stretch mode, pixel perfect)
- Player movement 4 arah, collision, dan camera follow
- Sistem interaksi dasar (tombol interact untuk shelf, NPC, item)

### Sistem Toko
- Shelf 6 slot dengan item display dan quantity
- Inventory sederhana untuk menyimpan stok
- Restock dari inventory ke shelf
- Replace item antar slot
- Ordering barang malam hari
- Incoming delivery pagi hari
- Checkout satu tombol
- Store fee harian

### Sistem Ekonomi
- Pencatatan daily revenue
- Pencatatan product cost dari ordering
- Kalkulasi net profit harian
- Daily report akhir hari
- Kalkulasi starting capital toko baru berdasarkan profit akhir

### NPC & AI
- NPC purchase flow (spawn, cari item, ambil dari shelf, checkout, keluar)
- State machine NPC: enter → walk → search → take → checkout → pay → talk → exit
- Flow item tidak tersedia (NPC komentar dan keluar)
- Jadwal NPC normal (siang), Irene (sore), Gooby (saat toko sepi)

### Sistem Relationship
- Trust 0–100 untuk Irene dan Gooby
- Trust naik saat item favorit tersedia atau request selesai
- Dialogue branch berdasarkan trust, item, dan story flag
- Request item: NPC minta → player order → pajang → selesai

### Advanced Event
- Greenhouse event untuk Irene (dibuka dengan trust tinggi)
- Search object event untuk Gooby (dibuka dengan trust tinggi)

### Ending Branch
- Closure Day 6 (surat penutupan toko lama)
- Evaluasi snapshot: profit, trust, support flag, request completion
- Seleksi varian ending berdasarkan support Irene dan Gooby
- Scene gudang tua sebagai transisi toko baru
- Ending summary dengan modal awal toko baru

### Balancing & QA
- Balancing harga item, store fee, trust gain, dan pacing 6 hari
- Bug fixing
- Playtest internal
- Polish UI dan feedback visual

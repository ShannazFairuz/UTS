# UTS TMI6257 — Shannaz Fairuz
NIM             : 23051430020
Parameter P     : 5  (produk dengan id 5)
Kode verifikasi : UTS-7361
Basis data      : uts_23051430020

## Bagian A. Implementasi Skema dan Integritas Data

**A3. Hasil uji migrasi dari nol** 

| t | count |
|---|---|
| jenis_produk | 3 |
| lini_produksi | 3 |
| pelanggan | 4 |
| produk | 8 |
| produksi | 24 |
| pengiriman | 18 |

(uji_migrasi.png)

---

## Bagian B. Analisis dan VIEW

### B4. Interpretasi Manajerial

**Hasil `SELECT * FROM v_nilai_persediaan_jenis`:**

| nama_jenis | total_unit_saldo | nilai_persediaan |
|---|---|---|
| Karton Gelombang | 34000 | 295080000 |
| Karton Lipat | 9400 | 60020000 |
| Sekat Partisi | 11300 | 43350000 |

(view_nilai.png)

**Interpretasi:**

Nilai persediaan tertinggi ada pada jenis Karton Gelombang sebesar Rp295.080.000 (34.000 unit), jauh di atas Karton Lipat (Rp60.020.000) dan Sekat Partisi (Rp43.350.000). Produk fokus PRD-05 (Box Lipat Cetak 4 Warna) memiliki yield terendah dari seluruh produk, yaitu 93,76% (B2), tetapi saldonya 7.900 unit masih di atas stok minimum 4.000 sehingga berstatus SEHAT (B3). Masalah stok justru ada pada PRD-04, produk Karton Lipat sejenis, yang saldonya 1.500 unit jauh di bawah minimum 5.000 unit sehingga menjadi satu-satunya produk berstatus DI BAWAH MINIMUM. Manajemen disarankan segera menjadwalkan produksi ulang PRD-04 di Lini Flexo Printing, sekaligus meninjau pengaturan cetak 4 warna untuk PRD-05 dengan target yield minimal 96%, agar modal tidak menumpuk di Karton Gelombang sementara Karton Lipat kekurangan stok.


## Bagian C. Transaksi dan Konkurensi

Produk fokus: P = 5 (PRD-05, Box Lipat Cetak 4 Warna). Saldo awal dari B3 adalah 7.900 unit.

### C1. Transaksi Pengiriman yang Atomik

**C1.1** Saldo sebelum 7.900. Pengiriman 80% adalah floor(7.900 x 0,8) = 6.320 unit, sehingga saldo sesudah 1.580. Sisipan ke `pengiriman` dan pengurangan `stok_produk` dilakukan dalam satu transaksi (BEGIN sampai COMMIT).

**C1.2** Transaksi kedua mencoba mengirim 7.900 unit (saldo awal). `UPDATE stok_produk` gagal karena 1.580 - 7.900 bernilai negatif dan melanggar constraint `ck_stok_produk_jumlah` (`jumlah >= 0`) yang dibuat di C0. Pesan galat asli:

**C1.3** Setelah ROLLBACK, kueri menunjukkan tidak ada baris pengiriman berjumlah 7.900 untuk produk 5 (hasil 0), saldo tetap 1.580, dan total pengiriman 19 baris (18 dari seed + 1 dari transaksi pertama). *(Lampirkan screenshot ketiga kueri.)*

**Mekanisme.** Dalam transaksi kedua, `INSERT` ke `pengiriman` sempat berhasil, tetapi `UPDATE` berikutnya ditolak constraint sehingga transaksi masuk status aborted. Pada ROLLBACK, DBMS membatalkan seluruh perubahan transaksi itu sebagai satu kesatuan, termasuk sisipan yang sudah terlanjur dieksekusi, sehingga barisnya tidak pernah terlihat oleh sesi lain. Inilah atomisitas: transaksi berhasil seluruhnya atau tidak sama sekali.

### C2. Lost Update dan Pencegahannya

**Eksperimen 1 (tanpa penguncian).** Saldo awal 1.000. Saldo akhir **900**. Seharusnya 1.000 - 200 - 100 = **700**. Angka 900 salah secara bisnis karena pengurangan 200 oleh Sesi A hilang tertimpa: Sesi B menghitung dari nilai 1.000 yang sudah usang (dibaca sebelum Sesi A commit), lalu menulis 900 dan menimpa 800. Akibatnya catatan stok lebih tinggi 200 unit daripada kenyataan, dan perusahaan mengira masih punya barang yang sebenarnya sudah keluar.

**Eksperimen 2 (dengan `FOR UPDATE`).** Saat Sesi B menjalankan `SELECT ... FOR UPDATE`, kueri **tidak langsung kembali** dan terus menunggu karena baris sudah dikunci Sesi A. Lama menunggu:  Begitu Sesi A COMMIT, SELECT Sesi B selesai dan menampilkan **800** (bukan 1.000), sehingga Sesi B menghitung 800 - 100 = 700. Saldo akhir **700**, benar.

**Tabel kronologi Eksperimen 1 (tanpa penguncian)**

| Langkah | Sesi A | Sesi B |
|---|---|---|
| 1 | BEGIN; SELECT saldo, terbaca 1.000 | |
| 2 | | BEGIN; SELECT saldo, terbaca 1.000 |
| 3 | UPDATE saldo = 1.000 - 200 = 800; COMMIT | |
| 4 | | UPDATE saldo = 1.000 - 100 = 900; COMMIT, **PEMBARUAN HILANG DI SINI (800 tertimpa 900)** |
| 5 | Saldo akhir 900 (seharusnya 700) | |

**Tabel kronologi Eksperimen 2 (dengan `FOR UPDATE`)**

| Langkah | Sesi A | Sesi B |
|---|---|---|
| 1 | BEGIN; SELECT ... FOR UPDATE, terbaca 1.000, baris terkunci | |
| 2 | | BEGIN; SELECT ... FOR UPDATE, **MENUNGGU** (diblokir) |
| 3 | UPDATE saldo = 800; COMMIT, kunci dilepas | |
| 4 | | SELECT selesai, terbaca 800 (nilai terbaru) |
| 5 | | UPDATE saldo = 800 - 100 = 700; COMMIT |
| 6 | Saldo akhir 700 (benar) | |

### C3. Penjelasan ACID

- **Atomicity.** Seluruh langkah dalam satu transaksi dieksekusi semuanya atau dibatalkan semuanya. pada C1.2, `INSERT` pengiriman 7.900 ikut dibatalkan ketika `UPDATE stok_produk` gagal, terbukti dari kueri yang menunjukkan 0 baris berjumlah 7.900.
- **Consistency.** Transaksi hanya boleh membawa basis data dari satu keadaan valid ke keadaan valid lain sesuai aturan yang dipasang.  pada C1.2, constraint `ck_stok_produk_jumlah` menolak saldo negatif (1.580 - 7.900), sehingga stok tidak pernah masuk keadaan tidak valid.
- **Isolation.** Transaksi yang berjalan bersamaan tidak saling mengganggu hasilnya. pada Eksperimen 2, `FOR UPDATE` membuat Sesi B menunggu Sesi A selesai, sehingga saldo akhir benar (700). Pada Eksperimen 1 tanpa penguncian, isolasi tidak cukup melindungi dan terjadi lost update (900).
- **Durability.** Data hasil transaksi yang sudah COMMIT tidak hilang. setelah COMMIT pada C1.1, saldo 1.580 tetap terbaca dari sesi lain dan tetap ada setelah koneksi diputus lalu disambung ulang. **

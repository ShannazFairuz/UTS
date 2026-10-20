-- 1. CHECK (produksi): jumlah_baik negatif
INSERT INTO produksi (tanggal, id_produk, id_lini, jumlah_baik, jumlah_cacat)
VALUES ('2026-07-15 07:00+07', 1, 1, -100, 0);

-- 2. Kunci asing (produksi): id_produk 999 tidak ada
INSERT INTO produksi (tanggal, id_produk, id_lini, jumlah_baik, jumlah_cacat)
VALUES ('2026-07-15 07:00+07', 999, 1, 5000, 100);

-- 3. UNIQUE (produk): kode PRD-01 sudah ada
INSERT INTO produk (kode, nama, id_jenis, satuan, harga, stok_minimum)
VALUES ('PRD-01', 'Produk Uji Duplikat', 1, 'pcs', 5000, 100)

--pembuktian
1. SQL Error [23514]: ERROR: baris baru untuk relasi « produksi » melanggar pemeriksaan constraint « ck_produksi_jumlah_baik »
  Detail: Baris gagal berisi (31, 2026-07-15 07:00:00+07, 1, 1, -100, 0)

Error position:

2. SQL Error [23503]: ERROR: insert atau update pada table « produksi » menyalahin aturan foreign key « fk_produksi_produk »
  Detail: Key (id_produk)=(999) tidak ada dalam table « produk ».

Error position:

3. SQL Error [23505]: ERROR: nilai kunci ganda melanggar batasan unik « uq_produk_kode »
  Detail: Kunci « (kode)=(PRD-01) » sudah ada.

Error position:
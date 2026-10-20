
-- C0. Persiapan: tabel stok_produk
CREATE TABLE stok_produk (
    id_produk integer PRIMARY KEY REFERENCES produk (id),
    jumlah    integer NOT NULL,
    CONSTRAINT ck_stok_produk_jumlah CHECK (jumlah >= 0)
);

--  hasil perhitungan B3 
INSERT INTO stok_produk (id_produk, jumlah)
SELECT
    pr.id,
    COALESCE((SELECT SUM(jumlah_baik) FROM produksi  WHERE id_produk = pr.id), 0)
  - COALESCE((SELECT SUM(jumlah)      FROM pengiriman WHERE id_produk = pr.id), 0)
FROM produk pr;
COMMIT;

--saldo B3 (PRD-05 / id 5 = 7900)
SELECT sp.id_produk, pr.kode, sp.jumlah
FROM stok_produk sp JOIN produk pr ON pr.id = sp.id_produk
ORDER BY sp.id_produk;


-- =====================================================================
-- C1.1 Transaksi pengiriman atomik saldo P = 5 
-- =====================================================================
BEGIN;

SELECT jumlah AS saldo_sebelum FROM stok_produk WHERE id_produk = 5;

INSERT INTO pengiriman (id_produk, id_pelanggan, jumlah)
SELECT 5, 1, floor(jumlah * 0.8)::int
FROM stok_produk
WHERE id_produk = 5;

UPDATE stok_produk
SET jumlah = jumlah - floor(jumlah * 0.8)::int
WHERE id_produk = 5;

SELECT jumlah AS saldo_sesudah FROM stok_produk WHERE id_produk = 5;

COMMIT;


-- =====================================================================
-- C1.2  LOST UPDATE .
-- =====================================================================
BEGIN;

INSERT INTO pengiriman (id_produk, id_pelanggan, jumlah)
VALUES (5, 1, 7900);

UPDATE stok_produk
SET jumlah = jumlah - 7900
WHERE id_produk = 5;
-- 

ROLLBACK;


-- =====================================================================
-- C1.3 Bukti atomik 
-- =====================================================================
-- (a) Baris pengiriman 
SELECT count(*) AS baris_7900
FROM pengiriman
WHERE id_produk = 5 AND jumlah = 7900;

-- (b) Saldo tidak berubah 
SELECT jumlah AS saldo_setelah_gagal FROM stok_produk WHERE id_produk = 5;

-- (c) Hanya pengiriman transaksi
SELECT count(*) AS total_pengiriman FROM pengiriman;
SELECT id, tanggal, jumlah FROM pengiriman WHERE id_produk = 5 ORDER BY id DESC LIMIT 3;


-- C2. Lost update dan pencegahannya  
-- =====================================================================

UPDATE stok_produk SET jumlah = 1000 WHERE id_produk = 5;
COMMIT;

-- ---------------------------------------------------------------------
-- EKSPERIMEN 1: TANPA penguncian
-- ---------------------------------------------------------------------
-- [1] SESI A
BEGIN;
SELECT jumlah FROM stok_produk WHERE id_produk = 5;            

-- [2] SESI B
BEGIN;
SELECT jumlah FROM stok_produk WHERE id_produk = 5;            

-- [3] SESI A: tulis saldo - 200 lalu COMMIT
UPDATE stok_produk SET jumlah = 1000 - 200 WHERE id_produk = 5;   
COMMIT;

-- [4] SESI B
UPDATE stok_produk SET jumlah = 1000 - 100 WHERE id_produk = 5;   
COMMIT;

-- [5] Cek saldo akhir 
SELECT jumlah AS saldo_akhir_eksperimen_1 FROM stok_produk WHERE id_produk = 5;

-- ---------------------------------------------------------------------
-- EKSPERIMEN 2: DENGAN penguncian (FOR UPDATE)
-- ---------------------------------------------------------------------
UPDATE stok_produk SET jumlah = 1000 WHERE id_produk = 5;
COMMIT;

-- [1] SESI A
BEGIN;
SELECT jumlah FROM stok_produk WHERE id_produk = 5 FOR UPDATE;  

-- [2] SESI B 
BEGIN;
SELECT jumlah FROM stok_produk WHERE id_produk = 5 FOR UPDATE;  

;

-- [3] SESI A
UPDATE stok_produk SET jumlah = 1000 - 200 WHERE id_produk = 5;   
COMMIT;


-- [4] SESI B:
UPDATE stok_produk SET jumlah = 800 - 100 WHERE id_produk = 5;    
COMMIT;

-- [5] Cek saldo akhir
SELECT jumlah AS saldo_akhir_eksperimen_2 FROM stok_produk WHERE id_produk = 5;

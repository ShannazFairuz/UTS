-- B1. Rekap produksi per lini per bulan
-- ---------------------------------------------------------------------
SELECT
    l.kode                          AS kode_lini,
    to_char(p.tanggal, 'YYYY-MM')   AS bulan,
    SUM(p.jumlah_baik)              AS total_baik,
    SUM(p.jumlah_cacat)             AS total_cacat
FROM produksi p
JOIN lini_produksi l ON l.id = p.id_lini
GROUP BY l.kode, to_char(p.tanggal, 'YYYY-MM')
ORDER BY bulan ASC, kode_lini ASC;

-- B2. Yield per produk (CTE)
-- ---------------------------------------------------------------------
WITH total_produksi AS (
    SELECT
        id_produk,
        SUM(jumlah_baik)  AS total_baik,
        SUM(jumlah_cacat) AS total_cacat
    FROM produksi
    GROUP BY id_produk
)
SELECT
    pr.kode,
    pr.nama,
    COALESCE(t.total_baik, 0)  AS total_baik,
    COALESCE(t.total_cacat, 0) AS total_cacat,
    ROUND(
        100.0 * COALESCE(t.total_baik, 0)
        / NULLIF(COALESCE(t.total_baik, 0) + COALESCE(t.total_cacat, 0), 0)
    , 2) AS yield_persen
FROM produk pr
LEFT JOIN total_produksi t ON t.id_produk = pr.id
ORDER BY yield_persen ASC, pr.kode ASC;

-- B3. Saldo stok dan status terhadap stok minimum
-- ---------------------------------------------------------------------
WITH masuk AS (
    SELECT id_produk, SUM(jumlah_baik) AS total_baik
    FROM produksi
    GROUP BY id_produk
),
keluar AS (
    SELECT id_produk, SUM(jumlah) AS total_kirim
    FROM pengiriman
    GROUP BY id_produk
)
SELECT
    pr.kode,
    pr.nama,
    COALESCE(m.total_baik, 0) - COALESCE(k.total_kirim, 0) AS saldo,
    pr.stok_minimum,
    CASE
        WHEN COALESCE(m.total_baik, 0) - COALESCE(k.total_kirim, 0) >= pr.stok_minimum
            THEN 'SEHAT'
        ELSE 'DI BAWAH MINIMUM'
    END AS status
FROM produk pr
LEFT JOIN masuk  m ON m.id_produk = pr.id
LEFT JOIN keluar k ON k.id_produk = pr.id
ORDER BY pr.kode;

-- ---------------------------------------------------------------------
-- B4.1 VIEW nilai persediaan per jenis produk
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_nilai_persediaan_jenis AS
WITH masuk AS (
    SELECT id_produk, SUM(jumlah_baik) AS total_baik
    FROM produksi
    GROUP BY id_produk
),
keluar AS (
    SELECT id_produk, SUM(jumlah) AS total_kirim
    FROM pengiriman
    GROUP BY id_produk
),
saldo_produk AS (
    SELECT
        pr.id_jenis,
        pr.harga,
        COALESCE(m.total_baik, 0) - COALESCE(k.total_kirim, 0) AS saldo
    FROM produk pr
    LEFT JOIN masuk  m ON m.id_produk = pr.id
    LEFT JOIN keluar k ON k.id_produk = pr.id
)
SELECT
    jp.nama                    AS nama_jenis,
    SUM(sp.saldo)              AS total_unit_saldo,
    SUM(sp.saldo * sp.harga)   AS nilai_persediaan
FROM saldo_produk sp
JOIN jenis_produk jp ON jp.id = sp.id_jenis
GROUP BY jp.nama
ORDER BY nilai_persediaan DESC;

-- B4.2 SELECT atas VIEW 
-- ---------------------------------------------------------------------
SELECT * FROM v_nilai_persediaan_jenis ORDER BY nilai_persediaan DESC;

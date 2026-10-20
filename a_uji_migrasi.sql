SELECT 'jenis_produk' t, count(*) FROM jenis_produk
UNION ALL SELECT 'lini_produksi', count(*) FROM lini_produksi
UNION ALL SELECT 'pelanggan',     count(*) FROM pelanggan
UNION ALL SELECT 'produk',        count(*) FROM produk
UNION ALL SELECT 'produksi',      count(*) FROM produksi
UNION ALL SELECT 'pengiriman',    count(*) FROM pengiriman;
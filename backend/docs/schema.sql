-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Feb 03, 2026 at 02:54 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `ayocuci`
--

-- --------------------------------------------------------

--
-- Table structure for table `ac_config_nota`
--

CREATE TABLE `ac_config_nota` (
  `cn_id` varchar(50) NOT NULL,
  `cn_outlet` varchar(20) NOT NULL,
  `cn_nama_outlet` longtext DEFAULT NULL,
  `cn_alamat` longtext DEFAULT NULL,
  `cn_kontak` longtext DEFAULT NULL,
  `cn_logo` longtext DEFAULT NULL,
  `cn_footer_nota` longtext DEFAULT NULL,
  `cn_footer_whatsapp` longtext DEFAULT NULL,
  `cn_sett_logo` tinyint(1) DEFAULT 1,
  `cn_sett_qr` tinyint(1) DEFAULT 1,
  `cn_sett_kasir` tinyint(1) DEFAULT 1,
  `cn_sett_keterangan` tinyint(1) DEFAULT 1,
  `cn_sett_nota` tinyint(1) DEFAULT 1,
  `cn_sett_whatsapp` tinyint(1) DEFAULT 1,
  `cn_ukuran` bigint(20) DEFAULT 58,
  `cn_lastupdate` datetime(3) DEFAULT NULL,
  `cn_userupdate` varchar(50) DEFAULT NULL,
  `cn_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_config_nota`
--

INSERT INTO `ac_config_nota` (`cn_id`, `cn_outlet`, `cn_nama_outlet`, `cn_alamat`, `cn_kontak`, `cn_logo`, `cn_footer_nota`, `cn_footer_whatsapp`, `cn_sett_logo`, `cn_sett_qr`, `cn_sett_kasir`, `cn_sett_keterangan`, `cn_sett_nota`, `cn_sett_whatsapp`, `cn_ukuran`, `cn_lastupdate`, `cn_userupdate`, `cn_userupdate_type`) VALUES
('NS-1.001', '1.001', 'Ayo Cuci Batu Aji Updated', 'Jl. Sudirman No. 10, Komplek Ruko A1', '081234567890', NULL, 'Terima kasih telah mencuci di tempat kami. Harap simpan nota ini.', 'Cucian anda sudah selesai, silakan diambil!', 1, 1, 1, 0, 1, 1, 80, '2026-02-02 11:29:15.708', 'PGW.1.001.01', 'pegawai');

-- --------------------------------------------------------

--
-- Table structure for table `ac_detail_transaksi`
--

CREATE TABLE `ac_detail_transaksi` (
  `dtr_id` varchar(80) NOT NULL,
  `dtr_transaksi` varchar(60) DEFAULT NULL,
  `dtr_layanan` varchar(40) DEFAULT NULL,
  `dtr_nama_layanan` longtext DEFAULT NULL,
  `dtr_harga` double DEFAULT NULL,
  `dtr_qty` double DEFAULT NULL,
  `dtr_satuan` longtext DEFAULT NULL,
  `dtr_subtotal` double DEFAULT NULL,
  `dtr_ready_at` datetime(3) DEFAULT NULL,
  `dtr_created` datetime(3) DEFAULT NULL,
  `dtr_userupdate` varchar(50) DEFAULT NULL,
  `dtr_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_detail_transaksi`
--

INSERT INTO `ac_detail_transaksi` (`dtr_id`, `dtr_transaksi`, `dtr_layanan`, `dtr_nama_layanan`, `dtr_harga`, `dtr_qty`, `dtr_satuan`, `dtr_subtotal`, `dtr_ready_at`, `dtr_created`, `dtr_userupdate`, `dtr_userupdate_type`) VALUES
('DTRX/TRX/1.001/202601300001/001', 'TRX/1.001/202601300001', 'JP.LN.1.001.01.01', 'Cuci Komplit (Reguler)', 6000, 30, 'Kg', 180000, '2026-02-01 14:06:27.175', '2026-01-30 14:06:27.181', '1', 'user'),
('DTRX/TRX/1.001/202601300001/002', 'TRX/1.001/202601300001', 'JP.LN.1.001.02.01', 'Reguler', 2000, 8, 'Kg', 16000, '2026-02-01 14:06:27.175', '2026-01-30 14:06:27.183', '1', 'user'),
('DTRX/TRX/1.001/202601300002/001', 'TRX/1.001/202601300002', 'JP.LN.1.001.01.01', 'Cuci Komplit (Reguler)', 6000, 20.2, 'Kg', 121200, '2026-02-01 14:11:11.846', '2026-01-30 14:11:11.847', '1', 'user'),
('DTRX/TRX/1.001/202602020001/001', 'TRX/1.001/202602020001', 'JP.LN.1.001.01.01', 'Cuci Komplit (Reguler)', 6000, 30, 'Kg', 180000, '2026-02-04 11:27:45.627', '2026-02-02 11:27:45.632', 'PGW.1.001.01', 'pegawai'),
('DTRX/TRX/1.001/202602020001/002', 'TRX/1.001/202602020001', 'JP.LN.1.001.02.01', 'Reguler', 2000, 8, 'Kg', 16000, '2026-02-04 11:27:45.627', '2026-02-02 11:27:45.634', 'PGW.1.001.01', 'pegawai'),
('DTRX/TRX/1.001/202602020002/001', 'TRX/1.001/202602020002', 'JP.LN.1.001.01.01', 'Cuci Komplit (Reguler)', 6000, 30, 'Kg', 180000, '2026-02-04 11:29:26.139', '2026-02-02 11:29:26.142', 'PGW.1.001.01', 'pegawai'),
('DTRX/TRX/1.001/202602020002/002', 'TRX/1.001/202602020002', 'JP.LN.1.001.02.01', 'Reguler', 2000, 8, 'Kg', 16000, '2026-02-04 11:29:26.139', '2026-02-02 11:29:26.142', 'PGW.1.001.01', 'pegawai');

-- --------------------------------------------------------

--
-- Table structure for table `ac_diskon`
--

CREATE TABLE `ac_diskon` (
  `dis_id` varchar(50) NOT NULL,
  `dis_outlet` varchar(20) DEFAULT NULL,
  `dis_nama` longtext DEFAULT NULL,
  `dis_nilai_diskon` double DEFAULT NULL,
  `dis_jenis` longtext DEFAULT NULL,
  `dis_tanggal_mulai` datetime(3) DEFAULT NULL,
  `dis_tanggal_akhir` datetime(3) DEFAULT NULL,
  `dis_status` bigint(20) DEFAULT 1,
  `dis_created` datetime(3) DEFAULT NULL,
  `dis_lastupdate` datetime(3) DEFAULT NULL,
  `dis_userupdate` varchar(50) DEFAULT NULL,
  `dis_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_diskon`
--

INSERT INTO `ac_diskon` (`dis_id`, `dis_outlet`, `dis_nama`, `dis_nilai_diskon`, `dis_jenis`, `dis_tanggal_mulai`, `dis_tanggal_akhir`, `dis_status`, `dis_created`, `dis_lastupdate`, `dis_userupdate`, `dis_userupdate_type`) VALUES
('DIS.1.001.01.001', '1.001', 'Promo 11.11', 40000, 'nominal', '2026-01-01 07:00:00.000', '2026-02-01 07:00:00.000', 1, '2026-01-30 14:05:07.229', '2026-01-30 14:05:07.229', '1', 'user'),
('DIS.1.001.01.002', '1.001', 'Promo Grand Opening', 10, 'persen', '2026-01-01 07:00:00.000', '2026-02-01 07:00:00.000', 1, '2026-01-30 14:05:12.116', '2026-01-30 14:05:12.116', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_dp_transaksi`
--

CREATE TABLE `ac_dp_transaksi` (
  `dptr_id` varchar(70) NOT NULL,
  `dptr_transaksi` varchar(60) DEFAULT NULL,
  `dptr_metode_pembayaran` varchar(40) DEFAULT NULL,
  `dptr_bukti_dp` longtext DEFAULT NULL,
  `dptr_tanggal_dp` datetime(3) DEFAULT NULL,
  `dptr_jumlah_dp` double DEFAULT NULL,
  `dptr_jumlah_sisa` double DEFAULT NULL,
  `dptr_created` datetime(3) DEFAULT NULL,
  `dptr_lastupdate` datetime(3) DEFAULT NULL,
  `dptr_userupdate` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_dp_transaksi`
--

INSERT INTO `ac_dp_transaksi` (`dptr_id`, `dptr_transaksi`, `dptr_metode_pembayaran`, `dptr_bukti_dp`, `dptr_tanggal_dp`, `dptr_jumlah_dp`, `dptr_jumlah_sisa`, `dptr_created`, `dptr_lastupdate`, `dptr_userupdate`) VALUES
('DPTRX/TRX/1.001/202601300001/001', 'TRX/1.001/202601300001', 'MP.1.001.02', NULL, '2026-01-30 14:06:27.175', 50000, 106000, '2026-01-30 14:06:27.196', '2026-01-30 14:06:27.196', '1'),
('DPTRX/TRX/1.001/202601300002/001', 'TRX/1.001/202601300002', 'MP.1.001.02', NULL, '2026-01-30 14:11:11.846', 121200, 0, '2026-01-30 14:11:11.848', '2026-01-30 14:11:11.848', '1'),
('DPTRX/TRX/1.001/202602020001/001', 'TRX/1.001/202602020001', 'MP.1.001.02', NULL, '2026-02-02 11:27:45.627', 50000, 106000, '2026-02-02 11:27:45.639', '2026-02-02 11:27:45.639', 'PGW.1.001.01'),
('DPTRX/TRX/1.001/202602020002/001', 'TRX/1.001/202602020002', 'MP.1.001.02', NULL, '2026-02-02 11:29:26.139', 50000, 106000, '2026-02-02 11:29:26.157', '2026-02-02 11:29:26.157', 'PGW.1.001.01');

-- --------------------------------------------------------

--
-- Table structure for table `ac_fitur`
--

CREATE TABLE `ac_fitur` (
  `ftr_id` bigint(20) UNSIGNED NOT NULL,
  `ftr_kode` varchar(191) NOT NULL,
  `ftr_nama` longtext DEFAULT NULL,
  `ftr_status` bigint(20) DEFAULT 1,
  `ftr_lastupdate` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_fitur`
--

INSERT INTO `ac_fitur` (`ftr_id`, `ftr_kode`, `ftr_nama`, `ftr_status`, `ftr_lastupdate`) VALUES
(1, 'DASHBOARD_BASIC', 'Akses Dashboard Utama', 1, NULL),
(2, 'TRX_STANDARD', 'Transaksi Kiloan & Satuan', 1, NULL),
(3, 'PELANGGAN_DB', 'Database Pelanggan', 1, NULL),
(4, 'LAPORAN_HARIAN', 'Laporan Harian', 1, NULL),
(5, 'LAPORAN_ADV', 'Laporan Lanjutan & Grafik', 1, NULL),
(6, 'MULTI_OUTLET', 'Kelola Lebih dari 1 Outlet', 1, NULL),
(7, 'WHATSAPP_AUTO', 'Notifikasi WhatsApp Otomatis', 1, NULL),
(8, 'EXPENSE_TRACK', 'Pencatatan Pengeluaran', 1, NULL),
(9, 'EMP_MANAGEMENT', 'Manajemen Staff (Role & Access)', 1, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `ac_fitur_paket`
--

CREATE TABLE `ac_fitur_paket` (
  `fpkt_id` bigint(20) UNSIGNED NOT NULL,
  `fpkt_paket` bigint(20) UNSIGNED NOT NULL,
  `fpkt_fitur` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_fitur_paket`
--

INSERT INTO `ac_fitur_paket` (`fpkt_id`, `fpkt_paket`, `fpkt_fitur`) VALUES
(1, 1, 1),
(2, 1, 2),
(3, 1, 3),
(4, 1, 4),
(5, 2, 1),
(6, 2, 2),
(7, 2, 3),
(8, 2, 4),
(9, 2, 8),
(10, 2, 9),
(11, 3, 1),
(12, 3, 2),
(13, 3, 3),
(14, 3, 4),
(15, 3, 5),
(16, 3, 6),
(17, 3, 7),
(18, 3, 8),
(19, 3, 9),
(20, 3, 1),
(21, 3, 2),
(22, 3, 3),
(23, 3, 4),
(24, 3, 5),
(25, 3, 6),
(26, 3, 7),
(27, 3, 8),
(28, 3, 9);

-- --------------------------------------------------------

--
-- Table structure for table `ac_item`
--

CREATE TABLE `ac_item` (
  `it_id` varchar(40) NOT NULL,
  `it_outlet` varchar(20) DEFAULT NULL,
  `it_item` longtext NOT NULL,
  `it_status` bigint(20) DEFAULT 1,
  `it_created` datetime(3) DEFAULT NULL,
  `it_lastupdate` datetime(3) DEFAULT NULL,
  `it_userupdate` varchar(50) DEFAULT NULL,
  `it_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_item`
--

INSERT INTO `ac_item` (`it_id`, `it_outlet`, `it_item`, `it_status`, `it_created`, `it_lastupdate`, `it_userupdate`, `it_userupdate_type`) VALUES
('IT.1.001.01', '1.001', 'Baju', 1, '2026-01-30 14:00:38.780', '2026-01-30 14:00:38.780', '1', 'user'),
('IT.1.001.02', '1.001', 'Celana', 1, '2026-01-30 14:00:38.782', '2026-01-30 14:00:38.782', '1', 'user'),
('IT.1.001.03', '1.001', 'Selimut', 1, '2026-01-30 14:00:38.782', '2026-01-30 14:00:38.782', '1', 'user'),
('IT.1.001.04', '1.001', 'Handuk', 1, '2026-01-30 14:00:38.782', '2026-01-30 14:00:38.782', '1', 'user'),
('IT.1.001.05', '1.001', 'Sprei', 1, '2026-01-30 14:00:38.782', '2026-01-30 14:00:38.782', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_item_transaksi`
--

CREATE TABLE `ac_item_transaksi` (
  `itr_id` varchar(70) NOT NULL,
  `itr_transaksi` varchar(60) DEFAULT NULL,
  `itr_item` varchar(40) DEFAULT NULL,
  `itr_qty` bigint(20) DEFAULT NULL,
  `itr_keterangan` longtext DEFAULT NULL,
  `itr_created` datetime(3) DEFAULT NULL,
  `itr_lastupdate` datetime(3) DEFAULT NULL,
  `itr_userupdate` varchar(50) DEFAULT NULL,
  `itr_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_item_transaksi`
--

INSERT INTO `ac_item_transaksi` (`itr_id`, `itr_transaksi`, `itr_item`, `itr_qty`, `itr_keterangan`, `itr_created`, `itr_lastupdate`, `itr_userupdate`, `itr_userupdate_type`) VALUES
('ITRX/TRX/1.001/202601300001/001', 'TRX/1.001/202601300001', 'IT.1.001.01', 10, '', '2026-01-30 14:06:27.184', '2026-01-30 14:06:27.184', '1', 'user'),
('ITRX/TRX/1.001/202601300001/002', 'TRX/1.001/202601300001', 'IT.1.001.02', 2, '', '2026-01-30 14:06:27.190', '2026-01-30 14:06:27.190', '1', 'user'),
('ITRX/TRX/1.001/202601300002/001', 'TRX/1.001/202601300002', 'IT.1.001.01', 10, 'Baju campur', '2026-01-30 14:11:11.847', '2026-01-30 14:11:11.847', '1', 'user'),
('ITRX/TRX/1.001/202602020001/001', 'TRX/1.001/202602020001', 'IT.1.001.01', 10, '', '2026-02-02 11:27:45.634', '2026-02-02 11:27:45.634', 'PGW.1.001.01', 'pegawai'),
('ITRX/TRX/1.001/202602020001/002', 'TRX/1.001/202602020001', 'IT.1.001.02', 2, '', '2026-02-02 11:27:45.635', '2026-02-02 11:27:45.635', 'PGW.1.001.01', 'pegawai'),
('ITRX/TRX/1.001/202602020002/001', 'TRX/1.001/202602020002', 'IT.1.001.01', 10, '', '2026-02-02 11:29:26.149', '2026-02-02 11:29:26.149', 'PGW.1.001.01', 'pegawai'),
('ITRX/TRX/1.001/202602020002/002', 'TRX/1.001/202602020002', 'IT.1.001.02', 2, '', '2026-02-02 11:29:26.153', '2026-02-02 11:29:26.153', 'PGW.1.001.01', 'pegawai');

-- --------------------------------------------------------

--
-- Table structure for table `ac_jenis_produk`
--

CREATE TABLE `ac_jenis_produk` (
  `jp_id` varchar(40) NOT NULL,
  `jp_layanan` varchar(30) DEFAULT NULL,
  `jp_nama` longtext DEFAULT NULL,
  `jp_harga` double DEFAULT NULL,
  `jp_satuan` longtext DEFAULT NULL,
  `jp_durasi` bigint(20) DEFAULT NULL,
  `jp_durasi_satuan` longtext DEFAULT NULL,
  `jp_gambar` longtext DEFAULT NULL,
  `jp_lastupdate` datetime(3) DEFAULT NULL,
  `jp_userupdate` varchar(50) DEFAULT NULL,
  `jp_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_jenis_produk`
--

INSERT INTO `ac_jenis_produk` (`jp_id`, `jp_layanan`, `jp_nama`, `jp_harga`, `jp_satuan`, `jp_durasi`, `jp_durasi_satuan`, `jp_gambar`, `jp_lastupdate`, `jp_userupdate`, `jp_userupdate_type`) VALUES
('JP.LN.1.001.01.01', 'LN.1.001.01', 'Cuci Komplit (Reguler)', 6000, 'Kg', 2, 'Hari', 'assets/icons/kiloan.png', '2026-01-30 14:00:38.772', '1', 'user'),
('JP.LN.1.001.01.02', 'LN.1.001.01', 'Cuci Komplit (Ekspres)', 10000, 'Kg', 1, 'Hari', 'assets/icons/express.png', '2026-01-30 14:00:38.773', '1', 'user'),
('JP.LN.1.001.02.01', 'LN.1.001.02', 'Reguler', 2000, 'Kg', 2, 'Hari', 'assets/icons/kiloan.png', '2026-01-30 14:04:02.127', '1', 'user'),
('JP.LN.1.001.02.02', 'LN.1.001.02', 'Express', 4000, 'Kg', 1, 'Hari', 'assets/icons/express.png', '2026-01-30 14:04:02.132', '1', 'user'),
('JP.LN.1.001.02.03', 'LN.1.001.02', 'Kilat', 8000, 'Kg', 4, 'Jam', 'assets/icons/kilat.png', '2026-01-30 14:04:02.132', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_kategori_pengeluaran`
--

CREATE TABLE `ac_kategori_pengeluaran` (
  `kp_id` varchar(50) NOT NULL,
  `kp_outlet` varchar(20) DEFAULT NULL,
  `kp_kategori` longtext DEFAULT NULL,
  `kp_status` bigint(20) DEFAULT 1,
  `kp_created` datetime(3) DEFAULT NULL,
  `kp_lastupdate` datetime(3) DEFAULT NULL,
  `kp_userupdate` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_kategori_pengeluaran`
--

INSERT INTO `ac_kategori_pengeluaran` (`kp_id`, `kp_outlet`, `kp_kategori`, `kp_status`, `kp_created`, `kp_lastupdate`, `kp_userupdate`) VALUES
('KP.1.001.01', '1.001', 'Listrik & Air', 1, '2026-01-30 14:00:38.773', '2026-01-30 14:00:38.773', '1'),
('KP.1.001.02', '1.001', 'Sewa Tempat', 1, '2026-01-30 14:00:38.774', '2026-01-30 14:00:38.774', '1'),
('KP.1.001.03', '1.001', 'Gaji Pegawai', 1, '2026-01-30 14:00:38.774', '2026-01-30 14:00:38.774', '1'),
('KP.1.001.04', '1.001', 'Sabun & Pewangi', 1, '2026-01-30 14:00:38.774', '2026-01-30 14:00:38.774', '1'),
('KP.1.001.05', '1.001', 'Lain-lain', 1, '2026-01-30 14:00:38.779', '2026-01-30 14:00:38.779', '1');

-- --------------------------------------------------------

--
-- Table structure for table `ac_layanan`
--

CREATE TABLE `ac_layanan` (
  `ly_id` varchar(30) NOT NULL,
  `ly_outlet` varchar(20) DEFAULT NULL,
  `ly_nama` longtext DEFAULT NULL,
  `ly_proses` longtext DEFAULT NULL,
  `ly_created` datetime(3) DEFAULT NULL,
  `ly_lastupdate` datetime(3) DEFAULT NULL,
  `ly_userupdate` varchar(50) DEFAULT NULL,
  `ly_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_layanan`
--

INSERT INTO `ac_layanan` (`ly_id`, `ly_outlet`, `ly_nama`, `ly_proses`, `ly_created`, `ly_lastupdate`, `ly_userupdate`, `ly_userupdate_type`) VALUES
('LN.1.001.01', '1.001', 'Cuci Kiloan', 'Cuci,Kering,Setrika', '2026-01-30 14:00:38.772', '2026-01-30 14:00:38.772', '1', 'user'),
('LN.1.001.02', '1.001', 'Kiloan', 'Cuci,Kering,Setrika', '2026-01-30 14:04:02.125', '2026-01-30 14:04:02.125', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_log_transaksi`
--

CREATE TABLE `ac_log_transaksi` (
  `lr_id` varchar(80) NOT NULL,
  `lr_transaksi` varchar(60) DEFAULT NULL,
  `lr_detail_transaksi` varchar(80) DEFAULT NULL,
  `lr_scope` longtext DEFAULT NULL,
  `lr_field` longtext DEFAULT NULL,
  `lr_old_value` longtext DEFAULT NULL,
  `lr_new_value` longtext DEFAULT NULL,
  `lr_actor_id` varchar(50) DEFAULT NULL,
  `lr_actor_type` longtext DEFAULT NULL,
  `lr_created` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_log_transaksi`
--

INSERT INTO `ac_log_transaksi` (`lr_id`, `lr_transaksi`, `lr_detail_transaksi`, `lr_scope`, `lr_field`, `lr_old_value`, `lr_new_value`, `lr_actor_id`, `lr_actor_type`, `lr_created`) VALUES
('LTRX/TRX/1.001/202601300001/001', 'TRX/1.001/202601300001', NULL, 'header', 'status_order', NULL, 'Nota Dibuat', '1', 'user', '2026-01-30 14:06:27.198'),
('LTRX/TRX/1.001/202601300002/001', 'TRX/1.001/202601300002', NULL, 'header', 'status_order', NULL, 'Nota Dibuat', '1', 'user', '2026-01-30 14:11:11.849'),
('LTRX/TRX/1.001/202602020001/001', 'TRX/1.001/202602020001', NULL, 'header', 'status_order', NULL, 'Nota Dibuat', 'PGW.1.001.01', 'pegawai', '2026-02-02 11:27:45.645'),
('LTRX/TRX/1.001/202602020002/001', 'TRX/1.001/202602020002', NULL, 'header', 'status_order', NULL, 'Nota Dibuat', 'PGW.1.001.01', 'pegawai', '2026-02-02 11:29:26.158');

-- --------------------------------------------------------

--
-- Table structure for table `ac_metode_pembayaran`
--

CREATE TABLE `ac_metode_pembayaran` (
  `mp_id` varchar(40) NOT NULL,
  `mp_outlet` varchar(20) DEFAULT NULL,
  `mp_nama_metode` longtext DEFAULT NULL,
  `mp_deskripsi` longtext DEFAULT NULL,
  `mp_kategori` longtext DEFAULT NULL,
  `mp_status` bigint(20) DEFAULT 1,
  `mp_nama_pemilik` longtext DEFAULT NULL,
  `mp_nomor_akun` longtext DEFAULT NULL,
  `mp_nama_bank` longtext DEFAULT NULL,
  `mp_ewallet_provider` longtext DEFAULT NULL,
  `mp_nomor_hp` longtext DEFAULT NULL,
  `mp_created` datetime(3) DEFAULT NULL,
  `mp_lastupdate` datetime(3) DEFAULT NULL,
  `mp_userupdate` varchar(50) DEFAULT NULL,
  `mp_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_metode_pembayaran`
--

INSERT INTO `ac_metode_pembayaran` (`mp_id`, `mp_outlet`, `mp_nama_metode`, `mp_deskripsi`, `mp_kategori`, `mp_status`, `mp_nama_pemilik`, `mp_nomor_akun`, `mp_nama_bank`, `mp_ewallet_provider`, `mp_nomor_hp`, `mp_created`, `mp_lastupdate`, `mp_userupdate`, `mp_userupdate_type`) VALUES
('MP.1.001.01', '1.001', 'Tunai / Cash', '', 'Cash', 1, NULL, NULL, NULL, NULL, NULL, '2026-01-30 14:00:38.780', '2026-01-30 14:00:38.780', '1', 'user'),
('MP.1.001.02', '1.001', 'BCA - Transfer', 'BCA Helwiza', 'Transfer', 1, 'Helwiza', '1234567890', 'BCA', NULL, NULL, '2026-01-30 14:04:56.379', '2026-01-30 14:04:56.379', '1', 'user'),
('MP.1.001.03', '1.001', 'OVO Helwiza', 'Pembayaran via OVO', 'E-Wallet', 1, NULL, NULL, NULL, 'OVO', '08123456789', '2026-01-30 14:05:01.571', '2026-01-30 14:05:01.571', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_outlet`
--

CREATE TABLE `ac_outlet` (
  `ot_id` varchar(20) NOT NULL,
  `ot_user` bigint(20) UNSIGNED NOT NULL,
  `ot_nama` longtext DEFAULT NULL,
  `ot_nohp` longtext DEFAULT NULL,
  `ot_provinsi` longtext DEFAULT NULL,
  `ot_kota` longtext DEFAULT NULL,
  `ot_kecamatan` longtext DEFAULT NULL,
  `ot_alamat` longtext DEFAULT NULL,
  `ot_gambar` longtext DEFAULT NULL,
  `ot_status` bigint(20) DEFAULT 1,
  `ot_created` datetime(3) DEFAULT NULL,
  `ot_lastupdate` datetime(3) DEFAULT NULL,
  `ot_userupdate` varchar(50) DEFAULT NULL,
  `ot_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_outlet`
--

INSERT INTO `ac_outlet` (`ot_id`, `ot_user`, `ot_nama`, `ot_nohp`, `ot_provinsi`, `ot_kota`, `ot_kecamatan`, `ot_alamat`, `ot_gambar`, `ot_status`, `ot_created`, `ot_lastupdate`, `ot_userupdate`, `ot_userupdate_type`) VALUES
('1.001', 1, 'Ayo Cuci Batu Aji', '081234567890', 'Kepulauan Riau', 'Batam', 'Batam Kota', 'Jl. Sudirman No. 10', NULL, 1, '2026-01-30 14:00:38.753', '2026-01-30 14:15:34.940', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_paket`
--

CREATE TABLE `ac_paket` (
  `pkt_id` bigint(20) UNSIGNED NOT NULL,
  `pkt_nama` longtext NOT NULL,
  `pkt_harga` double DEFAULT 0,
  `pkt_jumlah_hari` bigint(20) DEFAULT NULL,
  `pkt_jumlah_staff` bigint(20) DEFAULT NULL,
  `pkt_status` bigint(20) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_paket`
--

INSERT INTO `ac_paket` (`pkt_id`, `pkt_nama`, `pkt_harga`, `pkt_jumlah_hari`, `pkt_jumlah_staff`, `pkt_status`) VALUES
(1, 'Paket Hemat (Trial)', 0, 7, 2, 1),
(2, 'Paket Reguler', 150000, 30, 5, 1),
(3, 'Paket Sultan (Business)', 350000, 30, 20, 1);

-- --------------------------------------------------------

--
-- Table structure for table `ac_parfum`
--

CREATE TABLE `ac_parfum` (
  `pf_id` varchar(40) NOT NULL,
  `pf_outlet` varchar(20) DEFAULT NULL,
  `pf_nama` longtext DEFAULT NULL,
  `pf_status` bigint(20) DEFAULT 1,
  `pf_created` datetime(3) DEFAULT NULL,
  `pf_lastupdate` datetime(3) DEFAULT NULL,
  `pf_userupdate` varchar(50) DEFAULT NULL,
  `pf_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_parfum`
--

INSERT INTO `ac_parfum` (`pf_id`, `pf_outlet`, `pf_nama`, `pf_status`, `pf_created`, `pf_lastupdate`, `pf_userupdate`, `pf_userupdate_type`) VALUES
('PF.1.001.01', '1.001', 'Ocean Fresh', 1, '2026-01-30 14:00:38.763', '2026-01-30 14:00:38.763', '1', 'user'),
('PF.1.001.02', '1.001', 'Sakura', 1, '2026-01-30 14:00:38.764', '2026-01-30 14:00:38.764', '1', 'user'),
('PF.1.001.03', '1.001', 'Lavender', 1, '2026-01-30 14:00:38.764', '2026-01-30 14:00:38.764', '1', 'user'),
('PF.1.001.04', '1.001', 'Lily', 1, '2026-01-30 14:00:38.769', '2026-01-30 14:00:38.769', '1', 'user'),
('PF.1.001.05', '1.001', 'Tanpa Parfum', 1, '2026-01-30 14:00:38.770', '2026-01-30 14:00:38.770', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_pegawai`
--

CREATE TABLE `ac_pegawai` (
  `pg_id` varchar(30) NOT NULL,
  `pg_outlet` varchar(20) DEFAULT NULL,
  `pg_role` varchar(50) NOT NULL,
  `pg_nama` longtext DEFAULT NULL,
  `pg_email` varchar(191) DEFAULT NULL,
  `pg_nohp` longtext DEFAULT NULL,
  `pg_password` longtext DEFAULT NULL,
  `pg_status` bigint(20) DEFAULT 1,
  `pg_created` datetime(3) DEFAULT NULL,
  `pg_lastupdate` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_pegawai`
--

INSERT INTO `ac_pegawai` (`pg_id`, `pg_outlet`, `pg_role`, `pg_nama`, `pg_email`, `pg_nohp`, `pg_password`, `pg_status`, `pg_created`, `pg_lastupdate`) VALUES
('PGW.1.001.01', '1.001', 'RL.1.001.01', 'Admin Agus', 'AdminAgus@ayocuci.com', '08123456789', '$2a$10$nRa6fn6N4ZKGKGuVOvVqz.42x0giBwAnjQNO8dR.5HmPNb7sGXHUW', 1, '2026-01-30 14:05:57.741', '2026-01-30 14:05:57.741'),
('PGW.1.001.02', '1.001', 'RL.1.001.03', 'Investor A', 'investor@ayocuci.com', '081234567890', '$2a$10$XfyQuAeA/XiIU2WRxEiF.OFFdXmsjRkCj5zyc/GAo9beaG0dkZNeq', 1, '2026-01-30 14:06:14.502', '2026-01-30 14:06:14.502');

-- --------------------------------------------------------

--
-- Table structure for table `ac_pelanggan`
--

CREATE TABLE `ac_pelanggan` (
  `pl_id` varchar(50) NOT NULL,
  `pl_outlet` varchar(20) DEFAULT NULL,
  `pl_kode` longtext DEFAULT NULL,
  `pl_nama` longtext DEFAULT NULL,
  `pl_nohp` longtext DEFAULT NULL,
  `pl_alamat` longtext DEFAULT NULL,
  `pl_jenis_kelamin` longtext DEFAULT NULL,
  `pl_tanggal_lahir` datetime(3) DEFAULT NULL,
  `pl_status` bigint(20) DEFAULT 1,
  `pl_created` datetime(3) DEFAULT NULL,
  `pl_lastupdate` datetime(3) DEFAULT NULL,
  `pl_userupdate` varchar(50) DEFAULT NULL,
  `pl_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_pelanggan`
--

INSERT INTO `ac_pelanggan` (`pl_id`, `pl_outlet`, `pl_kode`, `pl_nama`, `pl_nohp`, `pl_alamat`, `pl_jenis_kelamin`, `pl_tanggal_lahir`, `pl_status`, `pl_created`, `pl_lastupdate`, `pl_userupdate`, `pl_userupdate_type`) VALUES
('PL.1.001.202601001', '1.001', '67892', 'Susi Susanti', '081234567892', 'Jl. Batam Center No. 12', 'P', '1990-05-20 07:00:00.000', 1, '2026-01-30 14:04:20.799', '2026-01-30 14:04:20.799', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_pengeluaran`
--

CREATE TABLE `ac_pengeluaran` (
  `pg_id` varchar(50) NOT NULL,
  `pg_kategori` varchar(50) DEFAULT NULL,
  `pg_outlet` varchar(20) DEFAULT NULL,
  `pg_tanggal` datetime(3) DEFAULT NULL,
  `pg_due_date` datetime(3) DEFAULT NULL,
  `pg_total` double DEFAULT NULL,
  `pg_keterangan` longtext DEFAULT NULL,
  `pg_created` datetime(3) DEFAULT NULL,
  `pg_lastupdate` datetime(3) DEFAULT NULL,
  `pg_userupdate` varchar(50) DEFAULT NULL,
  `pg_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_pengeluaran`
--

INSERT INTO `ac_pengeluaran` (`pg_id`, `pg_kategori`, `pg_outlet`, `pg_tanggal`, `pg_total`, `pg_keterangan`, `pg_created`, `pg_lastupdate`, `pg_userupdate`, `pg_userupdate_type`) VALUES
('PG.1.001.2026010001', 'KP.1.001.01', '1.001', '2026-01-27 07:00:00.000', 75000, 'Beli deterjen Rinso 2kg & Pewangi', '2026-01-30 14:07:38.137', '2026-01-30 14:07:38.137', '1', 'user'),
('PG.1.001.2026010002', 'KP.1.001.01', '1.001', '2026-01-30 07:00:00.000', 75000, 'Beli deterjen Rinso 2kg & Pewangi', '2026-01-30 14:10:01.112', '2026-01-30 14:10:01.112', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_role`
--

CREATE TABLE `ac_role` (
  `rl_id` varchar(50) NOT NULL,
  `rl_outlet` varchar(20) DEFAULT NULL,
  `rl_nama` longtext DEFAULT NULL,
  `rl_permission` longblob DEFAULT NULL,
  `rl_created` datetime(3) DEFAULT NULL,
  `rl_lastupdate` datetime(3) DEFAULT NULL,
  `rl_userupdate` varchar(50) DEFAULT NULL,
  `rl_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_role`
--

INSERT INTO `ac_role` (`rl_id`, `rl_outlet`, `rl_nama`, `rl_permission`, `rl_created`, `rl_lastupdate`, `rl_userupdate`, `rl_userupdate_type`) VALUES
('RL.1.001.01', '1.001', 'Admin', 0x7b227472616e73616b7369223a5b22637265617465222c2272656164222c22757064617465222c227570646174655f737461747573225d2c2270656c616e6767616e223a5b22616c6c225d2c2270656e67656c756172616e223a5b22616c6c225d2c226974656d223a5b22616c6c225d2c2270617266756d223a5b22616c6c225d2c226c6179616e616e223a5b22616c6c225d2c226469736b6f6e223a5b22616c6c225d2c226d65746f64655f70656d6261796172616e223a5b2272656164222c22757064617465225d2c2270656761776169223a5b2272656164222c22637265617465222c22757064617465225d2c226c61706f72616e223a5b2272656164225d7d, '2026-01-30 14:00:38.755', '2026-01-30 14:00:38.755', '1', 'user'),
('RL.1.001.02', '1.001', 'Kasir', 0x7b227472616e73616b7369223a5b22637265617465222c2272656164222c227570646174655f737461747573225d2c2270656c616e6767616e223a5b22637265617465222c2272656164222c22757064617465225d2c2270656e67656c756172616e223a5b22637265617465222c2272656164225d2c226974656d223a5b2272656164225d2c2270617266756d223a5b2272656164225d2c226c6179616e616e223a5b2272656164225d2c226469736b6f6e223a5b2272656164225d7d, '2026-01-30 14:00:38.755', '2026-01-30 14:00:38.755', '1', 'user'),
('RL.1.001.03', '1.001', 'Investor', 0x7b227472616e73616b7369223a5b2272656164225d2c2270656e67656c756172616e223a5b2272656164225d2c226c61706f72616e223a5b2272656164225d2c226f75746c6574223a5b2272656164225d7d, '2026-01-30 14:00:38.762', '2026-01-30 14:00:38.762', '1', 'user');

-- --------------------------------------------------------

--
-- Table structure for table `ac_transaksi`
--

CREATE TABLE `ac_transaksi` (
  `tr_id` varchar(60) NOT NULL,
  `tr_outlet` varchar(20) DEFAULT NULL,
  `tr_pelanggan` varchar(60) DEFAULT NULL,
  `tr_parfum` varchar(40) DEFAULT NULL,
  `tr_diskon` varchar(50) DEFAULT NULL,
  `tr_total_kotor` double DEFAULT NULL,
  `tr_potongan_diskon` double DEFAULT NULL,
  `tr_total` double DEFAULT NULL,
  `tr_status_order` varchar(191) DEFAULT 'Antrian',
  `tr_status_pembayaran` varchar(191) DEFAULT 'Belum Lunas',
  `tr_catatan` longtext DEFAULT NULL,
  `tr_created` datetime(3) DEFAULT NULL,
  `tr_lastupdate` datetime(3) DEFAULT NULL,
  `tr_userupdate` varchar(50) DEFAULT NULL,
  `tr_userupdate_type` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_transaksi`
--

INSERT INTO `ac_transaksi` (`tr_id`, `tr_outlet`, `tr_pelanggan`, `tr_parfum`, `tr_diskon`, `tr_total_kotor`, `tr_potongan_diskon`, `tr_total`, `tr_status_order`, `tr_status_pembayaran`, `tr_catatan`, `tr_created`, `tr_lastupdate`, `tr_userupdate`, `tr_userupdate_type`) VALUES
('TRX/1.001/202601300001', '1.001', 'PL.1.001.202601001', 'PF.1.001.01', 'DIS.1.001.01.001', 196000, 40000, 156000, 'Antrian', 'Lunas', 'Jangan pakai pewangi terlalu banyak', '2026-01-30 14:06:27.177', '2026-01-30 14:06:27.177', '1', 'user'),
('TRX/1.001/202601300002', '1.001', 'PL.1.001.202601001', NULL, NULL, 121200, 0, 121200, 'Antrian', 'Lunas', '', '2026-01-30 14:11:11.847', '2026-01-30 14:11:11.847', '1', 'user'),
('TRX/1.001/202602020001', '1.001', 'PL.1.001.202601001', 'PF.1.001.01', 'DIS.1.001.01.001', 196000, 40000, 156000, 'Antrian', 'Lunas', 'Jangan pakai pewangi terlalu banyak', '2026-02-02 11:27:45.629', '2026-02-02 11:27:45.629', 'PGW.1.001.01', 'pegawai'),
('TRX/1.001/202602020002', '1.001', 'PL.1.001.202601001', 'PF.1.001.01', 'DIS.1.001.01.001', 196000, 40000, 156000, 'Antrian', 'Lunas', 'Jangan pakai pewangi terlalu banyak', '2026-02-02 11:29:26.141', '2026-02-02 11:29:26.141', 'PGW.1.001.01', 'pegawai');

-- --------------------------------------------------------

--
-- Table structure for table `ac_transaksi_paket`
--

CREATE TABLE `ac_transaksi_paket` (
  `tp_id` varchar(50) NOT NULL,
  `tp_outlet` varchar(20) DEFAULT NULL,
  `tp_paket` bigint(20) UNSIGNED NOT NULL,
  `tp_tanggal_mulai` datetime(3) DEFAULT NULL,
  `tp_tanggal_berakhir` datetime(3) DEFAULT NULL,
  `tp_status` varchar(20) DEFAULT 'pending',
  `tp_status_pembayaran` varchar(191) DEFAULT 'unpaid',
  `tp_created` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_transaksi_paket`
--

INSERT INTO `ac_transaksi_paket` (`tp_id`, `tp_outlet`, `tp_paket`, `tp_tanggal_mulai`, `tp_tanggal_berakhir`, `tp_status`, `tp_status_pembayaran`, `tp_created`) VALUES
('TP.1.001.2026.01', '1.001', 1, '2026-01-30 14:00:38.782', '2026-02-06 14:00:38.782', 'expired', 'paid', '2026-01-30 14:00:38.784'),
('TP.1.001.2026.02', '1.001', 3, '2026-01-30 14:08:56.107', '2026-03-01 14:08:56.107', 'active', 'paid', '2026-01-30 14:08:56.109');

-- --------------------------------------------------------

--
-- Table structure for table `ac_user`
--

CREATE TABLE `ac_user` (
  `usr_id` bigint(20) UNSIGNED NOT NULL,
  `usr_nama` longtext NOT NULL,
  `usr_email` varchar(191) NOT NULL,
  `usr_password` longtext DEFAULT NULL,
  `usr_nohp` longtext DEFAULT NULL,
  `usr_google_id` longtext DEFAULT NULL,
  `usr_lead_source` longtext DEFAULT NULL,
  `usr_status` bigint(20) DEFAULT 1,
  `usr_created` datetime(3) DEFAULT NULL,
  `usr_lastupdate` datetime(3) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ac_user`
--

INSERT INTO `ac_user` (`usr_id`, `usr_nama`, `usr_email`, `usr_password`, `usr_nohp`, `usr_google_id`, `usr_lead_source`, `usr_status`, `usr_created`, `usr_lastupdate`) VALUES
(1, 'Helwyza Fahry', 'helwyza@gmail.com', '$2a$10$rfbSljtw9PclFdwzaBmdbuc2uMQ3KOY2QAQeRAdYXLFSTH41fJ4Ju', '081234567890', NULL, NULL, 1, '2026-01-30 14:00:38.748', '2026-01-30 14:00:38.748');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ac_config_nota`
--
ALTER TABLE `ac_config_nota`
  ADD PRIMARY KEY (`cn_id`);

--
-- Indexes for table `ac_detail_transaksi`
--
ALTER TABLE `ac_detail_transaksi`
  ADD PRIMARY KEY (`dtr_id`),
  ADD KEY `fk_ac_detail_transaksi_product` (`dtr_layanan`),
  ADD KEY `fk_ac_transaksi_details` (`dtr_transaksi`);

--
-- Indexes for table `ac_diskon`
--
ALTER TABLE `ac_diskon`
  ADD PRIMARY KEY (`dis_id`),
  ADD KEY `fk_ac_outlet_discounts` (`dis_outlet`);

--
-- Indexes for table `ac_dp_transaksi`
--
ALTER TABLE `ac_dp_transaksi`
  ADD PRIMARY KEY (`dptr_id`),
  ADD KEY `fk_ac_transaksi_payment_history` (`dptr_transaksi`),
  ADD KEY `fk_ac_dp_transaksi_metode_pembayaran` (`dptr_metode_pembayaran`);

--
-- Indexes for table `ac_fitur`
--
ALTER TABLE `ac_fitur`
  ADD PRIMARY KEY (`ftr_id`),
  ADD UNIQUE KEY `uni_ac_fitur_ftr_kode` (`ftr_kode`);

--
-- Indexes for table `ac_fitur_paket`
--
ALTER TABLE `ac_fitur_paket`
  ADD PRIMARY KEY (`fpkt_id`);

--
-- Indexes for table `ac_item`
--
ALTER TABLE `ac_item`
  ADD PRIMARY KEY (`it_id`),
  ADD KEY `fk_ac_outlet_items` (`it_outlet`);

--
-- Indexes for table `ac_item_transaksi`
--
ALTER TABLE `ac_item_transaksi`
  ADD PRIMARY KEY (`itr_id`),
  ADD KEY `fk_ac_item_transaksi_master_item` (`itr_item`),
  ADD KEY `fk_ac_transaksi_items` (`itr_transaksi`);

--
-- Indexes for table `ac_jenis_produk`
--
ALTER TABLE `ac_jenis_produk`
  ADD PRIMARY KEY (`jp_id`),
  ADD KEY `fk_ac_layanan_products` (`jp_layanan`);

--
-- Indexes for table `ac_kategori_pengeluaran`
--
ALTER TABLE `ac_kategori_pengeluaran`
  ADD PRIMARY KEY (`kp_id`);

--
-- Indexes for table `ac_layanan`
--
ALTER TABLE `ac_layanan`
  ADD PRIMARY KEY (`ly_id`),
  ADD KEY `fk_ac_outlet_layanan` (`ly_outlet`);

--
-- Indexes for table `ac_log_transaksi`
--
ALTER TABLE `ac_log_transaksi`
  ADD PRIMARY KEY (`lr_id`),
  ADD KEY `fk_ac_transaksi_logs` (`lr_transaksi`);

--
-- Indexes for table `ac_metode_pembayaran`
--
ALTER TABLE `ac_metode_pembayaran`
  ADD PRIMARY KEY (`mp_id`),
  ADD KEY `fk_ac_outlet_payment_methods` (`mp_outlet`);

--
-- Indexes for table `ac_outlet`
--
ALTER TABLE `ac_outlet`
  ADD PRIMARY KEY (`ot_id`);

--
-- Indexes for table `ac_paket`
--
ALTER TABLE `ac_paket`
  ADD PRIMARY KEY (`pkt_id`);

--
-- Indexes for table `ac_parfum`
--
ALTER TABLE `ac_parfum`
  ADD PRIMARY KEY (`pf_id`),
  ADD KEY `fk_ac_outlet_parfums` (`pf_outlet`);

--
-- Indexes for table `ac_pegawai`
--
ALTER TABLE `ac_pegawai`
  ADD PRIMARY KEY (`pg_id`),
  ADD UNIQUE KEY `uni_ac_pegawai_pg_email` (`pg_email`),
  ADD KEY `fk_ac_outlet_pegawai` (`pg_outlet`),
  ADD KEY `fk_ac_pegawai_role` (`pg_role`);

--
-- Indexes for table `ac_pelanggan`
--
ALTER TABLE `ac_pelanggan`
  ADD PRIMARY KEY (`pl_id`),
  ADD KEY `fk_ac_outlet_customers` (`pl_outlet`);

--
-- Indexes for table `ac_pengeluaran`
--
ALTER TABLE `ac_pengeluaran`
  ADD PRIMARY KEY (`pg_id`),
  ADD KEY `fk_ac_pengeluaran_kategori` (`pg_kategori`);

--
-- Indexes for table `ac_role`
--
ALTER TABLE `ac_role`
  ADD PRIMARY KEY (`rl_id`),
  ADD KEY `fk_ac_outlet_roles` (`rl_outlet`);

--
-- Indexes for table `ac_transaksi`
--
ALTER TABLE `ac_transaksi`
  ADD PRIMARY KEY (`tr_id`),
  ADD KEY `fk_ac_transaksi_pelanggan` (`tr_pelanggan`),
  ADD KEY `fk_ac_transaksi_parfum` (`tr_parfum`),
  ADD KEY `fk_ac_transaksi_diskon` (`tr_diskon`);

--
-- Indexes for table `ac_transaksi_paket`
--
ALTER TABLE `ac_transaksi_paket`
  ADD PRIMARY KEY (`tp_id`),
  ADD KEY `fk_ac_transaksi_paket_paket` (`tp_paket`),
  ADD KEY `idx_ac_transaksi_paket_outlet_id` (`tp_outlet`),
  ADD KEY `idx_status_expiry` (`tp_tanggal_berakhir`,`tp_status`);

--
-- Indexes for table `ac_user`
--
ALTER TABLE `ac_user`
  ADD PRIMARY KEY (`usr_id`),
  ADD UNIQUE KEY `uni_ac_user_usr_email` (`usr_email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ac_fitur`
--
ALTER TABLE `ac_fitur`
  MODIFY `ftr_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `ac_fitur_paket`
--
ALTER TABLE `ac_fitur_paket`
  MODIFY `fpkt_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT for table `ac_paket`
--
ALTER TABLE `ac_paket`
  MODIFY `pkt_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `ac_user`
--
ALTER TABLE `ac_user`
  MODIFY `usr_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `ac_detail_transaksi`
--
ALTER TABLE `ac_detail_transaksi`
  ADD CONSTRAINT `fk_ac_detail_transaksi_product` FOREIGN KEY (`dtr_layanan`) REFERENCES `ac_jenis_produk` (`jp_id`),
  ADD CONSTRAINT `fk_ac_transaksi_details` FOREIGN KEY (`dtr_transaksi`) REFERENCES `ac_transaksi` (`tr_id`);

--
-- Constraints for table `ac_diskon`
--
ALTER TABLE `ac_diskon`
  ADD CONSTRAINT `fk_ac_outlet_discounts` FOREIGN KEY (`dis_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_dp_transaksi`
--
ALTER TABLE `ac_dp_transaksi`
  ADD CONSTRAINT `fk_ac_dp_transaksi_metode_pembayaran` FOREIGN KEY (`dptr_metode_pembayaran`) REFERENCES `ac_metode_pembayaran` (`mp_id`),
  ADD CONSTRAINT `fk_ac_transaksi_payment_history` FOREIGN KEY (`dptr_transaksi`) REFERENCES `ac_transaksi` (`tr_id`);

--
-- Constraints for table `ac_item`
--
ALTER TABLE `ac_item`
  ADD CONSTRAINT `fk_ac_outlet_items` FOREIGN KEY (`it_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_item_transaksi`
--
ALTER TABLE `ac_item_transaksi`
  ADD CONSTRAINT `fk_ac_item_transaksi_master_item` FOREIGN KEY (`itr_item`) REFERENCES `ac_item` (`it_id`),
  ADD CONSTRAINT `fk_ac_transaksi_items` FOREIGN KEY (`itr_transaksi`) REFERENCES `ac_transaksi` (`tr_id`);

--
-- Constraints for table `ac_jenis_produk`
--
ALTER TABLE `ac_jenis_produk`
  ADD CONSTRAINT `fk_ac_layanan_products` FOREIGN KEY (`jp_layanan`) REFERENCES `ac_layanan` (`ly_id`);

--
-- Constraints for table `ac_layanan`
--
ALTER TABLE `ac_layanan`
  ADD CONSTRAINT `fk_ac_outlet_layanan` FOREIGN KEY (`ly_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_log_transaksi`
--
ALTER TABLE `ac_log_transaksi`
  ADD CONSTRAINT `fk_ac_transaksi_logs` FOREIGN KEY (`lr_transaksi`) REFERENCES `ac_transaksi` (`tr_id`);

--
-- Constraints for table `ac_metode_pembayaran`
--
ALTER TABLE `ac_metode_pembayaran`
  ADD CONSTRAINT `fk_ac_outlet_payment_methods` FOREIGN KEY (`mp_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_parfum`
--
ALTER TABLE `ac_parfum`
  ADD CONSTRAINT `fk_ac_outlet_parfums` FOREIGN KEY (`pf_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_pegawai`
--
ALTER TABLE `ac_pegawai`
  ADD CONSTRAINT `fk_ac_outlet_pegawai` FOREIGN KEY (`pg_outlet`) REFERENCES `ac_outlet` (`ot_id`),
  ADD CONSTRAINT `fk_ac_pegawai_role` FOREIGN KEY (`pg_role`) REFERENCES `ac_role` (`rl_id`);

--
-- Constraints for table `ac_pelanggan`
--
ALTER TABLE `ac_pelanggan`
  ADD CONSTRAINT `fk_ac_outlet_customers` FOREIGN KEY (`pl_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_pengeluaran`
--
ALTER TABLE `ac_pengeluaran`
  ADD CONSTRAINT `fk_ac_pengeluaran_kategori` FOREIGN KEY (`pg_kategori`) REFERENCES `ac_kategori_pengeluaran` (`kp_id`);

--
-- Constraints for table `ac_role`
--
ALTER TABLE `ac_role`
  ADD CONSTRAINT `fk_ac_outlet_roles` FOREIGN KEY (`rl_outlet`) REFERENCES `ac_outlet` (`ot_id`);

--
-- Constraints for table `ac_transaksi`
--
ALTER TABLE `ac_transaksi`
  ADD CONSTRAINT `fk_ac_transaksi_diskon` FOREIGN KEY (`tr_diskon`) REFERENCES `ac_diskon` (`dis_id`),
  ADD CONSTRAINT `fk_ac_transaksi_parfum` FOREIGN KEY (`tr_parfum`) REFERENCES `ac_parfum` (`pf_id`),
  ADD CONSTRAINT `fk_ac_transaksi_pelanggan` FOREIGN KEY (`tr_pelanggan`) REFERENCES `ac_pelanggan` (`pl_id`);

--
-- Constraints for table `ac_transaksi_paket`
--
ALTER TABLE `ac_transaksi_paket`
  ADD CONSTRAINT `fk_ac_transaksi_paket_paket` FOREIGN KEY (`tp_paket`) REFERENCES `ac_paket` (`pkt_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

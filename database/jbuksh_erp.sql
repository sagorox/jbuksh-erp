-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 12, 2026 at 07:11 PM
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
-- Database: `jbuksh_erp`
--

-- --------------------------------------------------------

--
-- Table structure for table `accounting_vouchers`
--

CREATE TABLE `accounting_vouchers` (
  `id` int(11) NOT NULL,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `voucher_no` varchar(40) NOT NULL,
  `voucher_date` date NOT NULL,
  `voucher_type` varchar(10) NOT NULL,
  `amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `territory_id` bigint(20) DEFAULT NULL,
  `party_id` bigint(20) DEFAULT NULL,
  `user_id` bigint(20) DEFAULT NULL,
  `reference_type` varchar(50) DEFAULT NULL,
  `reference_id` bigint(20) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'POSTED',
  `approved_at` datetime DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `version` int(11) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `accounting_vouchers`
--

INSERT INTO `accounting_vouchers` (`id`, `uuid`, `voucher_no`, `voucher_date`, `voucher_type`, `amount`, `territory_id`, `party_id`, `user_id`, `reference_type`, `reference_id`, `description`, `status`, `approved_at`, `created_by`, `version`, `created_at`, `updated_at`) VALUES
(1, '7b4e6a11-1bf2-11f1-a674-e4115b57a012', 'VCH-000001', '2026-03-09', 'DEBIT', 1500.00, NULL, NULL, 6, 'manual', NULL, 'Opening debit voucher', 'POSTED', '2026-03-10 01:59:31', 6, 1, '2026-03-10 01:59:31', '2026-03-10 01:59:31'),
(2, '7b51317e-1bf2-11f1-a674-e4115b57a012', 'VCH-000002', '2026-03-09', 'CREDIT', 750.00, NULL, NULL, 6, 'manual', NULL, 'Opening credit voucher', 'DRAFT', NULL, 6, 1, '2026-03-10 01:59:31', '2026-03-10 01:59:31');

-- --------------------------------------------------------

--
-- Table structure for table `approvals`
--

CREATE TABLE `approvals` (
  `id` int(11) NOT NULL,
  `entity_type` varchar(20) NOT NULL,
  `entity_id` bigint(20) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `requested_by` bigint(20) NOT NULL,
  `requested_at` datetime NOT NULL,
  `action_by` bigint(20) DEFAULT NULL,
  `action_at` datetime DEFAULT NULL,
  `reason` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `approvals`
--

INSERT INTO `approvals` (`id`, `entity_type`, `entity_id`, `status`, `requested_by`, `requested_at`, `action_by`, `action_at`, `reason`) VALUES
(1, 'INVOICE', 1, 'APPROVED', 1, '2026-03-04 20:15:14', 1, '2026-03-04 21:22:46', NULL),
(2, 'COLLECTION', 1, 'PENDING', 1, '2026-03-04 21:22:46', NULL, NULL, NULL),
(3, 'COLLECTION', 2, 'PENDING', 1, '2026-03-04 21:23:19', NULL, NULL, NULL),
(4, 'COLLECTION', 3, 'PENDING', 1, '2026-03-04 21:24:26', NULL, NULL, NULL),
(5, 'COLLECTION', 4, 'PENDING', 1, '2026-03-04 21:26:34', NULL, NULL, NULL),
(6, 'ATTENDANCE', 1, 'APPROVED', 1, '2026-03-04 22:12:24', 1, '2026-03-04 22:15:01', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `areas`
--

CREATE TABLE `areas` (
  `id` bigint(20) NOT NULL,
  `zone_id` bigint(20) NOT NULL,
  `name` varchar(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance`
--

CREATE TABLE `attendance` (
  `id` int(11) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `territory_id` bigint(20) DEFAULT NULL,
  `att_date` date NOT NULL,
  `check_in_at` datetime DEFAULT NULL,
  `check_out_at` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'PENDING',
  `note` text DEFAULT NULL,
  `geo_lat` decimal(10,7) DEFAULT NULL,
  `geo_lng` decimal(10,7) DEFAULT NULL,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `version` int(11) NOT NULL DEFAULT 1,
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `attendance`
--

INSERT INTO `attendance` (`id`, `user_id`, `territory_id`, `att_date`, `check_in_at`, `check_out_at`, `status`, `note`, `geo_lat`, `geo_lng`, `uuid`, `version`, `updated_at`) VALUES
(1, 1, 1, '2026-03-04', '2026-03-04 22:12:24', NULL, 'PENDING', 'Morning checkin', NULL, NULL, 'a9f0bc3e-18db-11f1-b154-e4115b57a012', 1, '2026-03-06 03:38:35.734381'),
(2, 1, NULL, '2026-03-09', NULL, NULL, 'PRESENT', NULL, NULL, NULL, 'a-1772740597031120-31120', 1, '2026-03-10 03:01:29.594268');

-- --------------------------------------------------------

--
-- Table structure for table `audit_logs`
--

CREATE TABLE `audit_logs` (
  `id` int(11) NOT NULL,
  `entity_type` varchar(40) NOT NULL,
  `entity_uuid` varchar(36) DEFAULT NULL,
  `entity_id` bigint(20) DEFAULT NULL,
  `action` varchar(20) NOT NULL,
  `actor_user_id` bigint(20) DEFAULT NULL,
  `actor_role` varchar(30) DEFAULT NULL,
  `device_id` varchar(80) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `before_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`before_json`)),
  `after_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`after_json`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `audit_logs`
--

INSERT INTO `audit_logs` (`id`, `entity_type`, `entity_uuid`, `entity_id`, `action`, `actor_user_id`, `actor_role`, `device_id`, `created_at`, `before_json`, `after_json`) VALUES
(1, 'ATTENDANCE', 'a-1772740597031120-31120', 2, 'SYNC_MERGE', 1, 'MPO', NULL, '2026-03-10 03:01:29.635900', NULL, '{\"id\":2,\"uuid\":\"a-1772740597031120-31120\",\"user_id\":1,\"territory_id\":null,\"att_date\":\"2026-03-09\",\"check_in_at\":null,\"check_out_at\":null,\"status\":\"PRESENT\",\"note\":null,\"geo_lat\":null,\"geo_lng\":null,\"version\":1,\"updated_at\":\"2026-03-09T21:01:29.594Z\"}'),
(2, 'PARTY', 'P260312-327932', 10, 'SYNC_MERGE', 1, 'MPO', NULL, '2026-03-12 22:56:46.520471', NULL, '{\"id\":10,\"uuid\":\"P260312-327932\",\"territory_id\":1,\"assigned_mpo_user_id\":1,\"party_code\":\"P260312-327932\",\"name\":\"AHMED\",\"credit_limit\":\"10000.00\",\"is_active\":1,\"version\":1}');

-- --------------------------------------------------------

--
-- Table structure for table `categories`
--

CREATE TABLE `categories` (
  `id` int(11) NOT NULL,
  `is_active` tinyint(4) NOT NULL DEFAULT 1,
  `name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `collections`
--

CREATE TABLE `collections` (
  `id` int(11) NOT NULL,
  `collection_no` varchar(40) NOT NULL,
  `mpo_user_id` bigint(20) NOT NULL,
  `territory_id` bigint(20) NOT NULL,
  `party_id` bigint(20) NOT NULL,
  `collection_date` date NOT NULL,
  `method` varchar(10) NOT NULL DEFAULT 'CASH',
  `amount` decimal(12,2) NOT NULL,
  `reference_no` varchar(80) DEFAULT NULL,
  `status` varchar(30) NOT NULL DEFAULT 'APPROVED',
  `unused_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `version` int(11) NOT NULL DEFAULT 1,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  `allocations_json` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `collections`
--

INSERT INTO `collections` (`id`, `collection_no`, `mpo_user_id`, `territory_id`, `party_id`, `collection_date`, `method`, `amount`, `reference_no`, `status`, `unused_amount`, `version`, `uuid`, `created_at`, `updated_at`, `allocations_json`) VALUES
(1, 'COL-000001', 1, 1, 1, '2026-03-04', 'CASH', 100.00, NULL, 'PENDING_APPROVAL', 100.00, 1, 'aa4b5a68-18db-11f1-b154-e4115b57a012', '2026-03-06 03:38:36.115086', '2026-03-06 03:38:36.179980', NULL),
(2, 'COL-000002', 1, 1, 1, '2026-03-04', 'CASH', 100.00, NULL, 'PENDING_APPROVAL', 100.00, 1, 'aa4b5c48-18db-11f1-b154-e4115b57a012', '2026-03-06 03:38:36.115086', '2026-03-06 03:38:36.179980', NULL),
(3, 'COL-000003', 1, 1, 1, '2026-03-04', 'CASH', 100.00, NULL, 'PENDING_APPROVAL', 100.00, 1, 'aa4b5d3b-18db-11f1-b154-e4115b57a012', '2026-03-06 03:38:36.115086', '2026-03-06 03:38:36.179980', NULL),
(4, 'COL-000004', 1, 1, 1, '2026-03-04', 'CASH', 100.00, NULL, 'PENDING_APPROVAL', 100.00, 1, 'aa4b5ddf-18db-11f1-b154-e4115b57a012', '2026-03-06 03:38:36.115086', '2026-03-06 03:38:36.179980', NULL),
(5, 'COL-000005', 1, 1, 1, '2026-03-05', 'CASH', 500.00, NULL, 'APPROVED', 500.00, 1, 'aa4b5e96-18db-11f1-b154-e4115b57a012', '2026-03-06 03:38:36.115086', '2026-03-06 03:38:36.179980', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `collection_allocations`
--

CREATE TABLE `collection_allocations` (
  `id` int(11) NOT NULL,
  `collection_id` bigint(20) NOT NULL,
  `invoice_id` bigint(20) NOT NULL,
  `applied_amount` decimal(12,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `deliveries`
--

CREATE TABLE `deliveries` (
  `id` int(11) NOT NULL,
  `delivery_no` varchar(40) NOT NULL,
  `warehouse_id` bigint(20) DEFAULT NULL,
  `invoice_id` bigint(20) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'PACKED',
  `packed_at` datetime DEFAULT NULL,
  `dispatched_at` datetime DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `confirmed_by` bigint(20) DEFAULT NULL,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `version` int(11) NOT NULL DEFAULT 1,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `delivery_items`
--

CREATE TABLE `delivery_items` (
  `id` int(11) NOT NULL,
  `delivery_id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `qty` decimal(12,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `districts`
--

CREATE TABLE `districts` (
  `id` bigint(20) NOT NULL,
  `division_id` bigint(20) NOT NULL,
  `name_bn` varchar(120) NOT NULL,
  `name_en` varchar(120) NOT NULL,
  `code` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `divisions`
--

CREATE TABLE `divisions` (
  `id` bigint(20) NOT NULL,
  `name_bn` varchar(120) NOT NULL,
  `name_en` varchar(120) NOT NULL,
  `code` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expenses`
--

CREATE TABLE `expenses` (
  `id` int(11) NOT NULL,
  `uuid` varchar(36) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `territory_id` bigint(20) NOT NULL,
  `expense_date` date NOT NULL,
  `head_id` bigint(20) NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `note` text DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'APPROVED',
  `version` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expense_heads`
--

CREATE TABLE `expense_heads` (
  `id` int(11) NOT NULL,
  `name` varchar(120) NOT NULL,
  `is_active` tinyint(4) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `expense_heads`
--

INSERT INTO `expense_heads` (`id`, `name`, `is_active`) VALUES
(1, 'Gari Vara', 1);

-- --------------------------------------------------------

--
-- Table structure for table `invoices`
--

CREATE TABLE `invoices` (
  `id` int(11) NOT NULL,
  `invoice_no` varchar(40) NOT NULL,
  `mpo_user_id` bigint(20) NOT NULL,
  `territory_id` bigint(20) NOT NULL,
  `invoice_date` date NOT NULL,
  `invoice_time` time NOT NULL,
  `status` varchar(30) NOT NULL DEFAULT 'DRAFT',
  `subtotal` decimal(12,2) NOT NULL DEFAULT 0.00,
  `discount_percent` decimal(6,2) NOT NULL DEFAULT 0.00,
  `discount_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `net_total` decimal(12,2) NOT NULL DEFAULT 0.00,
  `received_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `due_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `remarks` text DEFAULT NULL,
  `pdf_url` varchar(255) DEFAULT NULL,
  `party_id` int(11) NOT NULL,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `items_json` longtext DEFAULT NULL,
  `version` int(11) NOT NULL DEFAULT 1,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoice_items`
--

CREATE TABLE `invoice_items` (
  `id` int(11) NOT NULL,
  `invoice_id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `qty` decimal(12,2) NOT NULL,
  `free_qty` decimal(12,2) NOT NULL DEFAULT 0.00,
  `unit_price` decimal(12,2) NOT NULL,
  `line_total` decimal(12,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `invoice_items`
--

INSERT INTO `invoice_items` (`id`, `invoice_id`, `product_id`, `qty`, `free_qty`, `unit_price`, `line_total`) VALUES
(1, 1, 1, 2.00, 0.00, 3.00, 6.00);

-- --------------------------------------------------------

--
-- Table structure for table `monthly_targets`
--

CREATE TABLE `monthly_targets` (
  `id` int(11) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `territory_id` bigint(20) DEFAULT NULL,
  `year` int(11) NOT NULL,
  `month` int(11) NOT NULL,
  `sales_target` decimal(12,2) NOT NULL DEFAULT 0.00,
  `collection_target` decimal(12,2) NOT NULL DEFAULT 0.00,
  `set_by` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `title` varchar(180) NOT NULL,
  `body` text NOT NULL,
  `type` varchar(20) NOT NULL DEFAULT 'SYSTEM',
  `ref_type` varchar(40) DEFAULT NULL,
  `ref_id` bigint(20) DEFAULT NULL,
  `is_read` tinyint(4) NOT NULL DEFAULT 0,
  `read_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`id`, `user_id`, `title`, `body`, `type`, `ref_type`, `ref_id`, `is_read`, `read_at`, `created_at`) VALUES
(1, 6, 'Welcome', 'System notification module is now active.', 'SYSTEM', NULL, NULL, 0, NULL, '2026-03-10 01:11:30'),
(2, 6, 'Approval Pending', 'There are approvals waiting for review.', 'APPROVAL', 'approval', 1, 0, NULL, '2026-03-10 01:11:30'),
(3, 6, 'Low Stock Alert', 'Some products are near stock-out level.', 'LOW_STOCK', 'product', 1, 0, NULL, '2026-03-10 01:11:30');

-- --------------------------------------------------------

--
-- Table structure for table `parties`
--

CREATE TABLE `parties` (
  `id` int(11) NOT NULL,
  `territory_id` int(11) NOT NULL,
  `party_code` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `credit_limit` decimal(12,2) NOT NULL DEFAULT 0.00,
  `is_active` tinyint(4) NOT NULL DEFAULT 1,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `version` int(11) NOT NULL DEFAULT 1,
  `assigned_mpo_user_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `parties`
--

INSERT INTO `parties` (`id`, `territory_id`, `party_code`, `name`, `credit_limit`, `is_active`, `uuid`, `version`, `assigned_mpo_user_id`) VALUES
(1, 1, 'P-001', 'Arafat Pharmacy', 0.00, 1, 'a93d05a2-18db-11f1-b154-e4115b57a012', 1, NULL),
(2, 2, 'P-002', 'Badda Pharmacy', 0.00, 1, 'a93d0853-18db-11f1-b154-e4115b57a012', 1, NULL),
(7, 1, 'P260312-268939', 'Shagor', 0.00, 1, 'abc8cad7-1e33-11f1-9ede-e4115b57a012', 1, 1),
(8, 1, 'P260312-375891', 'AHMED', 0.00, 1, 'eb85f460-1e33-11f1-9ede-e4115b57a012', 1, 1),
(10, 1, 'P260312-327932', 'AHMED', 10000.00, 1, 'P260312-327932', 1, 1);

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` int(11) NOT NULL,
  `sku` varchar(60) NOT NULL,
  `name` varchar(180) NOT NULL,
  `category_id` bigint(20) NOT NULL,
  `unit` varchar(20) NOT NULL DEFAULT 'pcs',
  `potency_tag` varchar(60) DEFAULT NULL,
  `purchase_price` decimal(12,2) NOT NULL DEFAULT 0.00,
  `sale_price` decimal(12,2) NOT NULL DEFAULT 0.00,
  `reorder_level` decimal(12,2) NOT NULL DEFAULT 0.00,
  `in_stock` decimal(12,2) NOT NULL DEFAULT 0.00,
  `is_active` tinyint(4) NOT NULL DEFAULT 1,
  `uuid` varchar(36) NOT NULL DEFAULT uuid(),
  `version` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `sku`, `name`, `category_id`, `unit`, `potency_tag`, `purchase_price`, `sale_price`, `reorder_level`, `in_stock`, `is_active`, `uuid`, `version`) VALUES
(1, 'TAB-001', 'Napa 500mg', 1, 'pcs', NULL, 2.50, 3.00, 50.00, 40.00, 1, 'a9550317-18db-11f1-b154-e4115b57a012', 1);

-- --------------------------------------------------------

--
-- Table structure for table `product_batches`
--

CREATE TABLE `product_batches` (
  `id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `batch_no` varchar(100) NOT NULL,
  `mfg_date` date DEFAULT NULL,
  `exp_date` date DEFAULT NULL,
  `qty` decimal(12,2) NOT NULL DEFAULT 0.00,
  `mrp` decimal(12,2) NOT NULL DEFAULT 0.00,
  `purchase_price` decimal(12,2) NOT NULL DEFAULT 0.00,
  `version` int(11) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `schedule_assignments`
--

CREATE TABLE `schedule_assignments` (
  `id` int(11) NOT NULL,
  `work_schedule_id` bigint(20) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `territory_id` bigint(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `schedule_assignments`
--

INSERT INTO `schedule_assignments` (`id`, `work_schedule_id`, `user_id`, `territory_id`) VALUES
(1, 1, 1, NULL),
(2, 2, 1, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `sync_change_log`
--

CREATE TABLE `sync_change_log` (
  `id` int(11) NOT NULL,
  `entity_type` varchar(30) NOT NULL,
  `entity_uuid` varchar(36) NOT NULL,
  `entity_id` bigint(20) DEFAULT NULL,
  `territory_id` bigint(20) DEFAULT NULL,
  `version` int(11) NOT NULL,
  `operation` varchar(10) NOT NULL,
  `changed_at` datetime(6) NOT NULL DEFAULT current_timestamp(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sync_change_log`
--

INSERT INTO `sync_change_log` (`id`, `entity_type`, `entity_uuid`, `entity_id`, `territory_id`, `version`, `operation`, `changed_at`) VALUES
(1, 'ATTENDANCE', 'a-1772740597031120-31120', 2, NULL, 1, 'UPSERT', '2026-03-10 03:01:29.617223'),
(2, 'PARTY', 'P260312-327932', 10, 1, 1, 'UPSERT', '2026-03-12 22:56:46.513407');

-- --------------------------------------------------------

--
-- Table structure for table `territories`
--

CREATE TABLE `territories` (
  `id` int(11) NOT NULL,
  `name` varchar(120) NOT NULL,
  `code` varchar(30) NOT NULL,
  `is_active` tinyint(4) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `territories`
--

INSERT INTO `territories` (`id`, `name`, `code`, `is_active`) VALUES
(1, 'Dhaka-1', 'DHK-1', 1),
(3, 'Dhaka-2', 'DHK-2', 1),
(10, 'Dhaka-X', 'DHK-X-001', 1),
(11, 'Chattogram-1', 'CTG-1', 1);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('SUPER_ADMIN','RSM','SALES_DEPT','ACCOUNTING','STOCK_KEEPER','MPO') NOT NULL DEFAULT 'MPO',
  `is_active` tinyint(4) NOT NULL DEFAULT 1,
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  `phone` varchar(20) NOT NULL,
  `full_name` varchar(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `password_hash`, `role`, `is_active`, `created_at`, `updated_at`, `phone`, `full_name`) VALUES
(1, '$2b$10$Wd1wxxKK2R0/plxscq4AvurLp2oMILv2kEuplFcP/qGI88YVrgN0a', 'MPO', 1, '2026-03-04 15:11:16.417125', '2026-03-06 22:51:43.628411', '01755128209', ''),
(6, '$2b$10$UvzVEOhgsHH9ATH5jtQlFOkn6JPzo..C4bXaOleezEuEj2zRQKDa2', 'SUPER_ADMIN', 1, '2026-03-09 21:24:38.000000', '2026-03-10 01:03:25.000000', '01844532895', 'Super Admin'),
(7, '$2b$10$UYM8AQeW8avXPQmDNTuxG.e5n6tvq6a6D1RPy4BoahgggdXjab4Da', 'MPO', 1, '2026-03-09 21:28:20.140509', '2026-03-09 21:28:20.140509', '01844532804', 'jahirul'),
(8, '$2b$10$b9vkBg/ZFhZHQkoYzolsNOzbOGORsmPAHY9qjFmtAoFlSE943Ylrq', 'RSM', 1, '2026-03-09 21:29:07.294878', '2026-03-09 21:29:07.294878', '01844532813', 'Ferdos');

-- --------------------------------------------------------

--
-- Table structure for table `user_territories`
--

CREATE TABLE `user_territories` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `territory_id` int(11) NOT NULL,
  `is_primary` tinyint(4) NOT NULL DEFAULT 0,
  `assigned_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `user_territories`
--

INSERT INTO `user_territories` (`id`, `user_id`, `territory_id`, `is_primary`, `assigned_at`) VALUES
(1, 2, 1, 1, NULL),
(3, 7, 11, 1, '2026-03-12 15:09:59'),
(4, 1, 1, 1, '2026-03-12 15:10:53');

-- --------------------------------------------------------

--
-- Table structure for table `work_schedules`
--

CREATE TABLE `work_schedules` (
  `id` int(11) NOT NULL,
  `name` varchar(120) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `created_by` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `work_schedules`
--

INSERT INTO `work_schedules` (`id`, `name`, `start_date`, `end_date`, `created_by`) VALUES
(1, 'March Week-1', '2026-03-04', '2026-03-10', 1),
(2, 'March Week-1', '2026-03-04', '2026-03-10', 1);

-- --------------------------------------------------------

--
-- Table structure for table `zones`
--

CREATE TABLE `zones` (
  `id` bigint(20) NOT NULL,
  `name` varchar(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `accounting_vouchers`
--
ALTER TABLE `accounting_vouchers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_accounting_vouchers_uuid` (`uuid`),
  ADD UNIQUE KEY `uq_accounting_vouchers_voucher_no` (`voucher_no`),
  ADD KEY `idx_accounting_vouchers_voucher_date` (`voucher_date`),
  ADD KEY `idx_accounting_vouchers_territory_id` (`territory_id`),
  ADD KEY `idx_accounting_vouchers_party_id` (`party_id`),
  ADD KEY `idx_accounting_vouchers_user_id` (`user_id`),
  ADD KEY `idx_accounting_vouchers_reference_type` (`reference_type`),
  ADD KEY `idx_accounting_vouchers_reference_id` (`reference_id`);

--
-- Indexes for table `approvals`
--
ALTER TABLE `approvals`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `areas`
--
ALTER TABLE `areas`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `attendance`
--
ALTER TABLE `attendance`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_091233f4a1b7618c7d26107ff0` (`user_id`,`att_date`),
  ADD UNIQUE KEY `IDX_03d4026e727211a1ecd058676b` (`uuid`);

--
-- Indexes for table `audit_logs`
--
ALTER TABLE `audit_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_2cd10fda8276bb995288acfbfb` (`created_at`),
  ADD KEY `IDX_b5dd2a15ea444221693f536197` (`entity_type`,`entity_uuid`);

--
-- Indexes for table `categories`
--
ALTER TABLE `categories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_8b0be371d28245da6e4f4b6187` (`name`);

--
-- Indexes for table `collections`
--
ALTER TABLE `collections`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_72449765cc5fbe16dc9cf672e7` (`collection_no`),
  ADD UNIQUE KEY `IDX_a85a551616d63511fd2755d000` (`uuid`);

--
-- Indexes for table `collection_allocations`
--
ALTER TABLE `collection_allocations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `deliveries`
--
ALTER TABLE `deliveries`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_59b27840552d96cdc0fe8f3a58` (`delivery_no`),
  ADD UNIQUE KEY `IDX_ff55105614d685fe85e2c8eb1c` (`uuid`);

--
-- Indexes for table `delivery_items`
--
ALTER TABLE `delivery_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `districts`
--
ALTER TABLE `districts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `divisions`
--
ALTER TABLE `divisions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `expenses`
--
ALTER TABLE `expenses`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_cc8ea0027b8bf74019faa5b043` (`uuid`);

--
-- Indexes for table `expense_heads`
--
ALTER TABLE `expense_heads`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_20df339958996dd69d71e1cb47` (`name`);

--
-- Indexes for table `invoices`
--
ALTER TABLE `invoices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_37669c562a2525929927d9d691` (`invoice_no`),
  ADD UNIQUE KEY `IDX_483267a3e3c18647d66c7ab213` (`uuid`),
  ADD KEY `FK_de393d36ce6b3977863950d5d7d` (`party_id`);

--
-- Indexes for table `invoice_items`
--
ALTER TABLE `invoice_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `monthly_targets`
--
ALTER TABLE `monthly_targets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_77afd2499b2701afeeb5942f08` (`user_id`,`territory_id`,`year`,`month`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_notifications_user_id` (`user_id`),
  ADD KEY `idx_notifications_type` (`type`),
  ADD KEY `idx_notifications_is_read` (`is_read`);

--
-- Indexes for table `parties`
--
ALTER TABLE `parties`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_7c1f196fbe8bf1651abd44e86c` (`party_code`),
  ADD UNIQUE KEY `IDX_37178f676914dad7fa47a76a67` (`uuid`),
  ADD KEY `fk_party_mpo` (`assigned_mpo_user_id`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_c44ac33a05b144dd0d9ddcf932` (`sku`),
  ADD UNIQUE KEY `IDX_98086f14e190574534d5129cd7` (`uuid`);

--
-- Indexes for table `product_batches`
--
ALTER TABLE `product_batches`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_product_batch_product_batch_no` (`product_id`,`batch_no`),
  ADD KEY `idx_product_batches_product_id` (`product_id`),
  ADD KEY `idx_product_batches_exp_date` (`exp_date`);

--
-- Indexes for table `schedule_assignments`
--
ALTER TABLE `schedule_assignments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_00c6ff96565a279ce5f3f67f58` (`work_schedule_id`,`user_id`);

--
-- Indexes for table `sync_change_log`
--
ALTER TABLE `sync_change_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_053926205a703fa5c854c2b05b` (`entity_type`,`entity_uuid`,`version`),
  ADD KEY `IDX_cde7351dd3d9695206c203d2f0` (`changed_at`);

--
-- Indexes for table `territories`
--
ALTER TABLE `territories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_e1a81c0cf29b429237ed209cc0` (`code`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_a000cca60bcf04454e72769949` (`phone`);

--
-- Indexes for table `user_territories`
--
ALTER TABLE `user_territories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `IDX_bf99cd71be274380f18cd7ccaf` (`user_id`,`territory_id`);

--
-- Indexes for table `work_schedules`
--
ALTER TABLE `work_schedules`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `zones`
--
ALTER TABLE `zones`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `accounting_vouchers`
--
ALTER TABLE `accounting_vouchers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `approvals`
--
ALTER TABLE `approvals`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `areas`
--
ALTER TABLE `areas`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance`
--
ALTER TABLE `attendance`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `audit_logs`
--
ALTER TABLE `audit_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `categories`
--
ALTER TABLE `categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `collections`
--
ALTER TABLE `collections`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `collection_allocations`
--
ALTER TABLE `collection_allocations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `deliveries`
--
ALTER TABLE `deliveries`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `delivery_items`
--
ALTER TABLE `delivery_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `districts`
--
ALTER TABLE `districts`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `divisions`
--
ALTER TABLE `divisions`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expenses`
--
ALTER TABLE `expenses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expense_heads`
--
ALTER TABLE `expense_heads`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `invoices`
--
ALTER TABLE `invoices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `invoice_items`
--
ALTER TABLE `invoice_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `monthly_targets`
--
ALTER TABLE `monthly_targets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `parties`
--
ALTER TABLE `parties`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `product_batches`
--
ALTER TABLE `product_batches`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `schedule_assignments`
--
ALTER TABLE `schedule_assignments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `sync_change_log`
--
ALTER TABLE `sync_change_log`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `territories`
--
ALTER TABLE `territories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `user_territories`
--
ALTER TABLE `user_territories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `work_schedules`
--
ALTER TABLE `work_schedules`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `zones`
--
ALTER TABLE `zones`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `invoices`
--
ALTER TABLE `invoices`
  ADD CONSTRAINT `FK_de393d36ce6b3977863950d5d7d` FOREIGN KEY (`party_id`) REFERENCES `parties` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Constraints for table `parties`
--
ALTER TABLE `parties`
  ADD CONSTRAINT `fk_party_mpo` FOREIGN KEY (`assigned_mpo_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

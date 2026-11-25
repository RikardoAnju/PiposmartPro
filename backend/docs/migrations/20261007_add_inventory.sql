CREATE TABLE IF NOT EXISTS ac_inventory_category (
  ic_id varchar(50) NOT NULL PRIMARY KEY, ic_outlet varchar(20) NOT NULL,
  ic_name varchar(100) NOT NULL, ic_icon_key varchar(80) NOT NULL DEFAULT '',
  ic_sort_order int NOT NULL DEFAULT 0, ic_status tinyint NOT NULL DEFAULT 1,
  ic_created datetime(3) NULL, ic_lastupdate datetime(3) NULL,
  UNIQUE KEY uq_inventory_category_name (ic_outlet, ic_name), KEY idx_inventory_category_outlet (ic_outlet)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ac_inventory_item (
  ii_id varchar(60) NOT NULL PRIMARY KEY, ii_outlet varchar(20) NOT NULL,
  ii_category_id varchar(50) NOT NULL, ii_name varchar(120) NOT NULL, ii_unit varchar(20) NOT NULL DEFAULT 'pcs',
  ii_stock decimal(14,2) NOT NULL DEFAULT 0, ii_minimum_stock decimal(14,2) NOT NULL DEFAULT 0,
  ii_status tinyint NOT NULL DEFAULT 1, ii_created datetime(3) NULL, ii_lastupdate datetime(3) NULL,
  UNIQUE KEY uq_inventory_item_name (ii_outlet, ii_name), KEY idx_inventory_item_outlet (ii_outlet), KEY idx_inventory_item_category (ii_category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ac_inventory_stock_movement (
  ism_id varchar(70) NOT NULL PRIMARY KEY, ism_outlet varchar(20) NOT NULL, ism_item_id varchar(60) NOT NULL,
  ism_type varchar(20) NOT NULL, ism_quantity decimal(14,2) NOT NULL, ism_stock_before decimal(14,2) NOT NULL,
  ism_stock_after decimal(14,2) NOT NULL, ism_note varchar(255) NOT NULL DEFAULT '',
  ism_actor_id varchar(50) NOT NULL DEFAULT '', ism_actor_type varchar(20) NOT NULL DEFAULT '',
  ism_created datetime(3) NULL, KEY idx_inventory_movement_item (ism_item_id), KEY idx_inventory_movement_outlet (ism_outlet)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ac_inventory_setting (
  is_outlet varchar(20) NOT NULL PRIMARY KEY, is_reminder_enabled tinyint NOT NULL DEFAULT 0,
  is_reminder_frequency varchar(20) NOT NULL DEFAULT 'mingguan', is_reminder_day varchar(15) NOT NULL DEFAULT 'Senin',
  is_reminder_hour tinyint NOT NULL DEFAULT 0, is_reminder_minute tinyint NOT NULL DEFAULT 0,
  is_lastupdate datetime(3) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

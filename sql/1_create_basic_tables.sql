
-- 1. 客户表

CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_type VARCHAR(50) NOT NULL,
    region VARCHAR(50)
);


-- 2. 产品表

CREATE TABLE products (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(50) NOT NULL,
    production_days INTEGER NOT NULL CHECK (production_days > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);



-- 3. 供应商表

CREATE TABLE suppliers (
    supplier_id VARCHAR(20) PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    supplier_region VARCHAR(50)
);



-- 4. 物料表

CREATE TABLE materials (
    material_id VARCHAR(20) PRIMARY KEY,
    material_name VARCHAR(100) NOT NULL,
    material_category VARCHAR(50) NOT NULL,
    material_type VARCHAR(50) NOT NULL,
    lead_time_days INTEGER NOT NULL CHECK (lead_time_days >= 0),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
    supplier_id VARCHAR(20),

    CONSTRAINT fk_material_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id)
);



-- 5. BOM 表
-- 联合主键：product_id + material_id

CREATE TABLE bom (
    product_id VARCHAR(20) NOT NULL,
    material_id VARCHAR(20) NOT NULL,
    quantity_per NUMERIC(12,4) NOT NULL CHECK (quantity_per > 0),

    PRIMARY KEY (product_id, material_id),

    CONSTRAINT fk_bom_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id),

    CONSTRAINT fk_bom_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id)
);


-- 6. 库存表
-- 联合主键：material_id + inventory_date

CREATE TABLE inventory (
    material_id VARCHAR(20) NOT NULL,
    inventory_date DATE NOT NULL,
    on_hand_qty NUMERIC(14,2) NOT NULL CHECK (on_hand_qty >= 0),
    safety_stock NUMERIC(14,2) NOT NULL CHECK (safety_stock >= 0),

    PRIMARY KEY (material_id, inventory_date),

    CONSTRAINT fk_inventory_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id)
);
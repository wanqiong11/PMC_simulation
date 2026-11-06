/*

因Visual Studio Code有许可限制

实际操作方法如下：
1. 打开pgAdmin
2. 在左边面板找到数据库“pmc”
3. 右键“pmc”并点击“PSQL Tool"
4. 在打开的页面中输入以下代码

\copy customers FROM '/.../raw_data/customers.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

\copy products FROM '/.../raw_data/products.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

\copy materials FROM '/.../raw_data/materials.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

\copy suppliers FROM '/.../raw_data/suppliers.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

\copy bom FROM '/.../raw_data/bom.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

\copy inventory FROM '/.../raw_data/inventory.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

（文件名用绝对路径，此处隐去了真实的绝对路径）
*/


COPY customers 
FROM '/.../raw_data/customers.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COPY products 
FROM '/.../raw_data/products.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COPY materials 
FROM '/.../raw_data/materials.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COPY suppliers 
FROM '/.../raw_data/suppliers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COPY bom 
FROM '/.../raw_data/bom.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COPY inventory 
FROM '/.../raw_data/inventory.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');



-- 检查数据是否成功导入

SELECT count(*) FROM customers;
SELECT count(*) FROM products;
SELECT count(*) FROM materials;
SELECT count(*) FROM suppliers;
SELECT count(*) FROM bom;
SELECT count(*) FROM inventory;


-- 新增物料入库检查时间
ALTER TABLE materials
ADD COLUMN inspection_days INTEGER NOT NULL DEFAULT 1
CHECK (inspection_days >= 0);

UPDATE materials
SET inspection_days = CASE
    WHEN material_type = '关键件' THEN 2
    WHEN material_type = '电子件' THEN 2
    WHEN material_type = '结构件' THEN 1
    WHEN material_type = '标准件' THEN 1
    WHEN material_type = '辅料' THEN 1
    END;

SELECT * FROM materials;

-- 物料新增MOQ数据
ALTER TABLE materials
ADD COLUMN minimum_order_qty NUMERIC(14,2)
DEFAULT 1
CHECK (minimum_order_qty > 0);

UPDATE materials
SET minimum_order_qty = CASE material_id

    WHEN 'M001' THEN 100
    WHEN 'M002' THEN 100
    WHEN 'M003' THEN 50
    WHEN 'M004' THEN 50

    WHEN 'M005' THEN 100
    WHEN 'M006' THEN 100
    WHEN 'M007' THEN 100
    WHEN 'M008' THEN 50

    WHEN 'M009' THEN 100
    WHEN 'M010' THEN 50
    WHEN 'M011' THEN 100
    WHEN 'M012' THEN 50

    WHEN 'M013' THEN 100
    WHEN 'M014' THEN 50

    WHEN 'M015' THEN 100
    WHEN 'M016' THEN 100

    WHEN 'M017' THEN 1000
    WHEN 'M018' THEN 1000
    WHEN 'M019' THEN 500
    WHEN 'M020' THEN 500
    WHEN 'M021' THEN 500
    WHEN 'M022' THEN 500

    WHEN 'M023' THEN 100
    WHEN 'M024' THEN 100
    WHEN 'M025' THEN 100

END;
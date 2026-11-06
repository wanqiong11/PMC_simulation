
CREATE TABLE planned_purchase_orders (
    plan_po_id VARCHAR(20) PRIMARY KEY,
    material_id VARCHAR(20) NOT NULL,
    supplier_id VARCHAR(20) NOT NULL,
    shortage_date DATE NOT NULL,
    shortage_qty NUMERIC(14,2) NOT NULL,
    minimum_order_qty NUMERIC(14,2) NOT NULL,
    planned_qty NUMERIC(14,2) NOT NULL,
    lead_time_days INTEGER NOT NULL,
    inspection_days INTEGER NOT NULL,
    planned_order_date DATE NOT NULL,
    planned_arrival_date DATE NOT NULL,
    planned_available_date DATE NOT NULL,
    plan_status VARCHAR(30) NOT NULL
        DEFAULT 'Suggested',

    CONSTRAINT fk_plan_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id),

    CONSTRAINT fk_plan_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id),

    CONSTRAINT chk_plan_status
        CHECK (
            plan_status IN (
                'Suggested',
                'Urgent',
                'Overdue'
            )
        )
);

INSERT INTO planned_purchase_orders (
    plan_po_id,
    material_id,
    supplier_id,
    shortage_date,
    shortage_qty,
    minimum_order_qty,
    planned_qty,
    lead_time_days,
    inspection_days,
    planned_order_date,
    planned_arrival_date,
    planned_available_date,
    plan_status
)

WITH purchase_requirement AS (

    SELECT
        mse.material_id,
        mse.shortage_start_date
            AS shortage_date,
        mse.shortage_qty,
        m.minimum_order_qty,
        m.lead_time_days,
        m.inspection_days,
        m.supplier_id
    FROM material_shortage_events mse

    JOIN materials m
        ON mse.material_id = m.material_id

    WHERE mse.shortage_status = 'Need Purchase'

),


--- MOQ取整

planned_quantity AS (

    SELECT
        *,
        CEILING(
        shortage_qty / minimum_order_qty
        ) * minimum_order_qty
            AS planned_qty
    FROM purchase_requirement

),


--- 倒推采购日期

purchase_dates AS (

    SELECT
        *,
        shortage_date
        - lead_time_days
        - inspection_days
            AS planned_order_date,
        shortage_date
        - inspection_days
            AS planned_arrival_date,
        shortage_date
            AS planned_available_date
    FROM planned_quantity

)

SELECT
    'PL' ||
    LPAD(
        ROW_NUMBER() OVER (
            ORDER BY material_id, shortage_date
        )::TEXT,
        3,
        '0'
    ) AS plan_po_id,

    material_id,
    supplier_id,
    shortage_date,
    shortage_qty,
    minimum_order_qty,
    planned_qty,
    lead_time_days,
    inspection_days,
    planned_order_date,
    planned_arrival_date,
    planned_available_date,

    CASE
        WHEN planned_order_date < DATE '2026-09-15'
        THEN 'Overdue'

        WHEN planned_order_date <= DATE '2026-09-20'
        THEN 'Urgent'

        ELSE 'Suggested'

    END AS plan_status

FROM purchase_dates

ORDER BY
    material_id,
    shortage_date;


/*
简化的表格,
验证拟采购数量是否正确

WITH gross_requirement AS (
    SELECT 
        material_id,
        sum(gross_requirement) as total_gross_demand
    FROM mrp_gross_demand
    GROUP BY material_id
    ORDER BY material_id
),

ordered_quantity AS (
    SELECT 
        material_id,
        sum(ordered_qty) as total_po_qty
    FROM purchase_orders
    GROUP BY material_id
)
SELECT 
    gr.material_id,
    gr.total_gross_demand,
    i.on_hand_qty,
    i.safety_stock,
    COALESCE(oq.total_po_qty,0) as total_po_qty,
    gr.total_gross_demand 
        +i.safety_stock
        -i.on_hand_qty
        -COALESCE(oq.total_po_qty,0) as net_requirement_qty
FROM gross_requirement gr
LEFT JOIN inventory i 
ON gr.material_id = i.material_id
LEFT JOIN ordered_quantity oq
ON gr.material_id = oq.material_id

*/

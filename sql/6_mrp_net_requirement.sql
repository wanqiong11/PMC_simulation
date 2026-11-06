DROP TABLE IF EXISTS mrp_net_requirement;

CREATE TABLE mrp_net_requirement (
    material_id VARCHAR(20) NOT NULL,
    material_need_date DATE NOT NULL, --物料实际需要的日期
    gross_requirement NUMERIC(14,2) NOT NULL DEFAULT 0, --当天订单产生的物料需求
    opening_inventory NUMERIC(14,2) NOT NULL, --当天开始时的预计库存
    scheduled_receipt NUMERIC(14,2) NOT NULL DEFAULT 0, --当天确定到货的采购数量
    safety_stock NUMERIC(14,2) NOT NULL,
    projected_inventory NUMERIC(14,2) NOT NULL, --当天需求和到货后的预计库存
    net_requirement NUMERIC(14,2) NOT NULL DEFAULT 0, --当天真正需要新增采购的数量

    PRIMARY KEY (material_id, material_need_date),

    CONSTRAINT fk_mrp_net_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id)
);


INSERT INTO mrp_net_requirement (
    material_id,
    material_need_date,
    gross_requirement,
    opening_inventory,
    scheduled_receipt,
    safety_stock,
    projected_inventory,
    net_requirement
)


WITH

--- 1. 取得计划日当天的库存
inventory_snapshot AS (
    SELECT
        material_id,
        on_hand_qty,
        safety_stock
    FROM inventory
    WHERE inventory_date = DATE '2026-09-15'
),

--- 2. 根据订单交期倒推物料实际需要的日期
material_demand AS (
    SELECT
        mrd.material_id,
        o.required_date - p.production_days AS material_need_date,
        SUM(mrd.gross_requirement) AS gross_requirement
    FROM mrp_gross_demand mrd
    JOIN orders o
        ON mrd.order_id = o.order_id
    JOIN products p
        ON mrd.product_id = p.product_id
    GROUP BY
        mrd.material_id,
        o.required_date - p.production_days
),

--- 3. 根据在途采购到货和来料控制推算真正可用日期
scheduled_receipts AS (
    SELECT
        po.material_id,
        po.expected_date + m.inspection_days AS available_date,
        SUM(po.ordered_qty - po.received_qty) AS scheduled_receipt
    FROM purchase_orders po
    JOIN materials m
        ON po.material_id = m.material_id
    WHERE po.po_status = 'In Transit'
    GROUP BY
        po.material_id,
        po.expected_date + m.inspection_days
),

--- 4. 建立物料的完整时间轴
event_dates AS (
    SELECT
        material_id,
        material_need_date AS event_date
    FROM material_demand

    UNION

    SELECT
        material_id,
        available_date AS event_date
    FROM scheduled_receipts
),

--- 5. 确定每个物料 + 日期的需求与采购到货 
daily_events AS (
    SELECT
        e.material_id,
        e.event_date,

        COALESCE(md.gross_requirement, 0) AS gross_requirement,

        COALESCE(sr.scheduled_receipt, 0) AS scheduled_receipt,

        i.on_hand_qty,
        i.safety_stock

    FROM event_dates e

    JOIN inventory_snapshot i
        ON e.material_id = i.material_id

    LEFT JOIN material_demand md
        ON e.material_id = md.material_id
        AND e.event_date = md.material_need_date

    LEFT JOIN scheduled_receipts sr
        ON e.material_id = sr.material_id
        AND e.event_date = sr.available_date
),

---6. 计算截至当天的累计需求和累计在途到货
inventory_calculation AS (
    SELECT
        material_id,
        event_date,

        gross_requirement,
        scheduled_receipt,

        on_hand_qty,
        safety_stock,
        
        on_hand_qty+
        COALESCE(SUM(scheduled_receipt - gross_requirement) 
            OVER (
                PARTITION BY material_id
                ORDER BY event_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0
        ) AS opening_inventory,

        on_hand_qty+
        SUM(scheduled_receipt - gross_requirement) 
            OVER (
                PARTITION BY material_id
                ORDER BY event_date
            ) AS projected_inventory
    FROM daily_events
)

SELECT
    material_id,
    event_date as material_need_date,
    gross_requirement,
    opening_inventory,
    scheduled_receipt,
    safety_stock,
    projected_inventory,
    GREATEST(
        safety_stock - projected_inventory,
        0
    ) as net_requirement
FROM inventory_calculation
ORDER BY material_id, material_need_date;
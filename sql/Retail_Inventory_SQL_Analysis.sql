CREATE DATABASE RETAIL_INVENTORY_PROJECT;
USE  RETAIL_INVENTORY_PROJECT;
DESCRIBE Retail_Inventory_Ledger;
SELECT * FROM Retail_Inventory_Ledger;
SHOW TABLES;

SELECT COUNT(*) AS total_rows
FROM Retail_Inventory_Ledger;

SELECT *
FROM Retail_Inventory_Ledger
LIMIT 10;

-- converting week_start-type text  by adding another column week_start_date-type date
SELECT week_start
FROM Retail_Inventory_Ledger
LIMIT 10;
SELECT COUNT(*) AS total_rows,
       SUM(STR_TO_DATE(week_start, '%d-%m-%Y') IS NULL)
           AS invalid_dates
FROM Retail_Inventory_Ledger;

ALTER TABLE Retail_Inventory_Ledger
ADD COLUMN week_start_date DATE;
UPDATE Retail_Inventory_Ledger
SET week_start_date = STR_TO_DATE(week_start, '%d-%m-%Y');

SELECT *
FROM Retail_Inventory_Ledger;
DESCRIBE Retail_Inventory_Ledger;
SELECT week_start, week_start_date
FROM Retail_Inventory_Ledger
LIMIT 10;
SELECT COUNT(*) AS invalid_dates
FROM Retail_Inventory_Ledger
WHERE week_start_date IS NULL;
ALTER TABLE Retail_Inventory_Ledger
RENAME COLUMN week_start TO week_start_text;
ALTER TABLE Retail_Inventory_Ledger
RENAME COLUMN week_start_date TO week_start;
DESCRIBE Retail_Inventory_Ledger;
SELECT week_start_text, week_start
FROM Retail_Inventory_Ledger
LIMIT 10;



-- SQL Analysis 1: Inventory Replenishment Risk Indicators
-- Business question: Which store–product combinations repeatedly fall below their inventory thresholds, and how severe are those risks?

-- Indicator A: Reorder-point risk
-- Which store–product combinations repeatedly have closing stock below the reorder point?

SELECT
    store_id,
    product_id,
    COUNT(*) AS risk_occurrences,
    ROUND(AVG(reorder_point - closing_stock), 2) AS avg_below_reorder_point
FROM retail_inventory_ledger
WHERE closing_stock < reorder_point
GROUP BY store_id, product_id
HAVING COUNT(*) > 1
ORDER BY risk_occurrences DESC;

-- Repeatedly low inventory may indicate that replenishment needs closer monitoring.


-- Indicator B: Safety-stock 
-- Which store–product combinations repeatedly fall below safety stock, and how large is the average shortfall?

SELECT
    store_id,
    product_id,
    COUNT(*) AS risk_occurrences,
    ROUND(AVG(safety_stock - closing_stock), 2) AS avg_safety_stock_gap
FROM Retail_Inventory_Ledger
WHERE closing_stock < safety_stock
GROUP BY store_id, product_id
HAVING COUNT(*) > 1
ORDER BY risk_occurrences DESC;


-- Among the results reviewed, Store S006–Product P007 had the highest frequency of safety stock risk, with 7 occurrences. Store S009–Product P026 had the largest average safety stock gap among the displayed results, at 40 units across 3 occurrences.0

-- Finding: Among the results reviewed, Store S006–Product P007 had the highest frequency of safety-stock risk, with 7 occurrences. Store S009–Product P026 had the largest average safety-stock gap among the displayed results, at 40 units across 3 occurrences.

-- Business implication: Review frequently flagged combinations and those with large safety-stock gaps to determine whether their replenishment settings or inventory practices need attention.

-- Limitation: These indicators identify inventory-threshold risks in the recorded data. They do not prove that a replenishment order was missed or that a stockout occurred as a result.


-- SQL Analysis 2: Stockouts and Lost Sales
-- Business question: Do records with stockouts also show higher lost-sales units?
SELECT DISTINCT stockout_flag 
FROM Retail_Inventory_Ledger;
SELECT
    stockout_flag,
    COUNT(*) AS total_records,
    SUM(lost_sales_units) AS total_lost_sales_units,
    AVG(lost_sales_units) AS avg_lost_sales_units
FROM Retail_Inventory_Ledger
GROUP BY stockout_flag
ORDER BY stockout_flag;
-- The dataset contained 303 records flagged as stockouts, representing approximately 1.77% of all 17,160 records.
-- These records accounted for 4,238 lost-sales units, averaging approximately 13.99 units per stockout record. Records without a stockout had zero recorded lost-sales units.


-- SQL Analysis 3: Supplier-Associated Spoilage Rate.
-- Which suppliers have the highest spoilage as a percentage of units received?
-- Total units received for each supplier:
SELECT
    supplier_id,
    SUM(units_received) AS total_units_received
FROM Retail_Inventory_Ledger
GROUP BY supplier_id
ORDER BY supplier_id;

SELECT
	supplier_id,
    SUM(units_received) AS total_units_received,
	SUM(spoilage_units) AS total_spoiled_units,
ROUND(
        SUM(spoilage_units) * 100.0 /
       NULLIF(SUM(units_received), 0),
    2
    ) AS spoilage_rate_pct
FROM Retail_Inventory_Ledger
GROUP BY supplier_id
ORDER BY spoilage_rate_pct DESC;   
SELECT
    supplier_id,
    SUM(units_received) AS total_units_received
FROM Retail_Inventory_Ledger
GROUP BY supplier_id
ORDER BY supplier_id;

-- Finding: SUP002 had the highest spoilage rate at 27.54%, followed by SUP001 at 17.15%. SUP007 and SUP008 had no recorded spoilage.

-- Business implication: Investigate the products and stores associated with SUP002 and SUP001 to understand the reasons for their high spoilage rates. Review storage, handling, product mix, and inventory practices before deciding on corrective actions.

-- Limitation: The spoilage rate is calculated using total spoiled units divided by total units received. It describes the records associated with each supplier but does not prove supplier causation. 
 USE retail_inventory_project;

SHOW TABLES;   
DESCRIBE Stores;
DESCRIBE Products;
DESCRIBE Suppliers;
SELECT * FROM Stores LIMIT 5;
SELECT * FROM Products LIMIT 5;
SELECT * FROM Suppliers LIMIT 5;

SELECT *
FROM Retail_Inventory_Ledger;

-- SQL Analysis 4 — Top 10 Store–Product Combinations by Lost-Sales Units
-- Business question: Which store–product combinations contribute the most recorded lost-sales units, and where should inventory teams investigate first?

SELECT store_id,product_id,sum(lost_sales_units) AS total_lost_sales_units
FROM retail_inventory_ledger
WHERE lost_sales_units > 0 
GROUP BY store_id,product_id
ORDER BY total_lost_sales_units DESC
LIMIT 10; 

SELECT
    r.store_id,
    s.store_name,
    s.region,
    r.product_id,
    p.product_name,
    p.category,
    SUM(r.lost_sales_units) AS total_lost_sales_units
FROM retail_inventory_ledger AS r
INNER JOIN Stores AS s
    ON r.store_id = s.store_id
INNER JOIN Products AS p
    ON r.product_id = p.product_id
WHERE r.lost_sales_units > 0
GROUP BY
    r.store_id,
    s.store_name,
    s.region,
    r.product_id,
    p.product_name,
    p.category
ORDER BY total_lost_sales_units DESC
LIMIT 10;
-- Finding
-- S013 — Energy Drink Can (P016) had the highest recorded lost-sales total, at 170 units.
-- S009 — Fresh Curd 500g (P004) ranked second, with 129 units.
-- S009 appeared four times in the top 10, while S013 appeared three times. 
-- These stores have multiple product combinations worth investigating.
-- Beverages appeared frequently among the top 10 results, suggesting that this category deserves further examination.
-- However, the top 10 alone cannot establish that beverages have the highest overall lost-sales total.
-- Business implication
-- Prioritise S013's Energy Drink Can and S009's Fresh Curd for investigation. 
-- Review their stockout history, closing stock, reorder points, and safety-stock levels to identify whether recurring inventory risks
--  may be contributing to recorded lost-sales units.
-- Limitation
-- These results show recorded lost-sales units, not confirmed lost revenue. 
-- The analysis identifies where to investigate but does not establish why the lost sales occurred. 
-- The top 10 is also a shortlist, not a complete comparison of all stores or product categories.


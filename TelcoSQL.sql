select * from telco t
order by "Txn_ID" asc;

ALTER TABLE telco DROP COLUMN "Churn1";
ALTER TABLE telco DROP COLUMN "Segmen_NPS";
ALTER TABLE telco DROP COLUMN "ARPU_Category";

ALTER TABLE telco 
ADD "Churn" boolean;


UPDATE telco t
SET "Churn" = s.churn
FROM (
    SELECT
        "Subscriber_ID",
        CASE
            WHEN COUNT(*) FILTER (
                WHERE EXTRACT(YEAR FROM "Activation_Date") = 2025
            ) > 0
            THEN FALSE
            ELSE TRUE
        END AS churn
    FROM telco
    GROUP BY "Subscriber_ID"
) s
WHERE t."Subscriber_ID" = s."Subscriber_ID";


UPDATE telco t
SET "Churn1" = s.churn
FROM (
    SELECT
        "Subscriber_ID",
        CASE
            WHEN COUNT(*) FILTER (
                WHERE EXTRACT(YEAR FROM "Activation_Date") = 2025
            ) > 0
            THEN 'N'
            ELSE 'Y'
        END AS churn
    FROM telco
    GROUP BY "Subscriber_ID"
) s
WHERE t."Subscriber_ID" = s."Subscriber_ID";

SELECT
    ROUND(
        COUNT(DISTINCT "Subscriber_ID")
            FILTER (WHERE "Churn" = TRUE) * 100.0
        / COUNT(DISTINCT "Subscriber_ID"),
        2
    ) AS churn_rate
FROM telco;


-- churn rate
WITH customer_year AS (
    SELECT DISTINCT
        "Subscriber_ID",
        EXTRACT(YEAR FROM "Activation_Date")::int AS order_year
    FROM telco
),
churn AS (
    SELECT
        a.order_year,
        COUNT(DISTINCT a."Subscriber_ID") AS active_customers,
        COUNT(DISTINCT b."Subscriber_ID") AS retained_customers,
        COUNT(DISTINCT a."Subscriber_ID")
          - COUNT(DISTINCT b."Subscriber_ID") AS churn_customers
    FROM customer_year a
    LEFT JOIN customer_year b
        ON a."Subscriber_ID" = b."Subscriber_ID"
       AND b.order_year = a.order_year + 1
    GROUP BY a.order_year
)
SELECT
    order_year,
    active_customers,
    retained_customers,
    churn_customers,
    ROUND(
        churn_customers * 100.0 / active_customers,
        2
    ) AS churn_rate
FROM churn
WHERE order_year IN (2023, 2024)
ORDER BY order_year;


--retention rate
WITH customer_year AS (
    SELECT DISTINCT
        "Subscriber_ID",
        EXTRACT(YEAR FROM "Activation_Date")::int AS order_year
    FROM telco
),
retention AS (
    SELECT
        a.order_year,
        COUNT(DISTINCT a."Subscriber_ID") AS active_customers,
        COUNT(DISTINCT b."Subscriber_ID") AS retained_customers,
        COUNT(DISTINCT a."Subscriber_ID")
          - COUNT(DISTINCT b."Subscriber_ID") AS churn_customers
    FROM customer_year a
    LEFT JOIN customer_year b
        ON a."Subscriber_ID" = b."Subscriber_ID"
       AND b.order_year = a.order_year + 1
    GROUP BY a.order_year
)
SELECT
    order_year,
    active_customers,
    retained_customers,
    churn_customers,
    ROUND(
        retained_customers * 100.0 / active_customers,
        2
    ) AS retention_rate
FROM retention
WHERE order_year IN (2023, 2024)
ORDER BY order_year;

--estimasi CLTV
select 
	DISTINCT "Subscriber_ID",
	sum("Recharge_Amount")/count("Txn_ID") as aov,
	count("Txn_ID") as f,
	sum("Recharge_Amount")/count("Txn_ID")*count("Txn_ID") as cltv
from telco t
group by "Subscriber_ID"
order by cltv desc;

--RFM
create table rfm as
WITH max_date AS (
    SELECT max("Activation_Date"::date) AS latest_date
    FROM telco
),
rfm AS (
    SELECT
      	t."Subscriber_ID",
         ((select max("Activation_Date"::date)+1 from telco t2 ) - max("Activation_Date"::date))AS recency,
        COUNT(distinct "Txn_ID") AS frequency,
        SUM(t."Recharge_Amount") AS monetary
    FROM telco t
    CROSS JOIN max_date m
    GROUP BY
        t."Subscriber_ID",
        m.latest_date
),
rfm_score AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency desc) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm
),
total_score as(
	select *,
	r_score + m_score + f_score as total_score
	from rfm_score
),
segment as (
select *,
case 
	when total_score >=11 then 'Champion'
	when total_score >=9 then 'Loyal'
	when total_score >=6 then 'At risk'
	when total_score >=4 then 'Hibernation'
	else 'Lost'
end as segment
from total_score
)
select * from segment;



select count(distinct "Subscriber_ID")from telco t;
select * from rfm
where segment = 'Hibernation' and r_score = 1 and f_score=3;

select Count(distinct "Subscriber_ID"),segment from rfm
--where {{segment}} and {{r_score}} and {{f_score}}
group by segment;

SELECT
    EXTRACT(YEAR FROM "Activation_Date") AS tahun,
    SUM("Profit") AS total_profit
FROM telco
GROUP BY EXTRACT(YEAR FROM "Activation_Date")
ORDER BY tahun;

select * from telco;


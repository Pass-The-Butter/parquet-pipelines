-- name: customer_rfm_analysis
-- layer: gold
-- description: RFM (Recency, Frequency, Monetary) analysis for customer segmentation
-- depends_on: silver.marketing_customers

CREATE OR REPLACE TABLE gold.customer_rfm_analysis AS
WITH rfm_calculations AS (
    SELECT 
        customer_id,
        first_name,
        last_name,
        email,
        generation,
        -- Recency (days since last order)
        COALESCE(days_since_last_order, 9999) as recency_days,
        -- Frequency (total orders)
        total_orders as frequency,
        -- Monetary (total spent)
        total_spent as monetary,
        
        -- Additional context
        total_orders,
        total_spent,
        avg_order_value,
        first_order_date,
        last_order_date,
        customer_lifespan_days,
        orders_per_month,
        is_holiday_shopper,
        is_weekend_shopper,
        preferred_payment_method
    FROM silver.marketing_customers
),
rfm_scores AS (
    SELECT *,
        -- Recency Score (1=worst, 5=best) - Lower days = better
        CASE 
            WHEN recency_days <= 30 THEN 5
            WHEN recency_days <= 90 THEN 4
            WHEN recency_days <= 180 THEN 3
            WHEN recency_days <= 365 THEN 2
            ELSE 1
        END AS recency_score,
        
        -- Frequency Score (1=worst, 5=best)
        CASE 
            WHEN frequency >= 10 THEN 5
            WHEN frequency >= 5 THEN 4
            WHEN frequency >= 3 THEN 3
            WHEN frequency >= 2 THEN 2
            WHEN frequency >= 1 THEN 1
            ELSE 0
        END AS frequency_score,
        
        -- Monetary Score (1=worst, 5=best)
        CASE 
            WHEN monetary >= 2000 THEN 5
            WHEN monetary >= 1000 THEN 4
            WHEN monetary >= 500 THEN 3
            WHEN monetary >= 100 THEN 2
            WHEN monetary > 0 THEN 1
            ELSE 0
        END AS monetary_score
    FROM rfm_calculations
)
SELECT 
    *,
    -- Combined RFM Score
    (recency_score + frequency_score + monetary_score) AS rfm_score,
    
    -- RFM Segments (Marketing Gold!)
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
        WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'Potential Loyalists'
        WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score >= 4 THEN 'Cannot Lose Them'
        WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Promising'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'Need Attention'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS rfm_segment,
    
    -- Marketing Action Recommendations
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Reward loyalty, upsell premium products'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Engage with personalized offers'
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'Welcome series, product education'
        WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'Increase purchase frequency'
        WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Win-back campaign, special offers'
        WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score >= 4 THEN 'VIP treatment, prevent churn'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Re-engagement campaign'
        ELSE 'Monitor and nurture'
    END AS marketing_action
    
FROM rfm_scores
ORDER BY rfm_score DESC, monetary DESC;
-- This query performs RFM (Recency, Frequency, Monetary) analysis on customers.
-- It calculates recency, frequency, and monetary scores for each customer,
-- segments them into RFM categories, and provides marketing action recommendations.
-- The RFM scores are used to identify customer segments such as Champions, Loyal Customers,        
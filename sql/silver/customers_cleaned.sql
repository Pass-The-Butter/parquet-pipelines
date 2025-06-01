-- name: customers_cleaned
-- layer: silver
-- description: Clean and standardize customer data
-- depends_on: bronze.customers

CREATE OR REPLACE TABLE silver.customers_cleaned AS
SELECT 
    customer_id,
    TRIM(UPPER(first_name)) AS first_name,
    TRIM(UPPER(last_name)) AS last_name,
    TRIM(first_name) || ' ' || TRIM(last_name) AS full_name,
    LOWER(TRIM(email)) AS email,
    phone,
    TRIM(address) AS address,
    TRIM(UPPER(city)) AS city,
    TRIM(UPPER(state)) AS state,
    zip_code,
    date_of_birth,
    created_date AS signup_date,
    updated_date,
    active,
    TRIM(UPPER(customer_type)) AS customer_type
FROM bronze.customers
WHERE customer_id IS NOT NULL
    AND first_name IS NOT NULL
    AND last_name IS NOT NULL
    AND email IS NOT NULL
    AND active = 1;
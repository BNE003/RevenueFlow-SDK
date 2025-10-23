-- =====================================================
-- RevenueFlow Database Setup
-- =====================================================
-- Run this SQL in your Supabase SQL Editor to set up the database
-- for the RevenueFlow SDK

-- =====================================================
-- 1. Create the purchases table
-- =====================================================

CREATE TABLE IF NOT EXISTS purchases (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- App and user identification
    app_id TEXT NOT NULL,
    user_id TEXT,

    -- Purchase details
    product_id TEXT NOT NULL,
    transaction_id TEXT NOT NULL UNIQUE,
    purchase_date TIMESTAMPTZ NOT NULL,
    environment TEXT NOT NULL, -- 'production', 'sandbox', or 'xcode'

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 2. Create indexes for better query performance
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_purchases_app_id
    ON purchases(app_id);

CREATE INDEX IF NOT EXISTS idx_purchases_transaction_id
    ON purchases(transaction_id);

CREATE INDEX IF NOT EXISTS idx_purchases_user_id
    ON purchases(user_id)
    WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_purchases_created_at
    ON purchases(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date
    ON purchases(purchase_date DESC);

-- =====================================================
-- 3. Enable Row Level Security (RLS)
-- =====================================================

ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. Create RLS Policies
-- =====================================================

-- Policy: Allow the SDK to insert purchases using the anon key
CREATE POLICY "Allow SDK inserts"
    ON purchases
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Policy: Allow reading all purchases (for your admin dashboard)
-- You can restrict this further based on your needs
CREATE POLICY "Allow authenticated reads"
    ON purchases
    FOR SELECT
    TO authenticated
    USING (true);

-- Optional: Allow service_role full access (for admin operations)
CREATE POLICY "Allow service_role full access"
    ON purchases
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- 5. Create helpful views (optional)
-- =====================================================

-- View: Recent purchases
CREATE OR REPLACE VIEW recent_purchases AS
SELECT
    id,
    app_id,
    user_id,
    product_id,
    transaction_id,
    purchase_date,
    environment,
    created_at
FROM purchases
ORDER BY created_at DESC
LIMIT 100;

-- View: Purchase statistics by app
CREATE OR REPLACE VIEW purchase_stats_by_app AS
SELECT
    app_id,
    COUNT(*) as total_purchases,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT product_id) as unique_products,
    MIN(purchase_date) as first_purchase,
    MAX(purchase_date) as last_purchase
FROM purchases
GROUP BY app_id;

-- View: Daily purchase counts
CREATE OR REPLACE VIEW daily_purchase_counts AS
SELECT
    app_id,
    DATE(purchase_date) as purchase_day,
    environment,
    COUNT(*) as purchase_count,
    COUNT(DISTINCT user_id) as unique_users
FROM purchases
GROUP BY app_id, DATE(purchase_date), environment
ORDER BY purchase_day DESC;

-- =====================================================
-- 6. Create a function to get app statistics
-- =====================================================

CREATE OR REPLACE FUNCTION get_app_stats(p_app_id TEXT)
RETURNS TABLE (
    total_purchases BIGINT,
    unique_users BIGINT,
    unique_products BIGINT,
    first_purchase TIMESTAMPTZ,
    last_purchase TIMESTAMPTZ,
    purchases_today BIGINT,
    purchases_this_week BIGINT,
    purchases_this_month BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT as total_purchases,
        COUNT(DISTINCT user_id)::BIGINT as unique_users,
        COUNT(DISTINCT product_id)::BIGINT as unique_products,
        MIN(purchase_date) as first_purchase,
        MAX(purchase_date) as last_purchase,
        COUNT(*) FILTER (WHERE purchase_date >= CURRENT_DATE)::BIGINT as purchases_today,
        COUNT(*) FILTER (WHERE purchase_date >= CURRENT_DATE - INTERVAL '7 days')::BIGINT as purchases_this_week,
        COUNT(*) FILTER (WHERE purchase_date >= CURRENT_DATE - INTERVAL '30 days')::BIGINT as purchases_this_month
    FROM purchases
    WHERE app_id = p_app_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. Setup complete!
-- =====================================================

-- You can now test the setup with a sample insert:
-- INSERT INTO purchases (app_id, product_id, transaction_id, purchase_date, environment)
-- VALUES ('test-app-123', 'com.test.premium', 'test-transaction-1', NOW(), 'sandbox');

-- Check if it worked:
-- SELECT * FROM purchases WHERE app_id = 'test-app-123';

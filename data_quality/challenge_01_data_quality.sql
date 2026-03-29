-- ============================================
-- Challenge 01: Data Quality Audit
-- MavenFuzzyFactory Hackathon
-- Author: Saleh Hossam
-- Date: 2026-03-18
-- ============================================
-- SECTION 0: Baseline Verification
-- Confirm all 6 tables loaded with expected row counts
-- Date range: 2012-03-19 to 2015-03-19 (3 years of data)

USE mavenfuzzyfactory;
SELECT COUNT(*) FROM website_sessions;

SELECT COUNT(*) FROM website_pageviews;

SELECT COUNT(*) FROM orders;

SELECT COUNT(*) FROM order_items;

SELECT COUNT(*) FROM order_item_refunds;

SELECT COUNT(*) FROM products;


SELECT 'website_sessions' AS tbl, COUNT(*) AS row_count FROM website_sessions
UNION ALL
SELECT 'website_pageviews', COUNT(*) FROM website_pageviews
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_item_refunds', COUNT(*) FROM order_item_refunds
UNION ALL
SELECT 'products', COUNT(*) FROM products;


SELECT MIN(created_at) AS first_record,
MAX(created_at) AS last_record
FROM website_sessions;

SELECT * FROM website_sessions LIMIT 5;

-- ============================================
-- ============================================
-- Check 0: Duplicate session records (planted dirty data)
-- Found during import: session_id = 3 inserted twice with identical data
-- Confirmed by viewing raw SQL file — duplicate INSERT at line 113
-- Fix applied: used INSERT IGNORE at load time to skip duplicate rows
-- To verify only 1 record exists for session_id = 3:
SELECT website_session_id, COUNT(*) AS cnt
FROM website_sessions
WHERE website_session_id = 3
GROUP BY website_session_id;
-- Expected result: 1 row with cnt = 1, confirming duplicate was excluded

-- Check 0b: Sessions with identical user_id AND identical timestamp
SELECT user_id, created_at, COUNT(*) AS cnt
FROM website_sessions
GROUP BY user_id, created_at
HAVING cnt > 1
ORDER BY cnt DESC;
-- Check 0b result: 0 additional duplicate user_id + timestamp combinations found
-- The only duplicate in the dataset was session_id = 3 caught at import
-- Confirms INSERT IGNORE captured the only planted duplicate
-- ============================================
-- Check 1: NULL timestamps
SELECT COUNT(*) AS null_timestamps FROM website_sessions WHERE created_at IS NULL;
-- No nulls found in the created At in website Session 
-- Check 1b: NULL timestamps in other tables
SELECT COUNT(*) AS null_order_timestamps FROM orders WHERE created_at IS NULL;
SELECT COUNT(*) AS null_pageview_timestamps FROM website_pageviews WHERE created_at IS NULL;
SELECT COUNT(*) AS null_refund_timestamps FROM order_item_refunds WHERE created_at IS NULL;

-- Check 1b results: All three returned 0
-- null_order_timestamps = 0
-- null_pageview_timestamps = 0  
-- null_refund_timestamps = 0
-- Timestamp integrity confirmed across all 6 tables
-- ============================================
-- Check 2: Zero or negative prices / cost exceeds price
SELECT COUNT(*) AS bad_prices FROM orders WHERE price_usd <= 0 OR cogs_usd >= price_usd;
SELECT * FROM orders WHERE price_usd <= 0 OR cogs_usd >= price_usd;

SELECT * FROM orders WHERE price_usd <= 0 OR cogs_usd >= price_usd;
SELECT * FROM orders WHERE price_usd <= 0 OR cogs_usd >= price_usd;


SELECT COUNT(*) AS null_prices
FROM orders
WHERE price_usd IS NULL OR cogs_usd IS NULL;

-- Check 2 findings: 8 bad price records found across 2 types:
-- Type A: 5 orders with price_usd = 0.00 and cogs_usd = 0.00 (impossible in retail)
-- Type B: 3 orders with price_usd = -59.99 and cogs_usd = -22.49
-- All 3 reference primary_product_id = 2 (The Forever Love Bear, price $59.99)
-- These are Love Bear refunds incorrectly recorded as negative orders
-- instead of being logged in the order_item_refunds table
-- The values are exactly the negative of the product's price and cost
-- confirming this is a data entry process error, not random corruption
-- Action: exclude all 8 records from revenue and conversion rate analysis
-- No null Prices or Cogs 
-- Check 2b: Bad prices in order_items table
SELECT COUNT(*) AS bad_item_prices
FROM order_items
WHERE price_usd <= 0 OR cogs_usd >= price_usd;

SELECT COUNT(*) AS null_prices
FROM order_items
WHERE price_usd IS NULL OR cogs_usd IS NULL;
-- Check 2b result: 0 bad prices found in order_items table
-- All order_items records have valid positive prices and cost < selling price
-- Price integrity confirmed at the line-item level
-- ============================================

-- Check 3: Pageviews timestamped before their session
SELECT COUNT(*) AS impossible_pageviews FROM website_pageviews wp
JOIN website_sessions ws ON wp.website_session_id = ws.website_session_id
WHERE wp.created_at < ws.created_at;

SELECT wp.website_pageview_id, wp.created_at AS PageViews_Creation, ws.created_at AS Website_Session_Creation FROM  website_pageviews wp
JOIN website_sessions ws ON wp.website_session_id = ws.website_session_id
WHERE wp.created_at < ws.created_at;
-- Check 3 findings: 10 pageviews timestamped before their parent session
-- ALL 10 occurred exclusively on 2012-03-19 — the company's very first day
-- Time differences are small (under 5 minutes) suggesting a clock sync issue
-- between the session tracking and pageview tracking systems on launch day
-- This was a one-time technical issue on day one — never repeated afterwards
-- Action: exclude these 10 pageviews from funnel analysis
-- Business note: this explains why early funnel metrics may look slightly off
-- ============================================

-- Check 4: Orphan product IDs in order_items
SELECT COUNT(*) AS orphan_products FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
SELECT * FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Check 4 findings: 15 order_items reference product_id = 99
-- product_id 99 does not exist in the products master table (only IDs 1,2,3,4 exist)
-- These span the full date range (2012 to 2014) suggesting systematic data corruption
-- not a one-time event
-- Action: exclude these 15 records from all product-level analysis

-- ============================================
-- Check 5: Potential bot traffic
SELECT user_id, COUNT(*) AS session_count
FROM website_sessions
GROUP BY user_id
HAVING session_count > 50
ORDER BY session_count DESC
LIMIT 20;
-- Check 5 findings: No suspicious bot traffic detected
-- Threshold used: users with more than 50 sessions (arbitrary but reasonable
-- for a toy retailer — legitimate repeat customers unlikely to visit 50+ times)
-- Result: 0 users exceeded this threshold
-- Additional check: what is the maximum session count per user?
SELECT MAX(session_count) AS max_sessions_per_user
FROM (
    SELECT user_id, COUNT(*) AS session_count
    FROM website_sessions
    GROUP BY user_id
) AS user_counts;
-- Check 5 findings: No suspicious bot traffic detected
-- Maximum sessions per single user = 4 (across 472,871 total sessions)
-- This is well within normal repeat customer behavior for an e-commerce retailer
-- Threshold of 50 was never approached — no user came close
-- Conclusion: dataset shows no signs of bot or automated traffic

-- ============================================
-- Check 6: Case inconsistency in text fields
SELECT DISTINCT utm_source, utm_campaign, device_type
FROM website_sessions
ORDER BY utm_source;
-- Check 6 findings: Case inconsistency in 3 text fields
-- utm_source: 'gsearch' recorded as gsearch / Gsearch / GSEARCH (3 variants)
--             'bsearch' recorded as bsearch / Bsearch / BSearch (3 variants)
-- utm_campaign: 'nonbrand' recorded as nonbrand / NonBrand / NONBRAND (3 variants)
--               'brand' recorded as brand / Brand (2 variants)
-- device_type: 'desktop' recorded as desktop / Desktop (2 variants)
--              'mobile' recorded as mobile / Mobile (2 variants)
-- Fix: apply LOWER() to all text fields in every analytical query
-- Impact: without this fix, channel session counts would be understated

-- Additional finding: undocumented channel 'socialbook' found in utm_source
-- The brief only documents gsearch, bsearch, brand, organic, and direct
-- socialbook appears to be a social media channel not covered in the channel key
-- Assumption: treat as a separate paid channel, exclude from gsearch/bsearch analysis

-- ============================================
-- Check 6b: Case inconsistency in pageview_url
SELECT DISTINCT pageview_url
FROM website_pageviews
ORDER BY pageview_url;
-- Check 6b findings: 5 pageview URLs have capital letter inconsistencies
-- /Cart, /Home, /Products, /Shipping, /The-Original-Mr-Fuzzy recorded with capitals
-- Fix: apply LOWER(pageview_url) in ALL funnel and conversion queries
-- Impact: without this fix funnel counts would be understated or not obvious 
-- ============================================
-- Check 7: Leading or trailing spaces in text fields
SELECT COUNT(*) AS dirty_sources
FROM website_sessions
WHERE utm_source != TRIM(utm_source)
   OR utm_campaign != TRIM(utm_campaign)
   OR device_type != TRIM(device_type);
-- There are leading and trailing spaces in 39 rows 

SELECT * 
FROM website_sessions
WHERE utm_source != TRIM(utm_source)
   OR utm_campaign != TRIM(utm_campaign)
   OR device_type != TRIM(device_type);
   
-- Check 7 findings: 39 sessions have leading/trailing spaces
-- in utm_source, utm_campaign, or device_type fields
-- Fix: apply TRIM() alongside LOWER() in all analytical queries
-- Combined fix for all text fields:
-- LOWER(TRIM(utm_source)), LOWER(TRIM(utm_campaign)), LOWER(TRIM(device_type))

-- Check 7b: Leading/trailing spaces in http_referer field
SELECT COUNT(*) AS dirty_referers
FROM website_sessions
WHERE http_referer != TRIM(http_referer);

SELECT *
FROM website_sessions
WHERE http_referer != TRIM(http_referer);

-- Check distinct http_referer values for case inconsistency
SELECT DISTINCT http_referer
FROM website_sessions
ORDER BY http_referer;

-- Check 7b findings: 50 sessions have leading/trailing spaces in http_referer
-- DISTINCT http_referer values reveal the issue:
-- ' https://www.gsearch.com' (with leading space) treated as different from
--   'https://www.gsearch.com' (clean) — same domain, two different values
-- Same issue found in ' https://www.bsearch.com'
-- Fix: apply TRIM(http_referer) in all channel classification queries
-- Additional confirmation: https://www.socialbook.com appears as a referer
-- This cross-validates the undocumented socialbook channel finding in Check 6
-- Combined fix for complete text field standardization:
-- LOWER(TRIM(utm_source)), LOWER(TRIM(utm_campaign)),
-- LOWER(TRIM(device_type)), TRIM(http_referer)

-- ============================================
-- ============================================
-- SUMMARY: Total records excluded from analysis
-- ================================================
-- 1. Duplicate session (1 record)
--    Justification: duplicate primary keys inflate session counts
--    causing conversion rates to be understated
--
-- 2. Bad price orders (8 records)
--    Justification: zero/negative revenue corrupts AOV and total
--    revenue calculations — cannot represent real transactions
--
-- 3. Impossible pageviews (10 records)
--    Justification: pageviews before session start are logically
--    impossible — including them breaks funnel sequence analysis
--
-- 4. Orphan product items (15 records)
--    Justification: product_id 99 cannot be joined to any product
--    name or price — including them corrupts product-level revenue

-- 5. Case/space issues:  89 records total
--   39 in utm fields (website_sessions)
--   50 in http_referer (website_sessions)
--   Fixed via LOWER(TRIM()) — not excluded, corrected at query time
--
-- Total hard exclusions: 34 records / ~1.7M total = 0.002%
-- Conclusion: exclusion rate is negligible — dataset suitable for
-- full analysis with LOWER(TRIM()) applied to all text fields
-- ============================================
-- 3-STEP DATA VALIDATION PROCESS
-- Step 1 — AT INGESTION: Apply LOWER(TRIM()) to all text fields and reject
--           any record where price_usd <= 0 or primary key already exists
-- Step 2 — AT LOAD: Run automated duplicate detection on user_id + timestamp
--           combinations and quarantine suspicious records before they enter
--           the production database
-- Step 3 — AT ANALYSIS: Run a standard validation script before every sprint
--           checking row counts, null rates, and price ranges against expected
--           baseline values — alert the analyst team if any metric deviates


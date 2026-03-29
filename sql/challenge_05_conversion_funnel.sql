-- ============================================================
-- Challenge 05: Customer Purchase Funnel
-- MavenFuzzyFactory Hackathon
-- Author: Zeina (Q1, Q3, Q4) | Saleh Hossam 
-- Date: 2026-03-22
-- ============================================================
-- C01 fixes that apply across this entire file:
--
--   LOWER(TRIM(utm_source))    -- gsearch was recorded in mixed case
--   LOWER(TRIM(utm_campaign))  -- same problem with nonbrand
--   LOWER(TRIM(device_type))   -- desktop/mobile have case variants
--   LOWER(pageview_url)        -- CRITICAL: /Cart, /Products, /Shipping,
--                              --   /The-Original-Mr-Fuzzy all have capitals
--                              --   in the raw data. Miss this and your
--                              --   funnel silently undercounts with no error.
--
--   AND o.price_usd > 0 goes in JOIN ON, not WHERE
--   -- If it goes in WHERE it kills all non-converting sessions
--   -- because NULL > 0 is false. Your LEFT JOIN becomes an
--   -- INNER JOIN and session counts drop. Full explanation in
--   -- the teammate guide.
--
--   product_id != 99 goes on any order_items query
--   -- Not needed in this file directly but listed for completeness.
--
-- Funnel window: August 5, 2012 onwards
--   -- lander-1 was confirmed live from June 19 (C06 Q1), test ended
--   --   July 28. August 5 is the brief's stated clean start date —
--   --   far enough past the test end that routing is settled.
--
-- Love Bear comparison window: January 6, 2013 onwards
--   -- Love Bear launch date. Comparing before this date makes no
--   --   sense because there was nothing to compare against.
-- ============================================================


-- ============================================================
-- Query 1a: Full Conversion Funnel — Session Counts at Each Step
-- Author: Zeina | Reviewed: Saleh Hossam
-- Date: 2026-03-22
-- What it answers: of all gsearch nonbrand visitors who landed on
--   /lander-1 from Aug 5 2012 onwards, how many made it to each
--   step of the funnel?
-- ============================================================

-- CTE 1: pull every gsearch nonbrand session that entered on /lander-1.
-- We join to website_pageviews here just to confirm /lander-1 was visited.
-- DISTINCT matters — a session that hit /lander-1 twice would appear twice
-- without it and inflate the lander count.

WITH lander_sessions AS (
    SELECT DISTINCT ws.website_session_id
    FROM website_sessions ws
    JOIN website_pageviews wp
        ON ws.website_session_id = wp.website_session_id
        AND LOWER(wp.pageview_url) = '/lander-1'
    WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
      AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
      AND ws.created_at >= '2012-08-05'
),

-- CTE 2: for every session above, check which funnel pages it visited.
-- MAX(CASE WHEN) gives 1 if the page was hit at least once, 0 if never.
-- Using MAX instead of SUM so a session that visits /cart twice
-- still only counts as 1 at that step — which is what we want.
-- The LEFT JOIN here keeps all sessions even if they left at /lander-1
-- and never visited another page.
session_flags AS (
    SELECT
        ls.website_session_id,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/products'
            THEN 1 ELSE 0 END)                                    AS hit_products,
        MAX(CASE WHEN LOWER(wp.pageview_url) IN (
                '/the-original-mr-fuzzy',
                '/the-forever-love-bear',
                '/the-birthday-sugar-panda',
                '/the-hudson-river-mini-bear')
            THEN 1 ELSE 0 END)                                    AS hit_product_detail,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/cart'
            THEN 1 ELSE 0 END)                                    AS hit_cart,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/shipping'
            THEN 1 ELSE 0 END)                                    AS hit_shipping,
        MAX(CASE WHEN LOWER(wp.pageview_url) IN ('/billing', '/billing-2')
            THEN 1 ELSE 0 END)                                    AS hit_billing,
        -- /billing-2 is the winner from the Sep-Nov 2012 A/B test (C06).
        -- It replaced /billing after the test — both are grouped here
        -- so no sessions are missed depending on when they came through.
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/thank-you-for-your-order'
            THEN 1 ELSE 0 END)                                    AS hit_thankyou
    FROM lander_sessions ls
    LEFT JOIN website_pageviews wp
        ON ls.website_session_id = wp.website_session_id
    GROUP BY ls.website_session_id
)

-- Final SELECT: sum the flags to get how many sessions reached each step.
-- COUNT(*) gives total lander sessions — that's our 100% baseline.
SELECT
    COUNT(*)                AS sessions_at_lander,
    SUM(hit_products)       AS sessions_at_products,
    SUM(hit_product_detail) AS sessions_at_product_detail,
    SUM(hit_cart)           AS sessions_at_cart,
    SUM(hit_shipping)       AS sessions_at_shipping,
    SUM(hit_billing)        AS sessions_at_billing,
    SUM(hit_thankyou)       AS sessions_at_thankyou
FROM session_flags;

-- Results (confirmed 2026-03-22):
--   sessions_at_lander         = 34,770
--   sessions_at_products       = 16,462
--   sessions_at_product_detail = 12,079
--   sessions_at_cart           =  5,242
--   sessions_at_shipping       =  3,588
--   sessions_at_billing        =  2,902
--   sessions_at_thankyou       =  1,542


-- ============================================================
-- Query 1b: Full Conversion Funnel — Clickthrough Rates at Each Step
-- Author: Saleh Hossam
-- Date: 2026-03-22
-- What it answers: what percentage of sessions at each step
--   made it to the next step? The lowest rate = the biggest leak.
-- Note: this is the same logic as Q1a wrapped in a subquery
--   so we only run the CTEs once and calculate rates on top.
-- ============================================================

SELECT
    sessions_at_lander,
    sessions_at_products,
    sessions_at_product_detail,
    sessions_at_cart,
    sessions_at_shipping,
    sessions_at_billing,
    sessions_at_thankyou,

    -- Each rate = sessions at this step / sessions at the previous step
    -- These are the numbers that tell you where the funnel is leaking
    ROUND(sessions_at_products       / sessions_at_lander          * 100, 1) AS lander_to_products_pct,
    ROUND(sessions_at_product_detail / sessions_at_products        * 100, 1) AS products_to_detail_pct,
    ROUND(sessions_at_cart           / sessions_at_product_detail  * 100, 1) AS detail_to_cart_pct,
    ROUND(sessions_at_shipping       / sessions_at_cart            * 100, 1) AS cart_to_shipping_pct,
    ROUND(sessions_at_billing        / sessions_at_shipping        * 100, 1) AS shipping_to_billing_pct,
    ROUND(sessions_at_thankyou       / sessions_at_billing         * 100, 1) AS billing_to_thankyou_pct

FROM (
    -- Exact same CTE chain as Q1a — pulled into a subquery so the
    -- percentages can be calculated in one clean outer SELECT
    WITH lander_sessions AS (
        SELECT DISTINCT ws.website_session_id
        FROM website_sessions ws
        JOIN website_pageviews wp
            ON ws.website_session_id = wp.website_session_id
            AND LOWER(wp.pageview_url) = '/lander-1'
        WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
          AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
          AND ws.created_at >= '2012-08-05'
    ),
    session_flags AS (
        SELECT
            ls.website_session_id,
            MAX(CASE WHEN LOWER(wp.pageview_url) = '/products'
                THEN 1 ELSE 0 END)                                    AS hit_products,
            MAX(CASE WHEN LOWER(wp.pageview_url) IN (
                    '/the-original-mr-fuzzy',
                    '/the-forever-love-bear',
                    '/the-birthday-sugar-panda',
                    '/the-hudson-river-mini-bear')
                THEN 1 ELSE 0 END)                                    AS hit_product_detail,
            MAX(CASE WHEN LOWER(wp.pageview_url) = '/cart'
                THEN 1 ELSE 0 END)                                    AS hit_cart,
            MAX(CASE WHEN LOWER(wp.pageview_url) = '/shipping'
                THEN 1 ELSE 0 END)                                    AS hit_shipping,
            MAX(CASE WHEN LOWER(wp.pageview_url) IN ('/billing', '/billing-2')
                THEN 1 ELSE 0 END)                                    AS hit_billing,
            MAX(CASE WHEN LOWER(wp.pageview_url) = '/thank-you-for-your-order'
                THEN 1 ELSE 0 END)                                    AS hit_thankyou
        FROM lander_sessions ls
        LEFT JOIN website_pageviews wp
            ON ls.website_session_id = wp.website_session_id
        GROUP BY ls.website_session_id
    )
    SELECT
        COUNT(*)                AS sessions_at_lander,
        SUM(hit_products)       AS sessions_at_products,
        SUM(hit_product_detail) AS sessions_at_product_detail,
        SUM(hit_cart)           AS sessions_at_cart,
        SUM(hit_shipping)       AS sessions_at_shipping,
        SUM(hit_billing)        AS sessions_at_billing,
        SUM(hit_thankyou)       AS sessions_at_thankyou
    FROM session_flags
) AS funnel_counts;

-- Results (confirmed 2026-03-22):
--   lander_to_products_pct    = 47.3%
--   products_to_detail_pct    = 73.4%
--   detail_to_cart_pct        = 43.4%   ← BIGGEST LEAK
--   cart_to_shipping_pct      = 68.4%
--   shipping_to_billing_pct   = 80.9%
--   billing_to_thankyou_pct   = 53.1%
--
-- BIGGEST LEAK: product detail → cart at 43.4%
--   Every other transition is 68%+. More than half the visitors
--   who looked at a product page left without adding it to cart.
--   This is the single highest-leverage step to fix.


-- ============================================================
-- Query 2: Mr. Fuzzy vs Love Bear — Funnel Comparison
-- Author: Saleh Hossam
-- Date: 2026-03-22
-- What it answers: since the Love Bear launched Jan 6 2013, do
--   visitors to the Mr. Fuzzy page and the Love Bear page convert
--   at different rates through the rest of the funnel?
-- Window: January 6, 2013 onwards only.
--   Using Aug 2012 as start would be unfair — Love Bear didn't
--   exist yet so Mr. Fuzzy would have 6 months of extra data.
-- ============================================================

-- CTE 1: same entry point — gsearch nonbrand sessions on /lander-1.
-- Only difference from Q1 is the date filter — Jan 6, 2013 from here on.
WITH lander_sessions AS (
    SELECT DISTINCT ws.website_session_id
    FROM website_sessions ws
    JOIN website_pageviews wp
        ON ws.website_session_id = wp.website_session_id
        AND LOWER(wp.pageview_url) = '/lander-1'
    WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
      AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
      AND ws.created_at >= '2013-01-06'
),

-- CTE 2: flag each funnel step per session.
-- Key difference from Q1: instead of one combined hit_product_detail
-- flag, we have two separate flags — one per product. This lets us
-- split the funnel at the product page level in the outer query.
-- A session that somehow visited both pages gets flagged for both —
-- we don't filter those out here. The outer query handles the split.
session_flags AS (
    SELECT
        ls.website_session_id,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/the-original-mr-fuzzy'
            THEN 1 ELSE 0 END)                                    AS hit_mrfuzzy,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/the-forever-love-bear'
            THEN 1 ELSE 0 END)                                    AS hit_lovebear,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/cart'
            THEN 1 ELSE 0 END)                                    AS hit_cart,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/shipping'
            THEN 1 ELSE 0 END)                                    AS hit_shipping,
        MAX(CASE WHEN LOWER(wp.pageview_url) IN ('/billing', '/billing-2')
            THEN 1 ELSE 0 END)                                    AS hit_billing,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/thank-you-for-your-order'
            THEN 1 ELSE 0 END)                                    AS hit_thankyou
    FROM lander_sessions ls
    LEFT JOIN website_pageviews wp
        ON ls.website_session_id = wp.website_session_id
    GROUP BY ls.website_session_id
)

-- Final SELECT: use conditional aggregation to show both products side
-- by side on one row. The denominator for each product's funnel steps
-- is the sessions that reached that product's detail page — not all
-- lander sessions. So cart/shipping/billing/thankyou for Mr. Fuzzy are
-- only counted where hit_mrfuzzy = 1, and same logic for Love Bear.
SELECT
    -- Mr. Fuzzy funnel
    SUM(hit_mrfuzzy)                                           AS mrfuzzy_at_detail,
    SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_cart     ELSE 0 END) AS mrfuzzy_at_cart,
    SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_shipping ELSE 0 END) AS mrfuzzy_at_shipping,
    SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_billing  ELSE 0 END) AS mrfuzzy_at_billing,
    SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_thankyou ELSE 0 END) AS mrfuzzy_at_thankyou,

    -- Mr. Fuzzy clickthrough rates
    ROUND(SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_cart     ELSE 0 END)
        / SUM(hit_mrfuzzy)                                     * 100, 1) AS mrfuzzy_detail_to_cart_pct,
    ROUND(SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_shipping ELSE 0 END)
        / SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_cart     ELSE 0 END) * 100, 1) AS mrfuzzy_cart_to_shipping_pct,
    ROUND(SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_billing  ELSE 0 END)
        / SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_shipping ELSE 0 END) * 100, 1) AS mrfuzzy_shipping_to_billing_pct,
    ROUND(SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_thankyou ELSE 0 END)
        / SUM(CASE WHEN hit_mrfuzzy = 1 THEN hit_billing  ELSE 0 END) * 100, 1) AS mrfuzzy_billing_to_thankyou_pct,

    -- Love Bear funnel
    SUM(hit_lovebear)                                           AS lovebear_at_detail,
    SUM(CASE WHEN hit_lovebear = 1 THEN hit_cart     ELSE 0 END) AS lovebear_at_cart,
    SUM(CASE WHEN hit_lovebear = 1 THEN hit_shipping ELSE 0 END) AS lovebear_at_shipping,
    SUM(CASE WHEN hit_lovebear = 1 THEN hit_billing  ELSE 0 END) AS lovebear_at_billing,
    SUM(CASE WHEN hit_lovebear = 1 THEN hit_thankyou ELSE 0 END) AS lovebear_at_thankyou,

    -- Love Bear clickthrough rates
    ROUND(SUM(CASE WHEN hit_lovebear = 1 THEN hit_cart     ELSE 0 END)
        / SUM(hit_lovebear)                                     * 100, 1) AS lovebear_detail_to_cart_pct,
    ROUND(SUM(CASE WHEN hit_lovebear = 1 THEN hit_shipping ELSE 0 END)
        / SUM(CASE WHEN hit_lovebear = 1 THEN hit_cart     ELSE 0 END) * 100, 1) AS lovebear_cart_to_shipping_pct,
    ROUND(SUM(CASE WHEN hit_lovebear = 1 THEN hit_billing  ELSE 0 END)
        / SUM(CASE WHEN hit_lovebear = 1 THEN hit_shipping ELSE 0 END) * 100, 1) AS lovebear_shipping_to_billing_pct,
    ROUND(SUM(CASE WHEN hit_lovebear = 1 THEN hit_thankyou ELSE 0 END)
        / SUM(CASE WHEN hit_lovebear = 1 THEN hit_billing  ELSE 0 END) * 100, 1) AS lovebear_billing_to_thankyou_pct

FROM session_flags;

-- Results (confirmed 2026-03-22):
--   mrfuzzy_at_detail                 = 1,399
--   mrfuzzy_at_cart                   =   591
--   mrfuzzy_at_shipping               =   396
--   mrfuzzy_at_billing                =   319
--   mrfuzzy_at_thankyou               =   207
--   mrfuzzy_detail_to_cart_pct        = 42.2%
--   mrfuzzy_cart_to_shipping_pct      = 67.0%
--   mrfuzzy_shipping_to_billing_pct   = 80.6%
--   mrfuzzy_billing_to_thankyou_pct   = 64.9%
--
--   lovebear_at_detail                =   401
--   lovebear_at_cart                  =   224
--   lovebear_at_shipping              =   152
--   lovebear_at_billing               =   121
--   lovebear_at_thankyou              =    73
--   lovebear_detail_to_cart_pct       = 55.9%
--   lovebear_cart_to_shipping_pct     = 67.9%
--   lovebear_shipping_to_billing_pct  = 79.6%
--   lovebear_billing_to_thankyou_pct  = 60.3%
--
-- KEY FINDING: the gap between the two products is almost entirely
--   at the detail → cart step — Love Bear converts 13.7pp better
--   (55.9% vs 42.2%). Cart onwards, both products are nearly identical
--   (within 1-5pp at every step). The Mr. Fuzzy product page is the
--   problem — not the checkout. Visitors who decide to add Love Bear
--   to cart are just as likely to complete the purchase as Mr. Fuzzy
--   buyers. The decision is made earlier, on the product page itself.


-- ============================================================
-- Query 3: Mobile vs Desktop Funnel Comparison
-- Author: Zeina | Reviewed: Saleh Hossam
-- Date: 2026-03-22
-- What it answers: does the funnel behave differently for mobile
--   vs desktop? At which step is mobile abandonment the worst?
-- Same window as Q1 — August 5, 2012 onwards.
-- ============================================================

-- CTE 1: same entry point as Q1 but we carry device_type through
-- so we can split on it later in the conditional aggregation.
WITH lander_sessions AS (
    SELECT DISTINCT
        ws.website_session_id,
        LOWER(TRIM(ws.device_type)) AS device_type
    FROM website_sessions ws
    JOIN website_pageviews wp
        ON ws.website_session_id = wp.website_session_id
        AND LOWER(wp.pageview_url) = '/lander-1'
    WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
      AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
      AND ws.created_at >= '2012-08-05'
),

-- CTE 2: same flag logic as Q1, but device_type comes along for
-- the GROUP BY so we can split by it in the final SELECT.
session_flags AS (
    SELECT
        ls.website_session_id,
        ls.device_type,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/products'
            THEN 1 ELSE 0 END)                                    AS hit_products,
        MAX(CASE WHEN LOWER(wp.pageview_url) IN (
                '/the-original-mr-fuzzy',
                '/the-forever-love-bear',
                '/the-birthday-sugar-panda',
                '/the-hudson-river-mini-bear')
            THEN 1 ELSE 0 END)                                    AS hit_product_detail,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/cart'
            THEN 1 ELSE 0 END)                                    AS hit_cart,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/shipping'
            THEN 1 ELSE 0 END)                                    AS hit_shipping,
        MAX(CASE WHEN LOWER(wp.pageview_url) IN ('/billing', '/billing-2')
            THEN 1 ELSE 0 END)                                    AS hit_billing,
        MAX(CASE WHEN LOWER(wp.pageview_url) = '/thank-you-for-your-order'
            THEN 1 ELSE 0 END)                                    AS hit_thankyou
    FROM lander_sessions ls
    LEFT JOIN website_pageviews wp
        ON ls.website_session_id = wp.website_session_id
    GROUP BY ls.website_session_id, ls.device_type
)

-- Final SELECT: both device types on one row using conditional aggregation.
-- COUNT for the lander step (session IDs) — SUM for everything after
-- because those are already 0/1 flag columns.
-- Rates calculated inline so the file is self-contained.
SELECT
    -- Desktop counts
    COUNT(CASE WHEN device_type = 'desktop'
        THEN website_session_id END)                              AS desktop_at_lander,
    SUM(CASE WHEN device_type = 'desktop' THEN hit_products      ELSE 0 END) AS desktop_at_products,
    SUM(CASE WHEN device_type = 'desktop' THEN hit_product_detail ELSE 0 END) AS desktop_at_product_detail,
    SUM(CASE WHEN device_type = 'desktop' THEN hit_cart          ELSE 0 END) AS desktop_at_cart,
    SUM(CASE WHEN device_type = 'desktop' THEN hit_shipping      ELSE 0 END) AS desktop_at_shipping,
    SUM(CASE WHEN device_type = 'desktop' THEN hit_billing       ELSE 0 END) AS desktop_at_billing,
    SUM(CASE WHEN device_type = 'desktop' THEN hit_thankyou      ELSE 0 END) AS desktop_at_thankyou,

    -- Desktop clickthrough rates
    ROUND(SUM(CASE WHEN device_type = 'desktop' THEN hit_products       ELSE 0 END)
        / COUNT(CASE WHEN device_type = 'desktop' THEN website_session_id END) * 100, 1) AS desktop_lander_to_products_pct,
    ROUND(SUM(CASE WHEN device_type = 'desktop' THEN hit_product_detail ELSE 0 END)
        / SUM(CASE WHEN device_type = 'desktop' THEN hit_products       ELSE 0 END) * 100, 1) AS desktop_products_to_detail_pct,
    ROUND(SUM(CASE WHEN device_type = 'desktop' THEN hit_cart           ELSE 0 END)
        / SUM(CASE WHEN device_type = 'desktop' THEN hit_product_detail ELSE 0 END) * 100, 1) AS desktop_detail_to_cart_pct,
    ROUND(SUM(CASE WHEN device_type = 'desktop' THEN hit_shipping       ELSE 0 END)
        / SUM(CASE WHEN device_type = 'desktop' THEN hit_cart           ELSE 0 END) * 100, 1) AS desktop_cart_to_shipping_pct,
    ROUND(SUM(CASE WHEN device_type = 'desktop' THEN hit_billing        ELSE 0 END)
        / SUM(CASE WHEN device_type = 'desktop' THEN hit_shipping       ELSE 0 END) * 100, 1) AS desktop_shipping_to_billing_pct,
    ROUND(SUM(CASE WHEN device_type = 'desktop' THEN hit_thankyou       ELSE 0 END)
        / SUM(CASE WHEN device_type = 'desktop' THEN hit_billing        ELSE 0 END) * 100, 1) AS desktop_billing_to_thankyou_pct,

    -- Mobile counts
    COUNT(CASE WHEN device_type = 'mobile'
        THEN website_session_id END)                              AS mobile_at_lander,
    SUM(CASE WHEN device_type = 'mobile' THEN hit_products       ELSE 0 END) AS mobile_at_products,
    SUM(CASE WHEN device_type = 'mobile' THEN hit_product_detail ELSE 0 END) AS mobile_at_product_detail,
    SUM(CASE WHEN device_type = 'mobile' THEN hit_cart           ELSE 0 END) AS mobile_at_cart,
    SUM(CASE WHEN device_type = 'mobile' THEN hit_shipping       ELSE 0 END) AS mobile_at_shipping,
    SUM(CASE WHEN device_type = 'mobile' THEN hit_billing        ELSE 0 END) AS mobile_at_billing,
    SUM(CASE WHEN device_type = 'mobile' THEN hit_thankyou       ELSE 0 END) AS mobile_at_thankyou,

    -- Mobile clickthrough rates
    ROUND(SUM(CASE WHEN device_type = 'mobile' THEN hit_products       ELSE 0 END)
        / COUNT(CASE WHEN device_type = 'mobile' THEN website_session_id END) * 100, 1) AS mobile_lander_to_products_pct,
    ROUND(SUM(CASE WHEN device_type = 'mobile' THEN hit_product_detail ELSE 0 END)
        / SUM(CASE WHEN device_type = 'mobile' THEN hit_products       ELSE 0 END) * 100, 1) AS mobile_products_to_detail_pct,
    ROUND(SUM(CASE WHEN device_type = 'mobile' THEN hit_cart           ELSE 0 END)
        / SUM(CASE WHEN device_type = 'mobile' THEN hit_product_detail ELSE 0 END) * 100, 1) AS mobile_detail_to_cart_pct,
    ROUND(SUM(CASE WHEN device_type = 'mobile' THEN hit_shipping       ELSE 0 END)
        / SUM(CASE WHEN device_type = 'mobile' THEN hit_cart           ELSE 0 END) * 100, 1) AS mobile_cart_to_shipping_pct,
    ROUND(SUM(CASE WHEN device_type = 'mobile' THEN hit_billing        ELSE 0 END)
        / SUM(CASE WHEN device_type = 'mobile' THEN hit_shipping       ELSE 0 END) * 100, 1) AS mobile_shipping_to_billing_pct,
    ROUND(SUM(CASE WHEN device_type = 'mobile' THEN hit_thankyou       ELSE 0 END)
        / SUM(CASE WHEN device_type = 'mobile' THEN hit_billing        ELSE 0 END) * 100, 1) AS mobile_billing_to_thankyou_pct

FROM session_flags;

-- Results (confirmed 2026-03-22):
--   desktop_at_lander         = 26,317
--   desktop_at_products       = 13,581
--   desktop_at_product_detail = 10,313
--   desktop_at_cart           =  4,524
--   desktop_at_shipping       =  3,134
--   desktop_at_billing        =  2,577
--   desktop_at_thankyou       =  1,409
--   desktop rates:
--     lander → products       = 51.6%
--     products → detail       = 75.9%
--     detail → cart           = 43.9%
--     cart → shipping         = 69.3%
--     shipping → billing      = 82.2%
--     billing → thankyou      = 54.7%
--
--   mobile_at_lander          =  8,453
--   mobile_at_products        =  2,881
--   mobile_at_product_detail  =  1,766
--   mobile_at_cart            =    718
--   mobile_at_shipping        =    454
--   mobile_at_billing         =    325
--   mobile_at_thankyou        =    133
--   mobile rates:
--     lander → products       = 34.1%   ← BIGGEST MOBILE DROP-OFF
--     products → detail       = 61.3%
--     detail → cart           = 40.7%
--     cart → shipping         = 63.2%
--     shipping → billing      = 71.6%
--     billing → thankyou      = 40.9%
--
-- BIGGEST MOBILE DROP-OFF: lander → products at 34.1% vs 51.6% desktop
--   (-17.5pp gap). Mobile visitors are bouncing from the landing page
--   itself before they even reach the product catalogue. Every step
--   also underperforms but the damage starts immediately at entry.
-- C04 context: mobile converts at 39% the rate of desktop overall (3.18%
--   vs 8.21%). This query confirms the gap opens at the very first step.


-- ============================================================
-- Query 4: Revenue Opportunity at the Biggest Leak
-- Author: Zeina | Reviewed: Saleh Hossam
-- Date: 2026-03-22
-- What it answers: if the detail-to-cart step improved by 10pp,
--   how much extra revenue would that generate every month?
-- All inputs come from Q1b results and C03 confirmed AOV.
-- No table reads needed — this is a calculation query.
-- ============================================================
-- Biggest leak confirmed from Q1b: product detail → cart at 43.4%
-- Every other step is 68%+. This one step loses more than half
-- the visitors who actually looked at a product.
--
-- Inputs:
--   Sessions at product detail (Q1a):  12,079
--   Window: Aug 5 2012 – Mar 19 2015 = 31.5 months
--   Avg monthly sessions at detail:    12,079 / 31.5 = 383.5
--   Current CTR at detail → cart:      43.4% (Q1b confirmed)
--   AOV used:                          $63.79 (C03 Q4 2014 confirmed)
-- ============================================================

SELECT
    383.5                               AS avg_monthly_sessions_at_detail,
    43.4                                AS current_detail_to_cart_pct,
    53.4                                AS improved_detail_to_cart_pct,
    ROUND(383.5 * 0.10, 0)              AS additional_orders_per_month,
    ROUND(383.5 * 0.10 * 63.79, 2)      AS additional_revenue_per_month;

-- Result (confirmed 2026-03-22):
--   avg_monthly_sessions_at_detail  = 383.5
--   current_detail_to_cart_pct      = 43.4%
--   improved_detail_to_cart_pct     = 53.4%
--   additional_orders_per_month     = 38
--   additional_revenue_per_month    = $2,446.35
--
-- Note: MySQL evaluates 383.5 * 0.10 * 63.79 in one pass without
--   rounding the middle step (38.35 orders, not 38), so the result
--   is $2,446.35 not $2,423.62. The unrounded figure is more accurate.
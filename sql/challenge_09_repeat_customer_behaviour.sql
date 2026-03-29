-- ============================================================
-- Challenge 09: Repeat Customer Behaviour
-- Author: Omar | Reviewed & Finalized by: Saleh
-- Date: 2026-03-22
-- Scope: 2014 full year (2014-01-01 to 2014-12-31)
--
-- C01 FIXES APPLIED:
--   LOWER(TRIM()) on utm_source, utm_campaign
--   COALESCE(TRIM(http_referer),'') for organic vs direct
--   o.price_usd > 0 in JOIN ON — not in WHERE (Q4, Q5)
--   Socialbook excluded from all channel logic (Q3, Q4, Q5)
--   No order_items touched — product_id != 99 not needed
--   No pageview_url filters — LOWER(pageview_url) not needed
--
-- NOTE ON USER COUNTS (Q1 vs Q5):
--   Q1 counts all 193,958 users — no channel filter applied,
--   which is correct since Q1 is a pure behaviour question.
--   Q5 counts 184,668 users after Socialbook exclusion.
--   The 9,290 gap = users whose only 2014 sessions were
--   Socialbook. Not a bug — consistent with C01 methodology.
--
-- QUERIES:
--   Q1 — User session bucket breakdown
--   Q2 — Days between first and second visit
--   Q3 — Channel mix: new vs repeat
--   Q4 — Conversion rate + revenue per session: new vs repeat
--   Q5 — Lifetime value estimate: single-visit vs returning users
--
-- ============================================================
-- KEY NUMBERS FOR SLIDE (all confirmed)
-- ============================================================
--
--   13.4%  of 2014 users came back for at least a second visit
--          (26,063 out of 193,958 users)
--
--   32.5   average days between first and second session
--          (min: 1 day | max: 69 days)
--
--   66.8%  of repeat sessions came through free channels
--          (organic + direct) — the company is NOT paying
--          to bring these customers back
--
--   0%     of repeat sessions came through paid nonbrand search
--          Not approximately zero. Exactly zero.
--          Returning customers do not click nonbrand paid ads.
--
--   8.11%  repeat visitor conversion rate vs 7.25% new
--          (+0.86pp | +11.9% higher)
--
--   $5.15  repeat revenue per session vs $4.63 new
--          (+$0.52 | +11.2% higher)
--
--   2.67x  LTV multiple — a customer who comes back at least
--          once generates $12.42 vs $4.65 for a single-visit
--          user over their 2014 lifetime
--
-- BID STRATEGY IMPLICATION:
--   Repeat visitors come back for free (Q3: 66.8% organic+direct,
--   0% paid nonbrand), convert better than new visitors (Q4),
--   and generate 2.67x more revenue per user (Q5).
--   There is no case for bidding on nonbrand paid search to
--   recapture existing customers — they were never using it.
--   Recommendation: hold or reduce brand keyword bids for
--   returning-customer segments and redeploy that spend toward
--   new customer acquisition on nonbrand.
-- ============================================================


-- ============================================================
-- Query 1: User Repeat Visit Breakdown (2014)
-- Buckets every user by how many sessions they had in 2014.
-- Output: 4 rows.
-- No C01 fixes needed — no utm fields, no joins, no pageviews.
-- ============================================================

WITH user_session_counts AS (
    SELECT
        user_id,
        COUNT(DISTINCT website_session_id) AS total_sessions
    FROM website_sessions
    WHERE created_at >= '2014-01-01'
      AND created_at <  '2015-01-01'
    GROUP BY user_id
)
SELECT
    CASE
        WHEN total_sessions = 1  THEN '1 session'
        WHEN total_sessions = 2  THEN '2 sessions'
        WHEN total_sessions = 3  THEN '3 sessions'
        WHEN total_sessions >= 4 THEN '4+ sessions'
    END                         AS session_bucket,
    COUNT(DISTINCT user_id)     AS user_count
FROM user_session_counts
GROUP BY session_bucket
ORDER BY MIN(total_sessions);

-- Results:
--   1 session:   167,895 users  (86.6%)
--   2 sessions:   18,865 users
--   3 sessions:      995 users
--   4+ sessions:   6,203 users
--   ─────────────────────────────
--   Total:        193,958 users
--
-- SLIDE NUMBER:
--   Repeat users = 18,865 + 995 + 6,203 = 26,063
--   Repeat rate  = 26,063 / 193,958 = 13.4%
--   → 1 in 7.4 users came back at least once in 2014


-- ============================================================
-- Query 2: Days Between First and Second Visit (2014)
-- ROW_NUMBER ranks each user's sessions by date. We pull
-- rank 1 and rank 2, then DATEDIFF the gap.
-- Output: 1 row — min, max, avg days to return.
--
-- Scope note: the filter starts at 2014-01-01, so any user
-- who first visited in 2013 gets their 2014 sessions renumbered
-- from rank 1. This is intentional — the brief says 2014 YTD.
--
-- No C01 fixes needed here.
-- ============================================================

WITH ranked_sessions AS (
    SELECT
        user_id,
        website_session_id,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY created_at
        ) AS session_rank
    FROM website_sessions
    WHERE created_at >= '2014-01-01'
      AND created_at <  '2015-01-01'
),
first_sessions AS (
    SELECT user_id, created_at AS first_visit
    FROM ranked_sessions
    WHERE session_rank = 1
),
second_sessions AS (
    SELECT user_id, created_at AS second_visit
    FROM ranked_sessions
    WHERE session_rank = 2
)
SELECT
    MIN(DATEDIFF(s.second_visit, f.first_visit))           AS min_days_to_return,
    MAX(DATEDIFF(s.second_visit, f.first_visit))           AS max_days_to_return,
    ROUND(AVG(DATEDIFF(s.second_visit, f.first_visit)), 1) AS avg_days_to_return
-- INNER JOIN is correct — we only want users who actually came back.
-- Anyone with just one session has no row in second_sessions and drops out.
FROM first_sessions f
JOIN second_sessions s
    ON f.user_id = s.user_id;

-- Results:
--   min_days_to_return =  1 day
--   max_days_to_return = 69 days
--   avg_days_to_return = 32.5 days
--
-- SLIDE NOTE:
--   Average of 32.5 days — just over a month between first and
--   second visit. Not a daily-habit product, but not pure seasonal
--   gifting either. The max of 69 days means even the slowest
--   returners came back within a quarter. No one waited a full year.


-- ============================================================
-- Query 3: Channel Mix — New vs Repeat Sessions (2014)
-- Shows which channels new and repeat visitors arrive through.
-- The key question: are we bidding on paid search to bring back
-- people who would have come back anyway for free?
-- Output: 2 rows — New and Repeat.
--
-- C01 FIXES APPLIED:
--   LOWER(TRIM()) on utm_source and utm_campaign throughout
--   COALESCE(TRIM(http_referer),'') for organic vs direct
--   Socialbook excluded in WHERE — not counted anywhere.
--   (Previous version had utm_source != '' in WHERE, which
--    accidentally let Socialbook through into total_sessions
--    because 'socialbook' != '' evaluates TRUE. Fixed below.)
-- ============================================================

SELECT
    CASE
        WHEN is_repeat_session = 0 THEN 'New'
        WHEN is_repeat_session = 1 THEN 'Repeat'
    END                                        AS session_type,

    COUNT(DISTINCT CASE
        WHEN LOWER(TRIM(utm_source))   = 'gsearch'
         AND LOWER(TRIM(utm_campaign)) = 'nonbrand'
        THEN website_session_id END)            AS gsearch_nonbrand,

    COUNT(DISTINCT CASE
        WHEN LOWER(TRIM(utm_source))   = 'bsearch'
         AND LOWER(TRIM(utm_campaign)) = 'nonbrand'
        THEN website_session_id END)            AS bsearch_nonbrand,

    COUNT(DISTINCT CASE
        WHEN LOWER(TRIM(utm_campaign)) = 'brand'
        THEN website_session_id END)            AS paid_brand,

    COUNT(DISTINCT CASE
        WHEN utm_source IS NULL
         AND COALESCE(TRIM(http_referer), '') != ''
        THEN website_session_id END)            AS organic,

    COUNT(DISTINCT CASE
        WHEN utm_source IS NULL
         AND COALESCE(TRIM(http_referer), '') = ''
        THEN website_session_id END)            AS direct,

    COUNT(DISTINCT website_session_id)          AS total_sessions

FROM website_sessions
WHERE created_at >= '2014-01-01'
  AND created_at <  '2015-01-01'
  AND (
        utm_source IS NULL                           -- keep organic + direct
        OR LOWER(TRIM(utm_source)) != 'socialbook'  -- exclude Socialbook
      )

GROUP BY is_repeat_session
ORDER BY is_repeat_session;

-- Results (channel sums verified — both rows add up to total exactly):
--
--   session_type  gsearch_nb  bsearch_nb  paid_brand  organic  direct  total
--   New           129,154     25,367       8,679       9,231   8,366   180,797
--   Repeat              0          0      13,928      14,501  13,511    41,940
--
-- SLIDE CALCULATIONS:
--   Repeat free (organic + direct): 14,501 + 13,511 = 28,012 = 66.8% of repeat
--   Repeat paid brand:              13,928                    = 33.2% of repeat
--   Repeat paid nonbrand:                0                    =  0.0% of repeat
--
--   Not a rounding artifact — the paid nonbrand count for repeat is exactly 0.
--   Returning customers do not come back through generic paid search at all.
--   They come back through brand, organic, or direct — all of which either
--   cost nothing or are brand-keyword bids that could be reduced.


-- ============================================================
-- Query 4: Conversion Rate & Revenue Per Session — New vs Repeat (2014)
-- Compares purchase behaviour between first-time and returning visitors.
-- Output: 2 rows — New and Repeat.
--
-- C01 FIXES APPLIED:
--   o.price_usd > 0 in JOIN ON — not in WHERE.
--     Putting it in WHERE silently turns the LEFT JOIN into an
--     INNER JOIN and drops non-converting sessions from the
--     denominator, inflating conversion rates.
--   Socialbook excluded from WHERE
--   LOWER(TRIM()) on ws.utm_source
-- ============================================================

SELECT
    CASE
        WHEN ws.is_repeat_session = 0 THEN 'New'
        WHEN ws.is_repeat_session = 1 THEN 'Repeat'
    END                                             AS session_type,
    COUNT(DISTINCT ws.website_session_id)           AS sessions,
    COUNT(DISTINCT o.order_id)                      AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100
    , 2)                                            AS conv_rate_pct,
    ROUND(
        SUM(o.price_usd)
        / COUNT(DISTINCT ws.website_session_id)
    , 2)                                            AS rev_per_session_usd

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0         -- C01 fix: in ON not WHERE

WHERE ws.created_at >= '2014-01-01'
  AND ws.created_at <  '2015-01-01'
  AND (
        ws.utm_source IS NULL                           -- keep organic + direct
        OR LOWER(TRIM(ws.utm_source)) != 'socialbook'  -- exclude Socialbook
      )

GROUP BY ws.is_repeat_session
ORDER BY ws.is_repeat_session;

-- Results (session counts match Q3 totals exactly — cross-check confirmed ✅):
--
--   session_type  sessions  orders  conv_rate_pct  rev_per_session_usd
--   New           180,797   13,114       7.25%             $4.63
--   Repeat         41,940    3,403       8.11%             $5.15
--
-- SLIDE CALCULATIONS:
--   Conv rate lift:      8.11% - 7.25% = +0.86pp  (+11.9% relative)
--   Rev/session lift:   $5.15 - $4.63  = +$0.52   (+11.2% relative)
--
--   Repeat visitors convert better and generate more per session —
--   but the bigger story is Q3: they come back without any paid
--   nonbrand spend at all. The conversion premium is a bonus on
--   traffic the company is already getting for free.


-- ============================================================
-- Query 5: Lifetime Value Estimate — Single-Visit vs Returning Users (2014)
-- Required by the brief slide deliverable: "revised customer
-- lifetime value estimate."
--
-- Standard session-level analysis treats every visit as a separate
-- customer. This query groups by actual user and sums all their
-- revenue across all 2014 sessions — giving a true per-user LTV
-- figure. The gap between single-visit and returning users is the
-- number that justifies how much to spend acquiring a new customer.
--
-- Output: 2 rows — single-visit users vs users who returned.
--
-- C01 FIXES APPLIED:
--   o.price_usd > 0 in JOIN ON — not in WHERE
--   Socialbook excluded from WHERE
--   LOWER(TRIM()) on ws.utm_source
-- ============================================================

WITH user_totals AS (
    SELECT
        ws.user_id,
        COUNT(DISTINCT ws.website_session_id)  AS total_sessions,
        COUNT(DISTINCT o.order_id)             AS total_orders,
        COALESCE(SUM(o.price_usd), 0)          AS total_revenue
    FROM website_sessions ws
    LEFT JOIN orders o
        ON  ws.website_session_id = o.website_session_id
        AND o.price_usd > 0         -- C01 fix: in ON not WHERE
    WHERE ws.created_at >= '2014-01-01'
      AND ws.created_at <  '2015-01-01'
      AND (
            ws.utm_source IS NULL
            OR LOWER(TRIM(ws.utm_source)) != 'socialbook'
          )
    GROUP BY ws.user_id
)
SELECT
    CASE
        WHEN total_sessions = 1 THEN 'Single visit'
        ELSE 'Returned at least once'
    END                                     AS user_type,
    COUNT(DISTINCT user_id)                 AS users,
    ROUND(AVG(total_sessions), 1)           AS avg_sessions_per_user,
    ROUND(AVG(total_orders),   2)           AS avg_orders_per_user,
    ROUND(AVG(total_revenue),  2)           AS avg_revenue_per_user
FROM user_totals
GROUP BY user_type
ORDER BY user_type DESC;    -- 'Single visit' last, 'Returned' first

-- Results:
--
--   user_type               users    avg_sessions  avg_orders  avg_revenue
--   Returned at least once  25,052        2.5          0.19       $12.42
--   Single visit           159,616        1.0          0.07        $4.65
--
-- Note: Q5 total = 184,668 users vs Q1 total = 193,958 users.
--   Difference of 9,290 = users whose only 2014 sessions were
--   Socialbook, which Q5 excludes per C01. Not a bug.
--   Q1 intentionally has no channel filter — it is a pure
--   user behaviour count. Q5 applies C01 consistently.
--
-- SLIDE NUMBER:
--   LTV multiple = $12.42 / $4.65 = 2.67x
--
--   A customer who came back at least once generated 2.67x more
--   revenue over 2014 than a customer who only visited once.
--   This changes the acquisition conversation: if even a fraction
--   of new customers return, the true value of acquiring them is
--   meaningfully higher than a single-session analysis suggests.
--   The implied max CAC for a potentially returning customer is
--   2.67x higher than what a one-visit LTV would justify.
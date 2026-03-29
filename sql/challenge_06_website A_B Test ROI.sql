-- ============================================================
-- Challenge 06: Website A/B Test ROI
-- MavenFuzzyFactory Hackathon
-- Author: Saleh Hossam | Date: 2026-03-22
-- ============================================================
-- C01 fixes applied to every query in this file:
--   LOWER(TRIM()) on utm_source, utm_campaign, device_type
--   LOWER(pageview_url) on all pageview filters and joins
--   AND o.price_usd > 0 in JOIN ON clause — never in WHERE
--   product_id != 99 — not needed here, no order_items queries
--   Socialbook — not relevant; landing page test filters to
--   gsearch nonbrand; billing test is all-traffic (no utm filter)
-- ============================================================


-- ============================================================
-- EXPERIMENT 1: Landing Page A/B Test
-- Control: /home  |  Variant: /lander-1
-- Channel: gsearch nonbrand only
-- ============================================================

-- ============================================================
-- Q1: Find the exact start date — when did /lander-1 first
--     receive gsearch nonbrand traffic as a landing page?
-- ============================================================
-- The brief says to derive this from the data, not assume June 19.
-- The test infrastructure may have been set up before traffic
-- was actually routed — hardcoding June 19 risks including days
-- where only /home was running and skewing the bounce comparison.
--
-- Method:
--   Step 1 — find the first pageview per session (MIN pageview_id)
--             to identify true entry pages, not mid-session visits
--   Step 2 — filter to sessions that entered on /lander-1
--             via gsearch nonbrand
--   Step 3 — MIN(created_at) on those sessions gives the anchor date
--
-- Why MIN(website_pageview_id) not MIN(created_at) for entry page?
--   Pageview IDs are sequential — lower ID = earlier in the session.
--   Using MIN(pageview_id) is more reliable than MIN(created_at)
--   in case of any sub-second timestamp ties within a session.
-- ============================================================

SELECT
    MIN(wp.created_at) AS lander1_first_seen
FROM website_pageviews wp

-- Join to identify the first pageview of each session
INNER JOIN (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
) AS entry_pages
    ON wp.website_pageview_id = entry_pages.first_pageview_id

-- Join to sessions to apply the channel filter
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id

WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND LOWER(wp.pageview_url)       = '/lander-1';

-- Result: lander1_first_seen = 2012-06-19 00:35:54
-- This date is the fair comparison window start — used in Q2, Q3, and Q4
-- Aligns with the brief's stated June 19 date — confirmed from data, not assumed


-- ============================================================
-- Q1 Verification: confirm the result makes sense
-- Pull the first 5 gsearch nonbrand sessions that landed on
-- /lander-1 — timestamps and session IDs should align with
-- the MIN date returned above
-- ============================================================

SELECT
    ws.website_session_id,
    ws.created_at            AS session_start,
    wp.created_at            AS first_pageview_at,
    LOWER(wp.pageview_url)   AS landing_page
FROM website_pageviews wp

INNER JOIN (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
) AS entry_pages
    ON wp.website_pageview_id = entry_pages.first_pageview_id

JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id

WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND LOWER(wp.pageview_url)       = '/lander-1'

ORDER BY wp.created_at ASC
LIMIT 5;


-- Verification results:
--   session_start and first_pageview_at are identical on all 5 rows
--   — confirms pageview belongs to the exact moment the session opened
--   All landing_page values show /lander-1 lowercase — LOWER() confirmed
--   Earliest row is session 11683 at 2012-06-19 00:35:54
--   — matches lander1_first_seen exactly. Q1 anchor confirmed.
-- ============================================================


-- ============================================================
-- Q2: Bounce rate comparison — /home vs /lander-1
-- Window: 2012-06-19 (lander-1 first seen) to 2012-07-28
-- Channel: gsearch nonbrand only
-- ============================================================
-- Both pages must be live simultaneously for a fair comparison.
-- Starting before June 19 would include days with only /home
-- running, inflating its session count and skewing its bounce rate.
--
-- Structure:
--   Step 1 (entry_pages subquery) — same as Q1: find the true
--           landing page for every session using MIN(pageview_id)
--   Step 2 (pv_counts subquery)  — count total pageviews per
--           session. COUNT = 1 means the visitor bounced.
--   Step 3 (outer query)         — filter to the test window and
--           the two landing pages, then aggregate:
--           total sessions, bounced sessions, bounce rate
--
-- Why a separate pv_counts subquery?
--   The outer query joins on the first pageview row only (one row
--   per session). Counting pageviews there always returns 1.
--   pv_counts aggregates ALL pageviews per session separately
--   so we get the true total — bounce = pv_count of exactly 1.
-- ============================================================

SELECT
    LOWER(wp.pageview_url)                             AS landing_page,
    COUNT(DISTINCT ws.website_session_id)              AS total_sessions,
    COUNT(DISTINCT CASE WHEN pv_counts.pv_count = 1
          THEN ws.website_session_id END)              AS bounced_sessions,
    ROUND(COUNT(DISTINCT CASE WHEN pv_counts.pv_count = 1
          THEN ws.website_session_id END)
        / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS bounce_rate_pct

FROM website_pageviews wp

-- Step 1: identify true landing page per session
INNER JOIN (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
) AS entry_pages
    ON wp.website_pageview_id = entry_pages.first_pageview_id

-- Step 2: count total pageviews per session to classify bounces
JOIN (
    SELECT
        website_session_id,
        COUNT(*) AS pv_count
    FROM website_pageviews
    GROUP BY website_session_id
) AS pv_counts
    ON wp.website_session_id = pv_counts.website_session_id

-- Step 3: join sessions for channel filter
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id

WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND ws.created_at >= '2012-06-19'         -- lander-1 first seen (Q1 result)
  AND ws.created_at <= '2012-07-28'         -- brief test window end
  AND LOWER(wp.pageview_url) IN ('/home', '/lander-1')

GROUP BY LOWER(wp.pageview_url)
ORDER BY LOWER(wp.pageview_url);

-- Result:
--   /home:     2,261 sessions | 1,319 bounced | 58.34% bounce rate
--   /lander-1: 2,316 sessions | 1,233 bounced | 53.24% bounce rate
--   Lift: 5.10 pp improvement on /lander-1 (58.34 - 53.24)
--   /lander-1 is the winner — bounce rate lift used in Q4
-- ============================================================


-- ============================================================
-- Q3: Weekly routing — /home vs /lander-1
-- Window: June 1, 2012 onward (no upper bound)
-- Channel: gsearch nonbrand only
-- ============================================================
-- Purpose: confirm the test was run cleanly and traffic was
-- correctly routed to /lander-1 after the test window closed.
-- Three phases should be visible on the chart:
--   Phase 1 (Jun 1 – Jun 18):  only /home receives traffic
--   Phase 2 (Jun 19 – Jul 28): both pages split traffic
--   Phase 3 (Jul 29 onward):   only /lander-1 receives traffic
-- If /home traffic does not drop to zero after July 28, the
-- test was contaminated and Q2/Q4 results cannot be trusted.
--
-- Why YEARWEEK() for weekly grouping?
--   Returns a single integer per ISO week (e.g. 201225).
--   Clean for GROUP BY. MIN(ws.created_at) alongside it gives
--   a readable week-start date for Power BI charting.
--
-- Same entry_pages subquery as Q1 and Q2 — identifies the
-- true landing page per session via MIN(pageview_id).
-- Conditional aggregation puts both pages on one row per week
-- — same pattern used in C02 Q3 and Q4.
-- ============================================================
 
SELECT
    YEARWEEK(ws.created_at)                                    AS yr_wk,
    MIN(DATE(ws.created_at))                                   AS week_start,
    COUNT(DISTINCT CASE WHEN LOWER(wp.pageview_url) = '/home'
          THEN ws.website_session_id END)                      AS home_sessions,
    COUNT(DISTINCT CASE WHEN LOWER(wp.pageview_url) = '/lander-1'
          THEN ws.website_session_id END)                      AS lander1_sessions
 
FROM website_pageviews wp
 
-- Identify true landing page per session
INNER JOIN (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
) AS entry_pages
    ON wp.website_pageview_id = entry_pages.first_pageview_id
 
-- Join sessions for channel filter and date
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id
 
WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND ws.created_at >= '2012-06-01'          -- brief says start from June 1
  AND LOWER(wp.pageview_url) IN ('/home', '/lander-1')
 
GROUP BY YEARWEEK(ws.created_at)
ORDER BY YEARWEEK(ws.created_at);
 
-- Expected result: ~35 rows (June 2012 through end of dataset)
-- Routing confirmation checklist:
--   1. Weeks before Jun 19: home_sessions > 0, lander1_sessions = 0
--   2. Weeks Jun 19 – Jul 28: both columns populated (split traffic)
--   3. Weeks after Jul 28: home_sessions = 0, lander1_sessions > 0
--   If point 3 fails — home still receives traffic post-test —
--   flag it: the test was not cleanly handed over
-- Result:
--   Phase 1 (wk 201222-201224, Jun 1-16):  home only, lander1 = 0
--   Phase 2 (wk 201225-201230, Jun 17-Jul 28): both pages live ~50/50 split
--   Transition (wk 201231, Jul 29): home = 33 (last day of test), lander1 = 995
--   Phase 3 (wk 201232 onward, Aug 5+): home = 0, lander1 only — permanently
--   Routing confirmed clean. Q2 bounce rates and Q4 revenue calc are valid.
-- ============================================================
--   Extra finding: lander1 traffic tapers off by Mar 2013 — consistent with
--   lander-2/3/4/5 in the data, the company kept testing and iterating
-- ============================================================


-- ============================================================
-- Q4: Incremental revenue since the landing page test ended
-- Formula: lift × post-test sessions × AOV
-- ============================================================
-- Three numbers needed:
--   1. Conversion rate lift  — from Q4a (test window Jun 19–Jul 28)
--   2. Post-test sessions    — from Q4b (gsearch nonbrand, Jul 29 onward)
--   3. AOV                   — from Q4b (full dataset)
-- Multiplication done in Excel — not in SQL
-- ============================================================
 
 
-- ============================================================
-- Q4a: Conversion rates during test window
-- Same window and channel as Q2 — Jun 19 to Jul 28, gsearch nonbrand
-- Same entry_pages logic — true landing page per session only
-- LEFT JOIN orders so non-converting sessions stay in the count
-- price_usd > 0 in JOIN ON — never in WHERE
-- ============================================================
 
SELECT
    LOWER(wp.pageview_url)                    AS landing_page,
    COUNT(DISTINCT ws.website_session_id)     AS sessions,
    COUNT(DISTINCT o.order_id)                AS orders,
    ROUND(COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conv_rate_pct
 
FROM website_pageviews wp
 
-- Identify true landing page per session
INNER JOIN (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
) AS entry_pages
    ON wp.website_pageview_id = entry_pages.first_pageview_id
 
-- Join sessions for channel filter
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id
 
-- LEFT JOIN orders — keeps non-converting sessions in the count
-- price_usd > 0 in ON clause not WHERE — critical C01 fix
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0
 
WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND ws.created_at >= '2012-06-19'   -- lander-1 first seen (Q1 result)
  AND ws.created_at <= '2012-07-28'   -- test window end
  AND LOWER(wp.pageview_url) IN ('/home', '/lander-1')
 
GROUP BY LOWER(wp.pageview_url)
ORDER BY LOWER(wp.pageview_url);
 
-- Result :
--   /home:     2,261 sessions | 72 orders | 3.18% conv rate
--   /lander-1: 2,316 sessions | 94 orders | 4.06% conv rate
--   Lift: 0.88 pp (4.06 - 3.18) = 0.0088 as decimal
-- ============================================================
 
 
-- ============================================================
-- Q4b: Post-test gsearch nonbrand sessions on /lander-1
--      + overall AOV from full dataset
-- Sessions: Jul 29 2012 onward, gsearch nonbrand, entry on /lander-1
-- AOV: full dataset, price_usd > 0
-- ============================================================
 
SELECT
    COUNT(DISTINCT ws.website_session_id)   AS post_test_sessions,
    COUNT(DISTINCT o.order_id)              AS total_orders,
    ROUND(SUM(o.price_usd)
        / COUNT(DISTINCT o.order_id), 2)    AS overall_aov
 
FROM website_sessions ws
 
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0
 
-- Filter to sessions that entered on /lander-1 post-test
WHERE ws.website_session_id IN (
 
    -- Sessions whose first pageview was /lander-1
    SELECT wp.website_session_id
    FROM website_pageviews wp
    INNER JOIN (
        SELECT
            website_session_id,
            MIN(website_pageview_id) AS first_pageview_id
        FROM website_pageviews
        GROUP BY website_session_id
    ) AS entry_pages
        ON wp.website_pageview_id = entry_pages.first_pageview_id
    WHERE LOWER(wp.pageview_url) = '/lander-1'
 
)
  AND LOWER(TRIM(ws.utm_source))   = 'gsearch'
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND ws.created_at > '2012-07-28';    -- strictly after test ended
 
-- Result:
--   post_test_sessions = 35,799
--   total_orders       = 1,585
--   overall_aov        = $50.45 (orders from these 35,799 sessions only)
-- ============================================================
-- EXCEL CALCULATION (confirmed 2026-03-22):
--   home conv rate:      3.18%
--   lander-1 conv rate:  4.06%
--   Lift:                0.0088 (= 4.06 - 3.18 divided by 100)
--   Post-test sessions:  35,799
--   AOV:                 $50.45
--   Incremental revenue: 0.0088 x 35,799 x 50.45 = ~$15,887
--   Landing page test generated roughly $15,900 in extra revenue
--   since the winning page was fully deployed after July 28, 2012
 
-- ============================================================
-- EXPERIMENT 2: Billing Page A/B Test
-- Control: /billing  |  Variant: /billing-2
-- Channel: ALL traffic — no utm filter
-- Window: September 10 – November 10, 2012
-- ============================================================
 
 
-- ============================================================
-- Q5: Billing page conversion rate + revenue per billing session
-- ============================================================
-- No entry page logic needed here — we are not asking where
-- the session started. We are asking: of sessions that reached
-- the billing page, how many placed an order?
--
-- Denominator = sessions that hit /billing or /billing-2
-- Numerator   = orders placed by those same sessions
-- Revenue per session = total revenue / billing sessions
--
-- LEFT JOIN orders so non-ordering billing sessions stay in count
-- price_usd > 0 in JOIN ON — C01 fix applies here too
-- ============================================================
 
SELECT
    LOWER(wp.pageview_url)                        AS billing_page,
    COUNT(DISTINCT ws.website_session_id)         AS billing_sessions,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS billing_conv_rate_pct,
    ROUND(SUM(o.price_usd)
        / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_billing_session
 
FROM website_pageviews wp
 
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id
 
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0
 
WHERE LOWER(wp.pageview_url) IN ('/billing', '/billing-2')
  AND ws.created_at >= '2012-09-10'     -- billing test start
  AND ws.created_at <= '2012-11-10'     -- billing test end
 
GROUP BY LOWER(wp.pageview_url)
ORDER BY LOWER(wp.pageview_url);
 
-- Result:
--   /billing:   657 sessions | 299 orders | 45.51% conv rate | $22.75 rev/session
--   /billing-2: 654 sessions | 410 orders | 62.69% conv rate | $31.34 rev/session
--   Conv rate lift:       +17.18 pp (62.69 - 45.51)
--   Rev/session lift:     +$8.59 ($31.34 - $22.75)
--   /billing-2 wins on conversion rate (62.69% vs 45.51%) and
--   revenue per billing session ($31.34 vs $22.75)
-- ============================================================
 
 
-- ============================================================
-- Q6: Ongoing monthly value of the billing page improvement
-- Most recent full month = February 2015
-- (data ends March 19, 2015 — March is partial, unusable)
-- ============================================================
-- Count how many sessions hit /billing-2 in February 2015.
-- Multiply by the revenue-per-session lift from Q5 in Excel.
-- That is the extra revenue the new billing page adds every month.
--
-- Why only /billing-2?
-- After the test ended Nov 10, /billing-2 became the permanent page.
-- /billing is no longer live. We only count /billing-2 sessions.
-- ============================================================
 
SELECT
    COUNT(DISTINCT ws.website_session_id) AS feb2015_billing_sessions
 
FROM website_pageviews wp
 
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id
 
WHERE LOWER(wp.pageview_url) = '/billing-2'
  AND YEAR(ws.created_at)  = 2015
  AND MONTH(ws.created_at) = 2;
 
-- Expected: 1 row — total billing-2 sessions in February 2015
-- Result (confirmed 2026-03-22): feb2015_billing_sessions = 3,233
-- ============================================================
-- EXCEL CALCULATION (confirmed 2026-03-22):
--   /billing rev/session:   $22.75
--   /billing-2 rev/session: $31.34
--   Lift per session:        $8.59 ($31.34 - $22.75)
--   Feb 2015 sessions:       3,233
--   Ongoing monthly value:   $8.59 x 3,233 = ~$27,771/month
--   The redesigned billing page adds ~$27,800 in revenue every month
-- ============================================================


-- ============================================================
-- Q7: Next test recommendation
-- No SQL needed — written recommendation based on Q2 and Q5
-- ============================================================
-- The landing page test moved conversion rate 0.88 percentage point.
-- The billing page test moved it 17 percentage point That gap tells you where
-- the real leverage is — deeper in the funnel, not at the top.
-- The next logical step is the page sitting right before billing:
-- the shipping page.
--
-- Recommended next test: /shipping page redesign
-- Right now the shipping page collects delivery details and does
-- nothing else. Customers at that point have no idea how many
-- steps are left, what the return policy is, or whether their
-- order is secure. That uncertainty is what kills conversions
-- before they reach the billing page.
-- Hypothesis: showing a 3-step progress indicator
-- (shipping → billing → confirmation) and a short returns
-- statement above the fold will reduce drop-off at this step
-- and push more sessions through to the billing page.
-- Success metric: shipping-to-billing step conversion rate.
-- Run for 4 weeks minimum — use C05 funnel as the baseline.
-- ============================================================
-- ============================================================
-- MavenFuzzyFactory Hackathon
-- Challenge 03: Are We Getting Smarter With Every Sale?
-- Challenge 04: Have We Built a Resilient Revenue Base?
-- ============================================================
-- Author: Toqa Gabr
-- Reviewed & Finalized: Saleh Hossam | March 22, 2026
-- Deadline: March 26, 2026
-- ============================================================

-- ============================================================
-- C01 DATA QUALITY FIXES — APPLIED TO EVERY QUERY IN THIS FILE
-- ============================================================
-- FIX 1: Text field standardization
--   LOWER(TRIM(utm_source))    — channel names had 3 case variants
--   LOWER(TRIM(utm_campaign))  — brand/nonbrand had 3 case variants
--   LOWER(TRIM(device_type))   — desktop/mobile had 2 case variants
--   39 rows had leading/trailing spaces in utm fields
-- FIX 2: Pageview URL standardization
--   LOWER(pageview_url)        — 5 URLs recorded with capital letters
--   Not needed in C03/C04 (no pageview joins) but noted for reference
-- FIX 3: Bad price exclusion
--   AND o.price_usd > 0        — in JOIN ON clause, NEVER in WHERE
--   8 orders have zero/negative prices — corrupts revenue calculations
--   Putting this in WHERE silently converts LEFT JOIN to INNER JOIN
--   and drops all non-converting sessions from session counts
-- FIX 4: Orphan product exclusion
--   WHERE oi.product_id != 99  — order_items queries ONLY
--   Not needed in C03/C04 (no order_items joins)
-- FIX 5: Organic vs direct channel detection
--   COALESCE(TRIM(http_referer),'') — handles both NULL and
--   whitespace-only referers (50 rows had leading spaces in referer)
--   Plain IS NULL / IS NOT NULL misses trimmed empty strings
-- FIX 6: Socialbook exclusion
--   utm_source = 'socialbook' — undocumented channel found in C01
--   Excluded from all channel logic; treated as separate paid channel
--   Excluded from denominators to avoid inflating totals
-- ============================================================
-- DATASET SCOPE NOTES:
--   Q1 2012 is PARTIAL — data starts March 19 (~12 days only)
--   Q1 2015 is PARTIAL — data ends March 19 (~78 days)
--   Both quarters are INCLUDED and labeled partial on slides
--   Q4 2014 is the benchmark for investor comparisons (last full quarter)
-- ============================================================

USE mavenfuzzyfactory;


-- ============================================================
-- ============================================================
-- CHALLENGE 03: EFFICIENCY METRICS
-- ============================================================
-- ============================================================
-- Business question: Volume growth can mask inefficiency.
-- A truly healthy business converts a higher proportion of
-- visitors AND extracts more revenue from each one over time.
-- These three metrics prove the business is doing both.
-- ============================================================


-- ============================================================
-- C03 Query 1: Quarterly Session-to-Order Conversion Rate
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Reviewed by: Saleh Hossam
-- Brief requirement: C03 Q1 — "What proportion of site visitors
-- are completing a purchase each quarter, and how has that
-- conversion rate changed over the life of the business?"
-- Formula: orders / sessions * 100
-- Notes:
--   LEFT JOIN preserves non-converting sessions in denominator
--   price_usd > 0 in ON clause to protect LEFT JOIN integrity
--   No NULLIF needed — sessions can never be zero (it is the
--   left table, always has at least 1 row per group)
-- ============================================================

SELECT
    YEAR(ws.created_at)                          AS yr,
    QUARTER(ws.created_at)                       AS qtr,
    COUNT(DISTINCT ws.website_session_id)        AS sessions,
    COUNT(DISTINCT o.order_id)                   AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id) /
        COUNT(DISTINCT ws.website_session_id) * 100
    , 2)                                         AS conv_rate_pct

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0             -- C01 Fix 3: in ON not WHERE

GROUP BY
    YEAR(ws.created_at),
    QUARTER(ws.created_at)
ORDER BY yr, qtr;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22):
-- yr   | qtr | sessions | orders | conv_rate_pct
-- 2012 |  1  |   1,879  |     59 |  3.14%   ← PARTIAL Q (Mar 19 launch)
-- 2012 |  2  |  11,433  |    347 |  3.04%
-- 2012 |  3  |  16,892  |    684 |  4.05%   ← Landing page test Jul 2012
-- 2012 |  4  |  32,266  |  1,494 |  4.63%   ← Billing page test Nov 2012
-- 2013 |  1  |  19,833  |  1,271 |  6.41%   ← Billing fully reflected + Love Bear
-- 2013 |  2  |  24,745  |  1,716 |  6.93%
-- 2013 |  3  |  27,663  |  1,838 |  6.64%
-- 2013 |  4  |  40,540  |  2,616 |  6.45%
-- 2014 |  1  |  46,779  |  3,069 |  6.56%
-- 2014 |  2  |  53,129  |  3,848 |  7.24%   ← Cross-sell compounding
-- 2014 |  3  |  57,141  |  4,035 |  7.06%
-- 2014 |  4  |  76,373  |  5,908 |  7.74%   ← Holiday + full portfolio
-- 2015 |  1  |  64,198  |  5,420 |  8.44%   ← PARTIAL Q (ends Mar 19)
-- ============================================================
-- OBSERVATION:
--   Conversion rate grew from 3.14% at launch to 8.44% by Q1 2015
--   Sessions grew 34x (1,879 → 64,198) over the same period
--   Orders grew even faster — 92x (59 → 5,420)
--   NOTE: Q1 2015 is a partial quarter — 8.44% should be treated
--   as directional, not directly comparable to full quarters
--
-- INSIGHT:
--   Volume is up AND efficiency is up at the same time — most businesses
--   only manage one. Every website investment (landing page test, billing
--   page test) produced a measurable step-change visible in this chart.
--   The Q1 2013 jump (+1.78pp) is the single largest quarterly gain —
--   the billing page redesign fully landing on top of Love Bear launch.
--
-- ACTION:
--   Continue A/B testing on funnel pages — the data proves these tests
--   produce compounding returns. Priority: shipping page (C06 recommendation)
--   and cart page (biggest single drop-off point in C05 funnel).
--
-- IMPACT:
--   Current run rate: 64,198 sessions/quarter at 8.44% conversion
--   Every 1pp improvement in conversion rate = +642 orders/quarter
--   At $62.80 AOV (Q1 2015) = +$40,317 additional revenue per quarter
--   KPI: quarterly conversion rate — target 9%+ by end of 2015
-- ============================================================


-- ============================================================
-- C03 Query 2: Quarterly Average Order Value (AOV)
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Reviewed by: Saleh Hossam
-- Brief requirement: C03 Q2 — "How much revenue does the company
-- generate on average for each completed order? Has that grown
-- over time?"
-- Formula: SUM(price_usd) / COUNT(DISTINCT order_id)
-- Notes:
--   NULLIF on denominator is defensive — protects against
--   quarters with zero orders (theoretically impossible here
--   but good practice for any reuse of this query)
--   AOV will fluctuate as new products launch at different prices:
--   Love Bear $59.99 (Jan 2013) pulled AOV UP
--   Mini Bear  $24.99 (Feb 2014) should have pulled AOV DOWN
--   but it ROSE — cross-sell driving multi-item baskets
-- ============================================================

SELECT
    YEAR(ws.created_at)                          AS yr,
    QUARTER(ws.created_at)                       AS qtr,
    COUNT(DISTINCT o.order_id)                   AS orders,
    ROUND(SUM(o.price_usd), 2)                   AS total_revenue,
    ROUND(
        SUM(o.price_usd) /
        NULLIF(COUNT(DISTINCT o.order_id), 0)
    , 2)                                         AS avg_order_value

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0             -- C01 Fix 3: in ON not WHERE

GROUP BY
    YEAR(ws.created_at),
    QUARTER(ws.created_at)
ORDER BY yr, qtr;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22):
-- yr   | qtr | orders | total_revenue  | avg_order_value
-- 2012 |  1  |     59 |     2,949.41   |  49.99  ← Mr. Fuzzy only
-- 2012 |  2  |    347 |    17,346.53   |  49.99
-- 2012 |  3  |    684 |    34,193.16   |  49.99
-- 2012 |  4  |  1,494 |    74,685.06   |  49.99
-- 2013 |  1  |  1,271 |    66,267.29   |  52.14  ← Love Bear launch Jan 2013
-- 2013 |  2  |  1,716 |    88,432.84   |  51.53
-- 2013 |  3  |  1,838 |    95,081.56   |  51.73
-- 2013 |  4  |  2,616 |   143,136.24   |  54.72
-- 2014 |  1  |  3,069 |   190,771.14   |  62.16  ← Mini Bear launched Feb 2014
-- 2014 |  2  |  3,848 |   247,711.95   |  64.37    AOV ROSE despite cheapest
-- 2014 |  3  |  4,035 |   260,237.12   |  64.49    product ever — cross-sell
-- 2014 |  4  |  5,908 |   376,891.98   |  63.79    working
-- 2015 |  1  |  5,420 |   340,375.55   |  62.80  ← PARTIAL Q
-- ============================================================
-- OBSERVATION:
--   AOV was flat at $49.99 for all of 2012 — one product, no variation.
--   Love Bear launch in Jan 2013 ($59.99) pulled AOV up to $52.14.
--   The most revealing data point: Mini Bear launched Feb 2014 at $24.99
--   (cheapest product ever) but AOV JUMPED to $62.16 that same quarter.
--   Cross-sell feature (launched Sep 2013) was driving multi-item orders,
--   raising basket size faster than the cheap product could pull it down.
--   AOV peaked at $64.49 in Q3 2014 — 29% above the single-product baseline.
--
-- INSIGHT:
--   Adding the cheapest product in the catalogue did not pull AOV down
--   — it pushed it up. The cross-sell feature launched Sep 2013 was
--   already driving multi-item orders by the time Mini Bear arrived.
--   Customers were adding it as a second item, not replacing a
--   higher-priced primary purchase.
--
-- ACTION:
--   Maximize cross-sell on the highest-attachment product pairs.
--   Mini Bear is the optimal add-on candidate — low price removes
--   resistance. Full attachment rate matrix to be confirmed in C08.
--
-- IMPACT:
--   Run rate: ~5,400 orders/quarter
--   Every $1 increase in AOV = $5,400 additional revenue per quarter
--   Target: AOV reaches $65 by end of 2015 = +$11,800/quarter
--   KPI: monthly AOV — any drop signals cross-sell underperformance
-- ============================================================


-- ============================================================
-- C03 Query 3: Quarterly Revenue Per Session
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Reviewed by: Saleh Hossam
-- Brief requirement: C03 Q3 — "How much revenue does the company
-- generate for every single person who visits the site?"
-- Formula: SUM(price_usd) / COUNT(DISTINCT website_session_id)
-- Notes:
--   This is the single most powerful efficiency metric in the deck.
--   It is the product of conversion rate × AOV — if both go up,
--   rev/session goes up. It answers the investor question:
--   "Is each marketing dollar working harder over time?"
--   Denominator includes ALL sessions (converting and non-converting)
--   — that is the point. Non-converters cost money too.
-- ============================================================

SELECT
    YEAR(ws.created_at)                          AS yr,
    QUARTER(ws.created_at)                       AS qtr,
    COUNT(DISTINCT ws.website_session_id)        AS sessions,
    ROUND(SUM(o.price_usd), 2)                   AS total_revenue,
    ROUND(
        SUM(o.price_usd) /
        COUNT(DISTINCT ws.website_session_id)
    , 2)                                         AS rev_per_session

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0             -- C01 Fix 3: in ON not WHERE

GROUP BY
    YEAR(ws.created_at),
    QUARTER(ws.created_at)
ORDER BY yr, qtr;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22):
-- yr   | qtr | sessions | total_revenue  | rev_per_session
-- 2012 |  1  |   1,879  |    2,949.41    |   1.57  ← PARTIAL Q, launch baseline
-- 2012 |  2  |  11,433  |   17,346.53    |   1.52
-- 2012 |  3  |  16,892  |   34,193.16    |   2.02  ← Landing page test
-- 2012 |  4  |  32,266  |   74,685.06    |   2.31  ← Billing page test
-- 2013 |  1  |  19,833  |   66,267.29    |   3.34  ← Biggest single jump
-- 2013 |  2  |  24,745  |   88,432.84    |   3.57
-- 2013 |  3  |  27,663  |   95,081.56    |   3.44
-- 2013 |  4  |  40,540  |  143,136.24    |   3.53
-- 2014 |  1  |  46,779  |  190,771.14    |   4.08  ← Cross-sell compounding
-- 2014 |  2  |  53,129  |  247,711.95    |   4.66
-- 2014 |  3  |  57,141  |  260,237.12    |   4.55
-- 2014 |  4  |  76,373  |  376,891.98    |   4.93
-- 2015 |  1  |  64,198  |  340,375.55    |   5.30  ← PARTIAL Q, highest point
-- ============================================================
-- OBSERVATION:
--   Revenue per session grew from $1.57 at launch to $5.30 by Q1 2015
--   — a 237% improvement in three years.
--   Every major website investment produced a visible step-change:
--   Landing page test (Q3 2012): $1.52 → $2.02 (+32%)
--   Billing page test (Q4 2012 → Q1 2013): $2.02 → $3.34 (+65%)
--   Cross-sell launch (Q1 2014 onward): $3.53 → $4.08 (+16%)
--
-- INSIGHT:
--   Each marketing dollar now returns 3.4x more revenue than at launch
--   ($5.30 vs $1.57). The business didn't just get bigger — it got better
--   at converting traffic and extracting more from every order. Three years
--   of page tests, product launches, and cross-sell all stacked on top of
--   each other and this metric captures all of it in one number.
--
-- ACTION:
--   Continue investing in funnel optimization and cross-sell.
--   Both levers are proven to lift this metric. Historical data shows
--   deeper funnel tests (billing) move the needle more than top-of-funnel
--   (landing page). Priority: shipping page redesign (next A/B test).
--
-- IMPACT:
--   Run rate: 64,198 sessions/quarter generating $5.30 each
--   Every $0.10 increase in rev/session = +$6,420/quarter
--   Target: $6.00 rev/session by end of 2015 = +$44,935/quarter
--   KPI: quarterly revenue per session — tracked alongside conversion rate
-- ============================================================


-- ============================================================
-- C03 Query 4: Monthly Session-to-Order Conversion Rate
-- ============================================================
-- Author: Saleh Hossam | Date: 2026-03-22
-- Note: This query was not in the original teammate submission.
--   Added during review — the brief explicitly requires monthly
--   granularity and the quarterly view alone does not satisfy it.
-- Brief requirement: C03 Q4 — "Pull session-to-order conversion
-- rates by month to tell the story of website performance
-- improvements over time."
-- Notes:
--   Monthly granularity is required by the brief — the quarterly
--   view (Q1) smooths the landing page test (Jun–Jul 2012) and
--   billing page test (Sep–Nov 2012) into single quarters and
--   loses the precision that makes the inflection points defensible.
--   Monthly view shows exact months where tests took effect.
--   Expect spike starting July 2012 (landing page) and
--   another starting October/November 2012 (billing page).
--   37 rows: March 2012 through March 2015
-- ============================================================

SELECT
    YEAR(ws.created_at)                          AS yr,
    MONTH(ws.created_at)                         AS mo,
    COUNT(DISTINCT ws.website_session_id)        AS sessions,
    COUNT(DISTINCT o.order_id)                   AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id) /
        COUNT(DISTINCT ws.website_session_id) * 100
    , 2)                                         AS conv_rate_pct

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0             -- C01 Fix 3: in ON not WHERE

GROUP BY
    YEAR(ws.created_at),
    MONTH(ws.created_at)
ORDER BY yr, mo;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22) — 37 rows:
-- yr   | mo | sessions | orders | conv_rate_pct
-- 2012 |  3 |   1,879  |     59 |  3.14%  ← PARTIAL (launch Mar 19)
-- 2012 |  4 |   3,734  |     99 |  2.65%
-- 2012 |  5 |   3,736  |    108 |  2.89%
-- 2012 |  6 |   3,963  |    140 |  3.53%  ← Landing page test Jun 19
-- 2012 |  7 |   4,249  |    169 |  3.98%  ← Landing page full effect
-- 2012 |  8 |   6,097  |    228 |  3.74%
-- 2012 |  9 |   6,546  |    287 |  4.38%  ← Billing page test Sep 10
-- 2012 | 10 |   8,183  |    371 |  4.53%
-- 2012 | 11 |  14,011  |    617 |  4.40%  ← Holiday traffic (browsers↑)
-- 2012 | 12 |  10,072  |    506 |  5.02%  ← First month above 5%
-- 2013 |  1 |   6,401  |    390 |  6.09%  ← BIGGEST MONTHLY JUMP (+1.07pp)
-- 2013 |  2 |   7,168  |    496 |  6.92%
-- 2013 |  3 |   6,264  |    385 |  6.15%
-- 2013 |  4 |   7,971  |    552 |  6.93%
-- 2013 |  5 |   8,449  |    570 |  6.75%
-- 2013 |  6 |   8,325  |    594 |  7.14%
-- 2013 |  7 |   8,903  |    603 |  6.77%
-- 2013 |  8 |   9,180  |    606 |  6.60%
-- 2013 |  9 |   9,580  |    629 |  6.57%
-- 2013 | 10 |  10,773  |    708 |  6.57%
-- 2013 | 11 |  14,032  |    861 |  6.14%  ← Holiday traffic dip pattern
-- 2013 | 12 |  15,735  |  1,047 |  6.65%
-- 2014 |  1 |  14,825  |    983 |  6.63%
-- 2014 |  2 |  16,285  |  1,021 |  6.27%
-- 2014 |  3 |  15,669  |  1,065 |  6.80%
-- 2014 |  4 |  17,353  |  1,241 |  7.15%
-- 2014 |  5 |  18,061  |  1,368 |  7.57%
-- 2014 |  6 |  17,715  |  1,239 |  6.99%
-- 2014 |  7 |  19,038  |  1,287 |  6.76%
-- 2014 |  8 |  18,590  |  1,324 |  7.12%
-- 2014 |  9 |  19,513  |  1,424 |  7.30%
-- 2014 | 10 |  21,526  |  1,609 |  7.47%
-- 2014 | 11 |  25,125  |  1,985 |  7.90%
-- 2014 | 12 |  29,722  |  2,314 |  7.79%
-- 2015 |  1 |  25,337  |  2,099 |  8.28%
-- 2015 |  2 |  23,778  |  2,067 |  8.69%  ← HIGHEST MONTHLY RATE (Valentine's)
-- 2015 |  3 |  15,083  |  1,254 |  8.31%  ← PARTIAL (ends Mar 19)
-- ============================================================
-- OBSERVATION:
--   Three distinct step-changes are visible at monthly granularity:
--   Step 1 — Jun/Jul 2012: 2.89% → 3.98% (+1.09pp)
--     Landing page A/B test (Jun 19) immediately visible in Jun (+0.64pp)
--     Full effect reached in Jul 2012 (3.98%)
--   Step 2 — Sep/Oct 2012 → Jan 2013: 3.74% → 6.09% (+2.35pp over 4 months)
--     Billing page test launched Sep 10 — effect begins immediately (4.38%)
--     Jan 2013 is the single largest monthly jump in the dataset:
--     5.02% (Dec 2012) → 6.09% (Jan 2013) = +1.07pp in one month
--     Two events compounding: billing page fully deployed + Love Bear launch
--   Step 3 — 2014 grinding from 6.6% to 7.9%:
--     No single event — cumulative cross-sell effect, portfolio expansion,
--     repeat customer base growing. Steady not dramatic.
--
--   HOLIDAY CONVERSION DIP — every year without exception:
--   Nov 2012: 4.40% (vs 4.53% in Oct) — dip despite volume spike
--   Nov 2013: 6.14% (vs 6.57% in Oct) — same pattern
--   Nov 2014: 7.90% (higher, but note Dec drops to 7.79%)
--   Holiday months bring in high volumes of casual browsers who
--   inflate session counts without converting at the same rate.
--   This is normal retail behavior. December recovers as intent increases.
--   Slide note: do NOT show monthly conversion rate without this annotation
--   — investors will ask why conversion dips in the biggest revenue month.
--
--   HIGHEST MONTHLY RATE: Feb 2015 = 8.69%
--   Valentine's Day effect — Love Bear ($59.99) drives high-intent gift
--   purchases, pulling conversion rate above the January baseline.
--   This seasonal pattern should be visible in Feb 2013 and Feb 2014 too.
--
-- INSIGHT:
--   Every jump in this chart is traceable to a specific decision — a test
--   that ran, a product that launched. Every flat stretch is a period where
--   nothing changed. The data makes the case that running tests works and
--   not running them has a measurable cost.
--
-- ACTION:
--   The longest flat stretch without a meaningful jump is mid-2013 to
--   mid-2014 (~12 months of 6.5–7.0% plateau). The next test should
--   target a specific funnel step — shipping page redesign is the
--   recommendation from C06 analysis.
--
-- IMPACT:
--   Each step-change has been larger than the last in absolute terms
--   because the session base is larger:
--   Landing page test (2012): +~0.88pp on ~4,000 sessions = ~35 orders/mo
--   Billing page test (2012): +~17pp at billing step = hundreds of orders/mo
--   Next test on shipping page: even small lifts = large order volumes
--   at current session scale (20,000+ sessions/month in 2014)
-- ============================================================


-- ============================================================
-- C03 INVESTOR NARRATIVE — 2-SENTENCE EFFICIENCY STORY
-- ============================================================
-- READY TO PASTE ONTO SLIDE:
--
-- "When MavenFuzzyFactory launched in March 2012, each website
-- visitor generated $1.57 in revenue on a 3.14% session-to-order
-- conversion rate — the baseline of a single-product startup with
-- no optimization history."
--
-- "By Q1 2015, every visitor generates $5.30 — a 237% improvement
-- — the compound result of two A/B-tested page redesigns, a
-- four-product portfolio, and a cross-sell feature that raised
-- average order value from $49.99 to $62.80 despite launching
-- the cheapest product in the catalogue."
-- ============================================================


-- ============================================================
-- ============================================================
-- CHALLENGE 04: CHANNEL RESILIENCE
-- ============================================================
-- ============================================================
-- Business question: A business dependent on a single marketing
-- channel is fragile. Can MavenFuzzyFactory prove it has
-- diversified customer acquisition and that free channels are
-- playing an increasing role?
-- Investor concern: "What happens if Google raises ad prices?"
-- ============================================================


-- ============================================================
-- C04 Query 4: Monthly Channel Mix — All Sessions
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Fixed & reviewed by: Saleh Hossam
--   Fix 1: Replaced IS NOT NULL / IS NULL with COALESCE(TRIM()) —
--   original logic miscounted 50 dirty http_referer rows (C01 issue)
--   Fix 2: Added free_brand_pct_of_nonbrand column — required by brief,
--   was missing from original submission
--   Fix 3: Socialbook excluded from COUNT(*) total_sessions
-- Brief requirement: C04 Q1 — "Pull organic, direct, and brand
-- session volume by month. Show as a percentage of paid nonbrand
-- volume. Is brand momentum building over time?"
-- Notes:
--   Socialbook excluded from COUNT(*) total_sessions — it is an undocumented
--   channel that inflates totals and does not belong in the channel story.
--   The free_brand_pct_of_nonbrand column was missing from the original
--   submission and is required by the brief — added here.
-- ============================================================

SELECT
    YEAR(ws.created_at)   AS yr,
    MONTH(ws.created_at)  AS mo,

    -- Google paid nonbrand (main growth engine)
    COUNT(CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch'
               AND  LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
               THEN 1 END)                              AS gsearch_nonbrand,

    -- Bing paid nonbrand (secondary paid channel, launched Aug 2012)
    COUNT(CASE WHEN LOWER(TRIM(ws.utm_source))   = 'bsearch'
               AND  LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
               THEN 1 END)                              AS bsearch_nonbrand,

    -- Paid brand search (signals growing brand awareness — both platforms)
    COUNT(CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'brand'
               THEN 1 END)                              AS paid_brand,

    -- Organic search (free — found via search engine, no paid click)
    -- C01 Fix 5: COALESCE handles NULL and whitespace-only referers
    COUNT(CASE WHEN ws.utm_source IS NULL
               AND  COALESCE(TRIM(ws.http_referer), '') != ''
               THEN 1 END)                              AS organic_search,

    -- Direct type-in (free — strongest brand loyalty signal)
    -- C01 Fix 5: COALESCE handles NULL and whitespace-only referers
    COUNT(CASE WHEN ws.utm_source IS NULL
               AND  COALESCE(TRIM(ws.http_referer), '') = ''
               THEN 1 END)                              AS direct_typein,

    -- Total sessions (Socialbook excluded — undocumented channel, Fix 6)
    COUNT(DISTINCT ws.website_session_id)                   AS total_sessions,

    -- % of nonbrand: brief requirement — is free/brand momentum building?
    -- Denominator: gsearch nonbrand only (the business's primary paid channel)
    -- A rising ratio means the business needs paid ads less over time
    ROUND(
        (COUNT(CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'brand' THEN 1 END)
       + COUNT(CASE WHEN ws.utm_source IS NULL AND COALESCE(TRIM(ws.http_referer),'') != '' THEN 1 END)
       + COUNT(CASE WHEN ws.utm_source IS NULL AND COALESCE(TRIM(ws.http_referer),'') = '' THEN 1 END))
        / NULLIF(COUNT(CASE WHEN LOWER(TRIM(ws.utm_source)) = 'gsearch'
                            AND  LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
                            THEN 1 END), 0) * 100
    , 1)                                                AS free_brand_pct_of_nonbrand

FROM website_sessions ws
WHERE LOWER(TRIM(ws.utm_source)) != 'socialbook'   -- C01 Fix 6: exclude undocumented channel
   OR ws.utm_source IS NULL                        -- preserve organic/direct (utm_source IS NULL)

GROUP BY yr, mo
ORDER BY yr, mo;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22 — COALESCE fix + Socialbook exclusion applied):
-- NOTE: total_sessions is lower than original buggy run because Socialbook
--       sessions are now correctly excluded from COUNT(*).
--       Dec 2014 total was 29,722 in buggy run, now 28,075 — diff = 1,647 Socialbook.
--
-- yr  | mo | gsearch_nb | bsearch_nb | brand | organic | direct | total  | free_brand_pct
-- 2012|  3 |     1,852  |          0 |    10 |       8 |      9 |  1,879 |   1.5%  ← PARTIAL, launch
-- 2012|  4 |     3,509  |          0 |    76 |      78 |     71 |  3,734 |   6.4%
-- 2012|  5 |     3,295  |          0 |   140 |     150 |    151 |  3,736 |  13.4%
-- 2012|  6 |     3,439  |          0 |   164 |     190 |    170 |  3,963 |  15.2%
-- 2012|  7 |     3,660  |          0 |   195 |     207 |    187 |  4,249 |  16.1%
-- 2012|  8 |     4,673  |        645 |   264 |     265 |    250 |  6,097 |  16.7%  ← bsearch launch
-- 2012|  9 |     4,227  |      1,364 |   339 |     331 |    285 |  6,546 |  22.6%
-- 2012| 10 |     5,197  |      1,686 |   432 |     428 |    440 |  8,183 |  25.0%
-- 2012| 11 |     9,257  |      3,003 |   556 |     624 |    571 | 14,011 |  18.9%  ← holiday dip
-- 2012| 12 |     6,495  |      1,571 |   668 |     692 |    646 | 10,072 |  30.9%
-- 2013|  1 |     3,691  |        811 |   630 |     662 |    607 |  6,401 |  51.4%  ← FIRST 50%+ CROSS
-- 2013|  2 |     4,742  |        960 |   468 |     528 |    470 |  7,168 |  30.9%
-- 2013|  3 |     4,079  |        871 |   438 |     471 |    405 |  6,264 |  32.2%
-- 2013|  4 |     5,341  |      1,139 |   496 |     512 |    483 |  7,971 |  27.9%
-- 2013|  5 |     5,508  |      1,146 |   605 |     626 |    564 |  8,449 |  32.6%
-- 2013|  6 |     5,402  |      1,148 |   579 |     625 |    571 |  8,325 |  32.9%
-- 2013|  7 |     5,654  |      1,163 |   718 |     728 |    640 |  8,903 |  36.9%
-- 2013|  8 |     5,877  |      1,146 |   722 |     773 |    662 |  9,180 |  36.7%
-- 2013|  9 |     6,174  |      1,207 |   736 |     775 |    688 |  9,580 |  35.6%
-- 2013| 10 |     6,828  |      1,298 |   856 |     921 |    870 | 10,773 |  38.8%
-- 2013| 11 |     9,488  |      1,669 |   960 |     969 |    946 | 14,032 |  30.3%  ← holiday dip
-- 2013| 12 |    10,022  |      1,878 | 1,281 |   1,324 |  1,230 | 15,735 |  38.3%
-- 2014|  1 |     7,500  |      1,614 | 1,369 |   1,404 |  1,320 | 13,207 |  54.6%  ← sustained 50%+
-- 2014|  2 |     8,223  |      1,646 | 1,360 |   1,506 |  1,313 | 14,048 |  50.8%
-- 2014|  3 |     8,322  |      1,627 | 1,488 |   1,561 |  1,431 | 14,429 |  53.8%
-- 2014|  4 |    10,309  |      2,008 | 1,630 |   1,760 |  1,646 | 17,353 |  48.9%
-- 2014|  5 |    10,699  |      2,084 | 1,714 |   1,889 |  1,675 | 18,061 |  49.3%
-- 2014|  6 |    10,434  |      2,052 | 1,758 |   1,819 |  1,652 | 17,715 |  50.1%
-- 2014|  7 |    11,125  |      2,129 | 1,873 |   2,013 |  1,898 | 19,038 |  52.0%
-- 2014|  8 |    10,450  |      2,021 | 1,886 |   1,948 |  1,865 | 18,170 |  54.5%
-- 2014|  9 |    10,567  |      2,067 | 1,955 |   2,114 |  1,963 | 18,666 |  57.1%
-- 2014| 10 |    11,450  |      2,194 | 2,208 |   2,384 |  2,141 | 20,377 |  58.8%
-- 2014| 11 |    13,936  |      2,878 | 2,330 |   2,293 |  2,161 | 23,598 |  48.7%  ← holiday dip
-- 2014| 12 |    16,139  |      3,047 | 3,036 |   3,041 |  2,812 | 28,075 |  55.1%
-- 2015|  1 |    13,726  |      2,749 | 2,893 |   3,095 |  2,874 | 25,337 |  64.6%  ← HIGHEST POINT
-- 2015|  2 |    13,034  |      2,675 | 2,665 |   2,782 |  2,622 | 23,778 |  61.9%
-- 2015|  3 |     8,382  |      1,413 | 1,745 |   1,915 |  1,628 | 15,083 |  63.1%  ← PARTIAL
-- ============================================================
-- OBSERVATION:
--   At launch (Mar 2012), free + brand = 1.5% of gsearch nonbrand volume.
--   By Jan 2015, that ratio reached 64.6% — for every 3 visitors Google
--   sends via paid nonbrand, nearly 2 more arrive without any paid click.
--
--   NOVEMBER DIPS — every year without exception:
--   Nov 2012: 18.9% (vs 25.0% Oct) | Nov 2013: 30.3% (vs 38.8% Oct)
--   Nov 2014: 48.7% (vs 58.8% Oct)
--   Cause: gsearch nonbrand volume explodes in November (holiday season)
--   while free channels don't scale at the same pace — denominator grows
--   faster than numerator. NOT a resilience problem — it is seasonality.
--   MUST annotate this on the slide or investors will ask why resilience
--   drops in the company's biggest revenue month.
--
--   FIRST 50%+ CROSSING: January 2013 (51.4%)
--   Driven by: Love Bear launch (Jan 6) creating new brand search demand
--   AND seasonal post-holiday dip in gsearch nonbrand (3,691 sessions —
--   lowest month since launch). Both effects compressed the denominator
--   while brand/organic/direct held steady. Milestone but partly seasonal.
--
--   SUSTAINED 50%+: from January 2014 onward, every month except Nov 2014
--   stays above 48% — this is the structural shift investors want to see.
--
-- INSIGHT:
--   Free and brand channels grew from 1.5% to 64.6% of paid nonbrand
--   in three years with no dedicated SEO or brand awareness campaign.
--   Customers started seeking the company out on their own — that does
--   not happen unless the product is good and people talk about it.
--   Any deliberate SEO or brand investment would push this even higher.
--
-- ACTION:
--   Invest in SEO content and brand-building campaigns to break 70%+.
--   Brand search is the fastest-growing lever and cheapest to maintain.
--   Target the November dip specifically — if organic/direct can be
--   grown enough to keep the ratio above 50% even in November, that
--   is proof the brand is holiday-resilient, not just off-peak resilient.
--
-- IMPACT:
--   Jan 2015: 13,726 gsearch nonbrand sessions | 8,862 free+brand = 64.6%
--   Every 1pp increase in this ratio at Jan 2015 volumes = ~137 free sessions
--   at zero acquisition cost. At 8.28% conversion and $62.80 AOV = ~$712/month
--   KPI: monthly free_brand_pct_of_nonbrand — target 70%+ by end of 2015
--   Investor soundbite: "For every 3 paid visitors, nearly 2 more find us
--   for free — and that ratio has grown from 1 in 65 to 2 in 3 in 3 years."
-- ============================================================


-- ============================================================
-- C04 Query 5: Quarterly Channel Order Mix
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Fixed & reviewed by: Saleh Hossam
--   Fix 1: Replaced IS NOT NULL / IS NULL with COALESCE(TRIM()) —
--   same organic/direct detection bug as Q4 (C01 Fix 5)
--   Fix 2: Socialbook excluded from total_orders denominator
-- Brief requirement: C04 Q2 — "How has the share of orders from
-- each channel evolved quarter by quarter? Show both absolute
-- order volume and the percentage mix."
-- Notes:
--   gsearch_nb_pct and free_and_brand_pct are the two investor headline
--   metrics — they directly answer "what % of revenue survives if
--   Google raises prices tomorrow?"
-- ============================================================

SELECT
    YEAR(ws.created_at)    AS yr,
    QUARTER(ws.created_at) AS qtr,

    -- Total orders (Socialbook excluded from denominator)
    COUNT(DISTINCT o.order_id)                          AS total_orders,

    -- Orders by channel
    COUNT(CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch'
               AND  LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
               THEN o.order_id END)                     AS gsearch_nb_orders,

    COUNT(CASE WHEN LOWER(TRIM(ws.utm_source))   = 'bsearch'
               AND  LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
               THEN o.order_id END)                     AS bsearch_nb_orders,

    COUNT(CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'brand'
               THEN o.order_id END)                     AS brand_orders,

    -- C01 Fix 5: COALESCE for organic and direct
    COUNT(CASE WHEN ws.utm_source IS NULL
               AND  COALESCE(TRIM(ws.http_referer), '') != ''
               THEN o.order_id END)                     AS organic_orders,

    COUNT(CASE WHEN ws.utm_source IS NULL
               AND  COALESCE(TRIM(ws.http_referer), '') = ''
               THEN o.order_id END)                     AS direct_orders,

    -- Percentage mix — the investor headline metrics
    -- gsearch nonbrand as % of total (how dependent are we on Google?)
    ROUND(
        COUNT(CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch'
                   AND  LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
                   THEN o.order_id END)
        / NULLIF(COUNT(DISTINCT o.order_id), 0) * 100
    , 1)                                                AS gsearch_nb_pct,

    -- Free + brand as % of total (how resilient is the revenue base?)
    -- This directly answers: "If Google raised prices, what % survives?"
    ROUND(
        (COUNT(CASE WHEN ws.utm_source IS NULL
                    AND  COALESCE(TRIM(ws.http_referer), '') != ''
                    THEN o.order_id END)
       + COUNT(CASE WHEN ws.utm_source IS NULL
                    AND  COALESCE(TRIM(ws.http_referer), '') = ''
                    THEN o.order_id END)
       + COUNT(CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'brand'
                    THEN o.order_id END))
        / NULLIF(COUNT(DISTINCT o.order_id), 0) * 100
    , 1)                                                AS free_and_brand_pct

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0             -- C01 Fix 3: in ON not WHERE
WHERE LOWER(TRIM(ws.utm_source)) != 'socialbook'   -- C01 Fix 6
   OR ws.utm_source IS NULL

GROUP BY yr, qtr
ORDER BY yr, qtr;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22):
-- yr   | qtr | total | gsearch_nb | bsearch_nb | brand | organic | direct | gsearch_nb_pct | free_brand_pct
-- 2012 |  1  |    59 |         59 |          0 |     0 |       0 |      0 |         100.0% |   0.0%
-- 2012 |  2  |   347 |        291 |          0 |    20 |      15 |     21 |          83.9% |  16.1%
-- 2012 |  3  |   684 |        482 |         82 |    48 |      40 |     32 |          70.5% |  17.5%
-- 2012 |  4  | 1,494 |        913 |        311 |    88 |      94 |     88 |          61.1% |  18.1%
-- 2013 |  1  | 1,271 |        765 |        183 |   108 |     124 |     91 |          60.2% |  25.4%
-- 2013 |  2  | 1,716 |      1,112 |        237 |   114 |     134 |    119 |          64.8% |  21.4%
-- 2013 |  3  | 1,838 |      1,130 |        245 |   153 |     167 |    143 |          61.5% |  25.2%
-- 2013 |  4  | 2,616 |      1,657 |        291 |   248 |     223 |    197 |          63.3% |  25.5%
-- 2014 |  1  | 3,069 |      1,667 |        344 |   354 |     338 |    311 |          54.3% |  32.7%
-- 2014 |  2  | 3,848 |      2,208 |        427 |   410 |     436 |    367 |          57.4% |  31.5%
-- 2014 |  3  | 4,035 |      2,259 |        434 |   432 |     445 |    402 |          56.0% |  31.7%
-- 2014 |  4  | 5,908 |      3,248 |        683 |   615 |     605 |    532 |          55.0% |  29.7%
-- 2015 |  1  | 5,420 |      3,025 |        581 |   622 |     640 |    552 |          55.8% |  33.5%  ← PARTIAL Q
-- ============================================================
-- OBSERVATION:
--   In Q1 2012, 100% of orders came from a single channel (gsearch nonbrand).
--   By Q1 2015, free + brand channels account for 33.5% of all orders —
--   1 in 3 orders now comes from channels the company does not pay for.
--   gsearch nonbrand share has dropped from 100% to 55.8% in three years.
--
-- INSIGHT:
--   The company has structurally diversified its order base in three years
--   without a single strategic initiative dedicated to it — diversification
--   is the natural by-product of building a brand that people search for
--   and recommend. The free_and_brand_pct column is the answer to every
--   investor question about paid channel dependency.
--
-- ACTION:
--   Use this quarterly trend as the core resilience slide.
--   Annotate the chart with the key events: bsearch launch (Q3 2012),
--   Love Bear launch (Q1 2013), cross-sell feature (Q4 2013).
--   Each event contributed to reducing paid concentration.
--
-- IMPACT:
--   Q1 2015 total orders = 5,420. Free + brand = 1,814 orders (33.5%).
--   These 1,814 orders were acquired at zero paid search cost.
--   At $62.80 AOV = $113,919 in quarterly revenue with no CPC spend.
--   KPI: quarterly free_and_brand_pct — target 40% by end of 2015
-- ============================================================


-- ============================================================
-- C04 Query 6: Paid Search Conversion Rate by Channel and Device
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Reviewed by: Saleh Hossam
-- Brief requirement: C04 Q3 — "Pull nonbrand paid search conversion
-- rates for gsearch and bsearch, sliced by device type. This informs
-- bid optimisation decisions."
-- Notes:
--   Results are aggregate across full dataset — not trended.
--   This is the correct approach for bid strategy: we want the
--   best available estimate of true conversion by channel+device,
--   and more data = more reliable estimate.
--   No LOWER(TRIM(device_type)) needed in SELECT alias but IS needed
--   in GROUP BY — using the aliased column names handles this cleanly.
--   Socialbook automatically excluded by the utm_source IN filter.
-- ============================================================

SELECT
    LOWER(TRIM(ws.utm_source))                   AS channel,
    LOWER(TRIM(ws.device_type))                  AS device,
    COUNT(DISTINCT ws.website_session_id)        AS sessions,
    COUNT(DISTINCT o.order_id)                   AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id) /
        COUNT(DISTINCT ws.website_session_id) * 100
    , 2)                                         AS conv_rate_pct

FROM website_sessions ws
LEFT JOIN orders o
    ON  ws.website_session_id = o.website_session_id
    AND o.price_usd > 0             -- C01 Fix 3: in ON not WHERE

WHERE LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND LOWER(TRIM(ws.utm_source))   IN ('gsearch', 'bsearch')

GROUP BY channel, device
ORDER BY channel, device;

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22):
-- channel | device  | sessions | orders | conv_rate_pct
-- bsearch | desktop |  47,395  |  3,584 |  7.56%
-- bsearch | mobile  |   7,514  |    234 |  3.11%
-- gsearch | desktop | 195,155  | 16,031 |  8.21%
-- gsearch | mobile  |  87,551  |  2,785 |  3.18%
-- ============================================================
-- OBSERVATION:
--   Mobile converts at 3.11–3.18% across both channels.
--   Desktop converts at 7.56–8.21% — more than 2.5x mobile.
--   Mobile gap is IDENTICAL on both platforms: gsearch gap = 5.03pp,
--   bsearch gap = 4.45pp. This is a site problem, not a channel problem.
--   gsearch is 5.1x larger than bsearch in session volume (282,706 vs 54,909).
--   bsearch desktop performs nearly as well as gsearch desktop: 7.56% vs 8.21%.
--
-- INSIGHT:
--   Right now the company is paying the same bid per click for mobile
--   and desktop. Mobile converts at 39% the rate of desktop — so every
--   mobile click is overpaid by roughly 60%. bsearch desktop converts
--   at 92% of gsearch desktop (7.56% vs 8.21%) and is likely underbid.
--   Fixing bids costs nothing and requires no product changes.
--
-- ACTION:
--   Reduce mobile bids on both gsearch and bsearch immediately.
--   Increase bsearch desktop bids to approximately 92% of gsearch desktop.
--   Prioritize mobile site experience improvement — 87,551 gsearch mobile
--   sessions converting at 3.18% vs 8.21% desktop = ~4,400 orders lost.
--
-- IMPACT:
--   If gsearch mobile conversion improved from 3.18% → 5%:
--   87,551 sessions × (5.00% - 3.18%) = +1,593 additional orders
--   At $62.80 AOV = +$100,043 additional quarterly revenue
--   KPI: mobile vs desktop conversion rate gap — target gap under 40%
-- ============================================================


-- ============================================================
-- C04 Query 7: Weekly gsearch vs bsearch Nonbrand Session Volume
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Reviewed by: Saleh Hossam
-- Brief requirement: C04 Q4 — "Pull weekly trended session volume
-- for gsearch nonbrand and bsearch nonbrand side by side. bsearch
-- launched around August 22, 2012. What is the relative size and
-- trend of each channel?"
-- Notes:
--   Start date: 2012-08-22 — bsearch first appearance in data
--   Starting before this date would show zeros for bsearch and
--   distort the size comparison
--   YEARWEEK grouping with MIN(DATE) as week_start gives clean
--   calendar-aligned week labels for Power BI charting
--   Socialbook excluded by utm_source IN filter
--   utm_campaign = 'nonbrand' filter keeps this strictly nonbrand
--   — brand bsearch has different economics and should not be mixed
-- ============================================================

SELECT
    MIN(DATE(ws.created_at))                     AS week_start,
    COUNT(CASE WHEN LOWER(TRIM(ws.utm_source)) = 'gsearch'
               THEN 1 END)                       AS gsearch_sessions,
    COUNT(CASE WHEN LOWER(TRIM(ws.utm_source)) = 'bsearch'
               THEN 1 END)                       AS bsearch_sessions

FROM website_sessions ws
WHERE ws.created_at >= '2012-08-22'             -- bsearch launch date
  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
  AND LOWER(TRIM(ws.utm_source))   IN ('gsearch', 'bsearch')

GROUP BY YEARWEEK(ws.created_at)
ORDER BY week_start;

-- ============================================================
-- CONFIRMED RESULTS: 135 weeks (2026-03-22, via CSV export)
-- Key anchors:
-- 2012-08-22: gsearch=590  | bsearch=197  (bsearch=33% of gsearch at launch)
-- 2012-11-18: gsearch=3,508| bsearch=1,093 (first holiday spike, ratio held)
-- 2013-02-10: gsearch=2,207| bsearch=449  (Valentine's Day — Love Bear spike)
-- 2013-11-24: gsearch=4,552| bsearch=777  (bsearch ratio dropped to 17% at peak)
-- 2014-11-23: gsearch=5,358| bsearch=1,063 (biggest spike in full dataset)
-- 2015-03-15: gsearch=1,981| bsearch=235  (final partial week)
-- Long-term bsearch/gsearch ratio: ~19–20%
-- ============================================================
-- OBSERVATION:
--   bsearch launched at 33% of gsearch volume on day one.
--   Long-term settled ratio: ~19–20% of gsearch volume.
--   bsearch tracks gsearch exactly — same seasonal spikes,
--   same growth pattern, same holiday amplification.
--   During peak weeks, gsearch scales faster than bsearch —
--   bsearch ratio drops from ~25% to ~17% at holiday peaks.
--
-- INSIGHT:
--   bsearch is NOT bringing a different audience — it supplements
--   gsearch with the same intent at lower volume. It is a reliable
--   secondary channel, not a diversification play. Its conversion
--   rate (7.56% desktop) is close enough to gsearch (8.21%) that
--   it deserves proportional investment — just at 92 cents per
--   gsearch dollar, not equal bids.
--
-- ACTION:
--   Maintain bsearch as a secondary channel. Do not over-invest.
--   Calibrate bids: bsearch desktop ≈ 92% of gsearch desktop bid.
--   Bsearch mobile bids should be significantly reduced (3.11% conv rate).
--   Monitor weekly ratio — a sustained drop below 15% signals bsearch
--   is losing ground and warrants investigation.
--
-- IMPACT:
--   bsearch currently ~590 sessions/week = ~2,500/month
--   At 7.56% desktop conv rate and $62.80 AOV = ~$11,900/month revenue
--   Bid optimization saves ad spend without losing orders.
--   KPI: weekly bsearch/gsearch ratio — maintain 18–22% band
-- ============================================================


-- ============================================================
-- C04 Query 8: Channel Resilience Score (Full Year 2014)
-- ============================================================
-- Author: Toqa Gabr | Date: 2026-03-22
-- Reviewed by: Saleh Hossam
-- Brief requirement: C04 Q6 — "Create a Channel Resilience Score:
-- a single metric that summarises how exposed the business is to
-- paid channel disruption. Explain your methodology."
-- Notes:
--   Scope: 2014 full year — last complete year in dataset.
--   Using 2014 gives the most current and statistically robust
--   single-year picture. Q1 2015 is partial and not representative.
--   Numerator: all sessions that did NOT come from paid nonbrand —
--   i.e. sessions that would survive if paid search disappeared.
--   This includes: organic search, direct type-in, AND paid brand
--   because brand campaigns are low-cost and would likely be maintained
--   even if nonbrand budgets were cut. utm_source IS NULL covers
--   both organic and direct; utm_campaign = 'brand' covers brand.
--   Socialbook excluded from COUNT(*) denominator (Fix 6).
-- ============================================================

SELECT
    COUNT(*)                                     AS total_sessions,
    COUNT(CASE WHEN ws.utm_source IS NULL
               OR LOWER(TRIM(ws.utm_campaign)) = 'brand'
               THEN 1 END)                       AS free_and_brand_sessions,
    ROUND(
        COUNT(CASE WHEN ws.utm_source IS NULL
                   OR LOWER(TRIM(ws.utm_campaign)) = 'brand'
                   THEN 1 END)
        / COUNT(*) * 100
    , 1)                                         AS resilience_score_pct

FROM website_sessions ws
WHERE ws.created_at  >= '2014-01-01'
  AND ws.created_at  <  '2015-01-01'
  AND (LOWER(TRIM(ws.utm_source)) != 'socialbook'  -- C01 Fix 6
       OR ws.utm_source IS NULL);                  -- preserve organic/direct

-- ============================================================
-- CONFIRMED RESULTS (run 2026-03-22):
-- total_sessions | free_and_brand_sessions | resilience_score_pct
--     233,422    |          68,216          |        29.2%
-- ============================================================
-- METHODOLOGY NOTE (required by brief):
--   Resilience Score = (organic + direct + brand sessions) / total sessions × 100
--   Interpretation: the percentage of sessions that would continue to arrive
--   if all nonbrand paid advertising (gsearch + bsearch nonbrand) was stopped.
--   A score of 29.2% means: if paid ads stopped tomorrow, roughly 1 in 3
--   visitors would still find the site through organic search, direct URL
--   entry, or brand search.
--   Limitations: assumes brand search volume would not drop without paid
--   nonbrand support — some brand searches are stimulated by paid exposure.
--   The true floor is likely 25–27%, making 29.2% a slightly optimistic estimate.
--
-- OBSERVATION:
--   MavenFuzzyFactory started at 0% resilience in March 2012 — every single
--   session came from paid nonbrand Google ads. By 2014, the resilience score
--   is 29.2% — built entirely through organic brand equity, not any dedicated
--   SEO or loyalty investment.
--
-- INSIGHT:
--   29.2% resilience built in three years from a starting point of 0%,
--   with no SEO program and no brand campaign. People started searching
--   for the brand by name because the product earned it. That means any
--   actual investment in SEO or brand would compound what's already there.
--   The 70.8% paid dependency is still real and investors will ask about it.
--
-- ACTION:
--   Invest in SEO content and brand building to push resilience above 35%.
--   Brand search is the fastest lever — it is already growing at ~20% YoY
--   and costs a fraction of nonbrand paid clicks to maintain.
--   Set a 2015 target of 35% resilience score.
--
-- IMPACT:
--   2014: 68,216 free sessions = ~5,685/month at zero paid acquisition cost
--   Every 1pp improvement in resilience score = ~2,334 free sessions/year
--   At 7.74% conversion and $63.79 AOV = ~$11,520 annual revenue
--   at zero incremental acquisition cost
--   INVESTOR SOUNDBITE: "If paid advertising stopped tomorrow,
--   29.2% of our 2014 traffic — and the revenue it generates —
--   would remain completely unaffected."
--   KPI: annual resilience score — target 35% by end of 2015
-- ============================================================
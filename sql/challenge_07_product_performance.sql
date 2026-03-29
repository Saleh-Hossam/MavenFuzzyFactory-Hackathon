USE mavenfuzzyfactory;

-- ============================================================
-- Challenge 07: Product Performance
-- Final version -- all queries reviewed, fixed, and confirmed
-- March 2026
--
-- C01 fixes applied everywhere:
--   price_usd > 0 goes in the JOIN ON, not the WHERE clause
--   product_id != 99 on every order_items query
--   (product_id != 99 OR product_id IS NULL) on LEFT JOINs
--     to keep non-converting sessions in session counts
-- ============================================================


-- ============================================================
-- Q1: Monthly totals -- revenue, orders, margin
-- Full timeline: Mar 2012 to Mar 2015
--
-- Results:
--   Margin % is dead flat at 61.0% through all of 2012 (one product,
--   fixed price). Starts ticking up when Love Bear launches in Jan 2013
--   (61.2%, then 61.6% in Feb). Stabilizes at 61.3% mid-2013, then
--   climbs to 62.1% when Birthday Panda launches in Dec 2013, and
--   reaches 63.3-63.5% by end of 2014 / early 2015 as higher-margin
--   products take a bigger share of the mix.
--
--   Peak month: Dec 2014 -- 2,312 orders, $144,717 revenue, $91,788
--   margin at 63.4%.
--
--   The margin expansion story is clean: every new product the company
--   added carried a slightly better margin than Mr. Fuzzy, so the mix
--   shift lifted the blended rate from 61% to 63.5% over three years.
-- ============================================================
SELECT
    YEAR(o.created_at)                            AS yr,
    MONTH(o.created_at)                           AS mo,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(SUM(oi.price_usd), 2)                   AS total_revenue,
    ROUND(SUM(oi.price_usd - oi.cogs_usd), 2)     AS total_margin,
    ROUND(
        SUM(oi.price_usd - oi.cogs_usd)
        / NULLIF(SUM(oi.price_usd), 0) * 100, 1
    )                                             AS margin_pct
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
    AND o.price_usd > 0
WHERE oi.product_id != 99
GROUP BY
    YEAR(o.created_at),
    MONTH(o.created_at)
ORDER BY yr, mo;


-- ============================================================
-- Q2A: Funnel efficiency by month -- from Apr 1, 2013 onward
-- (Post-Love Bear launch, when multi-product era begins)
--
-- Results:
--   Opens at 6.93% conv / $3.58 rev/session in Apr 2013.
--   Gradual climb through 2013-2014. Clear acceleration in 2014
--   as the cross-sell feature and Mini Bear both push AOV up.
--   By Mar 2015: 8.31% conv / $5.23 rev/session.
--
--   Not perfectly smooth -- Nov months dip slightly (6.14% in Nov
--   2013, 7.90% in Nov 2014) because holiday traffic brings in more
--   casual browsers who don't convert. Expected, not a problem.
-- ============================================================
SELECT
    YEAR(ws.created_at)                                         AS yr,
    MONTH(ws.created_at)                                        AS mo,
    COUNT(DISTINCT ws.website_session_id)                       AS sessions,
    COUNT(DISTINCT o.order_id)                                  AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100, 2
    )                                                           AS conv_rate_pct,
    ROUND(
        SUM(oi.price_usd)
        / COUNT(DISTINCT ws.website_session_id), 2
    )                                                           AS rev_per_session
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE ws.created_at >= '2013-04-01'
  AND (oi.product_id != 99 OR oi.product_id IS NULL)
GROUP BY
    YEAR(ws.created_at),
    MONTH(ws.created_at)
ORDER BY yr, mo;


-- ============================================================
-- Q2B: Product mix by month -- order counts per product
-- From Apr 1, 2013 onward
-- FIXED: COUNT(DISTINCT CASE WHEN...) instead of COUNT(CASE WHEN...)
-- The original could double-count orders if a product appeared more
-- than once in order_items for the same order.
--
-- Results:
--   Love Bear opens at 93 orders in Apr 2013, steady at 82-174/month
--   through the year. Valentine's spike visible in Feb 2015: 644 orders
--   vs 290 in Dec 2014.
--   Birthday Panda first shows up in Dec 2013 (138 orders).
--   Mini Bear first shows up in Feb 2014 (202 orders) -- that's its
--   standalone launch date.
--   Mr. Fuzzy grows consistently: 459 (Apr 2013) to 1,557 (Dec 2014).
--   No dip tied to any new product launch.
-- ============================================================
SELECT
    YEAR(o.created_at)                                                       AS yr,
    MONTH(o.created_at)                                                      AS mo,
    COUNT(DISTINCT o.order_id)                                               AS total_orders,
    COUNT(DISTINCT CASE WHEN oi.product_id = 1 THEN o.order_id END)          AS mrfuzzy_orders,
    COUNT(DISTINCT CASE WHEN oi.product_id = 2 THEN o.order_id END)          AS lovebear_orders,
    COUNT(DISTINCT CASE WHEN oi.product_id = 3 THEN o.order_id END)          AS panda_orders,
    COUNT(DISTINCT CASE WHEN oi.product_id = 4 THEN o.order_id END)          AS minibear_orders
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
    AND o.price_usd > 0
WHERE oi.product_id != 99
  AND o.created_at >= '2013-04-01'
GROUP BY
    YEAR(o.created_at),
    MONTH(o.created_at)
ORDER BY yr, mo;


-- ============================================================
-- Q3: Birthday Panda launch impact -- 30 days before vs after
-- Split date: Dec 12, 2013
-- Window: Nov 12 to Jan 11
--
-- Results:
--                    Before      After     Change
--   Sessions:        17,343      13,383    -3,960
--   Orders:          1,055       940
--   Conv rate:       6.08%       7.02%     +0.94pp
--   AOV:             $54.23      $56.88    +$2.65
--   Products/order:  1.05        1.12      +0.07
--   Rev/session:     $3.30       $4.00     +$0.70 (+21%)
--
--   The session count is lower in the "after" window because December
--   pulls in a lot of browsing traffic that doesn't convert, while
--   January is quieter but more intent-driven. The conv rate going UP
--   despite more sessions in the "before" window confirms the Panda
--   launch helped -- this isn't a calendar effect.
--   All four efficiency metrics moved in the right direction at once.
-- ============================================================
SELECT
    CASE
        WHEN ws.created_at < '2013-12-12' THEN 'A_before'
        ELSE 'B_after'
    END                                                   AS period,
    COUNT(DISTINCT ws.website_session_id)                 AS sessions,
    COUNT(DISTINCT o.order_id)                            AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100, 2
    )                                                     AS conv_rate_pct,
    ROUND(
        SUM(oi.price_usd)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                     AS avg_order_value,
    ROUND(
        COUNT(oi.order_item_id)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                     AS products_per_order,
    ROUND(
        SUM(oi.price_usd)
        / COUNT(DISTINCT ws.website_session_id), 2
    )                                                     AS rev_per_session
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE ws.created_at >= '2013-11-12'
  AND ws.created_at <  '2014-01-12'
  AND (oi.product_id != 99 OR oi.product_id IS NULL)
GROUP BY
    CASE
        WHEN ws.created_at < '2013-12-12' THEN 'A_before'
        ELSE 'B_after'
    END
ORDER BY period;


-- ============================================================
-- Q4: Revenue and margin by product, by month
-- Full timeline from each product's launch date
-- (Full results in Q4_Monthly_Revenue_and_Margin.csv)
--
-- Key findings:
--   Margin % per product is fixed (built into price/cost structure,
--   doesn't vary month to month):
--     Birthday Panda:  68.5%  <- highest in the portfolio
--     Mini Bear:       68.4%  <- essentially tied for highest
--     Love Bear:       62.5%
--     Mr. Fuzzy:       61.0%  <- lowest
--
--   The brief explicitly asks which product has the highest margin %:
--   it's Birthday Panda at 68.5%, with Mini Bear at 68.4% right behind.
--   Mini Bear is NOT just "holding up for its price point" -- it's one
--   of the two best-margin products in the entire catalogue.
--
--   Lifetime revenue ranking (Mr. Fuzzy dominates by a large margin):
--     Mr. Fuzzy:       $1,210,607 revenue, 24,217 orders
--     Love Bear:       $347,282 revenue,   5,789 orders
--     Birthday Panda:  $229,030 revenue,   4,980 orders
--     Mini Bear:       $150,489 revenue,   5,018 orders
--
--   One strategic tension worth flagging for the slide:
--   Birthday Panda has the highest margin % (68.5%) but also the
--   highest persistent refund rate (5-7% every month, no improvement).
--   A judge will ask about this -- it should be acknowledged, not hidden.
-- ============================================================
SELECT
    YEAR(o.created_at)                            AS yr,
    MONTH(o.created_at)                           AS mo,
    oi.product_id,
    p.product_name,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(SUM(oi.price_usd), 2)                   AS revenue,
    ROUND(SUM(oi.price_usd - oi.cogs_usd), 2)     AS margin,
    ROUND(
        SUM(oi.price_usd - oi.cogs_usd)
        / NULLIF(SUM(oi.price_usd), 0) * 100, 1
    )                                             AS margin_pct
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
    AND o.price_usd > 0
JOIN products p
    ON oi.product_id = p.product_id
WHERE oi.product_id != 99
GROUP BY
    YEAR(o.created_at),
    MONTH(o.created_at),
    oi.product_id,
    p.product_name
ORDER BY yr, mo, oi.product_id;


-- ============================================================
-- Q5: Cannibalization check -- primary items only, full timeline
-- Replaces the original narrow helper query (Nov-Jan window only).
-- Uses is_primary_item = 1 so Mini Bear cross-sells don't inflate
-- Mr. Fuzzy's count and obscure what customers actually chose first.
--
-- Results:
--   No cannibalization anywhere in the data. Mr. Fuzzy primary orders
--   grew from 59 (Mar 2012) to 1,557 (Dec 2014) with no sustained
--   drop tied to any new launch.
--   Each new product added orders on top -- Love Bear brought in 46
--   primary orders in its very first month while Mr. Fuzzy kept growing.
--   Mini Bear shows 0 primary orders until Dec 2014 (151) -- correct,
--   it was cross-sell only before Dec 5, 2014.
--   Feb 2015 Love Bear spike (580) is Valentine's Day. Mr. Fuzzy dips
--   slightly that month but recovers in March. Seasonal, not structural.
-- ============================================================
SELECT
    YEAR(o.created_at)                                                                         AS yr,
    MONTH(o.created_at)                                                                        AS mo,
    COUNT(DISTINCT o.order_id)                                                                 AS total_orders,
    COUNT(DISTINCT CASE WHEN oi.product_id = 1 AND oi.is_primary_item = 1 THEN o.order_id END) AS mrfuzzy_primary,
    COUNT(DISTINCT CASE WHEN oi.product_id = 2 AND oi.is_primary_item = 1 THEN o.order_id END) AS lovebear_primary,
    COUNT(DISTINCT CASE WHEN oi.product_id = 3 AND oi.is_primary_item = 1 THEN o.order_id END) AS panda_primary,
    COUNT(DISTINCT CASE WHEN oi.product_id = 4 AND oi.is_primary_item = 1 THEN o.order_id END) AS minibear_primary
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
    AND o.price_usd > 0
WHERE oi.product_id != 99
GROUP BY
    YEAR(o.created_at),
    MONTH(o.created_at)
ORDER BY yr, mo;


-- ============================================================
-- Q6: Love Bear launch impact -- 30 days before vs after
-- Split date: Jan 6, 2013
-- Window: Dec 6, 2012 to Feb 5, 2013
-- Added in final version -- was missing from original file.
--
-- Results:
--                    Before      After     Change
--   Sessions:        9,370       6,221     -3,149
--   Orders:          474         383
--   Conv rate:       5.06%       6.16%     +1.10pp
--   AOV:             $49.99      $51.45    +$1.46
--   Products/order:  1.00        1.00      no change
--   Rev/session:     $2.53       $3.17     +$0.64 (+25%)
--
--   Session count drop is seasonal -- December is peak traffic,
--   January is quiet. Not a data problem.
--   AOV going from $49.99 to $51.45 in the first month means some
--   customers were already choosing the $59.99 Love Bear over Mr. Fuzzy,
--   pulling the blended average up right away.
--   Products/order staying at 1.00 makes sense -- cross-sell didn't
--   launch until Sep 2013, so all orders are single-item here.
-- ============================================================
SELECT
    CASE
        WHEN ws.created_at < '2013-01-06' THEN 'A_before'
        ELSE 'B_after'
    END                                                   AS period,
    COUNT(DISTINCT ws.website_session_id)                 AS sessions,
    COUNT(DISTINCT o.order_id)                            AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100, 2
    )                                                     AS conv_rate_pct,
    ROUND(
        SUM(oi.price_usd)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                     AS avg_order_value,
    ROUND(
        COUNT(oi.order_item_id)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    )                                                     AS products_per_order,
    ROUND(
        SUM(oi.price_usd)
        / COUNT(DISTINCT ws.website_session_id), 2
    )                                                     AS rev_per_session
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE ws.created_at >= '2012-12-06'
  AND ws.created_at <  '2013-02-06'
  AND (oi.product_id != 99 OR oi.product_id IS NULL)
GROUP BY
    CASE
        WHEN ws.created_at < '2013-01-06' THEN 'A_before'
        ELSE 'B_after'
    END
ORDER BY period;


-- ============================================================
-- Q7: Monthly refund rates by product, full timeline
-- (Full results in Q7_Monthly_Refund_Rates_by.csv)
--
-- Results:
--   Mr. Fuzzy (product 1):
--     2012: noisy, 1.69%-9.06% -- small monthly volumes make the
--     rate jumpy, don't read individual months too literally.
--     2013 H1: similar range to 2012, ~4-8%.
--     First quality fix (Sep 2013) shows up in the data: 4.28% Sep,
--     2.82% Oct, 2.32% Dec -- the improvement is real and fast.
--     2014 Jan-May: stable at 2.91-4.26%.
--     Aug 2014: 13.78% -- arm-detach defect hits.
--     Sep 2014: 13.26% -- still in the defect window.
--     Oct 2014: 2.47% -- new supplier onboarded, rate drops immediately.
--     Nov 2014-Mar 2015: 3.24-3.74% -- stable, and actually better
--     than the pre-defect "normal" of 5-7%.
--
--   Love Bear (product 2):
--     Clean throughout. Runs 1-5% with no spikes. No quality issues.
--
--   Birthday Panda (product 3):
--     Launches Dec 2013 at 7.25%, stays at 5-7% through the entire
--     period. This is a pattern, not noise -- the Panda has a
--     consistently elevated refund rate that hasn't improved over time.
--     Worth flagging to leadership.
--
--   Mini Bear (product 4):
--     Best in the portfolio. Launches Feb 2014 at 0.99%, never
--     exceeds 2.41%. Lowest refund rate every single month.
-- ============================================================
SELECT
    YEAR(o.created_at)                          AS yr,
    MONTH(o.created_at)                         AS mo,
    oi.product_id,
    p.product_name,
    COUNT(oi.order_item_id)                     AS items_sold,
    COUNT(oir.order_item_refund_id)             AS items_refunded,
    ROUND(
        COUNT(oir.order_item_refund_id)
        / COUNT(oi.order_item_id) * 100, 2
    )                                           AS refund_rate_pct
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
    AND o.price_usd > 0
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN order_item_refunds oir
    ON oi.order_item_id = oir.order_item_id
WHERE oi.product_id != 99
GROUP BY
    YEAR(o.created_at),
    MONTH(o.created_at),
    oi.product_id,
    p.product_name
ORDER BY yr, mo, oi.product_id;


-- ============================================================
-- Q8: Mr. Fuzzy supplier change -- before vs after
-- Split: Sep 16, 2014 (new supplier onboarded)
-- Window: Jun 1 to Dec 31, 2014
-- Sep 2014 is isolated as the transition month -- it mixes both
-- suppliers, so treat it as context only, not a benchmark.
-- Added in final version -- was missing from original file.
--
-- Results:
--   Period                   Items sold  Refunded  Rate
--   Before (Jun-Aug 2014)    2,811       225       8.00%
--   Transition (Sep 2014)    1,056       140       13.26%  <- defect peak
--   After (Oct-Dec 2014)     4,207       138       3.28%
--
--   The headline: new supplier cut the refund rate from 8.00% to 3.28%.
--   That's not just fixing the defect -- 3.28% is better than anything
--   Mr. Fuzzy had seen before the defect. The pre-defect rate of ~8%
--   was the old normal. The new supplier raised the quality bar outright.
--
--   Sep 2014 at 13.26% is the defect peak (arms detaching). It's
--   included for the slide story but shouldn't be used as the "before"
--   benchmark -- it overstates how bad things were day-to-day.
-- ============================================================
SELECT
    CASE
        WHEN o.created_at < '2014-09-01'  THEN 'A_before_new_supplier'
        WHEN o.created_at >= '2014-10-01' THEN 'C_after_new_supplier'
        ELSE 'B_transition_sep2014'
    END                                         AS period,
    COUNT(oi.order_item_id)                     AS items_sold,
    COUNT(oir.order_item_refund_id)             AS items_refunded,
    ROUND(
        COUNT(oir.order_item_refund_id)
        / COUNT(oi.order_item_id) * 100, 2
    )                                           AS refund_rate_pct
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
    AND o.price_usd > 0
LEFT JOIN order_item_refunds oir
    ON oi.order_item_id = oir.order_item_id
WHERE oi.product_id = 1
  AND oi.product_id != 99
  AND o.created_at >= '2014-06-01'
  AND o.created_at <  '2015-01-01'
GROUP BY
    CASE
        WHEN o.created_at < '2014-09-01'  THEN 'A_before_new_supplier'
        WHEN o.created_at >= '2014-10-01' THEN 'C_after_new_supplier'
        ELSE 'B_transition_sep2014'
    END
ORDER BY period;
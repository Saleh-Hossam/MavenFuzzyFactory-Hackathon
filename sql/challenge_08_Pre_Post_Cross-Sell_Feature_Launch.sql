-- ============================================================
-- Challenge 08: Cross-Sell Analysis
-- MavenFuzzyFactory Hackathon
-- Author: Saleh Hossam | Date: 2026-03-22
-- ============================================================
-- C01 fixes applied to every query in this file:
--   LOWER(pageview_url) on all pageview filters
--   o.price_usd > 0 in JOIN ON — never WHERE
--   oi.product_id != 99 on every order_items query
--   No utm filters needed — cross-sell is channel-agnostic
-- ============================================================


-- ============================================================
-- PART 1: Pre/Post Cross-Sell Feature Launch
-- Before: Aug 25 – Sep 24, 2013
-- After:  Sep 25 – Oct 24, 2013
-- Denominator: sessions that reached /cart
-- ============================================================
-- The cross-sell prompt went live Sep 25, 2013.
-- We use exactly one month either side to keep the comparison fair.
-- Denominator is cart sessions — not all sessions — because the
-- feature was only shown to people who actually reached the cart.
--
-- Metrics:
--   1. Cart-to-order CTR        = orders / cart sessions
--   2. Avg products per order   = total items / orders
--   3. AOV                      = total revenue / orders
--   4. Revenue per cart session = total revenue / cart sessions
--
-- Why NULLIF on the denominator for metrics 2 and 3?
--   Guards against division by zero if a period returns no orders.
--   Not expected here but correct practice.
-- ============================================================

SELECT
    period,
    COUNT(DISTINCT cart_session_id)                     AS cart_sessions,
    COUNT(DISTINCT order_id)                            AS orders,

    -- Metric 1: Cart-to-order CTR
    ROUND(COUNT(DISTINCT order_id)
        / COUNT(DISTINCT cart_session_id) * 100, 2)     AS cart_to_order_ctr_pct,

    -- Metric 2: Avg products per order
    ROUND(COUNT(item_id)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2)       AS avg_products_per_order,

    -- Metric 3: AOV
    ROUND(SUM(item_revenue)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2)       AS aov_usd,

    -- Metric 4: Revenue per cart session
    ROUND(SUM(item_revenue)
        / COUNT(DISTINCT cart_session_id), 2)           AS rev_per_cart_session_usd

FROM (

    SELECT
        CASE
            WHEN ws.created_at BETWEEN '2013-08-25' AND '2013-09-24'
                THEN 'before'
            WHEN ws.created_at BETWEEN '2013-09-25' AND '2013-10-24'
                THEN 'after'
        END                                             AS period,

        ws.website_session_id                           AS cart_session_id,
        o.order_id,
        oi.order_item_id                                AS item_id,
        oi.price_usd                                    AS item_revenue

    FROM website_pageviews wp

    JOIN website_sessions ws
        ON wp.website_session_id = ws.website_session_id

    -- Orders placed by those sessions
    LEFT JOIN orders o
        ON ws.website_session_id = o.website_session_id
        AND o.price_usd > 0

    -- Items in those orders
    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id
        AND oi.product_id != 99

    -- Only sessions that reached /cart
    WHERE LOWER(wp.pageview_url) = '/cart'
      AND ws.created_at BETWEEN '2013-08-25' AND '2013-10-24'

) AS cart_data

WHERE period IS NOT NULL
GROUP BY period
ORDER BY period DESC;   -- 'before' row first, then 'after'

-- ============================================================
-- PART 1 RESULTS (confirmed 2026-03-22)
-- ============================================================
--   BEFORE (Aug 25 – Sep 24 2013):
--     cart_sessions:              1,749
--     orders:                       625
--     cart_to_order_ctr_pct:      35.73%
--     avg_products_per_order:      1.00
--     aov_usd:                   $51.43
--     rev_per_cart_session_usd:  $18.38
--
--   AFTER (Sep 25 – Oct 24 2013):
--     cart_sessions:              1,895
--     orders:                       639
--     cart_to_order_ctr_pct:      33.72%
--     avg_products_per_order:      1.05
--     aov_usd:                   $54.32
--     rev_per_cart_session_usd:  $18.32
--
-- WHAT THE NUMBERS SAY:
--   CTR fell 2.01 pp (35.73 → 33.72). The cross-sell prompt added
--   a second decision at the cart — some customers hesitated.
--   AOV rose $2.89 (51.43 → 54.32). The customers who did complete
--   their order spent more.
--   Avg products per order went from exactly 1.00 to 1.05. Small
--   move, but the baseline was a hard floor of 1 — any movement
--   above it in the first month is meaningful.
--   Revenue per cart session barely moved ($18.38 → $18.32). The
--   drop in CTR and the rise in AOV offset each other almost exactly
--   in this early window.
--   The feature was not an immediate revenue win — it was a behaviour
--   shift that built steadily over the 15 months that followed. By Q4 2014 AOV had reached
--   $63.79, up from $51.43 before the feature existed.
-- ============================================================


-- ============================================================
-- PART 2: Cross-Sell Attachment Rate Matrix
-- Only orders after Dec 5, 2014 (Mini Bear became standalone)
-- ============================================================
-- Self-join on order_items to find what was bought alongside
-- the primary product in the same order.
--   primary_oi   — rows where is_primary_item = 1
--   crosssell_oi — rows where is_primary_item = 0, same order_id
--
-- Attachment rate = orders containing the pairing / total orders
--                   where that primary product was purchased
--
-- The denominator subquery (primary_totals) is calculated
-- separately so it reflects ALL primary orders for each product,
-- not just the ones that also had a cross-sell.
--
-- Why Dec 5, 2014?
--   Mini Bear was sold as a cross-sell add-on from Sep 25, 2013,
--   but it did not have its own product page until Dec 5, 2014.
--   Including pre-Dec 5 data would mix two different purchase
--   contexts and distort the attachment rates.
-- ============================================================

SELECT
    primary_oi.product_id                               AS primary_product_id,
    crosssell_oi.product_id                             AS crosssell_product_id,
    COUNT(DISTINCT primary_oi.order_id)                 AS orders_with_pairing,
    primary_totals.total_orders                         AS total_primary_orders,
    ROUND(COUNT(DISTINCT primary_oi.order_id)
        / primary_totals.total_orders * 100, 2)         AS attachment_rate_pct

FROM order_items primary_oi

-- Date filter and price check
JOIN orders o
    ON primary_oi.order_id = o.order_id
    AND o.price_usd > 0

-- Self-join: find cross-sell items in the same order
JOIN order_items crosssell_oi
    ON primary_oi.order_id = crosssell_oi.order_id
    AND crosssell_oi.is_primary_item = 0
    AND crosssell_oi.product_id != 99

-- Total orders per primary product — used as denominator
JOIN (
    SELECT
        oi.product_id,
        COUNT(DISTINCT oi.order_id) AS total_orders
    FROM order_items oi
    JOIN orders o2
        ON oi.order_id = o2.order_id
        AND o2.price_usd > 0
    WHERE oi.is_primary_item = 1
      AND oi.product_id != 99
      AND o2.created_at > '2014-12-05'
    GROUP BY oi.product_id
) AS primary_totals
    ON primary_oi.product_id = primary_totals.product_id

WHERE primary_oi.is_primary_item = 1
  AND primary_oi.product_id != 99
  AND o.created_at > '2014-12-05'

GROUP BY
    primary_oi.product_id,
    crosssell_oi.product_id,
    primary_totals.total_orders

ORDER BY primary_product_id, attachment_rate_pct DESC;

-- ============================================================
-- PART 2 RESULTS — ATTACHMENT RATE MATRIX (confirmed 2026-03-22)
-- ============================================================
--   Primary 1 (Mr. Fuzzy)  → Cross-sell 4 (Mini Bear):  20.89% | 933 orders
--   Primary 1 (Mr. Fuzzy)  → Cross-sell 3 (Panda):      12.38% | 553 orders
--   Primary 1 (Mr. Fuzzy)  → Cross-sell 2 (Love Bear):   5.33% | 238 orders
--   Primary 2 (Love Bear)  → Cross-sell 4 (Mini Bear):  20.38% | 260 orders
--   Primary 2 (Love Bear)  → Cross-sell 3 (Panda):       3.13% |  40 orders
--   Primary 2 (Love Bear)  → Cross-sell 1 (Mr. Fuzzy):   1.96% |  25 orders
--   Primary 3 (Panda)      → Cross-sell 4 (Mini Bear):  22.41% | 208 orders
--   Primary 3 (Panda)      → Cross-sell 1 (Mr. Fuzzy):   9.05% |  84 orders
--   Primary 3 (Panda)      → Cross-sell 2 (Love Bear):   4.31% |  40 orders
--   Primary 4 (Mini Bear)  → Cross-sell 3 (Panda):       3.79% |  22 orders
--   Primary 4 (Mini Bear)  → Cross-sell 1 (Mr. Fuzzy):   2.75% |  16 orders
--   Primary 4 (Mini Bear)  → Cross-sell 2 (Love Bear):   1.55% |   9 orders
--
-- WHAT THE NUMBERS SAY:
--   Mini Bear is the go-to add-on regardless of what the customer
--   originally came to buy. Mr. Fuzzy, Love Bear, and Panda all
--   attach to Mini Bear at 20-22% — consistent across the board.
--   When Mini Bear is the primary product the pattern flips completely.
--   Nobody adds anything meaningful to it — max attachment rate is
--   3.79%. Customers buying the cheapest product in the catalogue
--   are not looking to spend more on top of it.
-- ============================================================


-- ============================================================
-- PART 2b: Average Basket Value per Cross-Sell Pairing
-- Same date filter: orders after Dec 5, 2014
-- ============================================================
-- For each pairing, calculate the average total order value
-- — sum of ALL items in that order, not just the two products.
-- This answers whether featuring a high-attachment pairing
-- also means more money per transaction.
-- ============================================================

SELECT
    primary_oi.product_id                               AS primary_product_id,
    crosssell_oi.product_id                             AS crosssell_product_id,
    COUNT(DISTINCT o.order_id)                          AS orders_with_pairing,
    ROUND(SUM(oi_totals.order_revenue)
        / COUNT(DISTINCT o.order_id), 2)                AS avg_basket_value_usd

FROM order_items primary_oi

JOIN orders o
    ON primary_oi.order_id = o.order_id
    AND o.price_usd > 0

-- Find cross-sell item in the same order
JOIN order_items crosssell_oi
    ON primary_oi.order_id = crosssell_oi.order_id
    AND crosssell_oi.is_primary_item = 0
    AND crosssell_oi.product_id != 99

-- Full order revenue per order_id
JOIN (
    SELECT
        order_id,
        SUM(price_usd) AS order_revenue
    FROM order_items
    WHERE product_id != 99
    GROUP BY order_id
) AS oi_totals
    ON o.order_id = oi_totals.order_id

WHERE primary_oi.is_primary_item = 1
  AND primary_oi.product_id != 99
  AND o.created_at > '2014-12-05'

GROUP BY
    primary_oi.product_id,
    crosssell_oi.product_id

ORDER BY avg_basket_value_usd DESC;

-- ============================================================
-- PART 2b RESULTS — AVERAGE BASKET VALUE (confirmed 2026-03-22)
-- ============================================================
--   1 + 2 (Mr. Fuzzy  + Love Bear):  $109.98 | 238 orders
--   2 + 1 (Love Bear  + Mr. Fuzzy):  $109.98 |  25 orders
--   2 + 3 (Love Bear  + Panda):      $105.98 |  40 orders
--   3 + 2 (Panda      + Love Bear):  $105.98 |  40 orders
--   1 + 3 (Mr. Fuzzy  + Panda):       $95.98 | 553 orders
--   3 + 1 (Panda      + Mr. Fuzzy):   $95.98 |  84 orders
--   2 + 4 (Love Bear  + Mini Bear):   $89.98 | 260 orders
--   4 + 2 (Mini Bear  + Love Bear):   $89.98 |   9 orders
--   1 + 4 (Mr. Fuzzy  + Mini Bear):   $79.98 | 933 orders
--   4 + 1 (Mini Bear  + Mr. Fuzzy):   $79.98 |  16 orders
--   3 + 4 (Panda      + Mini Bear):   $75.98 | 208 orders
--   4 + 3 (Mini Bear  + Panda):       $75.98 |  22 orders
--
-- TOTAL REVENUE GENERATED PER PAIRING (Dec 5 2014 – Mar 19 2015):
--   Mr. Fuzzy + Mini Bear:   933 x $79.98  = $74,621  ← highest total
--   Mr. Fuzzy + Panda:       553 x $95.98  = $53,077
--   Mr. Fuzzy + Love Bear:   238 x $109.98 = $26,175
--   Love Bear + Mini Bear:   260 x $89.98  = $23,395
--   Panda     + Mini Bear:   208 x $75.98  = $15,804
-- ============================================================


-- ============================================================
-- Q5: WHICH PAIRING TO FEATURE AT CHECKOUT — AND WHY
-- No SQL needed — based on Parts 2 and 2b results
-- ============================================================
-- RECOMMENDATION: Feature Mini Bear at the cart page for every
-- primary product. The data is clear on this.
--
-- Mr. Fuzzy + Mini Bear is the right call:
--   Attachment rate:        20.89% — highest among all high-volume pairings
--   Orders in 3.5 months:  933
--   Total revenue:         $74,621 — nearly 3x the next pairing by volume
--   Monthly contribution:  ~$21,800
--
-- The temptation is to push Mr. Fuzzy + Love Bear instead because
-- the basket value is $109.98 vs $79.98. That logic breaks down
-- when you look at volume. The Love Bear attachment rate is 5.33%
-- — one in twenty customers. The Mini Bear rate is one in five.
-- You cannot build a reliable revenue line on a 5% attachment rate
-- regardless of how good the individual basket looks.
--
-- Panda shows the highest attachment rate of all at 22.41% to Mini
-- Bear, but Panda only has 928 primary orders vs Mr. Fuzzy's 4,467.
-- The volume base is not there to make it  the right call.
--
-- What the cart page should do:
--   Show Mini Bear as a single add-on option for every primary product.
--   Keep it simple — one image, one button, price visible.
--   The more steps between the customer and adding it, the lower
--   the attachment rate will be.
--
-- If attachment rate on Mr. Fuzzy → Mini Bear improves by 5 pp
-- (from 20.89% to 25.89%), that is roughly 65 extra Mini Bears
-- sold per month at $24.99 = ~$1,600/month in additional revenue.
--
-- Success metric: Mini Bear attachment rate across all primary products.
-- Target: lift from the current ~21% average to 26% within 60 days.
-- ============================================================
-- ============================================================
-- Challenge 02: The Growth Story
-- MavenFuzzyFactory Hackathon
-- Author: Saleh Hossam | Date: 2026-03-20
-- ============================================================
-- C01 fixes applied to every query in this file — listed here:
--   LOWER(TRIM()) on utm_source, utm_campaign, device_type
--   COALESCE(TRIM(http_referer),'') to handle organic vs direct
--   AND o.price_usd > 0 in JOIN ON clause — not WHERE
-- (keeps non-converting sessions  in LEFT JOIN counts)
--   Socialbook excluded throughout — undocumented channel from C01
--   order_items not used in C02 so product_id 99 exclusion not needed
-- ============================================================


-- ============================================================
-- Q1: Quarterly Sessions & Orders
-- ============================================================
-- The headline slide — full growth arc from launch to present.
-- Quarterly view keeps it clean for the investor chart.
-- Q1 2012 is partial (~12 days from March 19 launch) and
-- Q1 2015 is partial (~78 days, data ends March 19).
-- Kept both in — hiding the launch quarter makes no sense,
-- and Q1 2015 being nearly complete is worth showing.
-- Q4 2014 is the benchmark for any investor comparisons
-- since it's the last full quarter we have.
SELECT
    YEAR(ws.created_at) AS yr,
    QUARTER(ws.created_at)  AS qtr,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id)  AS orders,
    CASE WHEN YEAR(ws.created_at) IN(2012,2015) AND QUARTER(ws.created_at) = 1 THEN 'Partial' ELSE 'Complete' END AS Quarter_Status
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id AND o.price_usd > 0
GROUP BY
    YEAR(ws.created_at),
    QUARTER(ws.created_at),
	CASE WHEN YEAR(ws.created_at) IN(2012,2015) AND QUARTER(ws.created_at) = 1 THEN 'Partial' ELSE 'Complete' END 
ORDER BY yr, qtr;

-- 13 rows returned
-- Sessions went from 1,879 at launch to 76,373 by Q4 2014 — 40x in 3 years
-- Orders went from 59 to 5,908 in the same window — orders grew even faster
-- than sessions which already hints at improving conversion (C03 digs into this)
--
-- Inflection point analysis and event cross-referencing — see Q6 at bottom of file

-- ============================================================
-- Q2: Monthly gsearch Nonbrand Sessions & Orders
-- ============================================================
-- Drills into the main growth engine monthly.
-- gsearch nonbrand was literally the entire business at launch —
-- every session in March 2012 came through this channel.

SELECT
    YEAR(ws.created_at) AS yr,
    MONTH(ws.created_at)  AS mo,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id)  AS orders
FROM website_sessions ws
LEFT JOIN orders o 
ON ws.website_session_id = o.website_session_id AND o.price_usd > 0  
WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch'  AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'  
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)
ORDER BY yr,mo;

-- 37 rows (March 2012 through March 2015, March 2015 partial)
-- Sessions: 1,852 (Mar 2012) → 16,139 (Dec 2014) — roughly 9x
-- Orders: 59 (Mar 2012) → 1,324 (Dec 2014) — roughly 22x
-- Orders grew faster than sessions — conversion improving over time
-- Holiday pattern is consistent and gets stronger every year:
-- Nov 2012: 9,257 | Nov/Dec 2013: 9,488/10,022 | Nov/Dec 2014: 13,936/16,139
-- Worth annotating the November spike every year on the chart
-- Note: March 2012 shows 1,852 here vs 1,879 in Q1 — expected difference,
-- Q1 counts all channels, this query is gsearch nonbrand only

-- ============================================================
-- Q3: Monthly gsearch Nonbrand vs Brand
-- ============================================================
-- Same channel, split by campaign to show brand awareness building.
-- Important note: brand sessions here are gsearch only because
-- the WHERE clause filters to utm_source = gsearch.
-- Full brand picture including bsearch brand is in Q5.
-- Don't compare brand totals between Q3 and Q5 directly.
-- Used conditional aggregation to keep both campaigns on one row
-- — makes Power BI charting much cleaner than two separate queries.

SELECT
    YEAR(ws.created_at) AS yr, MONTH(ws.created_at) AS mo,
    
    -- Nonbrand sessions and orders
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'nonbrand' THEN ws.website_session_id END)  AS nonbrand_sessions,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'nonbrand' THEN o.order_id END)  AS nonbrand_orders,

    -- Brand sessions and orders
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'brand' THEN ws.website_session_id END)  AS brand_sessions,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_campaign)) = 'brand' THEN o.order_id END) AS brand_orders
    
FROM website_sessions ws
LEFT JOIN orders o
ON ws.website_session_id = o.website_session_id AND o.price_usd > 0 

WHERE LOWER(TRIM(ws.utm_source)) = 'gsearch' AND LOWER(TRIM(ws.utm_campaign)) IN ('nonbrand', 'brand') 

GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)

ORDER BY yr, mo;

-- 37 rows
-- Brand started at 8 sessions and 0 orders in March 2012
-- By December 2014: brand hit 2,438 sessions and 176 orders
-- Brand as a share of nonbrand went from ~0.4% to ~15% over 3 years
-- People are searching for the brand by name now — that's
-- earned awareness you don't have to keep paying for


-- ============================================================
-- Q4: Monthly gsearch Nonbrand by Device Type
-- ============================================================
-- Splits the main channel by device to find the mobile conversion gap.
-- If mobile converts at half the rate of desktop, paying the same
-- bid for both devices is overpaying for mobile traffic.

SELECT
    YEAR(ws.created_at)  AS yr, MONTH(ws.created_at)  AS mo,
    
    -- Desktop sessions and orders
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.device_type)) = 'desktop' THEN ws.website_session_id END) AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.device_type)) = 'desktop' THEN o.order_id END) AS desktop_orders,

    -- Mobile sessions and orders
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.device_type)) = 'mobile' THEN ws.website_session_id END) AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.device_type)) = 'mobile' THEN o.order_id END) AS mobile_orders

FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id AND o.price_usd > 0

WHERE LOWER(TRIM(ws.utm_source))   = 'gsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'

GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)

ORDER BY yr, mo;

-- 37 rows
-- Desktop conversion rate: ~4.3% at launch → ~10.0% by Dec 2014
-- Mobile conversion rate:  ~1.4% at launch → ~4.0%  by Dec 2014
-- Mobile is about 30% of sessions but only 15% of orders
-- The gap isn't closing — mobile is growing in volume but
-- not catching up on conversion rate
-- This feeds directly into the bid strategy recommendation in C04


-- ============================================================
-- Q5: Monthly All Channels Side by Side
-- ============================================================
-- Full picture — all five documented channels in one query.
-- No WHERE clause so everything comes through, channel identity
-- is handled inside the CASE conditions.
-- Brand split by source (gsearch vs bsearch) for proper
-- cost accountability — can't lump them if we're managing
-- separate budgets on each platform.
-- COALESCE(TRIM(http_referer),'') handles both NULL referers
-- and empty string referers cleanly in one condition.
-- Socialbook excluded from all CASE conditions — flagged in C01 as undocumented
-- Socialbook sessions still pass through FROM clause but return NULL
-- across all channel columns — they are not counted anywhere in this query
-- Channel column totals will not equal total session count for this reason
-- Socialbook will be addressed in C04

SELECT
    YEAR(ws.created_at) AS yr, MONTH(ws.created_at) AS mo,
    
    -- gsearch nonbrand
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand' 
    THEN ws.website_session_id END)  AS gsearch_nonbrand_sessions,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
        THEN o.order_id END) AS gsearch_nonbrand_orders,

 -- bsearch nonbrand
COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'bsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand' 
	THEN ws.website_session_id END) AS bsearch_nonbrand_sessions,
COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'bsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'nonbrand'
	THEN o.order_id END)  AS bsearch_nonbrand_orders,

-- gsearch brand
COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'brand'
	THEN ws.website_session_id END) AS gsearch_brand_sessions,
COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'gsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'brand'
	THEN o.order_id END)  AS gsearch_brand_orders,

-- bsearch brand
COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'bsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'brand' 
THEN ws.website_session_id END) AS bsearch_brand_sessions,
COUNT(DISTINCT CASE WHEN LOWER(TRIM(ws.utm_source))   = 'bsearch' AND LOWER(TRIM(ws.utm_campaign)) = 'brand' 
THEN o.order_id END) AS bsearch_brand_orders,

-- organic search (free)
-- utm_source is null but a referer exists — came via search engine
COUNT(DISTINCT CASE WHEN ws.utm_source IS NULL AND COALESCE(TRIM(ws.http_referer), '') != '' 
	THEN ws.website_session_id END) AS organic_sessions,
COUNT(DISTINCT CASE WHEN ws.utm_source IS NULL AND COALESCE(TRIM(ws.http_referer), '') != ''
	THEN o.order_id END)   AS organic_orders,

-- direct type-in (free)
-- utm_source is null AND no referer at all — typed URL directly
COUNT(DISTINCT CASE WHEN ws.utm_source IS NULL AND COALESCE(TRIM(ws.http_referer), '') = '' 
	THEN ws.website_session_id END) AS direct_sessions,
COUNT(DISTINCT CASE WHEN ws.utm_source IS NULL AND COALESCE(TRIM(ws.http_referer), '') = ''
	THEN o.order_id END) AS direct_orders
        
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id AND o.price_usd > 0
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at)
ORDER BY YEAR(ws.created_at), MONTH(ws.created_at);

-- 37 rows (March 2012 through March 2015)
-- bsearch shows zero sessions March through July 2012 then
-- jumps to 645 in August 2012 — lines up exactly with the
-- brief saying bsearch launched around August 22, 2012
-- Free channels (organic + direct) grew from near zero at launch
-- to 3,041 + 2,812 sessions by December 2014
-- gsearch nonbrand still dominates but the gap is narrowing
-- Full paid vs free split and resilience score is C04's job

-- ============================================================
-- Q6: Inflection Point Analysis
-- No new query — these are annotations for the Q1 chart
-- Brief asks to cross-reference spikes against: product launches,
-- bid changes, landing page tests, and new channel launches
-- ============================================================
--
-- Big jump (Inflection Point) 1 — Q4 2012: sessions almost doubled (16,892 → 32,266)
-- orders went from 684 to 1,494 in one quarter
-- The landing page test (June–July 2012) already improved Q3 conversion
-- The billing page A/B test (Sep–Nov 2012) then landed right before Q4
-- Holiday volume in November/December hit on top of that better checkout
-- Both tests will be quantified properly in C06
-- No bid change data in this dataset — if the jump exceeds what the
-- page tests explain, a Google Ads data pull would be needed to confirm
--
-- Big jump (Inflection Point) 2 — Q2 2013 onward: sustained acceleration begins
-- Q1 2013 (19,833 sessions, 1,271 orders) dipped vs Q4 2012 — normal post-holiday
-- Q2 2013 jumped to 24,745 sessions, 1,716 orders — above Q4 2012 for first time
-- The Forever Love Bear launched January 6, 2013 — first new product ever
-- Opened the gift buyer market. Valentine's Day six weeks after launch
-- helped Love Bear sales in those early months. The dip in Q1 2013 vs Q4 2012
-- is seasonal not structural — by Q2 the new baseline was clearly higher
-- Also: bsearch was ramping through Q1 2013 adding new channel volume
--
-- Big jump (Inflection Point) 3 — Q4 2014: biggest quarter ever
-- 76,373 sessions and 5,908 orders — both all-time highs
-- Known events contributing:
-- 1. Hudson River Mini Bear launched February 2014 —
--    full four-product portfolio now active for first time
-- 2. Birthday Sugar Panda launched December 2013 —
--    first full year with three products going into holiday season
-- 3. Holiday season with complete portfolio compounds everything
-- No single driver — this is the cumulative effect of three years
-- of product expansion, channel diversification, and page improvements
-- all hitting their first shared holiday season together
-- ============================================================
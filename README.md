# MavenFuzzyFactory Hackathon Analysis
**E-commerce growth analysis of MavenFuzzyFactory (2012–2015)**
DEBI Business Analytics Hackathon · Zesto Team · March 2026 · **Top 3 Finish**

---

## Table of Contents

- [Project Overview](#project-overview)
- [My Contributions](#my-contributions)
- [Team](#team)
- [Dataset](#dataset)
- [Challenges & Analysis](#challenges--analysis)
- [Key Findings](#key-findings)
- [Data Quality](#data-quality)
- [Tools](#tools)
- [Repository Structure](#repository-structure)
- [How to Run](#how-to-run)
- [Deliverables](#deliverables)

---

## Project Overview

MavenFuzzyFactory is a US-based direct-to-consumer e-commerce company selling stuffed animal toys online. It launched in March 2012 with a single product and grew to a four-product portfolio by early 2014.

The challenge: act as an external Business Analytics Consultant. The CEO is heading into a high-stakes investor meeting and needs a data-driven story proving the business has grown efficiently, built a resilient revenue base, and still has significant upside ahead.

We were handed the company's raw data warehouse — unclean, unvalidated — and had to answer 10 business challenges across 4 phases, culminating in a 10-minute investor pitch.

---

## My Contributions

This was a four-person team project.

| Challenge | Topic | Key Output |
|-----------|-------|------------|
| C01 | Data Quality — cleaning decisions, exclusion log, governance recommendations | 34 hard exclusions identified; 3-step governance framework |
| C02 | Overall Growth Story — sessions & orders by quarter, full business lifecycle | 38x session growth, 96x order growth documented |
| C06 | Website A/B Test ROI — landing page and billing page test analysis | Billing page: +17.18pp lift = ~$27,800/month ongoing |
| C08 | Cross-Sell Analysis — Mini Bear attachment rates, AOV impact | $74,621 in cross-sell revenue in 3.5 months |
| C09 | Repeat Customer Behaviour — retention, LTV, channel mix | 2.67x LTV multiple for repeat customers |
| C10 | Capstone & Strategic Roadmap — three strategic recommendations, $100K budget allocation | $29,074+/month projected return |


---

## Team

| Name | Role |
|------|------|
| Zeina Ahmed | Conversion Funnel Analysis (C05) |
| Toka Gabr | Efficiency & Resilience (C03, C04, C07) |
| Omar El Yemani | Product Performance (C09) |
| Saleh Hossam | Data Quality, Growth Story, A/B Test ROI, Cross-Sell, Capstone |

---

## Dataset

| Table | Rows | Description |
|-------|------|-------------|
| website_sessions | 472,871 | One row per site visit — traffic source, device, UTM params, timing |
| website_pageviews | 1,188,124 | One row per page viewed — reveals the full conversion funnel |
| orders | 32,313 | Completed purchases — ties revenue back to sessions |
| order_items | 40,025 | Individual line items per order — enables product and cross-sell analysis |
| order_item_refunds | 1,731 | Refunded items — net revenue and refund rate calculations |
| products | 4 | Master product catalogue |

**Date range:** March 19, 2012 — March 19, 2015

### Product Catalogue

| ID | Product | Launch | Price |
|----|---------|--------|-------|
| 1 | The Original Mr. Fuzzy | March 2012 | $49.99 |
| 2 | The Forever Love Bear | January 2013 | $59.99 |
| 3 | The Birthday Sugar Panda | December 2013 | $49.99 |
| 4 | The Hudson River Mini Bear | February 2014 | $24.99 |

> **Note:** The raw dataset is not included in this repository as it is proprietary to Maven Analytics.

---

## Challenges & Analysis

### Phase 1 — Data Quality & Preparation

#### C01 — Is Our Data Fit for Purpose?

| Issue | Count | % of Dataset | Action |
|-------|-------|--------------|--------|
| Duplicate sessions | 1 | 0.000% | Excluded — identical user_id + timestamp |
| Bad price orders | 8 | 0.001% | Excluded — price_usd = 0 or negative |
| Impossible pageviews | 10 | 0.001% | Excluded — pageview timestamp before session |
| Orphan product items | 15 | 0.001% | Excluded — product_id = 99 |
| **Total hard exclusions** | **34** | **0.002%** | Dataset confirmed clean |
| Case/spacing issues | 89+ | n/a | Fixed via LOWER(TRIM()) on all text fields |

**3-Step Data Governance Recommendation:**
1. At ingestion — reject any record where price_usd ≤ 0 or primary key already exists
2. At load — run automated duplicate detection on user_id + timestamp combinations
3. At analysis — run a standard validation script before every sprint

---

### Phase 2 — The Growth Story

#### C02 — How Big Have We Become?

| Metric | Q1 2012 | Q4 2014 | Growth |
|--------|---------|---------|--------|
| Sessions | 1,879 | 72,048 | **38x** |
| Orders | 59 | 5,681 | **96x** |
| Revenue per session | $1.57 | $5.03 | **+220%** |

**3 key inflection points:**
- **Q4 2012** — Billing page redesign converts more visitors
- **Q1 2013** — Love Bear launch expands addressable market
- **Q4 2014** — Full 4-product portfolio combined with holiday season

**Free channel growth:** 0% → **33.5%** of total orders built with zero SEO investment

---

### Phase 3 — Customer Experience & Conversion

#### C06 — What Was the Return on Our Website Investments?

| Test | Period | Lift | Monthly Value | Cumulative Value |
|------|--------|------|---------------|-----------------|
| Landing Page A/B | Jun–Jul 2012 | +0.88pp conversion | ~$497/month | ~$15,900 |
| Billing Page A/B | Sep–Nov 2012 | **+17.18pp conversion** | **~$27,800/month** | Ongoing |

The billing page test is the highest-ROI website investment in the dataset. Every month it continues to generate ~$27,800 in incremental revenue.

---

### Phase 4 — Product Strategy & Revenue Mix

#### C08 — Are We Leaving Money in the Cart?

Cross-sell feature launched alongside the Mini Bear (Product 4) in February 2014.

| Primary Product | Mini Bear attach rate | Monthly cross-sell revenue |
|----------------|----------------------|---------------------------|
| Mr. Fuzzy | 20.89% | — |
| Love Bear | 20.38% | — |
| Birthday Panda | **22.41%** (highest) | — |

**Mr. Fuzzy + Mini Bear** generated **$74,621 in 3.5 months** (~$21,800/month).

---

#### C09 — How Valuable Are Our Repeat Customers?

| Metric | Value |
|--------|-------|
| Repeat customer rate | 13.4% |
| Avg days to first repeat purchase | 32.5 days |
| Paid nonbrand repeat sessions | **Exactly 0** |
| Free channel share of repeat orders | 66.8% |
| LTV multiple (repeat vs new) | **2.67x** ($12.42 vs $4.65) |

Key insight: repeat customers never come back through paid channels — they return organically. This means every repeat purchase is effectively free to acquire.

---

### Phase 5 — Capstone

#### C10 — Why We Will Win

**$100,000 Budget Allocation:**

| Investment | Budget | Expected Monthly Return |
|------------|--------|------------------------|
| Product detail page A/B test | $40,000 | ~$26,700/month |
| Mini Bear cart optimisation | $25,000 | ~$2,374/month |
| Paid nonbrand channel scale-up | $35,000 | Est. 3–7× ROAS |
| **Total** | **$100,000** | **$29,074+/month** |

**Top 2 Risks:**
1. Birthday Panda 6.04% refund rate — apply new supplier quality framework immediately
2. 55–57% paid channel revenue concentration — invest in organic to reduce dependency

---

## Key Findings

| # | Finding | Number |
|---|---------|--------|
| 1 | Session growth (Q1 2012 → Q4 2014) | 38x (1,879 → 72,048) |
| 2 | Order growth over same period | 96x (59 → 5,681) |
| 3 | Revenue per session growth | +220% ($1.57 → $5.03) |
| 4 | Free + brand order share | 33.5% built from 0% |
| 5 | Biggest funnel leak | Product detail → cart: 43.4% conversion |
| 6 | Funnel leak revenue opportunity | +10pp fix = +$2,446/month |
| 7 | Billing page A/B monthly value | ~$27,800/month ongoing |
| 8 | Mini Bear cross-sell (best attach rate) | 22.41% from Birthday Panda |
| 9 | Cross-sell revenue (3.5 months) | $74,621 |
| 10 | Repeat customer LTV multiple | 2.67x vs new customers |
| 11 | Paid nonbrand repeat sessions | Exactly 0 |
| 12 | Total hard data exclusions | 34 records / 0.002% of dataset |
| 13 | $100K capstone projected return | $29,074+/month |

---

## Data Quality

All queries apply these cleaning rules consistently across every challenge:

```sql
-- Text standardisation (applied to all categorical fields)
LOWER(TRIM(utm_source))
LOWER(TRIM(utm_campaign))
LOWER(TRIM(device_type))
LOWER(pageview_url)

-- Bad price exclusion — in JOIN ON clause, never in WHERE
-- Using WHERE would silently convert LEFT JOINs to INNER JOINs
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
    AND o.price_usd > 0

-- Orphan product exclusion (product_id = 99 is a known test artifact)
WHERE oi.product_id != 99
-- Safe version for LEFT JOINs:
AND (oi.product_id != 99 OR oi.product_id IS NULL)

-- Organic vs direct traffic detection
COALESCE(TRIM(http_referer), '')

-- Socialbook test traffic exclusion
WHERE (LOWER(TRIM(utm_source)) != 'socialbook' OR utm_source IS NULL)
```

---

## Tools

| Tool | Purpose |
|------|---------|
| MySQL (MySQL Workbench) | All data extraction, cleaning, and analysis |
| Power BI | Dashboard and visual reporting |
| PowerPoint | Final investor presentation (20 slides) |

---

## Repository Structure

```
MavenFuzzyFactory-Hackathon/
│
├── sql/                          # All 10 challenge queries
│   ├── challenge_01_data_quality.sql
│   ├── challenge_02_the_growth_story.sql
│   ├── challenge_03_&_04_efficiency_resilience.sql
│   ├── challenge_05_conversion_funnel.sql
│   ├── challenge_06_website_A_B_Test_ROI.sql
│   ├── challenge_07_product_performance.sql
│   ├── challenge_08_Pre_Post_Cross_Sell_Feature_Launch.sql
│   ├── challenge_09_repeat_customer_behaviour.sql
│   └── challenge_10_capstone_strategic_roadmap.sql
│
├── data_quality/                 # Data cleaning decisions and exclusion log
│   └── Data_Quality_Documentation.docx
│
├── presentation/                 # Final investor presentation
│   └── team_zesto_presentation.pptx
│
└── README.md
```

---

## How to Run

```sql
USE mavenfuzzyfactory;
SOURCE sql/challenge_01_data_quality.sql;
```

1. Import the MavenFuzzyFactory schema into MySQL Workbench
2. Run queries in order: C01 → C02 → C03/C04 → C05 → C06 → C07 → C08 → C09 → C10
3. Export results as CSV from MySQL Workbench
4. Open the Power BI dashboard and refresh data source

> Queries are written in standard MySQL syntax. No additional packages or dependencies required.

---

## Deliverables

| File | Description |
|------|-------------|
| `challenge_01_data_quality.sql` | Full data audit — 6 issue categories, 34 exclusions, governance log |
| `challenge_02_the_growth_story.sql` | Quarterly sessions, orders, revenue per session, channel breakdown |
| `challenge_03_&_04_efficiency_resilience.sql` | Conversion rate, AOV, revenue per session trends, resilience score |
| `challenge_05_conversion_funnel.sql` | Full funnel drop-off, mobile vs desktop, revenue opportunity calc |
| `challenge_06_website_A_B_Test_ROI.sql` | Landing page + billing page A/B test ROI with cumulative value |
| `challenge_07_product_performance.sql` | Revenue, margin %, refund rates, supplier change impact |
| `challenge_08_Pre_Post_Cross_Sell_Feature_Launch.sql` | Pre/post cross-sell launch, attachment rate matrix by primary product |
| `challenge_09_repeat_customer_behaviour.sql` | Retention rate, LTV calc, channel mix new vs repeat customers |
| `challenge_10_capstone_strategic_roadmap.sql` | KPI summary view, $100K budget allocation, risk assessment |
| `Data_Quality_Documentation.docx` | Full written exclusion log and governance recommendations |
| `team_zesto_presentation.pptx` | 20-slide investor pitch presented at the DEBI hackathon |

---

## Results

**Top 3 finish** at the DEBI Business Analytics Hackathon
Presented as a 10-minute investor pitch with live Q&A
Every number in this README traces back to a confirmed, audited SQL result

---

*Zesto Team — Zeina Ahmed · Toka Gabr · Omar El Yemani · Saleh Hossam*
*DEBI Business Analytics Track · March 2026*

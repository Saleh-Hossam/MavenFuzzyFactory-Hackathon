<img width="1556" height="88" alt="image" src="https://github.com/user-attachments/assets/15c0e452-b5f8-4afa-8294-f43bd155d2fd" /><img width="1243" height="175" alt="image" src="https://github.com/user-attachments/assets/b981d7c4-338e-4b97-bb7c-0f954c1d3eb9" /># MavenFuzzyFactory Hackathon Analysis

**E-commerce growth analysis of MavenFuzzyFactory (2012–2015)**  
DEBI Business Analytics Hackathon · Zesto Team · March 2026

---

## Overview

MavenFuzzyFactory is a US-based online toy retailer (est. 2012). This project was submitted as part of the DEBI Business Analytics Hackathon — a 10-challenge competition requiring teams to analyse three years of e-commerce data and present findings to a simulated investor audience.

The dataset covers **472,871 sessions · 1,188,124 pageviews · 32,313 orders · 4 products** from March 2012 to March 2015.

---

## Key Findings

- **38x session growth** — from 1,879 (Q1 2012) to 72,048 (Q4 2014)
- **96x order growth** — from 59 to 5,681 orders over the same period
- **+220% revenue per session** — from $1.57 at launch to $5.03 by Q4 2014
- **33.5% of orders** now come from free channels — built with zero SEO investment
- **Biggest funnel leak identified:** product detail → cart converts at only 43.4% vs 68%+ everywhere else — a +10pp fix generates $2,446/month

---

## My Contributions

This was a four-person team project. I personally owned the following challenges:

| Challenge | Topic |
|-----------|-------|
| C01 | Data Quality — cleaning decisions, exclusion log, governance recommendations |
| C02 | Overall Growth Story How Big Have We Become? Sessions & Orders by Quarter — Full Business Lifecycle |
| C06 | Website A/B Test ROI — landing page and billing page test analysis, cumulative revenue impact |
| C08 | Cross-Sell Analysis — Mini Bear attachment rates, AOV impact |
| C10 | Capstone & Strategic Roadmap — three strategic recommendations, $100K budget allocation |

I also reviewed and validated the SQL and findings for C03, C04, C05, and C09 as part of the team QA process.

---

## Tools

- **MySQL** — all queries written and tested in MySQL Workbench
- **PowerPoint** — final investor presentation

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

## Dataset

Source: MavenFuzzyFactory training dataset  
Range: March 19, 2012 – March 19, 2015  
Database: MySQL

> **Note:** The raw dataset is not included in this repository as it is proprietary to Maven Analytics.

---

## Team

Zesto Team — Zeina Ahmed · Toka Gabr · Omar El Yemani · Saleh Hossam  
*DEBI Business Analytics Track · March 2026*# MavenFuzzyFactory-Hackathon
E-commerce growth analysis of MavenFuzzyFactory (2012–2015) — DEBI Business Analytics Hackathon, Zesto Team

# Examples

These examples demonstrate FastCSV's API using real-world transit ridership data from the Chicago Transit Authority (CTA).

**New to FastCSV?** Start with the [project README](../README.md) — it covers every concept with examples.

## Sample Data

`cta-ridership.csv` contains monthly ridership averages and totals for every CTA bus route from January 2001 through early 2026 — approximately 40,000 rows across 7 columns:

| Column | Type | Description |
|--------|------|-------------|
| `route` | String | Route number (e.g., "9", "X21", "8A") |
| `routename` | String | Route name (e.g., "Ashland", "King Drive") |
| `Month_Beginning` | String | First day of month (`MM/dd/yyyy`) |
| `Avg_Weekday_Rides` | Double | Average weekday ridership for that month |
| `Avg_Saturday_Rides` | Double | Average Saturday ridership (0 if route doesn't run) |
| `Avg_Sunday-Holiday_Rides` | Double | Average Sunday/holiday ridership (0 if route doesn't run) |
| `MonthTotal` | Int | Total rides for the month |

## Running

The examples are a standalone Swift package. From this directory:

```bash
swift run Filtering
swift run Aggregation
swift run Writing
swift run RawAccess
```

## Examples

| Target | Source | What it demonstrates |
|--------|--------|----------------------|
| `Filtering` | [main.swift](Sources/Filtering/main.swift) | Query and filter rows — simple guards, top-10, weekend service, COVID impact |
| `Aggregation` | [main.swift](Sources/Aggregation/main.swift) | Accumulate statistics over 40K rows in constant memory |
| `Writing` | [main.swift](Sources/Writing/main.swift) | Read, transform, and write back out — the full round-trip |
| `RawAccess` | [main.swift](Sources/RawAccess/main.swift) | Array and dictionary iterators for schema-less CSV exploration |

## Data Attribution

**Source:** [Chicago Transit Authority (CTA) — Ridership — Bus Routes — Monthly Day-Type Averages & Totals](https://data.cityofchicago.org/Transportation/CTA-Ridership-Bus-Routes-Monthly-Day-Type-Averages/jyb9-n7fm)

**Publisher:** City of Chicago

**License:** See the [CTA Developer Terms of Use](https://www.transitchicago.com/developers/terms/) for details.

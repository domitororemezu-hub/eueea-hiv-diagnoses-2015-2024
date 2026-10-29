# Data sources

All files in `data/raw` were extracted from public documents. PDF tables were read with pdf.js text extraction and
checked against the totals printed in the same tables; page numbers below are positions in the PDF file. Counts are
copied exactly as printed; no value was corrected, imputed or redistributed.

## ECDC/WHO Regional Office for Europe, HIV/AIDS surveillance in Europe 2025 – 2024 data

European Centre for Disease Prevention and Control, WHO Regional Office for Europe. HIV/AIDS surveillance in Europe
2025 – 2024 data. Stockholm: ECDC; 2025.
Report page: https://www.ecdc.europa.eu/en/publications-data/hivaids-surveillance-europe-2025-2024-data
PDF: https://www.ecdc.europa.eu/sites/default/files/documents/2025-Annual-HIV-Report.pdf (accessed 13 October 2026)

| File | Source table (PDF pages) | Content |
|---|---|---|
| `ecdc2025_tables2to7.csv` | Table 2, males (64–65); Table 3, females (66–67); Table 4, men who have sex with men (68); Table 5, people who inject drugs (69); Table 6, heterosexual contact (70); Table 7, mother-to-child transmission (71) | Annual HIV diagnoses 2015–2024 for the 30 EU/EEA countries and the EU/EEA total; columns `table`, `series`, `country`, `2015`–`2024` |
| `ecdc2025_table8_2024.csv` | Table 8 (72–73) | 2024 diagnoses by transmission mode and sex (male, female, transgender), including unknown mode and the total |
| `ecdc2025_table10_2024.csv` | Table 10 (76–77) | 2024 diagnoses by region of origin (number and %), including unknown origin and the total |

Checks: for every series and year, the sum of the 30 countries equals the EU/EEA total printed in Tables 2–7
(60 series-years); the country sums of Table 8 (24,084) and Table 10 (24,164 diagnoses; 2,992 of unknown origin)
equal the printed EU/EEA totals.

## Region of origin, 2015–2024 (`ecdc_origin_cee_2015-2024.csv`)

Diagnoses among people originating from Central and Eastern Europe, diagnoses of unknown origin and all diagnoses, by
country of report, from the origin table of each annual report (column `source`). Cells for countries that did not
report region of origin in a year are `NA` (for the nine countries in Figure 4: Germany 2017 and Belgium 2019).

| Data year | Report | Table (PDF pages) | PDF |
|---|---|---|---|
| 2015 | HIV/AIDS surveillance in Europe 2015 (2016) | Table 11 (78–79) | https://www.ecdc.europa.eu/sites/portal/files/media/en/publications/Publications/HIV-AIDS-surveillance-Europe-2015.pdf |
| 2016 | HIV/AIDS surveillance in Europe 2017 – 2016 data | Table 11 (76–77) | https://www.ecdc.europa.eu/sites/default/files/documents/20171127-Annual_HIV_Report_Cover%2BInner.pdf |
| 2017 | HIV/AIDS surveillance in Europe 2018 – 2017 data | Table 11 (86–87) | https://www.ecdc.europa.eu/sites/default/files/documents/hiv-aids-surveillance-europe-2018.pdf |
| 2018 | HIV/AIDS surveillance in Europe 2019 – 2018 data | Table 10 (80–81) | https://www.ecdc.europa.eu/sites/default/files/documents/hiv-surveillance-report-2019.pdf |
| 2019 | HIV/AIDS surveillance in Europe 2020 – 2019 data | Table 10 (82–83) | https://www.ecdc.europa.eu/sites/default/files/documents/hiv-surveillance-report-2020.pdf |
| 2020 | HIV/AIDS surveillance in Europe 2021 – 2020 data | Table 10 (78–79) | https://www.ecdc.europa.eu/sites/default/files/documents/2021-Annual_HIV_Report_0.pdf |
| 2021 | HIV/AIDS surveillance in Europe 2022 – 2021 data | Table 10 (78–79) | https://www.ecdc.europa.eu/sites/default/files/documents/2022-Annual_HIV_Report_final.pdf |
| 2022 | HIV/AIDS surveillance in Europe 2023 – 2022 data | Table 10 (82–83) | https://www.ecdc.europa.eu/sites/default/files/documents/HIV-AIDS_surveillance_in_Europe_2023_%28_2022_data_%29_0.pdf |
| 2023 | HIV/AIDS surveillance in Europe 2024 – 2023 data | Table 10 (74–75) | https://www.ecdc.europa.eu/sites/default/files/documents/HIV_Surveillance_Report_2024.pdf |
| 2024 | HIV/AIDS surveillance in Europe 2025 – 2024 data | Table 10 (76–77) | as above |

All accessed 13 October 2026. The ECDC Central and Eastern Europe region-of-origin category is not Ukraine-specific.

## Eurostat, temporary protection (`eurostat_migr_asytpspop_UA_dec2022-2024.csv`)

Eurostat. Beneficiaries of temporary protection by citizenship - per thousand persons (`migr_asytpspop`),
Ukrainian citizens, December 2022, December 2023 and December 2024.
Data browser: https://ec.europa.eu/eurostat/databrowser/view/migr_asytpspop
Extracted with the Eurostat dissemination API on 13 October 2026 (dataset last updated 12 October 2026):
`https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/migr_asytpspop?format=JSON&lang=EN&citizen=UA&time=2022-12&time=2023-12&time=2024-12`

Values are as published; Eurostat flags (for example `[d]`, definition differs) are kept in the file and removed
when the values are read (`R/00_setup.R`). Denmark and Norway are not bound by the EU Temporary
Protection Directive; their values refer to persons protected under similar national schemes (Denmark's special act,
Norway's temporary collective protection). Eurostat revises these series; values extracted on another date can differ slightly.

## Reuse conditions

- ECDC/WHO reports: © European Centre for Disease Prevention and Control; reproduction is authorised, provided the
  source is acknowledged. © World Health Organization, some rights reserved (see the copyright notice of each report).
- Eurostat: reuse is authorised provided the source is acknowledged (Eurostat copyright notice; Creative Commons
  Attribution 4.0 International licence).

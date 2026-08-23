# Wispr usage statistics reference

Date: 2026-08-24

## Question

Which parts of Wispr Flow's usage dashboard are useful for OpenYap, and which parts can be calculated from local data?

## Primary sources

- Wispr's [Your Usage guide](https://docs.wisprflow.ai/articles/8760230576-your-usage-tab-track-your-dictation-stats-in-wispr-flow) documents the desktop WPM gauge, corrections, total words, app-usage bars, and streak heatmap. The page includes screenshots of the current dashboard.
- Wispr's [navigation guide](https://docs.wisprflow.ai/articles/5096240724-navigating-the-wispr-flow-app-desktop-ios-and-android) shows the smaller Home statistics card and its separate Insights navigation.
- Wispr's [team usage methodology](https://docs.wisprflow.ai/articles/5936327641-team-insights-measuring-the-impact-of-wispr-flow-rollout-admin-usage-page) uses 40 WPM as its typing-speed baseline.
- Wispr's [What is Flow? guide](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) describes word counts, WPM, and streaks as product feedback for dictation use.

## Findings

The useful pattern is the dashboard hierarchy, not Wispr's branding. One speed visualization leads into compact totals. Corrections, activity, and destination apps sit in separate cards below it. This keeps the first screen readable while leaving room for detailed local data.

OpenYap can calculate weighted WPM, words, characters, capture duration, correction counts, streaks, and heatmap intensity from existing dictation sessions. It cannot make a defensible global percentile claim because OpenYap has no server analytics or comparison population.

Time saved is an estimate. OpenYap compares the measured capture duration with the time required to type the same raw word count at 40 WPM. It does not assume that every person dictates at a fixed speed.

## OpenYap adaptation

- Use a Statistics sidebar tab with a WPM gauge, summary cards, correction counts, a 12-week heatmap, and app-usage bars.
- Use OpenYap terminology, Catppuccin colors, SF Symbols, and native macOS controls. Do not copy Wispr's assets or exact layout measurements.
- Store daily numeric aggregates and destination app identifiers locally. Do not add transcript text or audio to the statistics data.
- Keep statistics after transcript retention removes text. Provide a separate Reset Statistics action.
- Backfill existing retained sessions. Their destination app is unknown because older history did not store that information.

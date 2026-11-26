# Lootrack roadmap

## v1.0 Fully functional release

- [ ] **Record transactions in multiple currencies (release blocker).** Choose a currency for each expense or income, defaulting to the app’s currency setting. Preserve the original amount and currency through edits and Google Sheets sync. Migrate existing records safely and show separate dashboard totals for each currency.
- [ ] **Polish the Add Transaction flow.** Make everyday manual entry quick, with useful defaults, a clear path from amount to Save, and easy access to date, category, and currency when they need changing.
- [ ] **Complete custom widget creation (started).** Replace the numeric and chart placeholders with a setup flow. Let users choose what the widget shows, preview it, save it, and add it to the dashboard.
- [ ] **Open widget details on tap.** Let users tap built-in and custom dashboard widgets to see a larger view, the date range, and the transactions or breakdown behind the numbers.
- [ ] **Refresh in the background.** Refresh the configured sync provider when iOS grants background time. Catch up when the app reopens, including after a force quit. [Apple’s background refresh guidance](https://developer.apple.com/forums/thread/721584)
- [ ] **Hide existing Apple Foundation Models suggestions for launch.** Keep category and subcategory suggestions hidden in the public v1.0 build.

**Suggested release check.** Verify that users can create, edit, delete, and find transactions offline, then sync after reconnecting without losing or duplicating entries. Start with multi-currency because it affects transaction storage, sync, and both widget surfaces.

## v2.0 Sync and data portability

- [ ] **Add iCloud as a sync provider.** Offer iCloud alongside Google Sheets and support switching providers while preserving local records.
- [ ] **Import and export all app data.** Export a restorable backup of transactions, categories, subcategories, tags, dashboard widgets and layout, and preferences. Verify that it restores into a fresh install and keeps transaction currencies intact.

**Other features to consider**

- Recurring transactions for rent, subscriptions, and salary.
- A combined dashboard total in a chosen reporting currency, with the exchange rate and its date available for review.

## v3.0 Utilities and Apple Foundation Models

- [ ] **Ship the Apple Foundation Models integration.** Decide which utilities to ship, starting with the category and subcategory suggestions already in development.
- [ ] **Add AI-assisted transaction dictation.** Let users say “€28 for dinner yesterday” and use AFM to prefill the Add Transaction form from the transcript. Let users review and edit the fields before saving.

**Ideas to explore before picking the first utility**

- Find transactions with a query such as “restaurants in October.”
- Add a Shortcuts action that opens a prefilled transaction form.

## v4.0 and later Nice-to-haves

- [ ] **Suggest the local currency when traveling.** With location access enabled, detect that the user has entered another country and ask whether to use its currency as the default for new transactions.

**Other feature to consider**

- An optional travel summary that groups spending during a trip by category and currency.

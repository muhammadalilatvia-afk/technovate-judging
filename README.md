# Ajou Technovate Hackathon — Digital Judging System

Open-source, free judging platform built for the **Ajou Technovate Hackathon 2026 (3.0)** at Ajou University in Tashkent.

- **Judges** score each team on their own computer (5 criteria × 0–10).
- **Live screen** on the projector shows the team on stage, which judges have scored, and the real-time ranking.
- **Organizer panel** controls rounds, the team on stage, when scoring is open, and exports all results.
- **Database** (Supabase, free tier) stores everything permanently; results can be downloaded as CSV/JSON and reused next year.

- **Presentation portal**: each team uploads its PPT/PDF and a team photo with its team code and private 6-digit upload code.
- **Team photos everywhere**: full-screen *Team intro* before each pitch, photos on the live board, podium, judge screens and organizer panel.
- **Organizer dashboard**: teams, students, uploads, judging progress per round and judge, and a live activity feed.

| Page | Who uses it |
| --- | --- |
| `index.html` | Home page with links |
| `upload.html` | Teams upload their presentation |
| `live.html` | Big screen in the hall |
| `judge.html` | The 5 judges (personal PIN) |
| `admin.html` | Organizers (organizer PIN): dashboard, event control, presentations, teams, rounds, judges, results |

Add `?demo` to any page URL to rehearse without touching the real database.

No build step: plain HTML, CSS and JavaScript. Hosting on GitHub Pages is free.

---

## 1. Try it right now (demo mode)

With `js/config.js` left empty the site runs in **demo mode**: data is kept in the browser, and tabs in the same browser stay in sync. Good for rehearsals on one laptop.

```bash
python -m http.server 8080
```

Open <http://localhost:8080>. Demo PINs: organizer `0000`, judges `1111`, `2222`, `3333`.

## 2. Go live with a free Supabase database (≈10 minutes)

1. Create a free account at <https://supabase.com> and a **New project** (region: closest to Uzbekistan, e.g. Frankfurt).
2. Open **SQL Editor → New query**, paste the whole of [`supabase/schema.sql`](supabase/schema.sql) and press **Run**.
   Then do the same with [`supabase/002_presentations_dashboard.sql`](supabase/002_presentations_dashboard.sql) (presentation uploads + dashboard) , [`supabase/003_edit_judges.sql`](supabase/003_edit_judges.sql) , [`supabase/004_team_photos.sql`](supabase/004_team_photos.sql) and [`supabase/005_auto_advance.sql`](supabase/005_auto_advance.sql).
3. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key into [`js/config.js`](js/config.js).
4. Commit and push. Open `admin.html` — the first visit asks you to choose the organizer PIN.

The anon key is meant to be public. Reading is limited to teams, line-ups and aggregated scores; every change goes through SQL functions that check the organizer or judge PIN (stored as bcrypt hashes). Individual judges' scores and comments are visible only in the organizer panel.

## 3. Publish on GitHub Pages

1. Create a public repository and push this folder to the `main` branch.
2. In the repository: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. The included workflow (`.github/workflows/pages.yml`) publishes the site at `https://<user>.github.io/<repo>/`.

## 4. Before the event

1. **Teams tab** → upload the Google Form responses CSV (*File → Download → CSV*). Phone numbers, e-mails, Telegram usernames and student IDs are **not** imported. Duplicate submissions by the same leader are merged. Teams from IT Business (not 1st/2nd/4th year) are marked for Round 1 — adjust the checkboxes if needed.
2. **Judges tab** → add the 5 judges with a personal PIN each (use *Generate random PIN*). Give each judge their PIN privately.
3. **Rounds tab** → *Build line-up* for Round 1. Optionally shuffle the presentation order.
4. **Presentations tab** → *Team upload codes (CSV)* → send each team leader their team code + 6-digit upload code. Teams upload at `upload.html` (PPTX/PPT/PDF, max 50 MB, can replace until you press *Close uploads* on the dashboard). On stage, open the team's slides from the 📎 link in *Event control*.
5. Do a dry run: open `live.html` on the projector, `judge.html` on the judges' computers, `admin.html` on the organizer laptop.

## 5. On the day

| Step | Organizer panel |
| --- | --- |
| Team walks on stage | **Put on stage** (or *Next team ▶*) — every judge screen switches to that team |
| Presentation ends | **Scoring: open** — judges submit; the live screen ticks each judge off |
| All judges scored | Live screen reveals the team's score and rank. Click *Next team ▶* |
| Round 1 finished | Automatic: when every team has every judge's score, the top 20 + teams that skip Round 1 move into Round 2. Click **▶ Start Round 2** in the green banner |
| Round 2 finished | Automatic: the top 5 move into the Final. Click **▶ Start Final** |
| Awards | Live screen view **Winners** shows the podium. Use *Scores visible: hidden* to keep results secret until the reveal |
| After each round | Results tab → download **Ranking CSV**, **All judge scores CSV** and the **Full backup (JSON)** |

### Scoring

| Criterion | Points |
| --- | --- |
| Innovation & Creativity | 0–10 |
| Problem & Real-World Value | 0–10 |
| Feasibility & Technical Execution | 0–10 |
| Market & Impact Potential | 0–10 |
| Presentation & Q&A | 0–10 |

A team's score = average of the judges' totals, scaled to 100. Ties are broken by the Innovation average. Judges can correct their own scores while scoring is open.

### Awards (2026)

| Round | Award |
| --- | --- |
| Round 1 (IT Business 3rd year) | 1st: 600,000 UZS + certificate · 2nd: 300,000 UZS + certificate · 3rd: certificate · top 20 qualify |
| Round 2 (all Ajou teams) | Top 10: certificate · top 5 qualify for the Final |
| Final | 1st: cash prize + certificate + gift · 2nd and 3rd: certificate + gift |

## Reusing next year

Change dates and texts in `js/config.js`, `index.html` and the rounds/criteria rows at the top of `supabase/schema.sql`, then re-run the SQL (it resets the database).

## License

MIT — free to use and adapt.

## Updating the site

After changing any file in `js/` or `assets/app.css`, change the version stamp `?v=...` in the five HTML pages and in `js/common.js` (search for `?v=`) so browsers load the new files immediately instead of a cached copy.

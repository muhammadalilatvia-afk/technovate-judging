// ---------------------------------------------------------------------------
// Connect the site to your free Supabase database.
// Supabase → Project Settings → API: copy "Project URL" and the "anon public" key.
// Leave both empty to run in DEMO MODE (data stays in this browser only).
// The anon key is designed to be public; every write is protected by PINs in the database.
// ---------------------------------------------------------------------------
export const SUPABASE_URL = "https://delmbhgbgkdncfqnzyxe.supabase.co";
export const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlbG1iaGdiZ2tkbmNmcW56eXhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0OTM0MTUsImV4cCI6MjExMDA2OTQxNX0.ByAkYOFY4v3VrhuvKw7Iz8gjHJq1KsggY-axpt4bf0o";

// Add ?demo to any page URL to rehearse in demo mode without touching the real database.
export const FORCE_DEMO = new URLSearchParams(location.search).has("demo");

export const UPLOAD = {
  maxMb: 50,
  accept: ".pptx,.ppt,.pdf",
  deadline: "Monday, 16 November 2026, 23:59 (Tashkent time)",
};

export const EVENT = {
  name: "Ajou Technovate Hackathon 2026",
  edition: "3.0",
  date: "18 November 2026",
  venue: "Angor Hall, Ajou University in Tashkent",
  telegram: "https://t.me/AJOUH2025",
};

// Event-day judge roster and the panel for each round (names must match the Judges tab exactly).
// "Add event judges" creates missing accounts; "Go live" / "Start Round 2" / "Start Final" activate the matching panel.
const AI_JUDGE = "AI Innovation & Evaluation Judge";
export const JUDGE_PANELS = {
  1: ["Siroj Khayitov", "Egamberdiyev Oybek", "Mirjakhon", "Aziza Tukhtaeva", "Zulfiya Anvarbekovna", AI_JUDGE],
  2: ["Azamat Toshtemirov", "Dr Irtaza Nawaz", "Tehmina Rafi", "Zulfiya Anvarbekovna", AI_JUDGE],
  3: ["Dr Sajid Khan", "Dr Adnan Manzoor", "Dr Muhammad Bilal", AI_JUDGE],
};
export const JUDGE_ROSTER = [...new Set([...JUDGE_PANELS[1], ...JUDGE_PANELS[2], ...JUDGE_PANELS[3]])];

// Rounds whose results are shown on results.html (Results screen). Add 2 / 3 when they are announced.
export const PUBLISHED_RESULTS = [1];
// Rounds where the winners podium + scores are shown. Until then only the qualified teams are listed (by team code, no scores).
export const SHOW_WINNERS = [];
export const ROUND_PRIZES = {
  1: { 1: "600,000 UZS + Certificate", 2: "300,000 UZS + Certificate", 3: "Certificate" },
  2: { 1: "Certificate", 2: "Certificate", 3: "Certificate" },
  3: { 1: "1st Place", 2: "2nd Place", 3: "3rd Place" },
};

// Result appeals (appeal.html). Teams can appeal until this moment; organizers reply within APPEAL_REVIEW_DAYS.
// The database has its own copy of the deadline in supabase/008_appeals.sql (_appeal_deadline).
export const APPEAL_DEADLINE = "2026-11-25T23:59:59+05:00";
export const APPEAL_REVIEW_DAYS = 7;

// Results page: ranked positions shown per round (positions only, no scores), e.g. Round 1 → top 10.
export const SHOW_POSITIONS = { 1: 10 };

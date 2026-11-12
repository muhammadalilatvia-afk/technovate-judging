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
  deadline: "17 November 2026, 23:59",
};

export const EVENT = {
  name: "Ajou Technovate Hackathon 2026",
  edition: "3.0",
  date: "18 November 2026",
  venue: "Angor Hall, Ajou University in Tashkent",
  telegram: "https://t.me/AJOUH2025",
};

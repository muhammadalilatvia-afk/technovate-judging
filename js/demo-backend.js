// Demo backend: same API as the Supabase backend, stored in this browser's localStorage.
// Tabs in the same browser stay in sync through BroadcastChannel, so you can rehearse
// with the admin, judge and live screen open side by side.

const KEY = "technovate-demo-v1";
const channel = "BroadcastChannel" in window ? new BroadcastChannel(KEY) : null;
const ADMIN_PIN = "0000";

const ROUNDS = [
  { id: 1, name: "Round 1", qualify_top: 20, award_top: 3, description: "IT Business 3rd-year teams · Top 20 qualify · Top 3 win Round 1 prizes" },
  { id: 2, name: "Round 2", qualify_top: 5, award_top: 10, description: "All Ajou University teams · Top 10 get certificates · Top 5 go to the Final" },
  { id: 3, name: "Final", qualify_top: 3, award_top: 3, description: "Top 5 teams compete for 1st, 2nd and 3rd place" },
];
const CRITERIA = [
  { id: 1, name: "Innovation & Creativity", description: "How new and original is the idea?", max_points: 10, position: 1 },
  { id: 2, name: "Problem & Real-World Value", description: "Does it solve a real, important problem?", max_points: 10, position: 2 },
  { id: 3, name: "Feasibility & Technical Execution", description: "Does it work? Quality of the app, website or business model", max_points: 10, position: 3 },
  { id: 4, name: "Market & Impact Potential", description: "Market size, users, social or economic impact", max_points: 10, position: 4 },
  { id: 5, name: "Presentation & Q&A", description: "Clarity, confidence, teamwork and answers to judges", max_points: 10, position: 5 },
];
const SAMPLE = [
  ["T01", "CampusGo – smart campus navigation", "Aziza K.; Bekzod T.; Malika R.", "IT Business", true],
  ["T02", "AgroSense – IoT for small farms", "Javohir N.; Dilnoza S.", "IT Business", true],
  ["T03", "MedQueue – clinic booking app", "Sardor A.; Kamola Y.; Timur B.", "IT Business", true],
  ["T04", "EcoRide – shared e-scooters", "Nodira M.; Islom F.", "IT Business", true],
  ["T05", "TutorLink – peer tutoring", "Shahzod O.; Madina I.; Ali V.", "IT Business", true],
  ["T06", "PayLite – student wallet", "Ulugbek Q.", "IT Business", true],
  ["T07", "Retail AI shelf scanner", "Rustam H.; Laylo P.", "ECE", false],
  ["T08", "SilkRoad Tours marketplace", "Gulnora E.; Doniyor Z.; Asal T.", "IR", false],
];

function fresh() {
  return {
    teams: SAMPLE.map(([code, project, members, department, round1], i) => ({ id: i + 1, code, project, members, department, round1 })),
    round_teams: [],
    judges: [
      { id: 1, name: "Judge 1", pin: "1111", active: true },
      { id: 2, name: "Judge 2", pin: "2222", active: true },
      { id: 3, name: "Judge 3", pin: "3333", active: true },
    ],
    scores: [],
    state: { active_round: 1, current_team_id: null, scoring_open: false, show_scores: true, view: "board", message: "", version: 0 },
    nextTeamId: SAMPLE.length + 1,
    nextJudgeId: 4,
  };
}
function load() {
  try { return JSON.parse(localStorage.getItem(KEY)) || fresh(); } catch { return fresh(); }
}
function save(db) {
  db.state.version++;
  localStorage.setItem(KEY, JSON.stringify(db));
  channel?.postMessage("changed");
  listeners.forEach((fn) => fn());
}
const listeners = new Set();
channel && (channel.onmessage = () => listeners.forEach((fn) => fn()));
window.addEventListener("storage", (e) => e.key === KEY && listeners.forEach((fn) => fn()));

const maxTotal = CRITERIA.reduce((a, c) => a + c.max_points, 0);
const needAdmin = (pin) => { if (pin !== ADMIN_PIN) throw new Error("Wrong admin PIN"); };
const judgeBy = (db, pin) => db.judges.find((j) => j.active && j.pin === pin);
const delay = (v) => Promise.resolve(v);

export const demoBackend = {
  mode: "demo",
  subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); },
  getRounds: () => delay(ROUNDS),
  getCriteria: () => delay(CRITERIA),
  getState: () => delay(load().state),
  getTeams: () => delay(load().teams),
  getRoundTeams: (round) => delay(load().round_teams.filter((r) => r.round_id === round)),
  getLeaderboard(round) {
    const db = load();
    return delay(db.round_teams.filter((r) => r.round_id === round).map((rt) => {
      const t = db.teams.find((x) => x.id === rt.team_id) || {};
      const s = db.scores.filter((x) => x.round_id === round && x.team_id === rt.team_id);
      const avg = (f) => (s.length ? s.reduce((a, x) => a + f(x), 0) / s.length : 0);
      return { round_id: round, team_id: rt.team_id, code: t.code, project: t.project, members: t.members, department: t.department,
               position: rt.position, judges: s.length, score: +(avg((x) => x.total) * 100 / maxTotal).toFixed(2),
               innovation: +avg((x) => +x.criteria["1"]).toFixed(2) };
    }));
  },
  getJudgeProgress() {
    const db = load(), st = db.state;
    return delay(db.judges.filter((j) => j.active).map((j) => ({
      judge_id: j.id, name: j.name, round_id: st.active_round,
      scored: db.scores.filter((s) => s.judge_id === j.id && s.round_id === st.active_round).length,
      scored_current: db.scores.some((s) => s.judge_id === j.id && s.round_id === st.active_round && s.team_id === st.current_team_id),
    })));
  },

  // judges
  judgeLogin(pin) { const j = judgeBy(load(), pin); return delay(j ? { id: j.id, name: j.name } : null); },
  judgeScores(pin, round) {
    const db = load(), j = judgeBy(db, pin);
    if (!j) throw new Error("Wrong judge PIN");
    return delay(db.scores.filter((s) => s.judge_id === j.id && s.round_id === round));
  },
  submitScore(pin, round, team, criteria, comment) {
    const db = load(), j = judgeBy(db, pin);
    if (!j) throw new Error("Wrong judge PIN");
    if (!db.state.scoring_open) throw new Error("Scoring is closed by the organizer");
    if (round !== db.state.active_round) throw new Error("This round is not active");
    if (!db.round_teams.some((r) => r.round_id === round && r.team_id === team)) throw new Error("Team is not in this round");
    let total = 0; const clean = {};
    for (const c of CRITERIA) {
      const v = Number(criteria[c.id]);
      if (criteria[c.id] === undefined || Number.isNaN(v)) throw new Error(`Missing score for "${c.name}"`);
      if (v < 0 || v > c.max_points) throw new Error(`Score for "${c.name}" must be 0–${c.max_points}`);
      clean[c.id] = v; total += v;
    }
    db.scores = db.scores.filter((s) => !(s.round_id === round && s.team_id === team && s.judge_id === j.id));
    db.scores.push({ round_id: round, team_id: team, judge_id: j.id, criteria: clean, total, comment: comment || "", updated_at: new Date().toISOString() });
    save(db);
    return delay(total);
  },

  // admin
  adminStatus: () => delay({ configured: true }),
  adminSetup: () => delay(false),
  adminCheck: (pin) => delay(pin === ADMIN_PIN),
  adminChangePin() { throw new Error("In demo mode the admin PIN is always 0000"); },
  adminSetState(pin, patch) { needAdmin(pin); const db = load(); Object.assign(db.state, patch); save(db); return delay(); },
  adminImportTeams(pin, rows, replace) {
    needAdmin(pin); const db = load();
    if (replace) { db.teams = []; db.round_teams = []; db.scores = []; db.state.current_team_id = null; }
    for (const r of rows) {
      const ex = db.teams.find((t) => t.code === r.code);
      if (ex) Object.assign(ex, r); else db.teams.push({ id: db.nextTeamId++, ...r });
    }
    save(db); return delay(rows.length);
  },
  adminUpdateTeam(pin, id, patch) { needAdmin(pin); const db = load(); Object.assign(db.teams.find((t) => t.id === id), patch); save(db); return delay(); },
  adminDeleteTeam(pin, id) {
    needAdmin(pin); const db = load();
    db.teams = db.teams.filter((t) => t.id !== id); db.round_teams = db.round_teams.filter((r) => r.team_id !== id);
    db.scores = db.scores.filter((s) => s.team_id !== id); if (db.state.current_team_id === id) db.state.current_team_id = null;
    save(db); return delay();
  },
  adminSetRoundTeams(pin, round, ids) {
    needAdmin(pin); const db = load();
    db.round_teams = db.round_teams.filter((r) => r.round_id !== round).concat(ids.map((id, i) => ({ round_id: round, team_id: id, position: i + 1 })));
    save(db); return delay(ids.length);
  },
  adminAddJudge(pin, name, judgePin) {
    needAdmin(pin); const db = load();
    if (String(judgePin).length < 4) throw new Error("Judge PIN must have at least 4 characters");
    if (db.judges.some((j) => j.active && j.pin === judgePin)) throw new Error("This PIN is already used by another judge");
    db.judges.push({ id: db.nextJudgeId++, name, pin: judgePin, active: true }); save(db); return delay();
  },
  adminSetJudgeActive(pin, id, active) { needAdmin(pin); const db = load(); db.judges.find((j) => j.id === id).active = active; save(db); return delay(); },
  adminListJudges(pin) {
    needAdmin(pin); const db = load();
    return delay(db.judges.map((j) => ({ id: j.id, name: j.name, active: j.active, scores: db.scores.filter((s) => s.judge_id === j.id).length })));
  },
  adminScores(pin, round) {
    needAdmin(pin); const db = load();
    return delay(db.scores.filter((s) => s.round_id === round).map((s) => {
      const t = db.teams.find((x) => x.id === s.team_id) || {}, j = db.judges.find((x) => x.id === s.judge_id) || {};
      return { ...s, code: t.code, project: t.project, judge_name: j.name };
    }));
  },
  adminResetRound(pin, round) { needAdmin(pin); const db = load(); const n = db.scores.length; db.scores = db.scores.filter((s) => s.round_id !== round); save(db); return delay(n - db.scores.length); },
  resetDemo() { localStorage.removeItem(KEY); save(load()); },
};

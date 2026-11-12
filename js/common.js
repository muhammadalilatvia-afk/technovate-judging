import { SUPABASE_URL, SUPABASE_ANON_KEY, EVENT, FORCE_DEMO, UPLOAD } from "./config.js?v=20261113b";
import { demoBackend } from "./demo-backend.js?v=20261113b";

export { EVENT, UPLOAD };

export async function getApi() {
  if (SUPABASE_URL && SUPABASE_ANON_KEY && !FORCE_DEMO) {
    const { supabaseBackend } = await import("./supabase-backend.js?v=20261113b");
    return supabaseBackend(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return demoBackend;
}

export const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const $ = (sel, root = document) => root.querySelector(sel);
export const fmt = (n) => (Math.round(Number(n) * 10) / 10).toFixed(1);

/** Rank a leaderboard: scored teams by score, then innovation, then code; unscored teams last. */
export function rank(rows) {
  const scored = rows.filter((r) => r.judges > 0).sort((a, b) =>
    b.score - a.score || b.innovation - a.innovation || String(a.code).localeCompare(String(b.code)));
  let prev = null;
  scored.forEach((r, i) => {
    r.rank = prev && prev.score === r.score && prev.innovation === r.innovation ? prev.rank : i + 1;
    prev = r;
  });
  const unscored = rows.filter((r) => !r.judges).sort((a, b) => a.position - b.position).map((r) => ({ ...r, rank: null }));
  return [...scored, ...unscored];
}

export function toast(msg, kind = "ok") {
  let box = $("#toasts");
  if (!box) { box = document.createElement("div"); box.id = "toasts"; document.body.append(box); }
  const el = document.createElement("div");
  el.className = `toast ${kind}`; el.textContent = msg; box.append(el);
  setTimeout(() => el.remove(), 4200);
}

export function modeBadge(api) {
  if (api.mode !== "demo") return "";
  return `<span class="badge demo" title="Data is stored only in this browser. Add your Supabase keys in js/config.js to go live.">DEMO MODE</span>`;
}

export function brand(sub = "") {
  return `<a class="brand" href="index.html">
    <img src="assets/technovate-mark.svg" alt="" width="40" height="40">
    <span><b>AJOU TECHNOVATE</b><small>HACKATHON 3.0${sub ? " · " + esc(sub) : ""}</small></span></a>`;
}

/** Minimal RFC 4180 CSV parser. */
export function parseCsv(text) {
  const rows = []; let row = [], cell = "", q = false;
  text = text.replace(/^﻿/, "");
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') q = false;
      else cell += ch;
    } else if (ch === '"') q = true;
    else if (ch === ",") { row.push(cell); cell = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(cell); rows.push(row); row = []; cell = "";
    } else cell += ch;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim()));
}

export function toCsv(rows) {
  return rows.map((r) => r.map((c) => {
    const s = String(c ?? "");
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(",")).join("\n");
}

export function download(name, text, type = "text/csv") {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["﻿" + text], { type: type + ";charset=utf-8" }));
  a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

const cap = (n) => n.split(" ").map((w) => (w === w.toUpperCase() || w === w.toLowerCase()) ? w.charAt(0).toUpperCase() + w.slice(1).toLowerCase() : w).join(" ");

/**
 * Turn an uploaded CSV into team rows. Accepts either
 *  - the site's own format: code, project, members, department, round1
 *  - the Google Form export (Team Leader Name:, Team Member Name 1:, Project Name:, Your Department, Year of study, ...)
 * Contact details (phone, e-mail, Telegram, student ID) are never kept.
 */
export function teamsFromCsv(text) {
  const [head, ...body] = parseCsv(text);
  const h = head.map((x) => x.trim().toLowerCase());
  const col = (...names) => h.findIndex((x) => names.some((n) => x.startsWith(n)));
  if (col("code") >= 0 && col("project") >= 0) {
    const ci = col("code"), pi = col("project"), mi = col("members"), di = col("department"), ri = col("round1");
    return body.map((r) => ({ code: r[ci].trim(), project: r[pi].trim(), members: (r[mi] || "").trim(),
      department: (r[di] || "").trim(), round1: /^(yes|true|1|y)$/i.test((r[ri] || "").trim()) }));
  }
  const L = col("team leader name"), M1 = col("team member name 1"), M2 = col("team member name 2"),
        P = col("project name"), D = col("your department"), Y = col("year of study"), ID = col("team leader student id");
  if (L < 0 || P < 0) throw new Error("Unknown CSV format. Use columns: code, project, members, department, round1 — or the Google Form export.");
  const bad = new Set(["", "-", ".", "none", "no", "n/a"]);
  const byKey = new Map();
  body.forEach((r, i) => {
    const key = (ID >= 0 && r[ID]?.trim().toLowerCase()) || r[L]?.trim().toLowerCase() || "row" + i;
    byKey.set(key, { r, i: byKey.get(key)?.i ?? i }); // latest answers win, first position (and code) is kept
  });
  return [...byKey.values()].sort((a, b) => a.i - b.i).map(({ r }, idx) => {
    const names = [];
    for (const k of [L, M1, M2]) {
      const n = cap((r[k] || "").replace(/\s+/g, " ").replace(/\s+I24[A-C]$/i, "").trim());
      if (!bad.has(n.toLowerCase()) && !names.some((x) => x.toLowerCase() === n.toLowerCase())) names.push(n);
    }
    const dept = (r[D] || "").trim(), year = (r[Y] || "").trim();
    const itb = /it ?-? ?b|it bus|it department/i.test(dept);
    return { code: "T" + String(idx + 1).padStart(2, "0"), project: (r[P] || "").trim() || "Untitled project",
             members: names.join("; "), department: dept, round1: itb && !["1", "2", "4"].includes(year) };
  });
}

/** Team photo (or initials when there is none). size in px. */
export function avatar(api, row, size = 48, cls = "") {
  const url = row?.photo_path ? api.photoUrl(row.photo_path) : "";
  const initials = String(row?.code || "?").replace(/^T/i, "") || "?";
  const fallback = `<span class='avatar none ${cls}' style='width:${size}px;height:${size}px;font-size:${Math.round(size / 2.6)}px'>${esc(initials)}</span>`;
  return url
    ? `<img class="avatar ${cls}" src="${esc(url)}" alt="" style="width:${size}px;height:${size}px" loading="lazy" onerror="this.outerHTML=&quot;${fallback.replace(/"/g, "&quot;")}&quot;">`
    : `<span class="avatar none ${cls}" style="width:${size}px;height:${size}px;font-size:${Math.round(size / 2.6)}px">${esc(initials)}</span>`;
}

/** Shrink a photo in the browser to max `edge` px (JPEG) so uploads are fast on venue Wi-Fi. */
export function compressImage(file, edge = 1600, quality = 0.85) {
  return new Promise((resolve, reject) => {
    const img = new Image(), url = URL.createObjectURL(file);
    img.onload = () => {
      const k = Math.min(1, edge / Math.max(img.width, img.height));
      const c = document.createElement("canvas");
      c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
      c.getContext("2d").drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      c.toBlob((b) => (b ? resolve(b) : reject(new Error("Could not read this image"))), "image/jpeg", quality);
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("This file is not a supported image (use JPG or PNG).")); };
    img.src = url;
  });
}

export const fmtSize =(b) => (b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB");
export const fmtTime = (t) => (t ? new Date(t).toLocaleString([], { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }) : "");

export function clock(el) {
  const tick = () => { el.textContent = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }); };
  tick(); setInterval(tick, 10000);
}

// Printable certificates (A4 landscape, one per page) generated from a round's ranking.
import { EVENT } from "./config.js?v=20261115a";

const ordinal = (n) => { const s = ["th", "st", "nd", "rd"], v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); };
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const splitMembers = (m) => String(m || "").split(/[;,\n]+/).map((x) => x.trim()).filter(Boolean);

// rows: ranked rows ({ rank, code, project, members }); only rank 1..top are used.
export function openCertificates({ round, rows, top = 10, perStudent = true }) {
  const winners = rows.filter((r) => r.rank && r.rank <= top);
  if (!winners.length) return { count: 0 };
  const certs = [];
  for (const r of winners) {
    const names = perStudent ? splitMembers(r.members) : [];
    if (!names.length) certs.push({ ...r, name: `Team ${r.code}`, team: true });
    else names.forEach((name) => certs.push({ ...r, name }));
  }
  const abs = (p) => new URL(p, location.href).href;
  const page = (c) => {
    const podium = c.rank <= 3;
    const title = podium ? "Certificate of Achievement" : "Certificate of Excellence";
    const medal = c.rank === 1 ? "#E9B949" : c.rank === 2 ? "#B8C2D6" : c.rank === 3 ? "#C9814A" : "#F7931E";
    const what = `${ordinal(c.rank)} Place`;
    return `<section class="cert">
      <div class="frame"><div class="inner">
        <div class="top"><img src="${abs("assets/technovate-mark.svg")}" alt=""><div class="ev"><b>AJOU TECHNOVATE</b><span>HACKATHON ${esc(EVENT.edition)} · 2026</span></div>
          <span style="flex:1"></span><img src="${abs("assets/ajou-logo.png")}" alt="" class="uni"></div>
        <div class="title">${title}</div>
        <div class="sub">This certificate is proudly presented to</div>
        <div class="name">${esc(c.name)}</div>
        <div class="line"></div>
        <div class="text">${c.team ? "" : `member of team <b>${esc(c.code)}</b>, `}for the project <b>“${esc(c.project)}”</b>,<br>
          for achieving <b>${what}</b> in <b>${esc(round.name)}</b> of the ${esc(EVENT.name)}.</div>
        <div class="badge" style="--m:${medal}"><span class="big">${ordinal(c.rank)}</span><span class="sm">PLACE</span></div>
        <div class="foot">
          <div class="sig"><div class="sl"></div>Organizing Committee</div>
          <div class="meta">${esc(EVENT.date)}<br>${esc(EVENT.venue)}</div>
          <div class="sig"><div class="sl"></div>Head of the Judging Panel</div>
        </div>
      </div></div></section>`;
  };
  const html = `<!doctype html><html><head><meta charset="utf-8"><title>Certificates – ${esc(round.name)} – Top ${top}</title>
<style>
  @page { size: A4 landscape; margin: 0; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #e9edf5; font-family: "Segoe UI", Arial, sans-serif; color: #0A1A3F; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .bar { position: sticky; top: 0; z-index: 5; background: #0A1A3F; color: #fff; padding: 12px 20px; display: flex; gap: 14px; align-items: center; font-size: 15px; }
  .bar button { background: #F7931E; color: #1a1205; border: 0; border-radius: 8px; padding: 10px 18px; font-weight: 800; font-size: 15px; cursor: pointer; }
  .cert { width: 297mm; height: 210mm; margin: 14px auto; background: #fff; box-shadow: 0 6px 30px rgba(0,0,0,.15); padding: 9mm; page-break-after: always; break-after: page; overflow: hidden; }
  .frame { height: 100%; border: 3px solid #0A1A3F; padding: 2.5mm; background: linear-gradient(135deg, rgba(247,147,30,.10), transparent 30%, transparent 70%, rgba(10,26,63,.08)); }
  .inner { position: relative; height: 100%; border: 1.5px solid #F7931E; padding: 9mm 18mm 8mm; display: flex; flex-direction: column; align-items: center; text-align: center; }
  .top { width: 100%; display: flex; align-items: center; gap: 12px; text-align: left; }
  .top img { width: 15mm; height: 15mm; } .top img.uni { width: 17mm; height: 17mm; }
  .ev b { display: block; font-size: 17px; letter-spacing: 2px; } .ev span { font-size: 11px; letter-spacing: 2.5px; color: #F7931E; font-weight: 800; }
  .title { margin-top: 6mm; font: 700 44px/1.1 Georgia, "Times New Roman", serif; letter-spacing: 1px; text-transform: uppercase; }
  .sub { margin-top: 5mm; font-size: 17px; color: #4b5878; letter-spacing: .5px; }
  .name { margin-top: 4mm; font: italic 700 50px/1.15 Georgia, "Times New Roman", serif; color: #0A1A3F; max-width: 230mm; }
  .line { width: 150mm; height: 2px; background: linear-gradient(90deg, transparent, #F7931E, transparent); margin-top: 3mm; }
  .text { margin-top: 5mm; font-size: 18px; line-height: 1.6; color: #24324f; max-width: 215mm; }
  .badge { margin-top: 7mm; flex: none; width: 30mm; height: 30mm; border-radius: 50%; background: var(--m); color: #0A1A3F;
    display: flex; flex-direction: column; align-items: center; justify-content: center; box-shadow: inset 0 0 0 2.2mm rgba(255,255,255,.45), 0 4px 12px rgba(0,0,0,.18); }
  .badge .big { font: 900 30px/1 "Segoe UI", Arial; } .badge .sm { font-size: 9px; font-weight: 800; letter-spacing: 1.5px; margin-top: 1mm; }
  .foot { margin-top: auto; width: 100%; display: grid; grid-template-columns: 1fr 1fr 1fr; align-items: end; gap: 10mm; font-size: 14px; color: #4b5878; }
  .sig .sl { height: 1.5px; background: #0A1A3F; margin: 0 8mm 2mm; } .meta { font-weight: 700; color: #0A1A3F; line-height: 1.5; }
  @media print { body { background: #fff; } .bar { display: none; } .cert { margin: 0; box-shadow: none; } }
</style></head><body>
<div class="bar"><b>${certs.length} certificate${certs.length > 1 ? "s" : ""}</b> · ${esc(round.name)} · places 1–${Math.min(top, Math.max(...winners.map((w) => w.rank)))}
  <span style="flex:1"></span><span style="opacity:.8">Tip: in the print dialog choose “Save as PDF”, landscape, margins none, background graphics on.</span>
  <button onclick="print()">🖨 Print / Save as PDF</button></div>
${certs.map(page).join("\n")}
</body></html>`;
  // full-screen preview inside the page (no pop-up, so no pop-up blocker)
  document.getElementById("certOverlay")?.remove();
  const ov = document.createElement("div");
  ov.id = "certOverlay";
  ov.style.cssText = "position:fixed;inset:0;z-index:1000;background:#050c22;display:flex;flex-direction:column";
  ov.innerHTML = `<div style="display:flex;justify-content:flex-end;padding:8px 12px"><button class="btn" id="certClose">✕ Close</button></div>`;
  const fr = document.createElement("iframe");
  fr.style.cssText = "flex:1;border:0;width:100%;background:#e9edf5";
  fr.title = "Certificates";
  fr.srcdoc = html;
  ov.appendChild(fr);
  document.body.appendChild(ov);
  const close = () => { ov.remove(); document.removeEventListener("keydown", esc_); };
  const esc_ = (e) => e.key === "Escape" && close();
  document.addEventListener("keydown", esc_);
  ov.querySelector("#certClose").onclick = close;
  return { count: certs.length };
}

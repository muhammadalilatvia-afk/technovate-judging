// Supabase backend: reads public tables/views, writes only through PIN-checked SQL functions.
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm";

export function supabaseBackend(url, key) {
  const key_ = key;
  const sb = createClient(url, key, { realtime: { params: { eventsPerSecond: 5 } } });
  const ok = ({ data, error }) => { if (error) throw new Error(error.message); return data; };
  const rpc = async (fn, args) => ok(await sb.rpc(fn, args));
  const listeners = new Set();
  let channel = null;

  function ensureChannel() {
    if (channel) return;
    channel = sb.channel("state-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "state" }, () => listeners.forEach((fn) => fn()))
      .subscribe();
    // Safety net if a websocket drops on venue Wi-Fi: refresh every 8 s anyway.
    setInterval(() => listeners.forEach((fn) => fn()), 8000);
  }

  return {
    mode: "live",
    subscribe(fn) { ensureChannel(); listeners.add(fn); return () => listeners.delete(fn); },
    getRounds: async () => ok(await sb.from("rounds").select("*").order("id")),
    getCriteria: async () => ok(await sb.from("criteria").select("*").order("position")),
    getState: async () => ok(await sb.from("state").select("*").eq("id", 1).single()),
    getTeams: async () => ok(await sb.from("teams").select("id,code,project,members,department,round1").order("code")),
    getRoundTeams: async (round) => ok(await sb.from("round_teams").select("*").eq("round_id", round).order("position")),
    getLeaderboard: async (round) => ok(await sb.from("leaderboard").select("*").eq("round_id", round)),
    getJudgeProgress: async () => ok(await sb.from("judge_progress").select("*").order("judge_id")),

    judgeLogin: (pin) => rpc("judge_login", { p_pin: pin }),
    judgeScores: (pin, round) => rpc("judge_scores", { p_pin: pin, p_round: round }),
    submitScore: (pin, round, team, criteria, comment) =>
      rpc("submit_score", { p_pin: pin, p_round: round, p_team: team, p_criteria: criteria, p_comment: comment }),

    adminStatus: () => rpc("admin_status", {}),
    adminSetup: (pin) => rpc("admin_setup", { p_pin: pin }),
    adminCheck: (pin) => rpc("admin_check", { p_pin: pin }),
    adminChangePin: (pin, next) => rpc("admin_change_pin", { p_pin: pin, p_new: next }),
    adminSetState: (pin, patch) => rpc("admin_set_state", { p_pin: pin, p_patch: patch }),
    adminImportTeams: (pin, rows, replace) => rpc("admin_import_teams", { p_pin: pin, p_rows: rows, p_replace: replace }),
    adminUpdateTeam: (pin, id, patch) => rpc("admin_update_team", { p_pin: pin, p_id: id, p_patch: patch }),
    adminDeleteTeam: (pin, id) => rpc("admin_delete_team", { p_pin: pin, p_id: id }),
    adminSetRoundTeams: (pin, round, ids) => rpc("admin_set_round_teams", { p_pin: pin, p_round: round, p_team_ids: ids }),
    adminAddJudge: (pin, name, judgePin) => rpc("admin_add_judge", { p_pin: pin, p_name: name, p_judge_pin: judgePin }),
    adminSetJudgeActive: (pin, id, active) => rpc("admin_set_judge_active", { p_pin: pin, p_id: id, p_active: active }),
    adminListJudges: (pin) => rpc("admin_list_judges", { p_pin: pin }),
    adminScores: (pin, round) => rpc("admin_scores", { p_pin: pin, p_round: round }),
    adminResetRound: (pin, round) => rpc("admin_reset_round", { p_pin: pin, p_round: round }),
    adminPresentations: (pin) => rpc("admin_presentations", { p_pin: pin }),
    adminActivity: (pin, limit = 25) => rpc("admin_activity", { p_pin: pin, p_limit: limit }),

    // presentations
    teamCheck: (code, key) => rpc("team_check", { p_code: code, p_key: key }),
    fileUrl: (path) => sb.storage.from("presentations").getPublicUrl(path).data.publicUrl,
    /** Upload straight to Supabase Storage with a progress callback, then register it for the team. */
    async uploadPresentation(code, key, file, onProgress) {
      const team = await rpc("team_check", { p_code: code, p_key: key });
      if (!team) throw new Error("Wrong team code or upload code");
      if (!team.uploads_open) throw new Error("Uploads are closed by the organizer");
      code = team.code;
      const safe = file.name.normalize("NFKD").replace(/[^\w.\-]+/g, "_").replace(/_+/g, "_").slice(-90);
      const path = `${code}/${crypto.randomUUID()}/${safe}`;
      const type = file.type || ({ pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation", ppt: "application/vnd.ms-powerpoint", pdf: "application/pdf" })[file.name.split(".").pop().toLowerCase()];
      return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", `${url}/storage/v1/object/presentations/${path.split("/").map(encodeURIComponent).join("/")}`);
        xhr.setRequestHeader("Authorization", `Bearer ${key_}`);
        xhr.setRequestHeader("apikey", key_);
        xhr.setRequestHeader("Content-Type", type);
        xhr.setRequestHeader("x-upsert", "false");
        xhr.upload.onprogress = (e) => e.lengthComputable && onProgress?.(e.loaded / e.total);
        xhr.onerror = () => reject(new Error("Network error during upload. Please try again."));
        xhr.onload = async () => {
          if (xhr.status >= 300) {
            let msg = xhr.responseText; try { msg = JSON.parse(xhr.responseText).message || msg; } catch {}
            return reject(new Error(`Upload failed: ${msg}`));
          }
          try { await rpc("register_presentation", { p_code: code, p_key: key, p_path: path, p_name: file.name, p_size: file.size }); resolve(path); }
          catch (e) { reject(e); }
        };
        xhr.send(file);
      });
    },
  };
}

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js";

const cfg = window.ownerDashboardConfig;
if (!cfg?.firebase) {
  throw new Error("Missing config.js. Copy config.sample.js to config.js and fill values.");
}

const app = initializeApp(cfg.firebase);
const auth = getAuth(app);
const db = getFirestore(app);

const statusText = document.getElementById("statusText");
const signInBtn = document.getElementById("signInBtn");
const signOutBtn = document.getElementById("signOutBtn");
const refreshBtn = document.getElementById("refreshBtn");
const appWideToggle = document.getElementById("appWideToggle");
const summaryGrid = document.getElementById("summaryGrid");
const detailsGrid = document.getElementById("detailsGrid");

const familyNameEl = document.getElementById("familyName");
const memberCountEl = document.getElementById("memberCount");
const storyCountEl = document.getElementById("storyCount");
const taskCountEl = document.getElementById("taskCount");
const eventCountEl = document.getElementById("eventCount");
const vaultCountEl = document.getElementById("vaultCount");
const predictionCountEl = document.getElementById("predictionCount");
const gamesCountEl = document.getElementById("gamesCount");

const taskStatusList = document.getElementById("taskStatusList");
const moodList = document.getElementById("moodList");
const contributorsBody = document.getElementById("contributorsBody");
const recentList = document.getElementById("recentList");

const APP_WIDE_STORAGE_KEY = "ownerDashboardAppWide";

if (appWideToggle) {
  const stored = sessionStorage.getItem(APP_WIDE_STORAGE_KEY);
  // Default: all families. Only use linked family when user explicitly chose "0".
  if (stored === null) {
    appWideToggle.checked = true;
    sessionStorage.setItem(APP_WIDE_STORAGE_KEY, "1");
  } else {
    appWideToggle.checked = stored === "1";
  }
  appWideToggle.addEventListener("change", () => {
    sessionStorage.setItem(
      APP_WIDE_STORAGE_KEY,
      appWideToggle.checked ? "1" : "0",
    );
    const user = auth.currentUser;
    if (user) loadFamilyAnalytics(user);
  });
}

function setStatus(msg) {
  statusText.textContent = msg;
}

function setAuthedUi(on) {
  signInBtn.classList.toggle("hidden", on);
  signOutBtn.classList.toggle("hidden", !on);
  refreshBtn.disabled = !on;
}

function setDashboardVisible(on) {
  summaryGrid.classList.toggle("hidden", !on);
  detailsGrid.classList.toggle("hidden", !on);
}

function renderKvList(el, map) {
  el.innerHTML = "";
  const entries = Object.entries(map);
  if (!entries.length) {
    el.innerHTML = "<li><span>None</span><span>-</span></li>";
    return;
  }
  for (const [k, v] of entries) {
    const li = document.createElement("li");
    li.innerHTML = `<span>${k}</span><strong>${v}</strong>`;
    el.appendChild(li);
  }
}

function setText(el, v) {
  el.textContent = String(v ?? "");
}

function assertOwnerEmail(user) {
  const ownerEmails = (cfg.allowedEmails || []).map((e) => e.toLowerCase());
  const email = (user.email || "").toLowerCase();
  if (!ownerEmails.includes(email)) {
    return { ok: false, email };
  }
  return { ok: true, email };
}

async function collectFamilyMetrics(familyId, familyLabel) {
  const membersSnap = await getDocs(collection(db, "families", familyId, "members"));
  const storiesSnap = await getDocs(collection(db, "families", familyId, "stories"));
  const tasksSnap = await getDocs(collection(db, "families", familyId, "tasks"));
  const eventsSnap = await getDocs(collection(db, "families", familyId, "calendar_events"));
  const vaultSnap = await getDocs(collection(db, "families", familyId, "vault_items"));
  const predictionsSnap = await getDocs(collection(db, "families", familyId, "predictions"));
  const futurePredSnap = await getDocs(collection(db, "families", familyId, "future_predictions"));
  const reelsSnap = await getDocs(collection(db, "families", familyId, "reels"));
  const creativeSnap = await getDocs(collection(db, "families", familyId, "creative_submissions"));
  const timeTravelSnap = await getDocs(collection(db, "families", familyId, "time_travel_entries"));

  const taskStatus = { pending: 0, submitted: 0, approved: 0, rejected: 0 };
  for (const d of tasksSnap.docs) {
    const status = d.data().status || "pending";
    taskStatus[status] = (taskStatus[status] || 0) + 1;
  }

  const moods = {};
  for (const d of storiesSnap.docs) {
    const m = d.data().mood || "unknown";
    moods[m] = (moods[m] || 0) + 1;
  }

  const statsQ = query(
    collection(db, "families", familyId, "member_stats"),
    orderBy("points", "desc"),
    limit(10),
  );
  const statsSnap = await getDocs(statsQ);
  const contributorRows = [];
  for (const d of statsSnap.docs) {
    const s = d.data();
    contributorRows.push({
      familyLabel,
      displayName: s.displayName || s.email || d.id,
      points: s.points || 0,
      storiesCreated: s.storiesCreated || 0,
      gamesWon: s.gamesWon || 0,
    });
  }

  const recentStoriesQ = query(
    collection(db, "families", familyId, "stories"),
    orderBy("createdAt", "desc"),
    limit(6),
  );
  const recentStories = await getDocs(recentStoriesQ);
  const recentItems = [];
  for (const d of recentStories.docs) {
    const x = d.data();
    const ts = x.createdAt?.toDate?.() ?? null;
    recentItems.push({
      sortAt: ts ? ts.getTime() : 0,
      text: `[${familyLabel}] Story: ${x.title || "Untitled"} by ${x.authorName || "Unknown"}`,
    });
  }
  const recentTasksQ = query(
    collection(db, "families", familyId, "tasks"),
    orderBy("createdAt", "desc"),
    limit(4),
  );
  const recentTasks = await getDocs(recentTasksQ);
  for (const d of recentTasks.docs) {
    const x = d.data();
    const ts = x.createdAt?.toDate?.() ?? null;
    recentItems.push({
      sortAt: ts ? ts.getTime() : 0,
      text: `[${familyLabel}] Task: ${x.title || "Untitled"} (${x.status || "pending"})`,
    });
  }

  return {
    familyId,
    familyLabel,
    memberCount: membersSnap.size,
    storyCount: storiesSnap.size,
    taskCount: tasksSnap.size,
    eventCount: eventsSnap.size,
    vaultCount: vaultSnap.size,
    predictionCount: predictionsSnap.size + futurePredSnap.size,
    gamesCount: reelsSnap.size + creativeSnap.size + timeTravelSnap.size,
    taskStatus,
    moods,
    contributorRows,
    recentItems,
  };
}

function mergeTaskStatus(into, part) {
  for (const [k, v] of Object.entries(part)) {
    into[k] = (into[k] || 0) + v;
  }
}

function mergeMoods(into, part) {
  for (const [k, v] of Object.entries(part)) {
    into[k] = (into[k] || 0) + v;
  }
}

function renderDashboardFromAggregate(aggregate, statusSuffix) {
  const {
    scopeLabel,
    memberCount,
    storyCount,
    taskCount,
    eventCount,
    vaultCount,
    predictionCount,
    gamesCount,
    taskStatus,
    moods,
    contributorRows,
    recentItems,
  } = aggregate;

  setText(familyNameEl, scopeLabel);
  setText(memberCountEl, memberCount);
  setText(storyCountEl, storyCount);
  setText(taskCountEl, taskCount);
  setText(eventCountEl, eventCount);
  setText(vaultCountEl, vaultCount);
  setText(predictionCountEl, predictionCount);
  setText(gamesCountEl, gamesCount);

  renderKvList(taskStatusList, taskStatus);
  renderKvList(moodList, moods);

  contributorsBody.innerHTML = "";
  for (const row of contributorRows) {
    const tr = document.createElement("tr");
    const tdName = document.createElement("td");
    tdName.textContent = aggregate.isAppWide
      ? `${row.displayName} (${row.familyLabel})`
      : row.displayName;
    const tdPts = document.createElement("td");
    tdPts.textContent = String(row.points);
    const tdStories = document.createElement("td");
    tdStories.textContent = String(row.storiesCreated);
    const tdGames = document.createElement("td");
    tdGames.textContent = String(row.gamesWon);
    tr.append(tdName, tdPts, tdStories, tdGames);
    contributorsBody.appendChild(tr);
  }

  recentList.innerHTML = "";
  for (const item of recentItems) {
    const li = document.createElement("li");
    li.textContent = item.text;
    recentList.appendChild(li);
  }
  if (!recentList.children.length) {
    recentList.innerHTML = "<li>No recent activity yet.</li>";
  }

  setStatus(statusSuffix);
  setDashboardVisible(true);
}

async function mapPool(items, concurrency, fn) {
  const out = [];
  for (let i = 0; i < items.length; i += concurrency) {
    const chunk = items.slice(i, i + concurrency);
    const part = await Promise.all(chunk.map(fn));
    out.push(...part);
  }
  return out;
}

async function loadFamilyAnalytics(user) {
  setStatus("Loading analytics...");
  setDashboardVisible(false);

  const gate = assertOwnerEmail(user);
  if (!gate.ok) {
    setStatus(`Access denied for ${user.email}. Add this email to config.js allowedEmails.`);
    await signOut(auth);
    return;
  }

  const userDoc = await getDoc(doc(db, "users", user.uid));
  const familyId = userDoc.data()?.familyId;
  const forceAppWide = appWideToggle?.checked === true;

  if (familyId && !forceAppWide) {
    const familyDoc = await getDoc(doc(db, "families", familyId));
    const familyName = familyDoc.data()?.name || "Family";
    const m = await collectFamilyMetrics(familyId, familyName);
    const contributorRows = m.contributorRows.map((r) => ({
      familyLabel: m.familyLabel,
      displayName: r.displayName,
      points: r.points,
      storiesCreated: r.storiesCreated,
      gamesWon: r.gamesWon,
    }));
    const recentItems = m.recentItems.sort((a, b) => b.sortAt - a.sortAt).slice(0, 12);
    renderDashboardFromAggregate(
      {
        isAppWide: false,
        scopeLabel: familyName,
        memberCount: m.memberCount,
        storyCount: m.storyCount,
        taskCount: m.taskCount,
        eventCount: m.eventCount,
        vaultCount: m.vaultCount,
        predictionCount: m.predictionCount,
        gamesCount: m.gamesCount,
        taskStatus: m.taskStatus,
        moods: m.moods,
        contributorRows,
        recentItems,
      },
      `Signed in as ${gate.email} · family: ${familyName} (${familyId}). ` +
        `Turn on “App-wide totals” above to sum every family.`,
    );
    return;
  }

  // App-wide: no family on account, or owner enabled "All families" toggle.
  setStatus(
    familyId && forceAppWide
      ? "Loading app-wide totals (all families)…"
      : "No family on this account — loading app-wide totals…",
  );
  const famSnap = await getDocs(collection(db, "families"));
  if (famSnap.empty) {
    renderDashboardFromAggregate(
      {
        isAppWide: true,
        scopeLabel: "No families in project",
        memberCount: 0,
        storyCount: 0,
        taskCount: 0,
        eventCount: 0,
        vaultCount: 0,
        predictionCount: 0,
        gamesCount: 0,
        taskStatus: {},
        moods: {},
        contributorRows: [],
        recentItems: [],
      },
      `Signed in as ${gate.email} · no families found in Firestore.`,
    );
    return;
  }

  const familyDocs = famSnap.docs;
  try {
    const perFamily = await mapPool(familyDocs, 6, async (fd) => {
      const fid = fd.id;
      const name = (fd.data()?.name || "Family").trim() || fid;
      return collectFamilyMetrics(fid, name);
    });

    const taskStatus = {};
    const moods = {};
    let memberCount = 0;
    let storyCount = 0;
    let taskCount = 0;
    let eventCount = 0;
    let vaultCount = 0;
    let predictionCount = 0;
    let gamesCount = 0;
    const allContributors = [];
    const allRecent = [];

    for (const m of perFamily) {
      memberCount += m.memberCount;
      storyCount += m.storyCount;
      taskCount += m.taskCount;
      eventCount += m.eventCount;
      vaultCount += m.vaultCount;
      predictionCount += m.predictionCount;
      gamesCount += m.gamesCount;
      mergeTaskStatus(taskStatus, m.taskStatus);
      mergeMoods(moods, m.moods);
      allContributors.push(...m.contributorRows);
      allRecent.push(...m.recentItems);
    }

    allContributors.sort((a, b) => (b.points || 0) - (a.points || 0));
    const contributorRows = allContributors.slice(0, 10);
    const recentItems = allRecent.sort((a, b) => b.sortAt - a.sortAt).slice(0, 14);

    renderDashboardFromAggregate(
      {
        isAppWide: true,
        scopeLabel: `All families (${familyDocs.length})`,
        memberCount,
        storyCount,
        taskCount,
        eventCount,
        vaultCount,
        predictionCount,
        gamesCount,
        taskStatus,
        moods,
        contributorRows,
        recentItems,
      },
      `Signed in as ${gate.email} · app-wide · ${familyDocs.length} famil${familyDocs.length === 1 ? "y" : "ies"}`,
    );
  } catch (e) {
    const msg = e?.message || String(e);
    setStatus(
      `App-wide load failed (${msg}). Deploy updated firestore.rules, then in Firestore create doc ` +
        `_internal_rule_config/app_dashboard_owners with field emails (array of lowercase strings matching ` +
        `your Google sign-in), or set custom claim appAnalyticsOwner=true on your user. See owner_analytics_dashboard/README.md.`,
    );
    setDashboardVisible(false);
  }
}

signInBtn.addEventListener("click", async () => {
  try {
    const provider = new GoogleAuthProvider();
    await signInWithPopup(auth, provider);
  } catch (e) {
    setStatus(`Sign-in failed: ${e.message || e}`);
  }
});

signOutBtn.addEventListener("click", async () => {
  await signOut(auth);
});

refreshBtn.addEventListener("click", async () => {
  const user = auth.currentUser;
  if (user) await loadFamilyAnalytics(user);
});

onAuthStateChanged(auth, async (user) => {
  setAuthedUi(!!user);
  if (!user) {
    setStatus("Sign in to load analytics.");
    setDashboardVisible(false);
    return;
  }
  try {
    await loadFamilyAnalytics(user);
  } catch (e) {
    setStatus(`Load failed: ${e.message || e}`);
    setDashboardVisible(false);
  }
});

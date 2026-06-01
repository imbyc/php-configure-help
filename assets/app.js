const state = {
  data: [],
  stage: "all",
  major: "all",
  query: "",
};

const gridEl = document.getElementById("version-grid");
const searchInput = document.getElementById("search-input");
const resultMeta = document.getElementById("result-meta");
const majorFiltersEl = document.getElementById("major-filters");
const cardTemplate = document.getElementById("version-card-template");

const statTotal = document.getElementById("stat-total");
const statStable = document.getElementById("stat-stable");
const statPrerelease = document.getElementById("stat-prerelease");
const statLatest = document.getElementById("stat-latest");
const statLatestDate = document.getElementById("stat-latest-date");

function detectStage(version) {
  const lower = version.toLowerCase();
  if (lower.includes("alpha")) return "alpha";
  if (lower.includes("beta")) return "beta";
  if (lower.includes("rc")) return "rc";
  return "stable";
}

function detectMajor(version) {
  return String(version).split(".")[0] || "unknown";
}

function prettyStage(stage) {
  if (stage === "rc") return "Release Candidate";
  if (stage === "beta") return "Beta";
  if (stage === "alpha") return "Alpha";
  return "Stable";
}

function buildGitHubBase() {
  const host = window.location.host;
  const pathSeg = window.location.pathname.split("/").filter(Boolean);

  if (host.endsWith("github.io") && pathSeg.length > 0) {
    const owner = host.replace(".github.io", "");
    const repo = pathSeg[0];
    return `https://github.com/${owner}/${repo}`;
  }

  return "https://github.com/imbyc/php-configure-help";
}

function buildMajorFilters() {
  const majors = [...new Set(state.data.map((item) => item.major))].sort(
    (a, b) => Number(b) - Number(a)
  );

  majorFiltersEl.innerHTML = "";

  const allBtn = document.createElement("button");
  allBtn.className = `major-chip ${state.major === "all" ? "is-active" : ""}`;
  allBtn.dataset.major = "all";
  allBtn.textContent = "全部大版本";
  majorFiltersEl.appendChild(allBtn);

  for (const major of majors) {
    const btn = document.createElement("button");
    btn.className = `major-chip ${state.major === major ? "is-active" : ""}`;
    btn.dataset.major = major;
    btn.textContent = `PHP ${major}.x`;
    majorFiltersEl.appendChild(btn);
  }
}

function getFilteredList() {
  const query = state.query.trim().toLowerCase();

  return state.data.filter((item) => {
    const stagePass = state.stage === "all" || item.stage === state.stage;
    const majorPass = state.major === "all" || item.major === state.major;
    const queryPass =
      query.length === 0 ||
      item.version.toLowerCase().includes(query) ||
      item.stage.toLowerCase().includes(query) ||
      item.minor.toLowerCase().includes(query);
    return stagePass && majorPass && queryPass;
  });
}

function render() {
  const list = getFilteredList();
  const githubBase = buildGitHubBase();

  resultMeta.textContent = `共 ${list.length} 个结果（总计 ${state.data.length}）`;

  gridEl.innerHTML = "";

  if (list.length === 0) {
    gridEl.innerHTML = '<div class="empty">没有匹配结果，试试输入 8.4 / RC / beta。</div>';
    return;
  }

  list.forEach((item, index) => {
    const node = cardTemplate.content.firstElementChild.cloneNode(true);
    node.style.animationDelay = `${Math.min(index * 18, 260)}ms`;

    node.querySelector(".version-tag").textContent = `PHP ${item.major}.x · ${item.minor}`;
    node.querySelector(".version-name").textContent = item.version;
    node.querySelector(".version-stage").textContent = prettyStage(item.stage);
    node.querySelector(".version-date").textContent = `发布时间 ${item.date || "-"}`;

    const docsUrl = item.path;
    const githubDocUrl = `${githubBase}/blob/main/${item.path}`;

    const primary = node.querySelector(".btn-primary");
    primary.href = docsUrl;

    const ghost = node.querySelector(".btn-ghost");
    ghost.href = githubDocUrl;

    gridEl.appendChild(node);
  });
}

function renderStats() {
  const total = state.data.length;
  const stable = state.data.filter((v) => v.stage === "stable").length;
  const prerelease = total - stable;
  const latest = state.data[0] || {};

  statTotal.textContent = total;
  statStable.textContent = stable;
  statPrerelease.textContent = prerelease;
  statLatest.textContent = latest.version || "-";
  statLatestDate.textContent = latest.date || "-";
}

function bindEvents() {
  document.getElementById("stage-filters").addEventListener("click", (event) => {
    const btn = event.target.closest("button[data-stage]");
    if (!btn) return;

    state.stage = btn.dataset.stage;

    for (const chip of document.querySelectorAll("#stage-filters .chip")) {
      chip.classList.toggle("is-active", chip.dataset.stage === state.stage);
    }

    render();
  });

  majorFiltersEl.addEventListener("click", (event) => {
    const btn = event.target.closest("button[data-major]");
    if (!btn) return;

    state.major = btn.dataset.major;

    for (const chip of majorFiltersEl.querySelectorAll(".major-chip")) {
      chip.classList.toggle("is-active", chip.dataset.major === state.major);
    }

    render();
  });

  searchInput.addEventListener("input", () => {
    state.query = searchInput.value;
    render();
  });
}

async function bootstrap() {
  try {
    const resp = await fetch("docs/versions.json", { cache: "no-cache" });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);

    const payload = await resp.json();
    const versions = Array.isArray(payload.versions) ? payload.versions : [];

    state.data = versions.map((item) => {
      const version = item.version;
      const stage = item.stage || detectStage(version);
      const major = item.major || detectMajor(version);
      const parts = String(version).split(".");
      const minor = item.minor || (parts.length > 1 ? `${parts[0]}.${parts[1]}` : parts[0]);

      return {
        version,
        stage,
        major,
        minor,
        date: item.date || "",
        path: item.path || `docs/${version}.md`,
      };
    });

    renderStats();
    buildMajorFilters();
    bindEvents();
    render();
  } catch (error) {
    console.error(error);
    resultMeta.textContent = "读取 docs/versions.json 失败，请先运行生成脚本。";
    gridEl.innerHTML = '<div class="empty">版本索引不存在或格式错误。</div>';
  }
}

bootstrap();

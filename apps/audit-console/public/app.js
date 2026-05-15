const state = {
  data: null,
  search: "",
  type: "all",
  source: "all",
};

const $ = (selector) => document.querySelector(selector);

function value(text, fallback = "—") {
  if (text === null || text === undefined || text === "") return fallback;
  return String(text);
}

function escapeHtml(text) {
  return value(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function shortHash(text) {
  const raw = value(text, "");
  if (!raw) return "—";
  if (raw.length <= 18) return raw;
  return `${raw.slice(0, 10)}…${raw.slice(-8)}`;
}

function sourceTitle(source) {
  if (!source) return "证据批次";
  const names = {
    events_bundle: "综合事件清单",
    audit_query_summary: "链上查询摘要",
    malicious_open_summary: "验证揭示摘要",
    json_summary: "审计摘要",
  };
  return names[source.type] || "审计摘要";
}

function sourceBatchName(source, index) {
  return `${sourceTitle(source)} ${index + 1}`;
}

function sourceName(path) {
  const index = state.data?.sources.findIndex((source) => source.path === path) ?? -1;
  if (index < 0) return "证据批次";
  return sourceBatchName(state.data.sources[index], index);
}

function badge(text, tone = "muted") {
  return `<span class="badge ${tone}">${escapeHtml(text)}</span>`;
}

function statusTone(status) {
  const raw = value(status, "").toLowerCase();
  if (raw.includes("failed") || raw.includes("failure") || raw.includes("danger") || raw.includes("high")) return "danger";
  if (raw.includes("open_completed") || raw.includes("confirmed") || raw.includes("passed") || raw.includes("ok") || raw === "true") return "ok";
  if (raw.includes("expected") || raw.includes("medium") || raw.includes("partial")) return "warn";
  return "info";
}

function includesSearch(row) {
  const haystack = JSON.stringify(row).toLowerCase();
  return !state.search || haystack.includes(state.search.toLowerCase());
}

function sourceMatches(row) {
  return state.source === "all" || row.source_path === state.source || row.source_paths?.includes(state.source);
}

function eventMatches(row) {
  return state.type === "all" || row.event_type === state.type;
}

function filtered(rows, includeEventType = false) {
  return rows.filter((row) => includesSearch(row) && sourceMatches(row) && (!includeEventType || eventMatches(row)));
}

function setText(selector, text) {
  $(selector).textContent = text;
}

function renderMetrics(data) {
  const metrics = [
    ["证据批次", data.stats.source_count],
    ["结构化事件", data.stats.structured_event_count],
    ["用户", data.stats.user_count],
    ["合约", data.stats.contract_count],
    ["交易", data.stats.tx_count],
    ["区块", data.stats.block_count],
    ["查询", data.stats.query_count],
    ["验证/揭示", data.stats.verify_open_count],
  ];

  $("#metrics").innerHTML = metrics
    .map(([label, count]) => `<div class="metric"><span>${label}</span><strong>${count}</strong></div>`)
    .join("");
}

function renderSources(data) {
  const select = $("#sourceFilter");
  const current = select.value;
  select.innerHTML = `<option value="all">全部批次</option>${data.sources
    .map((source, index) => `<option value="${escapeHtml(source.path)}">${escapeHtml(sourceBatchName(source, index))}</option>`)
    .join("")}`;
  select.value = [...select.options].some((option) => option.value === current) ? current : "all";

  $("#sourceList").innerHTML = data.sources
    .map(
      (source) => `
        <div class="source-entry">
          <strong>${escapeHtml(sourceName(source.path))}</strong>
          <span>${escapeHtml(sourceTitle(source))} · ${escapeHtml(source.size_bytes)} 字节</span>
          <span class="mono">sha256 ${escapeHtml(shortHash(source.sha256))}</span>
        </div>
      `,
    )
    .join("");
}

function renderEvents(data) {
  const rows = filtered(data.events, true);
  setText("#eventCount", `${rows.length} 条`);
  $("#eventsBody").innerHTML = rows.length
    ? rows
        .map(
          (row) => `
            <tr>
              <td>${badge(row.event_type, statusTone(row.event_type))}</td>
              <td>${escapeHtml(row.user_name || row.manifest_user)}<br><span class="item-meta">${escapeHtml(row.user_id)}</span></td>
              <td>${escapeHtml(row.contract_name)}</td>
              <td class="mono" title="${escapeHtml(row.tx_hash)}">${escapeHtml(shortHash(row.tx_hash))}</td>
              <td>${escapeHtml(row.block_number)}</td>
              <td>${badge(row.status, statusTone(row.status))}</td>
              <td>${escapeHtml(row.summary)}</td>
            </tr>
          `,
        )
        .join("")
    : `<tr><td class="empty" colspan="7">没有匹配的结构化事件</td></tr>`;
}

function renderUsersAndContracts(data) {
  const users = filtered(data.users);
  const contracts = filtered(data.contracts);
  setText("#userContractCount", `${users.length} 用户 / ${contracts.length} 合约`);
  $("#userContractList").innerHTML = [
    ...users.map(
      (user) => `
        <div class="item">
          <div class="item-title">
            <span>${escapeHtml(user.user_name || user.manifest_user)}</span>
            ${badge(user.entry_point || user.role || "user", "info")}
          </div>
          <div class="item-meta">id ${escapeHtml(user.user_id)} · 身份标识 ${escapeHtml(user.manifest_user)} · ${escapeHtml(sourceName(user.source_path))}</div>
        </div>
      `,
    ),
    ...contracts.map(
      (contract) => `
        <div class="item">
          <div class="item-title">
            <span>${escapeHtml(contract.contract_name || contract.contract_key)}</span>
            ${badge(contract.contract_key || "contract", "muted")}
          </div>
          <div class="item-meta mono">${escapeHtml(contract.contract_address)}</div>
        </div>
      `,
    ),
  ].join("") || `<div class="empty">没有匹配的用户或合约</div>`;
}

function renderTransactions(data) {
  const rows = filtered(data.transactions);
  setText("#txCount", `${rows.length} 条`);
  $("#txBody").innerHTML = rows.length
    ? rows
        .map(
          (row) => `
            <tr>
              <td>${escapeHtml(row.user_name || row.manifest_user)}</td>
              <td>${escapeHtml(row.contract_name || row.contract_key)}</td>
              <td>${escapeHtml(row.block_number)}</td>
              <td class="mono" title="${escapeHtml(row.tx_hash)}">${escapeHtml(shortHash(row.tx_hash))}</td>
              <td>${row.select_exists === null ? "—" : badge(row.select_exists, row.select_exists ? "ok" : "danger")}</td>
              <td>${escapeHtml(sourceName(row.source_path))}</td>
            </tr>
          `,
        )
        .join("")
    : `<tr><td class="empty" colspan="6">没有匹配的交易与区块记录</td></tr>`;
}

function renderQueries(data) {
  const rows = filtered(data.query_results);
  setText("#queryCount", `${rows.length} 条`);
  $("#queryBody").innerHTML = rows.length
    ? rows
        .map(
          (row) => `
            <tr>
              <td>${escapeHtml(row.user_name || row.manifest_user)}</td>
              <td>${escapeHtml(row.contract_name || row.contract_key)}</td>
              <td>${badge(row.query, "info")}</td>
              <td>${escapeHtml(row.block_number)}</td>
              <td>${row.exists === null ? "—" : badge(row.exists, row.exists ? "ok" : "danger")}</td>
              <td>${escapeHtml(row.ret)}</td>
              <td>${escapeHtml(row.result || row.status)}</td>
            </tr>
          `,
        )
        .join("")
    : `<tr><td class="empty" colspan="7">没有匹配的查询记录</td></tr>`;
}

function renderVerifyOpen(data) {
  const rows = filtered(data.verify_open);
  setText("#verifyCount", `${rows.length} 条`);
  $("#verifyBody").innerHTML = rows.length
    ? rows
        .map(
          (row) => `
            <tr>
              <td>${escapeHtml(row.user_name || row.manifest_user)}</td>
              <td>${escapeHtml(row.node || row.committee)}</td>
              <td>${badge(row.verify_status || row.verify, statusTone(row.verify_status || row.verify))}</td>
              <td>${badge(row.open_status || row.open, statusTone(row.open_status || row.open))}</td>
              <td>${row.open_triggered_by_user === null ? "—" : badge(row.open_triggered_by_user, row.open_triggered_by_user ? "ok" : "muted")}</td>
            </tr>
          `,
        )
        .join("")
    : `<tr><td class="empty" colspan="5">没有匹配的验证与揭示记录</td></tr>`;
}

function renderRevealFields(data) {
  const rows = filtered(data.reveal_fields);
  setText("#revealCount", `${rows.length} 条`);
  $("#revealList").innerHTML = rows.length
    ? rows
        .map((row) => {
          const fields = Object.entries(row.fields || {})
            .map(([key, itemValue]) => `<span class="badge info">${escapeHtml(key)}: ${escapeHtml(itemValue)}</span>`)
            .join(" ");
          return `
            <div class="item">
              <div class="item-title">
                <span>${escapeHtml(row.user_name || row.manifest_user)}</span>
                ${badge(row.status, statusTone(row.status))}
              </div>
              <div>${fields}</div>
              <div class="item-meta">${escapeHtml(row.summary)}</div>
            </div>
          `;
        })
        .join("")
    : `<div class="empty">当前证据中没有匹配的揭示字段</div>`;
}

function renderFailures(data) {
  const rows = filtered(data.failure_scenarios);
  setText("#failureCount", `${rows.length} 条`);
  $("#failureList").innerHTML = rows.length
    ? rows
        .map(
          (row) => `
            <div class="item">
              <div class="item-title">
                <span>${escapeHtml(row.failure_code)}</span>
                ${badge(row.status, statusTone(row.status))}
              </div>
              <div>${escapeHtml(row.summary)}</div>
              <div class="item-meta">${escapeHtml(row.operation)} · ${escapeHtml(row.diagnostic)}</div>
            </div>
          `,
        )
        .join("")
    : `<div class="empty">没有匹配的失败场景</div>`;
}

function renderAll() {
  const data = state.data;
  if (!data) return;

  const hasErrors = data.load_errors.length > 0;
  $("#healthBadge").className = `badge ${hasErrors ? "danger" : "ok"}`;
  $("#healthBadge").textContent = hasErrors ? "加载异常" : "数据已同步";
  $("#statusBanner").className = `notice ${hasErrors ? "error" : "ok"}`;
  $("#statusBanner").textContent = hasErrors
    ? `发现 ${data.load_errors.length} 个证据文件异常，已跳过异常来源。`
    : `当前批次包含 ${data.stats.source_count} 组证据、${data.stats.tx_count} 笔链上交易、${data.stats.verify_open_count} 条验证/揭示记录。更新时间 ${data.generated_at}`;

  renderMetrics(data);
  renderSources(data);
  renderEvents(data);
  renderUsersAndContracts(data);
  renderRevealFields(data);
  renderTransactions(data);
  renderQueries(data);
  renderVerifyOpen(data);
  renderFailures(data);
}

async function loadData() {
  $("#healthBadge").className = "badge muted";
  $("#healthBadge").textContent = "加载中";
  const response = await fetch("/api/evidence", { cache: "no-store" });
  if (!response.ok) throw new Error(`API returned ${response.status}`);
  state.data = await response.json();
  renderAll();
}

$("#refreshBtn").addEventListener("click", () => {
  loadData().catch((error) => {
    $("#healthBadge").className = "badge danger";
    $("#healthBadge").textContent = "加载失败";
    $("#statusBanner").className = "notice error";
    $("#statusBanner").textContent = error.message;
  });
});

$("#searchInput").addEventListener("input", (event) => {
  state.search = event.target.value;
  renderAll();
});

$("#typeFilter").addEventListener("change", (event) => {
  state.type = event.target.value;
  renderAll();
});

$("#sourceFilter").addEventListener("change", (event) => {
  state.source = event.target.value;
  renderAll();
});

loadData().catch((error) => {
  $("#healthBadge").className = "badge danger";
  $("#healthBadge").textContent = "加载失败";
  $("#statusBanner").className = "notice error";
  $("#statusBanner").textContent = error.message;
});

import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { readdir, readFile, stat } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const appDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(appDir, "../..");
const publicDir = join(appDir, "public");

const allowedEvidenceDirs = [
  { label: "examples/evidence", path: join(repoRoot, "examples", "evidence") },
  { label: "docs/evidence", path: join(repoRoot, "docs", "evidence") },
];

const contentTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
};

function repoRelative(path) {
  return relative(repoRoot, path).replaceAll("\\", "/");
}

function isInside(child, parent) {
  const rel = relative(parent, child);
  return rel === "" || (rel && !rel.startsWith("..") && !isAbsolute(rel));
}

function sha256(text) {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

function jsonResponse(res, statusCode, data) {
  const body = JSON.stringify(data, null, 2);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  res.end(body);
}

function textValue(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  return String(value);
}

function boolish(value) {
  if (value === true || value === "true") return true;
  if (value === false || value === "false") return false;
  return null;
}

function contractName(contractKey, fallback) {
  if (fallback) return fallback;
  if (contractKey === "signature") return "Signature";
  if (contractKey === "personal_info") return "PersonalInfo";
  return contractKey || null;
}

function detectSourceType(data, path) {
  if (Array.isArray(data?.events)) return "events_bundle";
  if (path.includes("audit-query")) return "audit_query_summary";
  if (path.includes("malicious-open")) return "malicious_open_summary";
  if (Array.isArray(data?.verify_open_status?.role_logs)) return "malicious_open_summary";
  if (Array.isArray(data?.query_results)) return "audit_query_summary";
  return path.endsWith(".json") ? "json_summary" : "unknown";
}

function uniqueRows(rows, keyFn) {
  const seen = new Map();
  for (const row of rows) {
    const key = keyFn(row);
    if (!key) continue;
    const previous = seen.get(key);
    if (!previous) {
      seen.set(key, { ...row, source_paths: [...new Set(row.source_paths || [row.source_path].filter(Boolean))] });
      continue;
    }
    const sources = new Set([...(previous.source_paths || []), ...(row.source_paths || []), row.source_path].filter(Boolean));
    seen.set(key, { ...previous, ...row, source_paths: [...sources] });
  }
  return [...seen.values()];
}

function mergeUsers(rows) {
  const seen = new Map();
  const sourceOnlyRows = [];

  for (const row of rows) {
    const sourcePaths = [...new Set(row.source_paths || [row.source_path].filter(Boolean))];
    const stableKey = row.user_name || row.manifest_user || row.user_id;
    if (!stableKey) {
      sourceOnlyRows.push({ ...row, source_paths: sourcePaths });
      continue;
    }

    const previous = seen.get(stableKey);
    if (!previous) {
      seen.set(stableKey, { ...row, source_paths: sourcePaths });
      continue;
    }

    seen.set(stableKey, {
      ...previous,
      ...row,
      manifest_user: previous.manifest_user || row.manifest_user,
      user_id: previous.user_id || row.user_id,
      user_name: previous.user_name || row.user_name,
      entry_point: previous.entry_point || row.entry_point,
      role: previous.role || row.role,
      source_paths: [...new Set([...(previous.source_paths || []), ...sourcePaths])],
    });
  }

  return [...seen.values(), ...sourceOnlyRows];
}

async function listEvidenceFiles() {
  const files = [];
  for (const dir of allowedEvidenceDirs) {
    try {
      const entries = await readdir(dir.path, { withFileTypes: true });
      const jsonEntries = entries
        .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
        .sort((a, b) => a.name.localeCompare(b.name));
      for (const entry of jsonEntries) {
        files.push({
          directory: dir.label,
          path: join(dir.path, entry.name),
          repo_path: repoRelative(join(dir.path, entry.name)),
        });
      }
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
  return files;
}

async function loadSources() {
  const sources = [];
  const errors = [];
  const files = await listEvidenceFiles();

  for (const file of files) {
    if (!allowedEvidenceDirs.some((dir) => isInside(file.path, dir.path))) {
      errors.push({ path: file.repo_path, message: "outside allowed evidence directories" });
      continue;
    }

    try {
      const [content, fileStat] = await Promise.all([readFile(file.path, "utf8"), stat(file.path)]);
      const data = JSON.parse(content);
      sources.push({
        directory: file.directory,
        path: file.repo_path,
        absolute_path: file.path,
        sha256: sha256(content),
        size_bytes: fileStat.size,
        generated_at: textValue(data.generated_at),
        success: typeof data.success === "boolean" ? data.success : null,
        type: detectSourceType(data, file.repo_path),
        data,
      });
    } catch (error) {
      errors.push({ path: file.repo_path, message: error.message });
    }
  }

  return { sources, errors };
}

function addUser(model, user, source) {
  if (!user) return;
  const manifestUser = textValue(user.manifest_key || user.manifest_user || user.manifestUser);
  const userName = textValue(user.user_name || user.user || user.name);
  const userId = textValue(user.user_id || user.id);
  if (!manifestUser && !userName && !userId) return;
  model.users.push({
    manifest_user: manifestUser,
    user_id: userId,
    user_name: userName,
    entry_point: textValue(user.entry_point),
    role: textValue(user.role),
    source_path: source.path,
  });
}

function addContract(model, contract, source) {
  if (!contract) return;
  const key = textValue(contract.key || contract.contract_key);
  const name = contractName(key, contract.name || contract.contract_name || contract.contract);
  const address = textValue(contract.address || contract.contract_address);
  if (!key && !name && !address) return;
  model.contracts.push({
    contract_key: key,
    contract_name: name,
    contract_address: address,
    source_path: source.path,
  });
}

function addTransaction(model, tx, source) {
  if (!tx?.tx_hash) return;
  model.transactions.push({
    manifest_user: textValue(tx.manifest_user || tx.manifest_key),
    user_id: textValue(tx.user_id),
    user_name: textValue(tx.user_name || tx.user),
    contract_key: textValue(tx.contract_key),
    contract_name: contractName(tx.contract_key, tx.contract_name || tx.contract),
    tx_hash: textValue(tx.tx_hash),
    block_number: textValue(tx.block_number),
    select_exists: boolish(tx.select_exists),
    identity_ciphertext_sha256: textValue(tx.identity_ciphertext_sha256),
    source_path: source.path,
  });
}

function addQueryResult(model, query, source) {
  if (!query) return;
  model.query_results.push({
    event_id: textValue(query.event_id),
    manifest_user: textValue(query.manifest_user || query.manifest_key),
    user_id: textValue(query.user_id),
    user_name: textValue(query.user_name || query.user),
    contract_key: textValue(query.contract_key),
    contract_name: contractName(query.contract_key, query.contract_name || query.contract),
    tx_hash: textValue(query.tx_hash),
    block_number: textValue(query.block_number),
    query: textValue(query.query),
    status: textValue(query.status),
    exists: boolish(query.exists ?? query.select_exists),
    ret: textValue(query.ret),
    value_present: boolish(query.value_present),
    result: textValue(query.result),
    output_sha256: textValue(query.output_sha256),
    source_path: source.path,
  });
}

function addVerifyOpen(model, row, source) {
  if (!row) return;
  model.verify_open.push({
    event_id: textValue(row.event_id),
    manifest_user: textValue(row.manifest_user || row.manifest_key),
    user_id: textValue(row.user_id),
    user_name: textValue(row.user_name),
    entry_point: textValue(row.entry_point),
    node: textValue(row.node),
    committee: Array.isArray(row.committee) ? row.committee.join(", ") : textValue(row.committee),
    signature_query: textValue(row.signature_query),
    signature_query_status: textValue(row.signature_query_status),
    verify: textValue(row.verify),
    verify_status: textValue(row.verify_status),
    open: textValue(row.open),
    open_status: textValue(row.open_status),
    open_triggered_by_user: typeof row.open_triggered_by_user === "boolean" ? row.open_triggered_by_user : null,
    reveal: textValue(row.reveal),
    source_path: source.path,
  });
}

function addRevealFields(model, row, source) {
  if (!row?.fields) return;
  model.reveal_fields.push({
    event_id: textValue(row.event_id),
    manifest_user: textValue(row.manifest_user),
    user_id: textValue(row.user_id),
    user_name: textValue(row.user_name),
    fields: row.fields,
    status: textValue(row.status),
    summary: textValue(row.summary),
    source_path: source.path,
  });
}

function addFailureScenario(model, row, source) {
  if (!row) return;
  model.failure_scenarios.push({
    event_id: textValue(row.event_id),
    failure_code: textValue(row.failure_code),
    operation: textValue(row.operation),
    status: textValue(row.status),
    risk_level: textValue(row.risk_level),
    diagnostic: textValue(row.diagnostic),
    summary: textValue(row.summary),
    source_path: source.path,
  });
}

function ingestEvents(model, events, source) {
  for (const event of events || []) {
    const target = event.target || {};
    const chain = event.chain || {};
    const row = {
      event_id: textValue(event.event_id),
      event_type: textValue(event.event_type),
      timestamp: textValue(event.timestamp),
      actor_role: textValue(event.actor?.role),
      actor_name: textValue(event.actor?.name),
      manifest_user: textValue(target.manifest_user),
      user_id: textValue(target.user_id),
      user_name: textValue(target.user_name),
      contract_name: textValue(target.contract_name || chain.contract_name),
      tx_hash: textValue(chain.tx_hash),
      block_number: textValue(chain.block_number),
      status: textValue(event.status),
      risk_level: textValue(event.risk_level),
      summary: textValue(event.summary),
      failure_code: textValue(target.failure_code),
      source_path: source.path,
    };
    model.events.push(row);
    addUser(model, target, source);
    addContract(model, chain, source);
    addTransaction(model, {
      manifest_user: target.manifest_user,
      user_id: target.user_id,
      user_name: target.user_name,
      contract_key: chain.contract_key,
      contract_name: chain.contract_name,
      tx_hash: chain.tx_hash,
      block_number: chain.block_number,
    }, source);

    for (const query of chain.queries || []) {
      addQueryResult(model, {
        ...query,
        event_id: event.event_id,
        manifest_user: target.manifest_user,
        user_id: target.user_id,
        user_name: target.user_name,
        contract_key: chain.contract_key,
        contract_name: chain.contract_name,
        tx_hash: chain.tx_hash,
        block_number: query.block_number || chain.block_number,
      }, source);
    }

    for (const record of chain.records || []) {
      addContract(model, record, source);
      addTransaction(model, {
        ...record,
        manifest_user: target.manifest_user,
        user_id: target.user_id,
        user_name: target.user_name,
      }, source);
    }

    if (event.event_type === "malicious_open") {
      addVerifyOpen(model, {
        event_id: event.event_id,
        manifest_user: target.manifest_user,
        user_id: target.user_id,
        user_name: target.user_name,
        committee: event.actor?.nodes,
        verify_status: event.status === "open_completed" ? "failed_triggers_open" : null,
        open_status: event.status,
        open: event.status === "open_completed" ? "完成" : null,
        open_triggered_by_user: event.status === "open_completed",
        reveal: target.reveal_fields ? JSON.stringify(target.reveal_fields) : null,
      }, source);
      addRevealFields(model, {
        event_id: event.event_id,
        manifest_user: target.manifest_user,
        user_id: target.user_id,
        user_name: target.user_name,
        fields: target.reveal_fields,
        status: event.status,
        summary: event.summary,
      }, source);
    }

    if (event.event_type === "failure_scenario") {
      addFailureScenario(model, {
        event_id: event.event_id,
        failure_code: target.failure_code,
        operation: target.operation,
        status: event.status,
        risk_level: event.risk_level,
        diagnostic: chain.diagnostic,
        summary: event.summary,
      }, source);
    }
  }
}

function ingestSummary(model, source) {
  const data = source.data;
  const userByManifest = new Map();

  for (const user of data.users || []) {
    addUser(model, user, source);
    const manifestKey = user.manifest_key || user.manifest_user;
    if (manifestKey) userByManifest.set(manifestKey, user);
  }

  for (const [key, address] of Object.entries(data.contract_addresses || {})) {
    addContract(model, { key, address }, source);
  }

  for (const [manifestUser, txByContract] of Object.entries(data.tx_hashes || {})) {
    const user = userByManifest.get(manifestUser) || {};
    const blocks = data.block_numbers?.[manifestUser] || {};
    for (const [contractKey, txHash] of Object.entries(txByContract || {})) {
      addTransaction(model, {
        manifest_user: manifestUser,
        user_id: user.user_id,
        user_name: user.user_name,
        contract_key: contractKey,
        tx_hash: txHash,
        block_number: blocks[contractKey],
      }, source);
    }
  }

  for (const query of data.query_results || []) {
    addQueryResult(model, query, source);
    addTransaction(model, query, source);
  }

  for (const row of data.verify_open_status?.role_logs || []) {
    addVerifyOpen(model, row, source);
  }

  for (const target of data.verify_open_status?.targets || []) {
    addUser(model, target, source);
  }
}

function buildModel(sources, loadErrors) {
  const model = {
    generated_at: new Date().toISOString(),
    read_policy: {
      mode: "read_only",
      allowed_globs: ["examples/evidence/*.json", "docs/evidence/*.json"],
      blocked_materials: [
        "FISCO BCOS live nodes",
        "certificates",
        "private keys",
        "wallet",
        "keystore",
        "conf/config.toml",
        "runtime logs",
      ],
    },
    sources: sources.map((source) => ({
      path: source.path,
      directory: source.directory,
      type: source.type,
      sha256: source.sha256,
      size_bytes: source.size_bytes,
      generated_at: source.generated_at,
      success: source.success,
      counts: {
        users: Array.isArray(source.data.users) ? source.data.users.length : 0,
        events: Array.isArray(source.data.events) ? source.data.events.length : 0,
        query_results: Array.isArray(source.data.query_results) ? source.data.query_results.length : 0,
        role_logs: Array.isArray(source.data.verify_open_status?.role_logs)
          ? source.data.verify_open_status.role_logs.length
          : 0,
      },
    })),
    load_errors: loadErrors,
    users: [],
    contracts: [],
    transactions: [],
    query_results: [],
    verify_open: [],
    reveal_fields: [],
    failure_scenarios: [],
    events: [],
    stats: {},
  };

  for (const source of sources) {
    if (Array.isArray(source.data.events)) {
      ingestEvents(model, source.data.events, source);
    }
    ingestSummary(model, source);
  }

  model.users = mergeUsers(model.users);
  model.contracts = uniqueRows(model.contracts, (row) => [row.contract_key, row.contract_name, row.contract_address].join("|"));
  model.transactions = uniqueRows(model.transactions, (row) => [row.manifest_user, row.contract_key, row.tx_hash].join("|"));
  model.query_results = uniqueRows(model.query_results, (row) => [
    row.event_id,
    row.manifest_user,
    row.contract_key,
    row.tx_hash,
    row.query,
    row.block_number,
    row.source_path,
  ].join("|"));
  model.verify_open = uniqueRows(model.verify_open, (row) => [
    row.event_id,
    row.manifest_user,
    row.node,
    row.verify_status,
    row.open_status,
    row.source_path,
  ].join("|"));
  model.reveal_fields = uniqueRows(model.reveal_fields, (row) => [row.event_id, row.manifest_user, row.source_path].join("|"));
  model.failure_scenarios = uniqueRows(model.failure_scenarios, (row) => [row.event_id, row.failure_code, row.source_path].join("|"));
  model.events = uniqueRows(model.events, (row) => [row.event_id, row.source_path].join("|"));

  const txHashes = new Set(model.transactions.map((row) => row.tx_hash).filter(Boolean));
  const blockNumbers = new Set(model.transactions.map((row) => row.block_number).filter(Boolean));
  model.stats = {
    source_count: model.sources.length,
    source_error_count: model.load_errors.length,
    user_count: model.users.length,
    contract_count: model.contracts.length,
    tx_count: txHashes.size,
    block_count: blockNumbers.size,
    query_count: model.query_results.length,
    verify_open_count: model.verify_open.length,
    reveal_field_count: model.reveal_fields.length,
    failure_scenario_count: model.failure_scenarios.length,
    structured_event_count: model.events.length,
  };

  return model;
}

async function getEvidenceModel() {
  const { sources, errors } = await loadSources();
  return buildModel(sources, errors);
}

async function serveStatic(req, res) {
  const url = new URL(req.url, "http://localhost");
  const requestedPath = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);
  const target = resolve(publicDir, `.${requestedPath}`);

  if (!isInside(target, publicDir)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  try {
    const content = await readFile(target);
    const type = contentTypes[extname(target)] || "application/octet-stream";
    res.writeHead(200, {
      "content-type": type,
      "cache-control": "no-store",
    });
    res.end(content);
  } catch (error) {
    res.writeHead(error.code === "ENOENT" ? 404 : 500);
    res.end(error.code === "ENOENT" ? "Not found" : error.message);
  }
}

async function handleRequest(req, res) {
  const url = new URL(req.url, "http://localhost");

  try {
    if (url.pathname === "/api/health") {
      const model = await getEvidenceModel();
      jsonResponse(res, model.load_errors.length ? 500 : 200, {
        ok: model.load_errors.length === 0,
        generated_at: model.generated_at,
        stats: model.stats,
        read_policy: model.read_policy,
        errors: model.load_errors,
      });
      return;
    }

    if (url.pathname === "/api/evidence") {
      jsonResponse(res, 200, await getEvidenceModel());
      return;
    }

    await serveStatic(req, res);
  } catch (error) {
    jsonResponse(res, 500, { ok: false, error: error.message });
  }
}

function parseArgs(argv) {
  const result = { check: false, port: process.env.PORT || "4173", host: process.env.HOST || "127.0.0.1" };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--check") result.check = true;
    if (arg === "--port" && argv[i + 1]) result.port = argv[++i];
    if (arg === "--host" && argv[i + 1]) result.host = argv[++i];
  }
  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.check) {
    const model = await getEvidenceModel();
    const ok = model.sources.length > 0 && model.load_errors.length === 0;
    const summary = {
      ok,
      allowed_globs: model.read_policy.allowed_globs,
      stats: model.stats,
      sources: model.sources.map((source) => source.path),
      errors: model.load_errors,
    };
    console.log(JSON.stringify(summary, null, 2));
    process.exit(ok ? 0 : 1);
  }

  const server = createServer(handleRequest);
  server.listen(Number(args.port), args.host, () => {
    console.log(`GSTBK audit console listening on http://${args.host}:${args.port}`);
    console.log("Read-only inputs: examples/evidence/*.json, docs/evidence/*.json");
  });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

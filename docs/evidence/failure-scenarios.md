# 失败场景库

下面列出六类常见故障的触发命令、预期错误和恢复方法。命令默认在 Ubuntu 虚拟机的仓库根目录执行，使用现有健康检查、E2E 脚本和测试样例。

## 基线环境

先加载 Java SDK 配置和合约地址：

```bash
export FISCO_CONFIG="$PWD/chain-apps/fisco-bcos-java-sdk/conf/config.toml"
export FISCO_GROUP=group0
export FISCO_CONSOLE_DIR=/home/gstbk/fisco/console
export GRADLE_BIN=/tmp/gradle-8.10.2/bin/gradle
export GSTBK_PERSONAL_INFO_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"
export GSTBK_SIGNATURE_APP_DIR="$PWD/chain-apps/fisco-bcos-java-sdk"

set -a
. ./.env.fisco.generated
set +a
```

可用以下命令复核基线：

```bash
bash scripts/fisco/doctor.sh
```

若当前还没有 `.env.fisco.generated`，优先使用复用模式生成：

```bash
bash scripts/fisco/bootstrap-vm-smoke.sh \
  --contract-mode reuse \
  --smoke none
```

## 场景总览

| 场景 | 预期失败点 | 错误分类 | 首选定位入口 |
| --- | --- | --- | --- |
| 缺合约地址 | `doctor.sh` 合约地址检查，或 `run-e2e.sh` 环境变量校验 | `CONFIG_CONTRACT_ADDRESS_MISSING` | `doctor.sh` |
| 缺证书 | `doctor.sh` SDK 证书目录或证书文件检查 | `CONFIG_CERT_MISSING` | `doctor.sh` |
| 链不可达 | 端口检查和 Java SDK `blockNumber` 调用 | `CHAIN_CONNECTIVITY_UNREACHABLE` | `doctor.sh` |
| 端口占用 | `run-e2e.sh` 角色端口预检 | `LOCAL_PORT_BUSY` | `run-e2e.sh` |
| 错误身份字段 | 身份字段 CLI 编码阶段 | `INPUT_IDENTITY_INVALID` | `run-id-info.sh` |
| 重复注册 | `Signature` 合约第二次 `register` 返回 `ret -1` | `CHAIN_BUSINESS_DUPLICATE_REGISTER` | `signature_run.sh` |

## 1. 缺合约地址

触发命令：

```bash
set -a
. ./.env.fisco.generated
set +a

unset GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS
unset GSTBK_SIGNATURE_CONTRACT_ADDRESS

bash scripts/fisco/doctor.sh
```

也可以从 E2E 入口触发：

```bash
bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-failure-missing-address \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 60
```

预期失败点：

- `doctor.sh` 输出 `GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS is not set.` 和 `GSTBK_SIGNATURE_CONTRACT_ADDRESS is not set.`。
- `run-e2e.sh` 在 `validating environment` 阶段失败，提示缺少必要环境变量，并在 manifest 里记录 `failed during validating environment`。

错误分类：`CONFIG_CONTRACT_ADDRESS_MISSING`，属于链端合约配置缺失。

恢复建议：

- 仅做部署前诊断时，使用 `bash scripts/fisco/doctor.sh --allow-missing-contract-addresses`。
- 需要复用当前基线合约时，运行 `bash scripts/fisco/bootstrap-vm-smoke.sh --contract-mode reuse --smoke none`，再 `set -a; . ./.env.fisco.generated; set +a`。
- 确认地址不是全零占位符；全零地址同样应视为配置错误。

## 2. 缺证书

触发命令：

```bash
tmp_cert_dir="$(mktemp -d /tmp/gstbk-missing-certs.XXXXXX)"

bash scripts/fisco/doctor.sh \
  --cert-dir "$tmp_cert_dir"
```

预期失败点：

- `doctor.sh` 能进入 SDK 配置检查，但在证书材料检查阶段输出 `Expected certificate material missing`。
- 缺少的文件通常是 `ca.crt`、`sdk.crt` 和 `sdk.key`。

错误分类：`CONFIG_CERT_MISSING`，属于 Java SDK 链接链节点所需的本地配置缺失。

恢复建议：

- 从节点 SDK 目录重新准备配置：

```bash
bash scripts/fisco/prepare-sdk-conf.sh \
  --node-sdk-dir /home/gstbk/fisco/nodes/127.0.0.1/sdk \
  --app-dir "$PWD/chain-apps/fisco-bcos-java-sdk" \
  --group group0 \
  --peers 127.0.0.1:20200,127.0.0.1:20201 \
  --force
```

- 或使用 `bash scripts/fisco/bootstrap-vm-smoke.sh --prepare-mode force --contract-mode reuse --smoke none` 串联准备、检查和复用合约。
- 恢复后执行 `git status --short --ignored`，确认 `conf/config.toml`、`conf/sdk/` 和账户材料仍被忽略。

## 3. 链不可达

触发命令：

```bash
tmp_cfg="$(mktemp /tmp/gstbk-unreachable-config.XXXXXX.toml)"
sed 's#peers = .*#peers = ["127.0.0.1:65530"]#' "$FISCO_CONFIG" > "$tmp_cfg"

FISCO_CONFIG="$tmp_cfg" bash scripts/fisco/doctor.sh \
  --config "$tmp_cfg" \
  --ports "65530" \
  --personal-info-address "$GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS" \
  --signature-address "$GSTBK_SIGNATURE_CONTRACT_ADDRESS"
```

预期失败点：

- 端口检查输出 `Port 65530 is not listening.`。
- Java SDK 调用 `blockNumber` 失败，`doctor.sh` 输出 `Java SDK blockNumber command failed.`。

错误分类：`CHAIN_CONNECTIVITY_UNREACHABLE`，属于链节点进程、端口、group 或 SDK peer 配置不可达。

恢复建议：

- 不直接重建链或清空链数据；先确认节点状态：

```bash
bash /home/gstbk/fisco/nodes/127.0.0.1/status.sh
```

- 确认 `FISCO_CONFIG` 使用真实 peers，例如 `127.0.0.1:20200,127.0.0.1:20201`。
- 确认 `FISCO_GROUP=group0` 与配置文件 `defaultGroup` 一致。
- 恢复真实配置后运行 `bash scripts/fisco/doctor.sh`，能读取 `blockNumber` 才继续 E2E。

## 4. 端口占用

触发命令：

```bash
python3 -m http.server 50000 >/tmp/gstbk-port-50000.log 2>&1 &
port_pid=$!
trap 'kill "$port_pid" 2>/dev/null || true' EXIT

bash scripts/run-local/run-e2e.sh \
  --users 2 \
  --nodes 4 \
  --runtime-dir /tmp/gstbk-failure-port-busy \
  --reuse-chain \
  --contract-addresses-from-env \
  --timeout-seconds 60
```

预期失败点：

- `run-e2e.sh` 在 `checking ports` 阶段失败，输出 `Port already in use: 50000`。
- 失败 manifest 记录 `failed during checking ports`，角色进程不会继续启动。

错误分类：`LOCAL_PORT_BUSY`，属于本机角色端口冲突。默认端口为 Proxy `50000`，Node `50001` 到 `50004`，User `60001` 到 `60006`。

恢复建议：

- 先确认端口占用来源：

```bash
ss -ltnp | grep ':50000'
```

- 如果是本轮临时触发进程，执行 `kill "$port_pid"`。
- 如果是项目服务管理脚本残留，优先使用：

```bash
GSTBK_SERVICE_RUNTIME_DIR=/tmp/gstbk-service-vm-smoke \
  bash scripts/run-local/gstbk-service.sh stop all
```

- 当前 `run-e2e.sh` 固定使用上述默认端口；先处理占用进程，再重试。

## 5. 错误身份字段

触发命令：

```bash
tmp_runtime="$(mktemp -d /tmp/gstbk-invalid-identity.XXXXXX)"
bad_input="$tmp_runtime/bad-user.json"

cat > "$bad_input" <<'JSON'
{
  "id_info": {
    "id": "11010520000101001Z",
    "name": "测试错误身份字段"
  },
  "other_info": {
    "behaivor": "缴纳税务",
    "agency": "文昌市税务局",
    "time": "2026-05-11T09:30:00+08:00",
    "location": "海南省 海口市 文昌市"
  }
}
JSON

GSTBK_RUNTIME_DIR="$tmp_runtime" \
  bash scripts/run-local/run-id-info.sh keygen

GSTBK_RUNTIME_DIR="$tmp_runtime" \
GSTBK_CL_KEYPAIR_PATH="$tmp_runtime/cl_keypair.json" \
  bash scripts/run-local/run-id-info.sh enc \
    --input "$bad_input" \
    --output "$tmp_runtime/bad-block-personal-info.json"
```

预期失败点：

- `id_info_process` 在身份字段编码阶段失败。
- 错误信息包含 `failed to encode personal identity fields` 和 `identity id check digit must be numeric or X`。

错误分类：`INPUT_IDENTITY_INVALID`，属于业务输入数据格式错误，还没有进入 CL 加密或 ZKP 验证阶段。

恢复建议：

- 使用 `examples/id-info/user1.json` 和 `examples/id-info/user2.json` 这类脱敏样例做基线。
- E2E 前先单独运行：

```bash
GSTBK_RUNTIME_DIR=/tmp/gstbk-id-check \
  bash scripts/run-local/run-id-info.sh keygen

GSTBK_RUNTIME_DIR=/tmp/gstbk-id-check \
GSTBK_CL_KEYPAIR_PATH=/tmp/gstbk-id-check/cl_keypair.json \
  bash scripts/run-local/run-id-info.sh enc \
    --input examples/id-info/user1.json \
    --output /tmp/gstbk-id-check/user1-block-personal-info.json

GSTBK_RUNTIME_DIR=/tmp/gstbk-id-check \
GSTBK_CL_KEYPAIR_PATH=/tmp/gstbk-id-check/cl_keypair.json \
  bash scripts/run-local/run-id-info.sh verify \
    --input /tmp/gstbk-id-check/user1-block-personal-info.json
```

## 6. 重复注册

触发命令：

```bash
set -a
. ./.env.fisco.generated
set +a

duplicate_user="failure_duplicate_$(date -u +%Y%m%dT%H%M%SZ)"
payload='{"scenario":"duplicate-register","source":"docs/evidence/failure-scenarios.md"}'

bash chain-apps/fisco-bcos-java-sdk/signature_run.sh \
  register "$duplicate_user" "$payload"

bash chain-apps/fisco-bcos-java-sdk/signature_run.sh \
  register "$duplicate_user" "$payload"
```

预期失败点：

- 第一次 `Signature` register 写入成功，输出 `ret 0`、`transactionHash` 和 `blockNumber`。
- 第二次同名 register 交易本身仍可上链，但合约业务返回 `ret -1`，表示该用户签名记录已存在。

错误分类：`CHAIN_BUSINESS_DUPLICATE_REGISTER`，属于合约业务返回码，不是 SDK 网络失败，也不是交易状态失败。

恢复建议：

- 正常 E2E 使用时间戳用户名前缀，避免复用链上已有用户键。
- 如果是演示重复注册，保留第二次 `ret -1` 作为业务失败证据，并用 `select` 复核原记录仍存在：

```bash
bash chain-apps/fisco-bcos-java-sdk/signature_run.sh \
  select "$duplicate_user"
```

- 如果需要完全隔离的新测试，不清空链数据；应部署新合约或使用新的用户命名空间。
- `PersonalInfo` 合约当前重复注册会更新身份密文并返回 `ret 0`，因此重复注册失败口径以 `Signature` 合约为准。

## 定位入口

`doctor.sh` 检查链端环境和配置，`run-e2e.sh` 检查角色启动条件，`run-id-info.sh` 校验身份字段，Java SDK 脚本处理合约业务返回码。复现后保存触发命令、错误分类和关键输出，便于与预期结果对照。

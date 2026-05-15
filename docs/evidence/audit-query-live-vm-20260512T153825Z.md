# 链上审计查询复核

本报告由 `scripts/evidence/run-audit-query-demo.sh` 生成，只记录只读查询命令、TX（Transaction，交易）哈希、区块高度和输出文件路径。

- Manifest（运行清单）：`/tmp/gstbk-e2e-vm-smoke/runtime-logs/20260512T153825Z/manifest.json`
- 输出目录：`/tmp/gstbk-live-audit-query-20260512T153825Z`
- dry-run（只打印命令）：`false`

## 查询步骤

| 用户 | 合约 | TX 哈希 | 登记区块 | 查询 | 命令 | 输出 | 结果 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| e2e20260512T153825Z_user1 | `Signature` | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `select` | `bash chain-apps/fisco-bcos-java-sdk/signature_run.sh select 0xcceef68c9b4811b32c75df284a1396c7c5509561 e2e20260512T153825Z_user1` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user1-signature-select.out` | exists true; signature present |
| e2e20260512T153825Z_user1 | `Signature` | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `history@block` | `bash chain-apps/fisco-bcos-java-sdk/signature_run.sh history 0xcceef68c9b4811b32c75df284a1396c7c5509561 e2e20260512T153825Z_user1 51` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user1-signature-history-block-51.out` | ret 0; signature present |
| e2e20260512T153825Z_user1 | `Signature` | `0x6241dbee06f3de44c1f8090549e7e835ba8c7d7bf7c529251370e98da2396edb` | `51` | `history@previous-block` | `bash chain-apps/fisco-bcos-java-sdk/signature_run.sh history 0xcceef68c9b4811b32c75df284a1396c7c5509561 e2e20260512T153825Z_user1 50` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user1-signature-history-block-50.out` | ret -2; signature absent |
| e2e20260512T153825Z_user1 | `PersonalInfo` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `select` | `bash chain-apps/fisco-bcos-java-sdk/info_run.sh select 0x6546c3571f17858ea45575e7c6457dad03e53dbb e2e20260512T153825Z_user1` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user1-personal-info-select.out` | exists true; info present |
| e2e20260512T153825Z_user1 | `PersonalInfo` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `history@block` | `bash chain-apps/fisco-bcos-java-sdk/info_run.sh history 0x6546c3571f17858ea45575e7c6457dad03e53dbb e2e20260512T153825Z_user1 53` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user1-personal-info-history-block-53.out` | ret 0; info present |
| e2e20260512T153825Z_user1 | `PersonalInfo` | `0xfc5613668bf381f3bd0d9b939688a909148ceddf612906c9f1a23d9ac6c6c907` | `53` | `history@previous-block` | `bash chain-apps/fisco-bcos-java-sdk/info_run.sh history 0x6546c3571f17858ea45575e7c6457dad03e53dbb e2e20260512T153825Z_user1 52` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user1-personal-info-history-block-52.out` | ret -2; info absent |
| e2e20260512T153825Z_user2 | `Signature` | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `select` | `bash chain-apps/fisco-bcos-java-sdk/signature_run.sh select 0xcceef68c9b4811b32c75df284a1396c7c5509561 e2e20260512T153825Z_user2` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user2-signature-select.out` | exists true; signature present |
| e2e20260512T153825Z_user2 | `Signature` | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `history@block` | `bash chain-apps/fisco-bcos-java-sdk/signature_run.sh history 0xcceef68c9b4811b32c75df284a1396c7c5509561 e2e20260512T153825Z_user2 52` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user2-signature-history-block-52.out` | ret 0; signature present |
| e2e20260512T153825Z_user2 | `Signature` | `0xfceab5a2c4927e908499d4a517f6c5d1fe9c3f62d2bb3c6c9e3e81d19169ff23` | `52` | `history@previous-block` | `bash chain-apps/fisco-bcos-java-sdk/signature_run.sh history 0xcceef68c9b4811b32c75df284a1396c7c5509561 e2e20260512T153825Z_user2 51` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user2-signature-history-block-51.out` | ret -2; signature absent |
| e2e20260512T153825Z_user2 | `PersonalInfo` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `select` | `bash chain-apps/fisco-bcos-java-sdk/info_run.sh select 0x6546c3571f17858ea45575e7c6457dad03e53dbb e2e20260512T153825Z_user2` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user2-personal-info-select.out` | exists true; info present |
| e2e20260512T153825Z_user2 | `PersonalInfo` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `history@block` | `bash chain-apps/fisco-bcos-java-sdk/info_run.sh history 0x6546c3571f17858ea45575e7c6457dad03e53dbb e2e20260512T153825Z_user2 54` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user2-personal-info-history-block-54.out` | ret 0; info present |
| e2e20260512T153825Z_user2 | `PersonalInfo` | `0x9b52c5c553b00196223b36ea70fb9b9c5d583ec1053d24e60ea2b87da4dcacd9` | `54` | `history@previous-block` | `bash chain-apps/fisco-bcos-java-sdk/info_run.sh history 0x6546c3571f17858ea45575e7c6457dad03e53dbb e2e20260512T153825Z_user2 53` | `/tmp/gstbk-live-audit-query-20260512T153825Z/user2-personal-info-history-block-53.out` | ret -2; info absent |

## 判读口径

- `select` 返回 `exists true` 时，说明当前主键仍可查到该用户的最新链上记录。
- `history@block` 返回 `ret 0` 时，说明可按登记区块追溯到该区块写入的历史记录。
- `history@previous-block` 通常返回 `ret -2`，用于证明登记前一区块尚无该用户的历史快照。

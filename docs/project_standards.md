# Project Standards

## 目的
這份文件定義所有未來專案都應共同遵守的最低治理標準。

治理模型預設為：AI agents 自主執行，人類保留校正與回滾權。

如果某個專案需要偏離這份標準，必須在專案文件中清楚寫出原因、影響與核准者。

## 1. Repository 標準
1. 每個專案都必須使用 Git。
2. 每個專案都必須建立 GitHub repository，且預設為 private。
3. 專案建立當天就要完成第一次 push，避免專案只存在本機。
4. 預設主要分支建議使用 `main`。
5. 除非專案明確採用更嚴格流程，AI agents 可直接在預設主要分支進行可回滾的 commit / push。
6. 所有變更都應保持小步、可追蹤、可回滾。
7. 若人類判定變更偏離原始意圖、偏離目的太遠或引入不必要風險，可要求 correction 或 rollback。

## 2. 最低文件標準
每個專案至少要有以下文件：

- `README.md`：專案摘要、目標、啟動方式、目前狀態
- `docs/project_bootstrap.md`：專案背景、範圍、交付物、風險、里程碑
- `docs/open_issues.md`：必要未知事項與 follow-up 追蹤

如果專案進入實作或維運階段，建議再補：

- `docs/decision_log.md`
- `docs/status.md`
- `CONTRIBUTING.md`

## 3. 自主執行與 Human Override
AI agents：

- 預設可自主規劃、執行、補文件、開 issue、commit、push
- 遇到必要但未知的資訊時，必須主動建立或更新 open issue
- 發現可能偏離方向時，應先縮小變更範圍，必要時主動標記風險

人類：

- 不需要逐步參與每一項工作
- 可隨時要求 correction 或 rollback
- 可重新界定原始意圖、範圍邊界與不可接受風險

## 4. Unknown / Open Issue 規則
以下情況一律要建立 GitHub open issue：

- 關鍵需求尚未確認
- 專案命名、範圍、時程、資料來源、權限、部署方式尚未確認
- 某項資訊會影響架構、交付、風險或優先順序
- 團隊決定暫時先假設，但之後必須回頭確認

不接受以下做法作為正式追蹤：

- 只寫在聊天紀錄
- 只寫 `TODO`
- 只寫在腦中或口頭約定

每一個 unknown issue 至少要包含：

- 為什麼這件事重要
- 目前缺少什麼資訊
- 如果不處理，風險是什麼
- 誰負責追蹤
- 預計何時回覆或重新檢查

## 5. Issue 最小分類建議
建議每個專案至少建立以下 labels：

- `unknown`
- `decision-needed`
- `blocking`
- `follow-up`
- `correction`
- `documentation`
- `priority:P1`
- `priority:P2`
- `priority:P3`

建議標題格式：

- `[Unknown] 確認正式專案名稱`
- `[Decision Needed] 確定 MVP 範圍`
- `[Follow-up] 補齊部署環境清單`
- `[Correction] 輸出偏離原始意圖，請修正或回滾`

## 6. 校正與回滾規則
收到 human correction / rollback 要求後，應遵守以下原則：

1. 優先修正方向，不先爭論既有做法。
2. 若最小修正不足以恢復原意，回滾最近相關提交。
3. correction / rollback 完成後，更新 README、issue、status 或其他相關文件。
4. 若 correction / rollback 揭露原本規則不足，應補開 follow-up issue。

## 7. 假設管理
允許暫時假設，但要符合以下條件：

1. 假設內容被寫進文件。
2. 假設有明確影響範圍。
3. 假設對應到一個 open issue。
4. 假設有預定檢查時間點。

## 8. 啟動完成定義
一個新專案只有在以下條件都成立時，才算完成初始化：

- Git repository 已建立
- GitHub private repository 已建立並完成首次 push
- 基本文件已建立
- AI 自主執行範圍已明確
- 人類 correction / rollback 權限已明確
- 已辨識出目前已知的必要 unknowns
- 所有必要 unknowns 都已開 issue 並寫回文件

## 9. 偏離標準的處理
若專案因法規、客戶要求、平台限制或其他原因，無法遵守本標準，應在 `docs/project_bootstrap.md` 額外增加：

- 偏離項目
- 偏離原因
- 風險
- 暫行做法
- 負責人


# New Project Checklist

## 目的
這份清單用來確認一個新專案是否已經從「想法」進入「可執行、可追蹤、可協作」的狀態。

## A. 啟動前
- [ ] 專案名稱已有暫定名稱；如果沒有，已建立命名 issue
- [ ] 已描述專案要解決的問題
- [ ] 已識別主要使用者或受益對象
- [ ] 已指定人類負責人
- [ ] 已定義 AI agents 預期扮演的角色

## B. Repository 初始化
- [ ] 已在本機建立專案資料夾
- [ ] 已初始化 Git
- [ ] 已建立 `.gitignore`
- [ ] 已建立 GitHub repository
- [ ] GitHub repository 已設為 private
- [ ] 已完成第一次 commit
- [ ] 已完成第一次 push
- [ ] 預設主要分支已確認
- [ ] 已確認是否允許 AI 直接 commit / push

## C. 文件初始化
- [ ] `README.md` 已建立
- [ ] `docs/project_bootstrap.md` 已填入基本資訊
- [ ] `docs/project_standards.md` 已納入或引用
- [ ] `docs/open_issues.md` 已建立
- [ ] `docs/decision_log.md` 已建立
- [ ] `docs/status.md` 已建立
- [ ] `.github/ISSUE_TEMPLATE/` 已建立或複製
- [ ] 專案範圍（in scope / out of scope）已寫明
- [ ] 初版里程碑已寫明
- [ ] 初版交付物已寫明

## D. Unknowns 與風險
- [ ] 第一張 open issue 已建立，用於檢查專案主資訊是否缺漏
- [ ] 已盤點必要但未知的資訊
- [ ] 每一項必要 unknown 都已建立 GitHub open issue
- [ ] 所有 open issues 都已回寫到 `docs/open_issues.md`
- [ ] blocking 類 issue 已標示清楚
- [ ] 重要假設已寫入文件
- [ ] 主要風險與對策已寫入文件

## E. 協作與治理
- [ ] AI agents 的自主執行範圍已寫明
- [ ] 人類的校正 / 回滾權已寫明
- [ ] correction / rollback 通道已決定
- [ ] 狀態更新頻率已決定
- [ ] issue labels 已建立或規劃
- [ ] 後續要不要加 `CONTRIBUTING.md` 已決定

## F. 可開始執行的判定
只有當以下條件成立時，才建議進入正式實作：

- [ ] 目標清楚
- [ ] 範圍足夠清楚
- [ ] blocking unknowns 已被處理，或已由人類明確接受風險
- [ ] repository 與文件都已可用
- [ ] 偏離原意時有明確的 correction / rollback 路徑
- [ ] 當前待辦已有可執行優先順序

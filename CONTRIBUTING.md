# CONTRIBUTING.md

## 協作模式

本專案採用 **AI-first collaborative workflow**：

- AI agents 預設可直接 commit 到 `main`（小步、可回滾）
- 人類保留 correction / rollback 權
- 詳細治理規範見 `docs/project_standards.md`

## AI Agents 規則

### ✅ **Always do**
- 遵守 `docs/project_standards.md` 所有規範
- 每個 commit 必須 atomic（單一目的）、可回滾
- Commit message 使用 Conventional Commits 格式（`feat:`, `fix:`, `docs:`, `chore:`）
- 發現 unknown / decision-needed，立即建 GitHub issue
- 變更前確認不會破壞既有功能

### ⚠️ **Ask first**
- 刪除既有功能或檔案
- 修改 CI/CD workflows (`.github/workflows/`)
- 變更專案核心架構（需在 `docs/decision_log.md` 記錄）
- 大範圍重構（影響 > 10 個檔案）

### 🚫 **Never do**
- Commit secrets、API keys、passwords
- 直接修改 production config（`config/production.*`）
- 刪除 git history 或 force push
- 修改 `docs/project_standards.md` 治理規則（需 Sovereign 核准）

## 人類貢獻者規則

### 內部協作者（repo collaborators）
- **建議流程**：Fork → Branch → PR（保留 code review 可能性）
- **允許流程**：Direct commit to `main`（需符合 AI agents 規則）

### 外部貢獻者
- **必須流程**：Fork → Branch → PR
- PR title 格式：`[feat/fix/docs/chore] <summary>`
- 確保通過所有 CI checks

## Code Review（可選）

- **預設模式**：不強制 review（信任 + 可回滾）
- **若專案啟用 review**：須在 `docs/project_bootstrap.md` 明確宣告並設定 GitHub branch protection rules

## Rollback 流程

收到人類 correction / rollback 要求後：

1. 優先修正方向，不先爭論既有做法
2. 若最小修正不足以恢復原意，回滾最近相關提交（`git revert` or `git reset`）
3. Rollback 完成後，更新 `README.md`、相關 issue、`docs/status.md`
4. 若 rollback 揭露原本規則不足，補開 follow-up issue

詳見 `docs/project_standards.md` Section 6。

## Commit Message 格式

建議使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<scope>): <subject>

<body> (optional)

<footer> (optional, e.g., Closes #123)
```

**常用 type：**
- `feat`: 新功能
- `fix`: Bug 修復
- `docs`: 文件變更
- `chore`: 維護性工作（不影響功能）
- `refactor`: 重構（不改變行為）
- `test`: 測試相關

**範例：**
```
feat(api): add user authentication endpoint

Implements JWT-based authentication for /api/users

Closes #42
```

## 疑問與討論

若不確定某項變更是否符合規範，建議先開 GitHub issue 討論，或在現有 issue 留言。

---

**本文件可依專案需求調整。若專案需更嚴格流程（如強制 PR review），請在 `docs/project_bootstrap.md` 明確宣告。**

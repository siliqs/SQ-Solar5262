# Open Issues Register

## 目的
這份文件用來集中整理「必要但尚未確認」的事項，以及已在 GitHub 建立的對應 open issues。

原則很簡單：只要這個未知事項會影響專案方向、交付、風險、時程或品質，就不能只放著不管，必須進入追蹤。

## 使用規則
1. AI agents 可主動在 GitHub 建立或更新 issue，再把連結寫回這份文件。
2. 如果 issue 尚未建立，狀態不得標示為完成。
3. 每一列都要有 owner。
4. blocking 類 issue 要在每日或每週狀態更新中追蹤。
5. 問題解決後，關閉 GitHub issue，並同步更新這份文件。
6. 若人類要求 correction / rollback，對應 issue 應補記錄原因與後續處理。

## 追蹤表模板
| 類別 | 項目 | 為何重要 | GitHub Issue | Owner | 目標日期 | 狀態 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- |
{{INITIAL_REVIEW_OPEN_ISSUES_ROW}}
| decision-needed |  |  |  |  |  | open |  |
| follow-up |  |  |  |  |  | open |  |
| correction |  |  |  |  |  | open |  |

## 建議的 issue 內容模板
```markdown
Title: [Unknown] <要確認的事項>

## 背景
這個資訊目前缺失，但會影響專案執行。

## 為什麼需要確認
- 

## 若不處理的風險
- 

## 預期輸出
- 

## Owner
- 

## 目標日期
- 
```

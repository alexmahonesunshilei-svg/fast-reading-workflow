# Zotero 同步 · Agent 指令卡

> bash 不能调 MCP。这是给 **Agent（我）** 读的指令：用户说"存进 Zotero"或工作流完成后，按这套 5 步顺序执行。

---

## 触发条件

任一即触发：
1. 用户明说："存进 Zotero" / "入 Zotero" / "同步到 Zotero"
2. `通用提取.sh --to-zotero` 末尾会打印 `[ZOTERO-SYNC-HOOK]` 标记
3. 工作流 Step 3 解读完成、且材料类型是 **学术论文/书籍** 时主动询问

---

## 5 步 MCP 调用顺序

### Step A · 入库（按 DOI 或 ISBN）

**有 DOI 的论文**：
```
mcp__zotero__zotero_add_by_doi(
  doi="10.14353/sjk.2021.29.4.03",
  collection_id=<可选，如果用户指定了 collection>
)
```

**有 ISBN 的书**：
```
mcp__zotero__zotero_add_by_url(
  url="https://book.douban.com/subject/27127895/"  # 豆瓣链接 Zotero translator 也支持
)
```

**只有本地 PDF**：
```
mcp__zotero__zotero_add_from_file(
  file_path="/Users/sunshilei/Desktop/快速阅读/库/xxx/원문.pdf",
  collection_id=<可选>
)
```

返回 `item_key`，记住，后面要用。

---

### Step B · 把解读卡当 note 挂上

```
mcp__zotero__zotero_create_note(
  parent_key=<上一步的 item_key>,
  note_html="<h1>解读卡_三档</h1>" + 解读卡_三档.md 转 HTML 后的内容,
  tags=["三档精读", "已审查通过"]
)
```

> HTML 转换：解读卡是 markdown，Zotero note 接受 HTML。简单转换：
> - `# H1` → `<h1>`
> - `## H2` → `<h2>`
> - `**bold**` → `<strong>`
> - 表格保持（markdown 表格转 `<table>`）
> - 列表 `- item` → `<ul><li>`

---

### Step C · 自动打标签（按材料变体）

```
mcp__zotero__zotero_batch_update_tags(
  item_keys=[<item_key>],
  tags_to_add=[
    <类型>,        # "学术论文" / "书籍" / "小说" / "散文" / "报刊" / "采访"
    <方法论>,       # "格雷마스语义学" / "拉康精神分析" / 等，从解读卡 §1 提取
    <博论关联>,     # "上位" / "本位" / "下位"，从新加的 §10 挂载点提取
    <章节归属>,     # "第3章本体" / "第4章案例" 等，从 §10 提取
    "已审查通过",
    "本月读"
  ]
)
```

---

### Step D · 关联到博论 collection

如果用户的 Zotero 有 "박사논문" 或 "Dissertation" collection：
```
1. 先查 collection_id：
   mcp__zotero__zotero_search_collections(query="박사논문")

2. 把 item 挪进去：
   mcp__zotero__zotero_manage_collections(
     action="add_items",
     collection_id=<查到的 id>,
     item_keys=[<item_key>]
   )
```

---

### Step E · 验证 & 报告

```
mcp__zotero__zotero_get_item_metadata(item_key=<item_key>)
```

显示给用户：
```
✅ Zotero 同步完成
  · 条目: <title>
  · Key: <item_key>
  · Tags: <tags>
  · Collection: 박사논문 → 第3章本体
  · Note: 解读卡_三档（已挂）
```

---

## 失败回退

| 失败点 | 回退 |
|---|---|
| DOI 不在 Zotero translator 库里 | 改用 `zotero_add_from_file` 直接上传 PDF |
| `zotero_create_note` HTML 解析失败 | 改用 `zotero_create_annotation`（PDF 内注释）|
| 没找到对应 collection | 创建：`zotero_create_collection(name="박사논문")` |

---

## 不要做的事

- ❌ 不要重复添加（先用 `zotero_search_by_citation_key` 或 DOI 查重）
- ❌ 不要修改用户已有的 tags（用 `tags_to_add`，不用 `replace_tags`）
- ❌ 不要在没有用户确认的情况下挪进 collection（先问"挂到博论 collection 吗"）

---

## 完整 prompt 示例（给我自己）

> 我刚完成 `~/Desktop/快速阅读/库/02-书籍/xxx/` 的精读。
> 用户说"存进 Zotero"。
> 我应该：
>   1. 读 `元数据.md` 拿 DOI/ISBN
>   2. 读 `解读卡_三档.md` §10 拿挂载点
>   3. 顺序跑 Step A → E
>   4. 报告给用户

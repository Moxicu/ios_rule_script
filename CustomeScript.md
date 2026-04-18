可以。下面我按**完全新手**的方式，从零开始带你做一遍。你的默认分支是 **`main`**，所以后面我都按 `main` 写。GitHub 的 fork 可以从网页直接创建；fork 之后可以在仓库首页用 **Sync fork** 更新分支；GitHub Actions 也支持手动触发和定时触发。`actions/checkout@v4` 在需要拉完整历史时，建议配 `fetch-depth: 0`。([GitHub Docs][1])

---

# 你最终要达到的效果

你会得到：

1. 一个你自己的 GitHub 仓库（是从上游 fork 来的）
2. 仓库里有 3 个你自己维护的文件：

   * `remove_rules.list`：写要删除的规则
   * `add_rules.list`：写要新增的规则
   * `ChinaMax_All_No_Resolve_Custom.list`：自动生成，不手改
3. 一个 GitHub Actions 工作流，会自动：

   * 同步上游更新
   * 重新生成你的自定义规则文件
   * 自动提交到你自己的仓库
4. Surge 最后引用的是**你自己的 raw 链接**

---

# 先理解这 3 个文件各自干什么

你以后只需要维护这两个：

## 1）删除列表

文件名：

```text
rule/Surge/Custom/remove_rules.list
```

这里一行一条，写“要从上游规则里删掉”的内容。
例如：

```txt
DOMAIN-SUFFIX,sciencedirect.com
```

## 2）新增列表

文件名：

```text
rule/Surge/Custom/add_rules.list
```

这里一行一条，写“你想额外加进去”的规则。
例如：

```txt
DOMAIN-SUFFIX,efilmcloud.com
```

## 3）最终生成的文件

文件名：

```text
rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list
```

这个文件**不手工编辑**。它由脚本自动生成。

---

# 第 1 步：Fork 上游仓库

1. 打开上游仓库页面：`blackmatrix7/ios_rule_script`
2. 点击右上角 **Fork**
3. 选择你的账号
4. 等 GitHub 创建完成

GitHub 官方把 fork 定义为：基于原仓库创建一个你自己的仓库副本，方便你在没有上游写权限时维护自己的改动。([GitHub Docs][1])

完成后，你会看到你自己的仓库，大概是：

```text
https://github.com/你的用户名/ios_rule_script
```

---

# 第 2 步：先打开 Actions 功能

这是新手最容易漏的一步。

因为 fork 出来的仓库，工作流一开始可能不会自动运行；GitHub 社区说明过，新 fork 往往需要仓库拥有者先到 **Actions** 页签确认启用。([GitHub][2])

操作：

1. 进入你 fork 后的仓库首页
2. 点上方菜单里的 **Actions**
3. 如果看到类似“workflows aren’t being run on this forked repository”之类的提示
4. 按页面提示启用

做完这一步，后面工作流才更顺利。

---

# 第 3 步：创建 `remove_rules.list`

现在开始加文件。

1. 在你的仓库首页，点击 **Add file**
2. 点击 **Create new file**
3. 在文件名输入框里粘贴：

```text
rule/Surge/Custom/remove_rules.list
```

GitHub 网页创建新文件时，如果路径里的目录不存在，会一起创建。

4. 在大文本框里填入：

```txt
# 写你想删除的规则，一行一条
DOMAIN-SUFFIX,sciencedirect.com
```

5. 页面下方 **Commit changes...**
6. 提交信息写：

```text
add remove_rules.list
```

7. 点 **Commit changes**

---

# 第 4 步：创建 `add_rules.list`

1. 再次点击 **Add file**
2. 点击 **Create new file**
3. 文件名填：

```text
rule/Surge/Custom/add_rules.list
```

4. 内容填：

```txt
# 写你想新增的规则，一行一条
DOMAIN-SUFFIX,efilmcloud.com
```

5. 往下滚动，点击 **Commit changes**
6. 提交信息写：

```text
add add_rules.list
```

7. 提交

---

# 第 5 步：创建构建脚本

这个脚本负责：

* 读取上游 `ChinaMax_All_No_Resolve.list`
* 删除 `remove_rules.list` 里列出的规则
* 添加 `add_rules.list` 里列出的规则
* 生成 `ChinaMax_All_No_Resolve_Custom.list`

操作：

1. 点击 **Add file**
2. 点击 **Create new file**
3. 文件名填：

```text
scripts/build_chinamax_custom.sh
```

4. 内容完整粘贴下面这段：

```bash
#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_FILE="rule/Surge/ChinaMax/ChinaMax_All_No_Resolve.list"
REMOVE_FILE="rule/Surge/Custom/remove_rules.list"
ADD_FILE="rule/Surge/Custom/add_rules.list"
OUTPUT_FILE="rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# 先复制上游文件
cp "$UPSTREAM_FILE" "$OUTPUT_FILE"

# 删除 remove_rules.list 中列出的规则
if [ -f "$REMOVE_FILE" ]; then
  while IFS= read -r rule || [ -n "$rule" ]; do
    # 跳过空行和注释
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue

    awk -v target="$rule" '$0 != target' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"
    mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
  done < "$REMOVE_FILE"
fi

# 追加 add_rules.list 中的规则
if [ -f "$ADD_FILE" ]; then
  printf '\n# ===== My custom added rules =====\n' >> "$OUTPUT_FILE"
  while IFS= read -r rule || [ -n "$rule" ]; do
    # 跳过空行和注释
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue

    # 避免重复追加
    if ! grep -Fxq "$rule" "$OUTPUT_FILE"; then
      echo "$rule" >> "$OUTPUT_FILE"
    fi
  done < "$ADD_FILE"
fi

echo "Generated: $OUTPUT_FILE"
```

5. 点击 **Commit changes**
6. 提交信息写：

```text
add build script
```

7. 提交

---

# 第 6 步：创建 GitHub Actions 工作流

这是最关键的一步。

GitHub Actions 支持：

* `workflow_dispatch`：手动点按钮运行
* `schedule`：按 cron 定时运行。([GitHub Docs][3])

1. 点击 **Add file**
2. 点击 **Create new file**
3. 文件名填：

```text
.github/workflows/sync-and-build.yml
```

4. 把下面内容完整粘贴进去：

```yaml
name: Sync upstream and build custom rules

on:
  workflow_dispatch:
  schedule:
    - cron: "0 */6 * * *"

permissions:
  contents: write

jobs:
  sync-and-build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

      - name: Add upstream remote
        run: |
          git remote add upstream https://github.com/blackmatrix7/ios_rule_script.git || true
          git fetch upstream

      - name: Sync main from upstream
        run: |
          git checkout main
          git merge upstream/main --no-edit

      - name: Build custom rule file
        run: |
          chmod +x scripts/build_chinamax_custom.sh
          ./scripts/build_chinamax_custom.sh

      - name: Commit and push changes
        run: |
          git add rule/Surge/Custom/remove_rules.list
          git add rule/Surge/Custom/add_rules.list
          git add rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list
          git add scripts/build_chinamax_custom.sh
          git add .github/workflows/sync-and-build.yml

          if git diff --cached --quiet; then
            echo "No changes to commit"
          else
            git commit -m "chore: sync upstream and rebuild custom Surge rules"
            git push
          fi
```

这里有几个关键点：

* `actions/checkout@v4` 用来把仓库代码取到运行环境中；它默认只拉一层历史，官方说明如果要完整历史，设 `fetch-depth: 0`。([GitHub][4])
* `schedule` 里的 `cron: "0 */6 * * *"` 表示每 6 小时运行一次。
* `workflow_dispatch` 让你可以在网页里手动点 **Run workflow**。
* `permissions: contents: write` 让工作流有权限把生成后的文件推回仓库。

5. 点击 **Commit changes**
6. 提交信息写：

```text
add workflow
```

7. 提交

---

# 第 7 步：手动运行一次工作流

现在工作流文件已经进仓库了。

操作：

1. 打开你仓库顶部的 **Actions**
2. 左侧找到 `Sync upstream and build custom rules`
3. 点进去
4. 右侧点 **Run workflow**
5. 分支选 `main`
6. 点绿色按钮确认运行

GitHub 官方的 workflow 文档说明，`workflow_dispatch` 就是给这种手动运行准备的。([GitHub Docs][3])

---

# 第 8 步：查看有没有运行成功

运行后：

1. 点进这次运行记录
2. 看每一步是不是绿色对勾

如果成功，你的仓库里会多出这个文件：

```text
rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list
```

打开它，检查两件事：

1. 里面**没有**这行：

```txt
DOMAIN-SUFFIX,sciencedirect.com
```

2. 里面**有**这行：

```txt
DOMAIN-SUFFIX,efilmcloud.com
```

---

# 第 9 步：把 Surge 链接改成你自己的

你现在不要再引用原始上游链接，而是引用你 fork 里生成的文件。

把这条：

```ini
RULE-SET,https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/refs/heads/master/rule/Surge/ChinaMax/ChinaMax_All_No_Resolve.list,DIRECT
```

改成：

```ini
RULE-SET,https://raw.githubusercontent.com/你的用户名/ios_rule_script/refs/heads/main/rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list,DIRECT
```

把“你的用户名”换成你的 GitHub 用户名。

---

# 第 10 步：以后你怎么维护

以后你只改两个文件。

## 想删除更多规则

打开：

```text
rule/Surge/Custom/remove_rules.list
```

继续一行一条往下加，例如：

```txt
# 删除不想要的规则
DOMAIN-SUFFIX,sciencedirect.com
DOMAIN-SUFFIX,example-remove1.com
DOMAIN,old.example.com
```

## 想新增更多规则

打开：

```text
rule/Surge/Custom/add_rules.list
```

继续一行一条往下加，例如：

```txt
# 新增规则
DOMAIN-SUFFIX,efilmcloud.com
DOMAIN-SUFFIX,example-add1.com
DOMAIN,api.example.com
```

然后：

1. 提交改动
2. 去 **Actions**
3. 手动点一次 **Run workflow**

或者等它自动定时跑。

---

# 以后同步上游，有两种方式

## 方式 A：完全靠 Actions

这是你最省心的方式。
工作流每 6 小时自动运行一次，自动 `git fetch upstream` + `git merge upstream/main`。这就是你现在已经配置好的。

## 方式 B：手工点 GitHub 网页上的 Sync fork

GitHub 官方也支持在 fork 仓库主页直接点 **Sync fork** → **Update branch** 来同步上游。发生冲突时，GitHub 会提示你处理。([GitHub Docs][5])

对你来说，优先用 **Actions 自动同步** 就够了；网页上的 **Sync fork** 可以当备用。

---

# 你最可能遇到的几个问题

## 1）Actions 页面没有 Run workflow 按钮

通常是这几个原因：

* 你还没提交 `.github/workflows/sync-and-build.yml`
* 你还没在 fork 的 **Actions** 页签里启用工作流
* 你看的不是默认分支 `main`

先检查这三项。

## 2）工作流报 merge conflict

如果上游改动和你 fork 上对同一部分产生冲突，自动 merge 可能失败。GitHub 官方也说明了：sync fork 遇到冲突时，需要人工处理。([GitHub Docs][5])

不过按我给你的结构：

* 上游规则文件不手改
* 你只改 `Custom/` 和脚本

冲突概率已经很低了。

## 3）raw 链接改了，但 Surge 没马上更新

GitHub raw 内容可能会有缓存，不一定每次立刻刷新。这个现象在 GitHub 社区讨论里有人提过。([GitHub][2])

一般等一会儿再更新即可。

---

# 你现在最值得复制保存的 4 段内容

## `rule/Surge/Custom/remove_rules.list`

```txt
# 写你想删除的规则，一行一条
DOMAIN-SUFFIX,sciencedirect.com
```

## `rule/Surge/Custom/add_rules.list`

```txt
# 写你想新增的规则，一行一条
DOMAIN-SUFFIX,efilmcloud.com
```

## `scripts/build_chinamax_custom.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_FILE="rule/Surge/ChinaMax/ChinaMax_All_No_Resolve.list"
REMOVE_FILE="rule/Surge/Custom/remove_rules.list"
ADD_FILE="rule/Surge/Custom/add_rules.list"
OUTPUT_FILE="rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# 先复制上游文件
cp "$UPSTREAM_FILE" "$OUTPUT_FILE"

# 删除 remove_rules.list 中列出的规则
if [ -f "$REMOVE_FILE" ]; then
  while IFS= read -r rule || [ -n "$rule" ]; do
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue

    awk -v target="$rule" '$0 != target' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"
    mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
  done < "$REMOVE_FILE"
fi

# 追加 add_rules.list 中的规则
if [ -f "$ADD_FILE" ]; then
  printf '\n# ===== My custom added rules =====\n' >> "$OUTPUT_FILE"
  while IFS= read -r rule || [ -n "$rule" ]; do
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue

    if ! grep -Fxq "$rule" "$OUTPUT_FILE"; then
      echo "$rule" >> "$OUTPUT_FILE"
    fi
  done < "$ADD_FILE"
fi

echo "Generated: $OUTPUT_FILE"
```

## `.github/workflows/sync-and-build.yml`

```yaml
name: Sync upstream and build custom rules

on:
  workflow_dispatch:
  schedule:
    - cron: "0 */6 * * *"

permissions:
  contents: write

jobs:
  sync-and-build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

      - name: Add upstream remote
        run: |
          git remote add upstream https://github.com/blackmatrix7/ios_rule_script.git || true
          git fetch upstream

      - name: Sync main from upstream
        run: |
          git checkout main
          git merge upstream/main --no-edit

      - name: Build custom rule file
        run: |
          chmod +x scripts/build_chinamax_custom.sh
          ./scripts/build_chinamax_custom.sh

      - name: Commit and push changes
        run: |
          git add rule/Surge/Custom/remove_rules.list
          git add rule/Surge/Custom/add_rules.list
          git add rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list
          git add scripts/build_chinamax_custom.sh
          git add .github/workflows/sync-and-build.yml

          if git diff --cached --quiet; then
            echo "No changes to commit"
          else
            git commit -m "chore: sync upstream and rebuild custom Surge rules"
            git push
          fi
```

---

# 最后一步：你在 Surge 里要用的地址

把下面这行里的 `你的用户名` 换掉：

```ini
RULE-SET,https://raw.githubusercontent.com/你的用户名/ios_rule_script/refs/heads/main/rule/Surge/Custom/ChinaMax_All_No_Resolve_Custom.list,DIRECT
```

---

如果你愿意，我下一条可以直接按**GitHub 网页界面**的顺序，给你写成“第几步点哪里、看到什么算对”的清单版。

[1]: https://docs.github.com/articles/fork-a-repo?utm_source=chatgpt.com "Fork a repository"
[2]: https://github.com/orgs/community/discussions/53510?utm_source=chatgpt.com "Changes in `.github/workflows/` silently enable Actions on ..."
[3]: https://docs.github.com/actions?utm_source=chatgpt.com "GitHub Actions documentation"
[4]: https://github.com/actions/checkout?utm_source=chatgpt.com "actions/checkout: Action for checking out a repo"
[5]: https://docs.github.com/articles/syncing-a-fork?utm_source=chatgpt.com "Syncing a fork"

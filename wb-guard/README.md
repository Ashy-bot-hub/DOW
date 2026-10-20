# WB-GUARD

WorkBuddy / WorkDaddy 桌面端的一个容错补丁：拦截切换会话（任务）时触发的整页「出错了」黑屏。

## 问题现象

在 WorkBuddy 中切换对话或任务时，页面偶尔被整屏错误页替换，DevTools 控制台可见：

```
NotFoundError: Failed to execute 'removeChild' on 'Node'
```

该异常由 React 卸载流程抛出：`removeChild` 的目标节点其父节点已发生变化，调用随即失败；异常冒泡到错误边界，错误边界按设计渲染整页错误界面，表现为「出错了」。

## 修复思路

WorkDaddy 会向 WorkBuddy 渲染进程注入 `scripts/inject.js`。本补丁在该文件最前面插入一段守卫，包装 `Node.prototype.removeChild`：

| 调用情形 | 处理方式 |
|---|---|
| `child.parentNode !== this`（节点已不在该父节点下） | 跳过删除，`window.__wbRCGuarded` 累加 |
| 其他任何情形 | 原样调用原生实现，语义不变 |

跳过删除后不再抛异常，错误边界不被触发，页面保持可用。

## 文件结构

```
wb-guard/
├── README.md
└── scripts/
    ├── install-wb-guard.ps1      # 安装 / 校验 / 还原脚本，无外部依赖
    └── wb-removechild-guard.js   # 守卫源码，供手动插入时参考
```

`install-wb-guard.ps1` 内置同一份守卫代码，无需引用 `.js` 文件；`.js` 仅为阅读与手工粘贴提供完整实现和注释。

## 安装

在项目目录打开 PowerShell：

```powershell
# 安装：自动备份 inject.js，幂等，可重复执行
powershell -ExecutionPolicy Bypass -File .\scripts\install-wb-guard.ps1

# 仅检查当前是否已打补丁
powershell -ExecutionPolicy Bypass -File .\scripts\install-wb-guard.ps1 -Verify

# 还原到打补丁前
powershell -ExecutionPolicy Bypass -File .\scripts\install-wb-guard.ps1 -Restore

# 非标准安装位置时指定目录
powershell -ExecutionPolicy Bypass -File .\scripts\install-wb-guard.ps1 -ScriptsDir "D:\Apps\WorkDaddy\scripts"
```

默认目标：`%LOCALAPPDATA%\Programs\WorkDaddy\scripts\inject.js`

退出码含义：`0` 成功 / `1` 未打补丁（`-Verify`）/ `2` 未找到 `inject.js` / `3` 未找到备份 / `4` 写入后校验失败。

## 验证

1. 重启 WorkDaddy（或 WorkBuddy），使 `inject.js` 重新注入。
2. 开发者工具控制台执行：

```js
window.__wbRCGuardInstalled   // true = 补丁已加载
window.__wbRCGuarded          // 累加 = 守卫实际拦截次数
```

若 `__wbRCGuarded` 持续增长，说明该环境确实存在节点错位卸载，补丁正在生效。

## 已知代价

- 被跳过的删除会留下孤立 DOM 节点，极端情况下可见轻微界面残影。
- 这是容错处理，不是根因修复。上游修复该卸载时序问题后即可移除本补丁。

## 维护

- WorkDaddy 每次升级会覆盖 `inject.js`，补丁需重新执行安装脚本；脚本幂等，重复执行安全，已存在守卫时直接跳过。
- 备份文件名 `inject.js.bak-wbguard`，在首次安装时生成，后续安装不覆盖，因此 `-Restore` 始终还原到最早的原件。
- 卸载方式：`-Restore`，或用备份文件手动覆盖 `inject.js`。

## 适用范围

补丁只改写 `inject.js` 这一个文件，不注册服务、不修改系统设置。凡加载该文件的环境即生效，未加载该文件的环境不受影响。

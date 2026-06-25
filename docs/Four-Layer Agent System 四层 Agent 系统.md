# Four-Layer Agent System 四层 Agent 系统

## 定义

这是一份用于定位 Agent 问题来源的参考文档。

核心命题：

```text
prompt、context、harness、loop
不是四个互相替代的阶段，
而是 Agent 干活时同时在场的四个部件。
```

嵌套关系：

```text
Model ⊂ Prompt ⊂ Context ⊂ Harness ⊂ Loop
```

## 四层解释

### 1. Prompt

Prompt 是直接发给模型的任务指令。

它解决的问题是：

- 任务目标是否清楚
- 输出格式是否明确
- 约束条件是否说清楚
- 判断标准是否完整

在千里马里，通常对应：

- task cards
- templates
- 输出要求

### 2. Context

Context 是模型当前可见的工作台。

它解决的问题是：

- 当前读了哪些文件
- 读入的信息是否够用
- 是否被无关内容干扰
- 是否出现 context rot

在千里马里，通常对应：

- `.qianlima/WORKSPACE_INDEX.md`
- `.qianlima/work.ws`
- `.qianlima/context-policy.yaml`
- `docs/README.md`

### 3. Harness

Harness 是 Agent 的工具层、权限层和执行边界。

它解决的问题是：

- 能不能读文件
- 能不能调用数据源
- 能不能执行脚本
- 有没有权限和风险护栏

在千里马里，通常对应：

- `.qianlima/data-sources.yaml`
- `.qianlima/file-registry.yaml`
- `.qianlima/risk-rules.yaml`
- `start-qianlima.ps1`

### 4. Loop

Loop 是任务执行后的自治循环。

它解决的问题是：

- 是否继续执行
- 是否需要停止
- 是否要进入评估
- 是否要更新规则、模板或偏好
- 是否出现高成本空转

在千里马里，通常对应：

- `Loop Engineering 循环工程.md`
- `.qianlima/improvement-loop.yaml`
- `.qianlima/evaluation-tasks.yaml`
- `.qianlima/usage-ledger/`

## 故障定位

遇到问题时，先判断故障在哪一层。

```text
答非所问 -> prompt
聊久了变笨/忘事 -> context
查不到文件/做不了操作 -> harness
停不下来/烧钱 -> loop
```

这条规则的价值在于：

- 不把所有问题都归到 prompt
- 不用错误的方法修错误的层
- 能更快定位该改模板、上下文、工具还是循环

## 千里马里的用法

在千里马里，这份文档不负责执行，它负责判断。

使用方式：

1. 任务失败时先按四层定位
2. 判断是 prompt、context、harness 还是 loop 问题
3. 再去改对应文件，不要盲改

常见映射：

```text
prompt   -> task cards / templates
context  -> WORKSPACE_INDEX / work.ws / context-policy
harness  -> data-sources / file-registry / risk-rules / startup scripts
loop     -> improvement-loop / evaluation-tasks / usage-ledger
```

## 和 Loop Engineering 的关系

Four-Layer Agent System 负责“先判断问题在哪一层”。

Loop Engineering 负责“发现问题后，怎么进入执行、评估、分析、改进、记录、再执行”。

所以这两份文档的关系是：

```text
Four-Layer Agent System
  -> 负责定位
Loop Engineering
  -> 负责闭环改进
```

## 一句话版本

搭 Agent 遇到问题时，先看问题卡在哪一层，再决定改哪里。

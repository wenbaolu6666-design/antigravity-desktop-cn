// 本地化规则回归测试：问候语、模型通知、思考等级、活动流子项
const fs = require('fs');
const path = require('path');
const assert = require('assert');

global.Node = { TEXT_NODE: 3 };
global.document = { body: {}, documentElement: {} };
const engine = fs.readFileSync(path.join(__dirname, '..', 'localization_engine.js'), 'utf8');
const norm = (value) => String(value || '').replace(/\s+/g, ' ').trim();

function loadFunction(name) {
  const start = engine.indexOf('    function ' + name + '(');
  if (start < 0) throw new Error('未找到函数 ' + name);
  const end = engine.indexOf('\n    }\n', start);
  const source = engine.slice(start, end + 7).replace(/\\\\/g, '\\');
  return eval('(' + source.trim() + ')');
}

global.isToolActivityContext = loadFunction('isToolActivityContext');
const greeting = loadFunction('getHomeGreetingTranslation');
const notice = loadFunction('getModelNoticeTranslation');
const effort = loadFunction('getModelEffortTranslation');
const workspaceName = loadFunction('getWorkspaceDisplayNameTranslation');
const workspaceRow = { nodeType: 3, parentElement: { getAttribute: (n) => n === 'data-testid' ? 'conversation-row-sidebar' : null, parentElement: null } };
const normalNode = { nodeType: 3, parentElement: { getAttribute: () => null, parentElement: null } };
assert.strictEqual(workspaceName(workspaceRow, 'Codex Session Import Plugin'), 'Codex 会话导入插件');
assert.strictEqual(workspaceName(workspaceRow, 'Codex Session Import'), 'Codex 会话导入');
assert.strictEqual(workspaceName(workspaceRow, 'Translate Skills Into Chinese'), '将技能翻译成中文');
assert.strictEqual(workspaceName(workspaceRow, 'My Own Workspace'), null);
assert.strictEqual(workspaceName(normalNode, 'Codex Session Import'), null);
const activityDetail = loadFunction('getToolActivityDetailTranslation');
const activityStatus = loadFunction('getToolActivityStatusTranslation');
const activityPhrase = loadFunction('getActivityRowPhraseTranslation');
const thoughtHeader = loadFunction('isThoughtHeaderText');
const artifactUi = loadFunction('getArtifactCardUiTranslation');
const agentSaid = loadFunction('getAgentSaidTranslation');

const greetingNode = { nodeType: 3, parentElement: { className: 'home-greeting-title', parentElement: null, getAttribute: () => null } };
for (const name of ['张三', '李四', 'Alice', 'Bob Smith', '欧阳娜娜']) {
  assert.strictEqual(greeting(greetingNode, `Welcome back, ${name}. Where should we pick up?`), `欢迎回来，${name}。想从哪里继续？`);
  assert.strictEqual(greeting(greetingNode, `Hey ${name}, what should we build today?`), `你好，${name}。今天想构建点什么？`);
  assert.strictEqual(greeting(greetingNode, `Good to see you, ${name}. What's next?`), `很高兴见到你，${name}。接下来做什么？`);
}
assert.strictEqual(greeting(greetingNode, 'Welcome back. Where should we pick up?'), '欢迎回来。想从哪里继续？');

assert.strictEqual(notice({}, 'Gemini 4 Hydrogen is currently available to paid Pro and Ultra subscribers.'), 'Gemini 4 Hydrogen 目前仅向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'Gemini 4 Argon is currently available to Ultra and paid Pro plan subscribers.'), 'Gemini 4 Argon 目前仅向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'Gemini 4 Argon is now available to paid Pro and Ultra subscribers.'), 'Gemini 4 Argon 现已向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'Gemini 4 Carbon is available only to paid Pro and Ultra subscribers.'), 'Gemini 4 Carbon 仅向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'GPT-OSS will be removed from Antigravity on November 18, 2026.'), 'GPT-OSS 将于 2026 年 11 月 18 日从 Antigravity 中移除。');
assert.strictEqual(notice({}, 'Claude Opus 4.6 is currently unavailable on your current plan.'), 'Claude Opus 4.6 在您当前计划中不可用。');
assert.strictEqual(notice({}, 'Gemini 4 Hydrogen requires a paid Pro or Ultra plan.'), 'Gemini 4 Hydrogen 需要付费 Pro 或 Ultra 计划。');
assert.strictEqual(notice({}, 'Opus 5.5 is now available on paid Pro and Ultra plans. Third-party model access will no longer be available on your current plan starting on November 18, 2026.'), 'Opus 5.5 现已向付费 Pro 与 Ultra 计划开放。自 2026 年 11 月 18 日起，您当前计划将不再提供第三方模型。');

const effortOptionNode = { nodeType: 3, parentElement: { getAttribute: (n) => n === 'data-testid' ? 'model-selector-effort-option' : null, hasAttribute: () => false, className: 'truncate', previousElementSibling: null, parentElement: null, closest: () => null } };
const effortGroupNode = { nodeType: 3, parentElement: { getAttribute: () => null, hasAttribute: () => false, className: 'shrink-0 opacity-70 text-sm', previousElementSibling: { getAttribute: (n) => n === 'data-testid' ? 'model-selector-effort-group' : null }, parentElement: null, closest: () => null } };
const effortTriggerNode = { nodeType: 3, parentElement: { getAttribute: () => null, hasAttribute: () => false, className: 'opacity-70', previousElementSibling: null, parentElement: null, closest: () => ({}) } };
assert.strictEqual(effort(effortOptionNode, 'Low'), '低');
assert.strictEqual(effort(effortOptionNode, 'Medium'), '中');
assert.strictEqual(effort(effortOptionNode, 'High'), '高');
assert.strictEqual(effort(effortOptionNode, 'Extra'), '极高');
assert.strictEqual(effort(effortOptionNode, 'Max'), '最高');
assert.strictEqual(effort(effortGroupNode, 'High'), '高');
assert.strictEqual(effort(effortTriggerNode, ' High · 1M'), ' 高 · 1M');
assert.strictEqual(effort({}, 'High'), null);

const activityNode = { nodeType: 3, parentElement: { tagName: 'SPAN', className: 'leading-snug text-muted-foreground', getAttribute: () => null, parentElement: null } };
const proseNode = { nodeType: 3, parentElement: { tagName: 'P', className: 'prose markdown', getAttribute: () => null, parentElement: null } };
assert.strictEqual(activityDetail(activityNode, 'Searched marketplace for "codex", "session import", "conversation"'), '已在插件市场搜索 "codex", "session import", "conversation"');
assert.strictEqual(activityDetail(activityNode, 'Searched codex conversation history session import export antigravity'), '已搜索 codex conversation history session import export antigravity');
assert.strictEqual(activityDetail(activityNode, 'Fetched dataset'), '已获取 dataset');
assert.strictEqual(activityDetail(activityNode, 'Created file'), '已创建 file');
assert.strictEqual(activityDetail(activityNode, 'Compacting conversation'), '正在压缩 conversation');
assert.strictEqual(activityDetail(proseNode, 'Searched something'), null);
assert.strictEqual(activityStatus(activityNode, 'Working'), '工作中');
assert.strictEqual(activityStatus(proseNode, 'Working'), null);
assert.strictEqual(activityStatus(activityNode, 'Canceled'), '已取消');
assert.strictEqual(activityStatus(activityNode, 'Killed'), '已终止');
assert.strictEqual(activityStatus(activityNode, 'Checked'), '已检查');
assert.strictEqual(activityDetail(activityNode, 'Canceled run find_Qc.js'), '已取消运行 find_Qc.js');
assert.strictEqual(activityDetail(activityNode, 'Killed task Search $Qc usages'), '已终止任务 Search $Qc usages');
assert.strictEqual(activityPhrase('Canceled search $Qc usages'), '已取消搜索 $Qc usages');
assert.strictEqual(activityPhrase('Killed task Search $Qc usages'), '已终止任务 搜索 $Qc usages');
assert.strictEqual(activityPhrase('Created js find_Qc.js +10 -0'), '已创建 js find_Qc.js +10 -0');
assert.strictEqual(thoughtHeader('思考 7 秒'), true);
assert.strictEqual(thoughtHeader('Thought for 7s'), true);
assert.strictEqual(thoughtHeader('工作了 44 秒'), false);
assert.strictEqual(thoughtHeader('Worked for 44s'), false);
const artifactNode = { nodeType: 3, parentElement: { closest: () => ({}) } };
assert.strictEqual(artifactUi(artifactNode, '3 files changed'), '3 个文件已更改');
assert.strictEqual(artifactUi(artifactNode, 'files changed'), '个文件已更改');
assert.strictEqual(artifactUi(artifactNode, 'Review'), '审查');
assert.strictEqual(artifactUi(artifactNode, 'Agent said'), '智能体说');
assert.strictEqual(artifactUi(artifactNode, 'random text'), null);
assert.strictEqual(artifactUi({ nodeType: 3, parentElement: { closest: () => null } }, 'Review'), null);
const plainNode = { nodeType: 3, parentElement: { className: '', hasAttribute: () => false, parentElement: null } };
const thoughtProseNode = { nodeType: 3, parentElement: { className: 'prose markdown', hasAttribute: () => false, parentElement: null } };
assert.strictEqual(agentSaid(plainNode, 'Agent said'), '智能体说');
assert.strictEqual(agentSaid(thoughtProseNode, 'Agent said'), null);

const commonDict = require('../dicts/common.json');
assert.strictEqual(commonDict['Agent said'], '智能体说');
assert.strictEqual(commonDict['files changed'], '个文件已更改');
assert.strictEqual(commonDict['Auto'], '自动');
assert.strictEqual(commonDict['Review'], '审查');

console.log('本地化规则测试全部通过');



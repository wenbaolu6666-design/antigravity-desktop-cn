// 本地化规则回归测试：问候语保留任意用户名，模型通知覆盖常见句式
const fs = require('fs');
const path = require('path');
const assert = require('assert');

global.Node = { TEXT_NODE: 3 };
const engine = fs.readFileSync(path.join(__dirname, '..', 'localization_engine.js'), 'utf8');
const norm = (value) => String(value || '').replace(/\s+/g, ' ').trim();

function loadFunction(name) {
  const start = engine.indexOf('    function ' + name + '(node, value) {');
  if (start < 0) throw new Error('未找到函数 ' + name);
  const end = engine.indexOf('\n    }\n', start);
  const source = engine.slice(start, end + 7).replace(/\\\\/g, '\\');
  return eval('(' + source.trim() + ')');
}

const greeting = loadFunction('getHomeGreetingTranslation');
const notice = loadFunction('getModelNoticeTranslation');
const greetingNode = { nodeType: 3, parentElement: { className: 'home-greeting-title', parentElement: null, getAttribute: () => null } };

for (const name of ['张三', '李四', 'Alice', 'Bob Smith', '欧阳娜娜']) {
  assert.strictEqual(greeting(greetingNode, `Welcome back, ${name}. Where should we pick up?`), `欢迎回来，${name}。想从哪里继续？`);
  assert.strictEqual(greeting(greetingNode, `Hey ${name}, what should we build today?`), `你好，${name}。今天想构建点什么？`);
  assert.strictEqual(greeting(greetingNode, `Good to see you, ${name}. What's next?`), `很高兴见到你，${name}。接下来做什么？`);
}
assert.strictEqual(greeting(greetingNode, 'Welcome back. Where should we pick up?'), '欢迎回来。想从哪里继续？');

assert.strictEqual(notice({}, 'Gemini 4 Hydrogen is currently available to paid Pro and Ultra subscribers.'), 'Gemini 4 Hydrogen 目前仅向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'Gemini 4 Argon is now available to paid Pro and Ultra subscribers.'), 'Gemini 4 Argon 现已向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'Gemini 4 Carbon is available only to paid Pro and Ultra subscribers.'), 'Gemini 4 Carbon 向付费 Pro 与 Ultra 订阅用户提供。');
assert.strictEqual(notice({}, 'Claude Opus 4.6 is currently unavailable on your current plan.'), 'Claude Opus 4.6 在您当前计划中不可用。');
assert.strictEqual(notice({}, 'Opus 5.5 is now available on paid Pro and Ultra plans. Third-party model access will no longer be available on your current plan starting on November 18, 2026.'), 'Opus 5.5 现已向付费 Pro 与 Ultra 计划开放。自 2026 年 11 月 18 日起，您当前计划将不再提供第三方模型。');

console.log('本地化规则测试全部通过');

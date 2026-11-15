#!/usr/bin/env node
// 对编译后的 main.js 做源码级 UI 汉化：只替换字符串/模板字面量，保留 ${变量}
const fs = require('fs');
const acorn = require('./vendor/acorn.js');

const [mainPath, dictPath, outPath = mainPath] = process.argv.slice(2);
if (!mainPath || !dictPath) {
  console.error('用法：node apply-source-i18n.js <main.js> <dict.json> [输出文件]');
  process.exit(1);
}
const src = fs.readFileSync(mainPath, 'utf8');
const dict = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
const ast = acorn.parse(src, { ecmaVersion: 'latest', sourceType: 'script', allowReturnOutsideFunction: true });

const css = /(?:^|\s)(?:!|\[&|bg-|text-|border-|rounded|shadow|flex|grid|inline|block|hidden|absolute|relative|fixed|sticky|inset|top-|bottom-|left-|right-|z-|w-|h-|min-|max-|p-|px-|py-|pt-|pb-|pl-|pr-|m-|mx-|my-|mt-|mb-|ml-|mr-|gap-|space-|items-|justify-|content-|overflow-|opacity-|font-|leading-|tracking-|animate-|transition|duration-|ease-|hover:|focus:|group-|peer-|cursor-|select-|pointer-events|whitespace-|truncate|shrink|grow|basis-|col-|row-|order-|aspect-|object-|fill-|stroke-|backdrop-|ring-|outline-|divide-|from-|via-|to-|bg-linear|bg-radial|calc\(|var\()/i;
const UI_PROPS = new Set(['title', 'label', 'description', 'tooltip', 'tooltipContent', 'placeholder', 'aria-label', 'ariaLabel', 'message', 'header', 'subtitle', 'secondaryTitle', 'confirmText', 'cancelText', 'emptyText', 'alt', 'summary', 'prefix']);
const TECH_VALUE = /^(?:Edition|FeatureSet|Semantic|DescriptorProto|FieldDescriptorProto|FileDescriptorProto|EnumDescriptorProto|ServiceDescriptorProto|MethodDescriptorProto|EditionDefault|FeatureSupport|UninterpretedOption|FieldOptions|MessageOptions|EnumOptions|ServiceOptions|MethodOptions|FileOptions)$/;

function isTechnical(value) { return TECH_VALUE.test(value) || value.startsWith('.google.protobuf.') || value.includes('google.protobuf.') || /^(?:translate|scale|rotate|matrix|skew|translate3d|scale3d|rotate3d|matrix3d)\s*\(/i.test(value) || /^url\(/i.test(value) || /^[Mm][\d\s,.-]+/.test(value); }

function safe(value) {
  if (!value || value.length < 4 || value.length > 200) return false;
  if (!value.includes(' ')) return false;
  const plain = value.replace(/\$\{\.\.\.\}/g, '');
  if (/[{}<>]/.test(plain)) return false;
  if (/:\/\/|\b(?:Error|failed|invalid|expected|missing|cannot|must be|offset|parse|token|stack|undefined|null)\b/i.test(value)) return false;
  if (css.test(value)) return false;
  return true;
}

const candidates = [];
function buildTemplate(translation, node) {
  const parts = translation.split('${...}');
  if (parts.length - 1 !== node.expressions.length) return null;
  let out = '`';
  for (let i = 0; i < parts.length; i++) {
    out += parts[i].replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$\{/g, '\\${');
    if (i < node.expressions.length) out += '${' + src.slice(node.expressions[i].start, node.expressions[i].end) + '}';
  }
  return out + '`';
}

function walk(node, parent, uiContext = false) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (const child of node) walk(child, parent, uiContext);
    return;
  }
  if (node.type === 'CallExpression' && node.callee) {
    const callee = src.slice(node.callee.start, node.callee.end);
    if (callee === 'createElement' || callee.endsWith('.createElement')) {
      for (let i = 0; i < node.arguments.length; i++) {
        walk(node.arguments[i], node, i >= 2 ? true : uiContext);
      }
      return;
    }
  }
  if (node.type === 'Property') {
    const keyName = !node.computed && node.key.type === 'Identifier' ? node.key.name : (!node.computed && node.key.type === 'Literal' ? node.key.value : '');
    walk(node.key, node, uiContext);
    walk(node.value, node, uiContext || UI_PROPS.has(keyName));
    return;
  }
  if (node.type === 'Literal' && typeof node.value === 'string') {
    const key = node.value;
    if (isTechnical(key)) return;
    if (parent && parent.type === 'Property' && parent.key === node) return;
    if (parent && parent.type === 'ImportDeclaration') return;
    if (dict[key] && dict[key] !== key && (safe(key) || uiContext)) {
      candidates.push({ start: node.start, end: node.end, replacement: JSON.stringify(dict[key]), key });
    }
  } else if (node.type === 'TemplateLiteral') {
    const key = node.quasis.map((q) => q.value.cooked || '').join('${...}');
    if (isTechnical(key)) return;
    if (dict[key] && dict[key] !== key && (safe(key) || uiContext)) {
      const replacement = buildTemplate(dict[key], node);
      if (replacement) candidates.push({ start: node.start, end: node.end, replacement, key });
    }
  }
  for (const key of Object.keys(node)) {
    if (['start', 'end', 'loc', 'range', 'parent'].includes(key)) continue;
    walk(node[key], node, uiContext);
  }
}

walk(ast, null);
candidates.sort((a, b) => a.start - b.start || b.end - a.end);
const kept = [];
let lastEnd = -1;
for (const candidate of candidates) {
  if (candidate.start >= lastEnd) {
    kept.push(candidate);
    lastEnd = candidate.end;
  }
}
let output = src;
for (let i = kept.length - 1; i >= 0; i--) {
  const candidate = kept[i];
  output = output.slice(0, candidate.start) + candidate.replacement + output.slice(candidate.end);
}
try {
  acorn.parse(output, { ecmaVersion: 'latest', sourceType: 'script', allowReturnOutsideFunction: true });
} catch (error) {
  console.error('生成后的 main.js 语法错误：' + error.message);
  process.exit(2);
}
fs.writeFileSync(outPath, output, 'utf8');
console.log(`源码汉化完成：${kept.length} 处 UI 文案`);



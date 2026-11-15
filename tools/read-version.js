// 读取 app.asar 内 package.json 的客户端版本号
const path = require('path');
const { readFile } = require('./asar.js');
const archive = process.argv[2];
if (!archive) {
  console.error('用法：node read-version.js <app.asar>');
  process.exit(1);
}
const buffer = readFile(archive, 'package.json');
if (!buffer) {
  console.error('未找到 package.json');
  process.exit(2);
}
try {
  const pkg = JSON.parse(buffer.toString('utf8'));
  process.stdout.write(String(pkg.version || ''));
} catch (error) {
  console.error('解析 package.json 失败：' + error.message);
  process.exit(3);
}

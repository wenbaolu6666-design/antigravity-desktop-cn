#!/usr/bin/env node
// 从 language_server.exe 中定位并解包内嵌的 Web UI ZIP
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

function findEmbeddedZip(buffer) {
  const results = [];
  const sig = Buffer.from([0x50, 0x4b, 0x05, 0x06]);
  let offset = 0;
  while ((offset = buffer.indexOf(sig, offset)) !== -1) {
    if (offset + 22 > buffer.length) break;
    const commentLength = buffer.readUInt16LE(offset + 20);
    if (offset + 22 + commentLength !== buffer.length && offset + 22 + commentLength > buffer.length) {
      offset += 4;
      continue;
    }
    const centralSize = buffer.readUInt32LE(offset + 12);
    const centralOffset = buffer.readUInt32LE(offset + 16);
    const start = offset - centralOffset - centralSize;
    if (start >= 0 && start + 4 <= buffer.length && buffer.readUInt32LE(start) === 0x04034b50) {
      results.push({ start, end: offset + 22 + commentLength, size: offset + 22 + commentLength - start });
    }
    offset += 4;
  }
  return results.sort((a, b) => b.size - a.size)[0] || null;
}

function extractZip(buffer, archive, outputDir) {
  const eocd = archive.end - 22 - buffer.readUInt16LE(archive.end - 2);
  const entryCount = buffer.readUInt16LE(eocd + 10);
  const centralSize = buffer.readUInt32LE(eocd + 12);
  const centralOffset = buffer.readUInt32LE(eocd + 16);
  let cursor = archive.start + centralOffset;
  let files = 0;
  for (let index = 0; index < entryCount; index++) {
    if (buffer.readUInt32LE(cursor) !== 0x02014b50) throw new Error('中央目录损坏');
    const method = buffer.readUInt16LE(cursor + 10);
    const compressedSize = buffer.readUInt32LE(cursor + 20);
    const uncompressedSize = buffer.readUInt32LE(cursor + 24);
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const localOffset = buffer.readUInt32LE(cursor + 42);
    const name = buffer.toString('utf8', cursor + 46, cursor + 46 + nameLength).replace(/\\/g, '/');
    const local = archive.start + localOffset;
    if (buffer.readUInt32LE(local) !== 0x04034b50) throw new Error('本地头损坏：' + name);
    const localNameLength = buffer.readUInt16LE(local + 26);
    const localExtraLength = buffer.readUInt16LE(local + 28);
    const dataStart = local + 30 + localNameLength + localExtraLength;
    const target = path.join(outputDir, ...name.split('/').filter(Boolean));
    if (name.endsWith('/')) {
      fs.mkdirSync(target, { recursive: true });
    } else {
      fs.mkdirSync(path.dirname(target), { recursive: true });
      const raw = buffer.subarray(dataStart, dataStart + compressedSize);
      let data;
      if (method === 0) data = Buffer.from(raw);
      else if (method === 8) data = zlib.inflateRawSync(raw);
      else throw new Error('不支持的压缩方式 ' + method + '：' + name);
      if (data.length !== uncompressedSize) throw new Error('解压长度不符：' + name);
      fs.writeFileSync(target, data);
      files++;
    }
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  return files;
}

if (require.main === module) {
  const [command, exePath, outputDir] = process.argv.slice(2);
  if (!command || !exePath) {
    console.error('用法：node web-bundle.js <find|extract> <language_server.exe> [输出目录]');
    process.exit(1);
  }
  const buffer = fs.readFileSync(exePath);
  const archive = findEmbeddedZip(buffer);
  if (!archive) { console.error('未找到内嵌 Web UI ZIP'); process.exit(2); }
  if (command === 'find') {
    console.log(JSON.stringify(archive));
  } else if (command === 'extract') {
    if (!outputDir) { console.error('缺少输出目录'); process.exit(1); }
    fs.mkdirSync(outputDir, { recursive: true });
    const count = extractZip(buffer, archive, outputDir);
    console.log(`已解包 ${count} 个文件到 ${outputDir}`);
  } else {
    console.error('未知命令：' + command);
    process.exit(1);
  }
}

module.exports = { findEmbeddedZip, extractZip };

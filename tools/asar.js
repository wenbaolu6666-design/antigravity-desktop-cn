#!/usr/bin/env node
// 轻量 asar 解包工具：支持列出与提取文件，避免额外安装依赖
const fs = require('fs');
const path = require('path');

function readArchive(archivePath) {
  const buffer = fs.readFileSync(archivePath);
  const headerSize = buffer.readUInt32LE(4);
  const jsonLength = buffer.readUInt32LE(12);
  const header = JSON.parse(buffer.toString('utf8', 16, 16 + jsonLength));
  const dataBase = 8 + headerSize;
  return { buffer, header, dataBase };
}

function walk(node, prefix, output) {
  for (const [name, entry] of Object.entries(node.files)) {
    const current = prefix ? `${prefix}/${name}` : name;
    if (entry.files) {
      walk(entry, current, output);
    } else {
      output.push({ path: current, entry });
    }
  }
}

function listFiles(archivePath) {
  const { header } = readArchive(archivePath);
  const output = [];
  walk(header, '', output);
  return output;
}

function extractFile(archivePath, targetPath, outputDir) {
  const { buffer, dataBase } = readArchive(archivePath);
  const found = listFiles(archivePath).find((item) => item.path === targetPath);
  if (!found) {
    throw new Error(`归档中不存在：${targetPath}`);
  }
  const destination = path.join(outputDir, ...targetPath.split('/'));
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  if (found.entry.unpacked) {
    throw new Error(`文件位于 unpacked 目录：${targetPath}`);
  }
  const start = dataBase + Number(found.entry.offset);
  fs.writeFileSync(destination, buffer.subarray(start, start + found.entry.size));
  return destination;
}

function readFile(archivePath, targetPath) {
  const { buffer, dataBase } = readArchive(archivePath);
  const found = listFiles(archivePath).find((item) => item.path === targetPath);
  if (!found) return null;
  if (found.entry.unpacked) return null;
  const start = dataBase + Number(found.entry.offset);
  return buffer.subarray(start, start + found.entry.size);
}

function extractAll(archivePath, outputDir) {
  const { buffer, dataBase } = readArchive(archivePath);
  const files = listFiles(archivePath);
  let count = 0;
  for (const item of files) {
    if (item.entry.unpacked) continue;
    const destination = path.join(outputDir, ...item.path.split('/'));
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    const start = dataBase + Number(item.entry.offset);
    fs.writeFileSync(destination, buffer.subarray(start, start + item.entry.size));
    count += 1;
  }
  return count;
}

if (require.main === module) {
  const [command, archivePath, ...rest] = process.argv.slice(2);
  if (!command || !archivePath) {
    console.error('用法：node asar.js <list|extract|extract-all> <app.asar> [目标路径] [输出目录]');
    process.exit(1);
  }
  if (command === 'list') {
    for (const item of listFiles(archivePath)) {
      console.log(`${item.entry.size}\t${item.path}`);
    }
  } else if (command === 'extract') {
    const [targetPath, outputDir] = rest;
    console.log(extractFile(archivePath, targetPath, outputDir));
  } else if (command === 'extract-all') {
    const [outputDir] = rest;
    console.log(`已提取 ${extractAll(archivePath, outputDir)} 个文件到 ${outputDir}`);
  } else {
    console.error(`未知命令：${command}`);
    process.exit(1);
  }
}

module.exports = { listFiles, extractFile, extractAll, readFile };

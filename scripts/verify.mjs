import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import swift from '@ast-grep/lang-swift';
import { registerDynamicLanguage, parse } from '@ast-grep/napi';
import xcode from 'xcode';
import plist from 'plist';

function walk(folder) {
  return fs.readdirSync(folder, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(`${folder}/${e.name}`) : [`${folder}/${e.name}`]);
}
registerDynamicLanguage({ swift });
const appSources = walk('CountdownApp').filter(f => f.endsWith('.swift'));
const tests = walk('CountdownAppTests').filter(f => f.endsWith('.swift'));
let errors = 0;
for (const file of [...appSources, ...tests, 'Package.swift']) {
  const root = parse('swift', fs.readFileSync(file, 'utf8')).root();
  const invalid = root.findAll({ rule: { kind: 'ERROR' } });
  for (const node of invalid) {
    console.error(`${file}:${node.range().start.line + 1}: syntax: ${node.text().slice(0, 180)}`);
    errors++;
  }
}
assert.equal(errors, 0, 'Swift grammar errors');
console.log(`Swift syntax parsed: ${appSources.length} app sources, ${tests.length} test sources, Package.swift.`);
const project = xcode.project('CountdownApp.xcodeproj/project.pbxproj');
project.parseSync();
const refs = project.pbxFileReferenceSection();
const paths = new Set(Object.values(refs).filter(v => typeof v === 'object').map(v => v.path?.replace(/^"|"$/g, '')));
for (const source of [...appSources, ...tests]) assert(paths.has(source), `Source absent from project: ${source}`);
for (const [key, ref] of Object.entries(refs)) {
  if (typeof ref !== 'object' || !ref.path || ref.sourceTree === 'BUILT_PRODUCTS_DIR') continue;
  assert(fs.existsSync(ref.path.replace(/^"|"$/g, '')), `Missing project resource ${key}: ${ref.path}`);
}
const info = plist.parse(fs.readFileSync('CountdownApp/Resources/Info.plist', 'utf8'));
const privacy = plist.parse(fs.readFileSync('CountdownApp/Resources/PrivacyInfo.xcprivacy', 'utf8'));
assert.equal(privacy.NSPrivacyTracking, false);
assert.equal(info.UIAppFonts.length, 3);
const names = [];
for (const font of info.UIAppFonts) {
  const b = fs.readFileSync(path.join('CountdownApp/Resources', font));
  let offset;
  for (let i = 0; i < b.readUInt16BE(4); i++) { const o = 12 + i * 16; if (b.toString('ascii', o, o + 4) === 'name') offset = b.readUInt32BE(o + 8); }
  assert.notEqual(offset, undefined);
  const strings = offset + b.readUInt16BE(offset + 4), count = b.readUInt16BE(offset + 2);
  for (let i = 0; i < count; i++) {
    const o = offset + 6 + i * 12;
    if (b.readUInt16BE(o) !== 3 || b.readUInt16BE(o + 6) !== 6) continue;
    const start = strings + b.readUInt16BE(o + 10), length = b.readUInt16BE(o + 8);
    names.push(Buffer.from(b.subarray(start, start + length)).swap16().toString('utf16le'));
    break;
  }
}
assert.deepEqual(names, ['CalendarNunito-Regular', 'CalendarNunito-Bold', 'CalendarNunito-Heavy']);
for (const file of walk('CountdownApp/Resources/Assets.xcassets').filter(p => p.endsWith('Contents.json'))) {
  const catalog = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const image of catalog.images ?? []) if (image.filename) assert(fs.existsSync(path.join(path.dirname(file), image.filename)));
}
const icon = fs.readFileSync('CountdownApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png');
assert.equal(icon.readUInt32BE(16), 1024); assert.equal(icon.readUInt32BE(20), 1024);
assert.equal(icon[25], 2, 'App icon must be opaque RGB');
const testCases = tests.reduce((n, f) => n + (fs.readFileSync(f, 'utf8').match(/func test\w+/g) ?? []).length, 0);
console.log(`Xcode project parsed; all Swift files referenced; resources, plist files, 1024px icon, and three distinct font names verified.`);
console.log(`${testCases} XCTest cases included. Syntax/resource checks do NOT compile Swift or execute these tests.`);

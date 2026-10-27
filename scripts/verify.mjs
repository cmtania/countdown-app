import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import swift from '@ast-grep/lang-swift';
import { registerDynamicLanguage, parse } from '@ast-grep/napi';
import xcode from 'xcode';
import plist from 'plist';
import { parse as parseYAML } from 'yaml';

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
const objects = project.hash.project.objects;
const unquote = value => String(value).replace(/^"|"$/g, '');
const records = section => Object.entries(section ?? {}).filter(([, value]) => typeof value === 'object');
const referenceID = ref => typeof ref === 'object' ? ref.value : ref;
const groups = { ...objects.PBXGroup, ...objects.PBXVariantGroup };
const projectObject = records(objects.PBXProject)[0][1];
const paths = new Set();
// XcodeGen uses nested groups; the portable generator uses SOURCE_ROOT paths.
function resolveReference(id, parent = '') {
  const ref = groups[id] ?? refs[id];
  if (!ref || unquote(ref.sourceTree) === 'BUILT_PRODUCTS_DIR') return;
  const sourceRoot = unquote(ref.sourceTree) === 'SOURCE_ROOT';
  const relative = ref.path ? unquote(ref.path) : '';
  const resolved = path.posix.normalize(path.posix.join(sourceRoot ? '' : parent, relative));
  if (groups[id]) {
    for (const child of ref.children ?? []) resolveReference(referenceID(child), resolved === '.' ? '' : resolved);
  } else {
    assert(fs.existsSync(resolved), `Missing project resource: ${resolved}`);
    paths.add(resolved);
  }
}
resolveReference(projectObject.mainGroup);
for (const source of [...appSources, ...tests]) assert(paths.has(source), `Source absent from project: ${source}`);

const spec = parseYAML(fs.readFileSync('project.yml', 'utf8'));
assert.equal(spec.name, 'CountdownApp');
assert.equal(spec.targets.CountdownApp.type, 'application');
assert.equal(spec.targets.CountdownAppTests.type, 'bundle.unit-test');
assert(spec.targets.CountdownAppTests.dependencies.some(d => d.target === 'CountdownApp'));
assert(spec.schemes.CountdownApp.test.targets.includes('CountdownAppTests'));
assert.equal(spec.schemes.CountdownApp.build.targets.CountdownApp, 'all');
const fontsEntry = spec.targets.CountdownApp.sources.find(s => s.path === 'CountdownApp/Resources/Fonts');
assert.equal(fontsEntry?.type, 'folder', 'Fonts must retain their bundle subdirectory');
assert.equal(fontsEntry?.buildPhase, 'resources');
assert(spec.targets.CountdownApp.sources.find(s => s.path === 'CountdownApp').excludes.includes('Resources'), 'Avoid duplicate resource compilation');
for (const target of Object.values(spec.targets)) {
  for (const source of target.sources) assert(fs.existsSync(source.path), `Missing spec source: ${source.path}`);
}
const normalizedSetting = value => Array.isArray(value) ? value.map(unquote).join(' ') : unquote(value);
for (const [, target] of records(objects.PBXNativeTarget)) {
  const name = unquote(target.name);
  const expected = spec.targets[name];
  assert(expected, `Generated target missing from project.yml: ${name}`);
  const configList = objects.XCConfigurationList[target.buildConfigurationList];
  for (const configRef of configList.buildConfigurations) {
    const config = objects.XCBuildConfiguration[referenceID(configRef)];
    for (const [key, value] of Object.entries(expected.settings.base)) {
      assert.equal(normalizedSetting(config.buildSettings[key]), String(value), `${name}/${config.name}: project.yml differs for ${key}`);
    }
  }
}
console.log('XcodeGen spec parsed; target settings, scheme, source paths, and font-folder packaging verified.');
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

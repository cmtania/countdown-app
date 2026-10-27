import fs from 'node:fs/promises';
import crypto from 'node:crypto';

const id = value => crypto.createHash('sha256').update(`CountdownApp:${value}`).digest('hex').slice(0, 24).toUpperCase();
const q = JSON.stringify;
const developmentTeam = 'MD42BG8ZP4'; // Same Apple Developer team as StepFurr.
const objects = [];
const add = (key, body) => { objects.push({ isa: body.match(/^isa = (\w+)/)[1], text: `${id(key)} = { ${body} };` }); return id(key); };
const list = values => `(${values.map(v => `${v},`).join(' ')})`;
async function files(folder) {
  const result = [];
  for (const entry of await fs.readdir(folder, { withFileTypes: true })) {
    const path = `${folder}/${entry.name}`;
    if (entry.isDirectory()) result.push(...await files(path));
    else if (path.endsWith('.swift')) result.push(path);
  }
  return result.sort();
}
const appFiles = await files('CountdownApp'), tests = await files('CountdownAppTests');
const appRefs = [], testRefs = [], sources = [], testSources = [], resourceRefs = [], resources = [];
for (const [paths, refs, builds] of [[appFiles, appRefs, sources], [tests, testRefs, testSources]]) {
  for (const path of paths) {
    const ref = add(`ref:${path}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${q(path)}; sourceTree = SOURCE_ROOT;`);
    refs.push(ref); builds.push(add(`build:${path}`, `isa = PBXBuildFile; fileRef = ${ref};`));
  }
}
for (const [name, type] of [['Fonts', 'folder'], ['Assets.xcassets', 'folder.assetcatalog'], ['PrivacyInfo.xcprivacy', 'text.xml']]) {
  const path = `CountdownApp/Resources/${name}`;
  const ref = add(`ref:${path}`, `isa = PBXFileReference; lastKnownFileType = ${type}; path = ${q(path)}; sourceTree = SOURCE_ROOT;`);
  resourceRefs.push(ref); resources.push(add(`build:${path}`, `isa = PBXBuildFile; fileRef = ${ref};`));
}
resourceRefs.push(add('ref:info', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "CountdownApp/Resources/Info.plist"; sourceTree = SOURCE_ROOT;'));
const appProduct = add('product:app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = CountdownApp.app; includeInIndex = 0; sourceTree = BUILT_PRODUCTS_DIR;');
const testProduct = add('product:tests', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CountdownAppTests.xctest; includeInIndex = 0; sourceTree = BUILT_PRODUCTS_DIR;');
const groups = [
  add('group:app', `isa = PBXGroup; children = ${list(appRefs)}; name = App; sourceTree = "<group>";`),
  add('group:resources', `isa = PBXGroup; children = ${list(resourceRefs)}; name = Resources; sourceTree = "<group>";`),
  add('group:tests', `isa = PBXGroup; children = ${list(testRefs)}; name = Tests; sourceTree = "<group>";`),
  add('group:products', `isa = PBXGroup; children = ${list([appProduct, testProduct])}; name = Products; sourceTree = "<group>";`)
];
const mainGroup = add('group:main', `isa = PBXGroup; children = ${list(groups)}; sourceTree = "<group>";`);
const phase = (key, isa, builds) => add(key, `isa = ${isa}; buildActionMask = 2147483647; files = ${list(builds)}; runOnlyForDeploymentPostprocessing = 0;`);
const appPhases = [phase('sources:app', 'PBXSourcesBuildPhase', sources), phase('frameworks:app', 'PBXFrameworksBuildPhase', []), phase('resources:app', 'PBXResourcesBuildPhase', resources)];
const testPhases = [phase('sources:tests', 'PBXSourcesBuildPhase', testSources), phase('frameworks:tests', 'PBXFrameworksBuildPhase', []), phase('resources:tests', 'PBXResourcesBuildPhase', [])];
function configs(name, settings) {
  const configs = ['Debug', 'Release'].map(config => {
    const values = { ...settings, SWIFT_OPTIMIZATION_LEVEL: config === 'Debug' ? '-Onone' : '-O', DEBUG_INFORMATION_FORMAT: config === 'Debug' ? 'dwarf' : 'dwarf-with-dsym', ENABLE_TESTABILITY: config === 'Debug' ? 'YES' : 'NO', SWIFT_ACTIVE_COMPILATION_CONDITIONS: config === 'Debug' ? '$(inherited) DEBUG' : '$(inherited)' };
    return add(`config:${name}:${config}`, `isa = XCBuildConfiguration; buildSettings = { ${Object.entries(values).map(([key, value]) => `${key} = ${q(String(value))};`).join(' ')} }; name = ${config};`);
  });
  return add(`configs:${name}`, `isa = XCConfigurationList; buildConfigurations = ${list(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
const projectConfigs = configs('project', { CLANG_ENABLE_MODULES: 'YES', CLANG_ENABLE_OBJC_ARC: 'YES', SWIFT_VERSION: '5.0', IPHONEOS_DEPLOYMENT_TARGET: '17.0', SDKROOT: 'iphoneos', TARGETED_DEVICE_FAMILY: '1', SWIFT_STRICT_CONCURRENCY: 'targeted' });
const appConfigs = configs('app', { PRODUCT_NAME: '$(TARGET_NAME)', PRODUCT_BUNDLE_IDENTIFIER: 'com.example.countdownapp', INFOPLIST_FILE: 'CountdownApp/Resources/Info.plist', GENERATE_INFOPLIST_FILE: 'NO', ASSETCATALOG_COMPILER_APPICON_NAME: 'AppIcon', ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: 'AccentColor', CURRENT_PROJECT_VERSION: '1', MARKETING_VERSION: '1.0', CODE_SIGN_STYLE: 'Automatic', DEVELOPMENT_TEAM: developmentTeam, SWIFT_EMIT_LOC_STRINGS: 'YES', SUPPORTED_PLATFORMS: 'iphoneos iphonesimulator', SUPPORTS_MACCATALYST: 'NO', SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: 'NO', LD_RUNPATH_SEARCH_PATHS: '$(inherited) @executable_path/Frameworks' });
const testConfigs = configs('tests', { PRODUCT_NAME: '$(TARGET_NAME)', PRODUCT_BUNDLE_IDENTIFIER: 'com.example.countdownapp.tests', GENERATE_INFOPLIST_FILE: 'YES', TEST_HOST: '$(BUILT_PRODUCTS_DIR)/CountdownApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CountdownApp', BUNDLE_LOADER: '$(TEST_HOST)', CODE_SIGN_STYLE: 'Automatic', DEVELOPMENT_TEAM: developmentTeam, LD_RUNPATH_SEARCH_PATHS: '$(inherited) @executable_path/Frameworks @loader_path/Frameworks' });
const proxy = add('proxy:app', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${id('target:app')}; remoteInfo = CountdownApp;`);
const dependency = add('dependency:app', `isa = PBXTargetDependency; target = ${id('target:app')}; targetProxy = ${proxy};`);
add('target:app', `isa = PBXNativeTarget; buildConfigurationList = ${appConfigs}; buildPhases = ${list(appPhases)}; buildRules = (); dependencies = (); name = CountdownApp; productName = CountdownApp; productReference = ${appProduct}; productType = "com.apple.product-type.application";`);
add('target:tests', `isa = PBXNativeTarget; buildConfigurationList = ${testConfigs}; buildPhases = ${list(testPhases)}; buildRules = (); dependencies = ${list([dependency])}; name = CountdownAppTests; productName = CountdownAppTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
add('project', `isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1500; TargetAttributes = { ${id('target:app')} = { CreatedOnToolsVersion = 15.0; }; ${id('target:tests')} = { CreatedOnToolsVersion = 15.0; TestTargetID = ${id('target:app')}; }; }; }; buildConfigurationList = ${projectConfigs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base,); mainGroup = ${mainGroup}; productRefGroup = ${id('group:products')}; projectDirPath = ""; projectRoot = ""; targets = ${list([id('target:app'), id('target:tests')])};`);
await fs.mkdir('CountdownApp.xcodeproj/xcshareddata/xcschemes', { recursive: true });
const sections = [...new Set(objects.map(o => o.isa))].sort().map(isa => `/* Begin ${isa} section */\n${objects.filter(o => o.isa === isa).map(o => o.text).join('\n')}\n/* End ${isa} section */`).join('\n');
await fs.writeFile('CountdownApp.xcodeproj/project.pbxproj', `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${sections}\n}; rootObject = ${id('project')}; }\n`);
const ref = target => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id(`target:${target}`)}" BuildableName="${target === 'app' ? 'CountdownApp.app' : 'CountdownAppTests.xctest'}" BlueprintName="${target === 'app' ? 'CountdownApp' : 'CountdownAppTests'}" ReferencedContainer="container:CountdownApp.xcodeproj"/>`;
await fs.writeFile('CountdownApp.xcodeproj/xcshareddata/xcschemes/CountdownApp.xcscheme', `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${ref('app')}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">${ref('tests')}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref('app')}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref('app')}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n`);
console.log(`Generated Xcode project: ${appFiles.length} app sources, ${tests.length} test sources.`);

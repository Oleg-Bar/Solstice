#!/usr/bin/env python3
"""Generate the checked-in Xcode project. No third-party packages required."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value), ensure_ascii=False)
def add(key, body):
    ident = uid(key)
    objects[ident] = body
    return ident
def refs(items): return '(' + ', '.join(items) + (',' if items else '') + ')'

shared = sorted(str(p.relative_to(root)) for folder in ['Core','Rendering','UI'] for p in (root/'Sources'/folder).glob('*.swift')) + ['Sources/AstronomyC/astronomy.c']
preview = sorted(str(p.relative_to(root)) for p in (root/'Sources/Preview').glob('*.swift'))
saver = ['Sources/Screensaver/TerraScreenSaverView.swift']
tests = ['Tests/TerraCoreTests.swift']
assets = sorted(str(p.relative_to(root)) for p in (root/'Resources').iterdir() if p.is_file())
file_refs = {}
for path in shared+preview+saver+tests+assets:
    kind = 'sourcecode.swift' if path.endswith('.swift') else ('sourcecode.c.c' if path.endswith('.c') else ('image.jpeg' if path.endswith('.jpg') else 'text'))
    file_refs[path] = add('file:'+path, '{isa = PBXFileReference; lastKnownFileType = '+kind+'; path = '+q(path)+'; sourceTree = SOURCE_ROOT;}')

source_group = add('sources', '{isa = PBXGroup; name = Sources; children = '+refs([file_refs[x] for x in shared+preview+saver+tests])+'; sourceTree = "<group>";}')
asset_group = add('assets', '{isa = PBXGroup; name = Resources; children = '+refs([file_refs[x] for x in assets])+'; sourceTree = "<group>";}')
products = []; targets = []; schemes = []
base = {'MACOSX_DEPLOYMENT_TARGET':'13.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES',
        'CODE_SIGN_IDENTITY':'-','CODE_SIGN_STYLE':'Manual','DEVELOPMENT_TEAM':'','COMBINE_HIDPI_IMAGES':'YES',
        'GENERATE_INFOPLIST_FILE':'YES','CURRENT_PROJECT_VERSION':'2','MARKETING_VERSION':'1.01',
        'HEADER_SEARCH_PATHS':'$(SRCROOT)/Sources/AstronomyC/include',
        'SWIFT_INCLUDE_PATHS':'$(SRCROOT)/Sources/AstronomyC/include',
        'ENABLE_HARDENED_RUNTIME':'NO','SWIFT_EMIT_LOC_STRINGS':'NO'}
def config_list(key, settings):
    configs = []
    for mode in ['Debug','Release']:
        fields = dict(settings)
        fields.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O', 'DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'})
        if mode=='Debug': fields['ENABLE_TESTABILITY']='YES'
        configs.append(add(key+mode,'{isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+' '.join(k+' = '+q(v)+';' for k,v in fields.items())+'};}'))
    return add(key+'configs','{isa = XCConfigurationList; buildConfigurations = '+refs(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')

for name, product, product_type, files, resources, identifier in [
    ('TerraPreview','Terra Preview.app','com.apple.product-type.application',shared+preview,assets,'studio.terra.preview'),
    ('TerraSaver','Terra.saver','com.apple.product-type.bundle',shared+saver,assets,'studio.terra.screensaver'),
    ('TerraCoreTests','TerraCoreTests.xctest','com.apple.product-type.bundle.unit-test',[x for x in shared if '/Core/' in x or x.endswith('.c')]+tests,[],'studio.terra.tests')]:
    prod = add('product:'+name,'{isa = PBXFileReference; explicitFileType = '+('wrapper.application' if name=='TerraPreview' else 'wrapper.cfbundle')+'; path = '+q(product)+'; sourceTree = BUILT_PRODUCTS_DIR;}')
    products.append(prod)
    phases = []
    for kind, selected in [('Sources',files),('Resources',resources)]:
        builds = [add(name+':'+path,'{isa = PBXBuildFile; fileRef = '+file_refs[path]+';}') for path in selected]
        phases.append(add(name+kind,'{isa = PBX'+kind+'BuildPhase; buildActionMask = 2147483647; files = '+refs(builds)+'; runOnlyForDeploymentPostprocessing = 0;}'))
    settings = dict(base)
    settings.update({'PRODUCT_BUNDLE_IDENTIFIER':identifier,'PRODUCT_NAME':product.rsplit('.',1)[0], 'PRODUCT_MODULE_NAME':name})
    if name=='TerraSaver':
        settings.update({'WRAPPER_EXTENSION':'saver','MACH_O_TYPE':'mh_bundle','INFOPLIST_KEY_NSPrincipalClass':'TerraScreenSaverView','SKIP_INSTALL':'YES'})
    elif name=='TerraCoreTests':
        settings.update({'TEST_HOST':'','BUNDLE_LOADER':'','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @loader_path/../Frameworks'})
    else:
        settings['INFOPLIST_KEY_NSHighResolutionCapable']='YES'
    configurations = config_list(name,settings)
    target = add('target:'+name,'{isa = PBXNativeTarget; name = '+name+'; productName = '+q(product)+'; productReference = '+prod+'; productType = '+q(product_type)+'; buildConfigurationList = '+configurations+'; buildPhases = '+refs(phases)+'; buildRules = (); dependencies = ();}')
    targets.append(target); schemes.append((name,product,target))

product_group = add('products','{isa = PBXGroup; name = Products; children = '+refs(products)+'; sourceTree = "<group>";}')
main_group = add('main','{isa = PBXGroup; children = '+refs([source_group,asset_group,product_group])+'; sourceTree = "<group>";}')
project_config = config_list('project',{})
project = add('project','{isa = PBXProject; attributes = {LastUpgradeCheck = 2600;}; buildConfigurationList = '+project_config+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = '+main_group+'; productRefGroup = '+product_group+'; projectDirPath = ""; projectRoot = ""; targets = '+refs(targets)+';}')
directory = root/'Terra.xcodeproj'
directory.mkdir(exist_ok=True)
(directory/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project+';}\n')
scheme_dir = directory/'xcshareddata/xcschemes'; scheme_dir.mkdir(parents=True,exist_ok=True)
for name,product,target in schemes:
    build_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Terra.xcodeproj"/>'
    test_ref = schemes[2]
    testable = f'<TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_ref[2]}" BuildableName="TerraCoreTests.xctest" BlueprintName="TerraCoreTests" ReferencedContainer="container:Terra.xcodeproj"/></TestableReference>'
    (scheme_dir/(name+'.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{build_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables>{testable}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{build_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{build_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Terra.xcodeproj')

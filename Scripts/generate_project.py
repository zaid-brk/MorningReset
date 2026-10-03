#!/usr/bin/env python3
"""Generate a deterministic, dependency-free Xcode project and shared scheme."""
from pathlib import Path
import hashlib
import json
import plistlib
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "MorningReset.xcodeproj"
PROJECT.mkdir(exist_ok=True)
objects = {}

def uid(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()

def obj(key, isa, **values):
    identity = uid(key)
    objects[identity] = dict(isa=isa, **values)
    return identity

def quote(value):
    return json.dumps(value)

def render(value, depth=0):
    if isinstance(value, dict):
        return "{\n" + "\n".join("\t" * (depth + 1) + f"{quote(k)} = {render(v, depth+1)};" for k, v in value.items()) + "\n" + "\t" * depth + "}"
    if isinstance(value, list):
        return "(" + ", ".join(render(v, depth + 1) for v in value) + ("," if value else "") + ")"
    return quote(str(value))

refs = {}
def file(path, kind=None):
    if path in refs: return refs[path]
    kind = kind or {".swift": "sourcecode.swift", ".xcconfig": "text.xcconfig", ".plist": "text.plist.xml", ".entitlements": "text.plist.entitlements", ".md": "net.daringfireball.markdown", ".py": "text.script.python"}.get(Path(path).suffix, "text")
    refs[path] = obj("file:"+path, "PBXFileReference", lastKnownFileType=kind, path=path, sourceTree="<group>")
    return refs[path]

core = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Sources/MorningResetCore").glob("*.swift"))
app = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "MorningReset").rglob("*.swift"))
tests = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Tests/MorningResetCoreTests").glob("*.swift"))
bridge = "MorningReset/Services/ScreenTimeBridge.swift"
environment = "MorningReset/Services/AppEnvironment.swift"
demo = [source for source in app if source != bridge]
targets = [
    ("MorningReset", core + app, "com.apple.product-type.application", "app", "$(BASE_BUNDLE_IDENTIFIER)"),
    ("MorningResetDemo", core + demo, "com.apple.product-type.application", "app", "$(BASE_BUNDLE_IDENTIFIER).Demo"),
    ("ActivityMonitor", core + [bridge, environment, "Extensions/ActivityMonitor/ActivityMonitor.swift"], "com.apple.product-type.app-extension", "appex", "$(BASE_BUNDLE_IDENTIFIER).ActivityMonitor"),
    ("ShieldConfiguration", ["Extensions/ShieldConfiguration/ShieldConfigurationExtension.swift"], "com.apple.product-type.app-extension", "appex", "$(BASE_BUNDLE_IDENTIFIER).ShieldConfiguration"),
    ("MorningResetTests", tests, "com.apple.product-type.bundle.unit-test", "xctest", "$(BASE_BUNDLE_IDENTIFIER).Tests")
]
products = []
frameworks = {}
for framework in ["Foundation", "SwiftUI", "UIKit", "FamilyControls", "ManagedSettings", "ManagedSettingsUI", "DeviceActivity", "SwiftData", "UserNotifications"]:
    frameworks[framework] = obj("framework:"+framework, "PBXFileReference", lastKnownFileType="wrapper.framework",
        name=framework+".framework", path="System/Library/Frameworks/"+framework+".framework", sourceTree="SDKROOT")

base_config = file("Config/Base.xcconfig")
project_configurations = []
for name in ["Debug", "Release"]:
    settings = {"SDKROOT": "iphoneos", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if name == "Debug" else "-O",
        "DEBUG_INFORMATION_FORMAT": "dwarf" if name == "Debug" else "dwarf-with-dsym",
        "ENABLE_TESTABILITY": "YES" if name == "Debug" else "NO"}
    if name == "Debug": settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG $(inherited)"
    project_configurations.append(obj("project-config:"+name, "XCBuildConfiguration", name=name, baseConfigurationReference=base_config, buildSettings=settings))
project_config_list = obj("project-config-list", "XCConfigurationList", buildConfigurations=project_configurations, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")

target_ids = []
for name, sources, product_type, suffix, bundle_id in targets:
    product = obj("product:"+name, "PBXFileReference", explicitFileType={"app":"wrapper.application", "appex":"wrapper.app-extension", "xctest":"wrapper.cfbundle"}[suffix],
        includeInIndex="0", path=name+"."+suffix, sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    build_sources = [obj("source:"+name+":"+path, "PBXBuildFile", fileRef=file(path)) for path in sources]
    source_phase = obj("sources:"+name, "PBXSourcesBuildPhase", buildActionMask="2147483647", files=build_sources, runOnlyForDeploymentPostprocessing="0")
    linked = {"MorningReset": ["Foundation", "SwiftUI", "UIKit", "FamilyControls", "ManagedSettings", "DeviceActivity", "SwiftData", "UserNotifications"],
        "MorningResetDemo": ["Foundation", "SwiftUI", "UIKit", "SwiftData", "UserNotifications"],
        "ActivityMonitor": ["Foundation", "FamilyControls", "ManagedSettings", "DeviceActivity"],
        "ShieldConfiguration": ["ManagedSettings", "ManagedSettingsUI", "UIKit"], "MorningResetTests": ["Foundation"]}[name]
    framework_phase = obj("frameworks:"+name, "PBXFrameworksBuildPhase", buildActionMask="2147483647",
        files=[obj("linked:"+name+":"+fw, "PBXBuildFile", fileRef=frameworks[fw]) for fw in linked], runOnlyForDeploymentPostprocessing="0")
    resources = []
    if suffix == "app":
        resources.append(obj("assets-build:"+name, "PBXBuildFile", fileRef=file("MorningReset/Assets.xcassets", "folder.assetcatalog")))
        resources.append(obj("privacy-build:"+name, "PBXBuildFile", fileRef=file("MorningReset/PrivacyInfo.xcprivacy", "text.xml")))
    resource_phase = obj("resources:"+name, "PBXResourcesBuildPhase", buildActionMask="2147483647", files=resources, runOnlyForDeploymentPostprocessing="0")
    phases = [source_phase, framework_phase, resource_phase]
    dependencies = []
    if name == "MorningReset":
        embedded = []
        for extension in ["ActivityMonitor", "ShieldConfiguration"]:
            extension_product = uid("product:"+extension)
            embedded.append(obj("embed:"+extension, "PBXBuildFile", fileRef=extension_product, settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]}))
            proxy = obj("proxy:"+extension, "PBXContainerItemProxy", containerPortal=uid("project"), proxyType="1", remoteGlobalIDString=uid("target:"+extension), remoteInfo=extension)
            dependencies.append(obj("dependency:"+extension, "PBXTargetDependency", target=uid("target:"+extension), targetProxy=proxy))
        phases.append(obj("embed-extensions", "PBXCopyFilesBuildPhase", buildActionMask="2147483647", dstPath="", dstSubfolderSpec="13", files=embedded, name="Embed App Extensions", runOnlyForDeploymentPostprocessing="0"))
    if name == "MorningResetTests":
        proxy = obj("test-host-proxy", "PBXContainerItemProxy", containerPortal=uid("project"), proxyType="1", remoteGlobalIDString=uid("target:MorningReset"), remoteInfo="MorningReset")
        dependencies.append(obj("test-host-dependency", "PBXTargetDependency", target=uid("target:MorningReset"), targetProxy=proxy))
    configs = []
    for mode in ["Debug", "Release"]:
        settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
            "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
            "INFOPLIST_FILE": "Config/"+name+"-Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]}
        if suffix == "appex": settings.update(APPLICATION_EXTENSION_API_ONLY="YES", SKIP_INSTALL="YES")
        if name not in ["MorningResetTests", "MorningResetDemo"]: settings["CODE_SIGN_ENTITLEMENTS"] = "Config/"+name+".entitlements"
        if suffix == "app": settings.update(ASSETCATALOG_COMPILER_APPICON_NAME="AppIcon", ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME="AccentColor")
        if name == "MorningResetDemo": settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) MORNING_RESET_DEMO"
        if name == "MorningResetTests":
            settings.update(TEST_HOST="$(BUILT_PRODUCTS_DIR)/MorningReset.app/MorningReset",
                BUNDLE_LOADER="$(TEST_HOST)", SWIFT_ACTIVE_COMPILATION_CONDITIONS="$(inherited) XCODE_TEST_TARGET")
        configs.append(obj("target-config:"+name+":"+mode, "XCBuildConfiguration", name=mode, baseConfigurationReference=base_config, buildSettings=settings))
    config_list = obj("target-config-list:"+name, "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    target_ids.append(obj("target:"+name, "PBXNativeTarget", buildConfigurationList=config_list, buildPhases=phases, buildRules=[], dependencies=dependencies,
        name=name, productName=name, productReference=product, productType=product_type))

info_base = {"CFBundleDevelopmentRegion":"en", "CFBundleExecutable":"$(EXECUTABLE_NAME)", "CFBundleIdentifier":"$(PRODUCT_BUNDLE_IDENTIFIER)",
    "CFBundleInfoDictionaryVersion":"6.0", "CFBundleName":"$(PRODUCT_NAME)", "CFBundleShortVersionString":"$(MARKETING_VERSION)",
    "CFBundleVersion":"$(CURRENT_PROJECT_VERSION)"}
for name, _, _, suffix, _ in targets:
    info = dict(info_base, CFBundlePackageType="APPL" if suffix == "app" else "XPC!" if suffix == "appex" else "BNDL")
    if name not in ["MorningResetTests", "MorningResetDemo"]: info["MorningResetAppGroup"] = "$(APP_GROUP_IDENTIFIER)"
    if suffix == "app":
        info.update(CFBundleDisplayName="Morning Reset Demo" if name == "MorningResetDemo" else "Morning Reset", LSRequiresIPhoneOS=True, UILaunchScreen={},
                    UIApplicationSceneManifest={"UIApplicationSupportsMultipleScenes":False},
                    UISupportedInterfaceOrientations=["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"])
    elif suffix == "appex":
        info["NSExtension"] = {"NSExtensionPointIdentifier": "com.apple.deviceactivity.monitor-extension" if name == "ActivityMonitor" else "com.apple.ManagedSettingsUI.shield-configuration-service",
            "NSExtensionPrincipalClass":"$(PRODUCT_MODULE_NAME)."+("ActivityMonitor" if name == "ActivityMonitor" else "ShieldConfigurationExtension")}
    (ROOT / "Config" / (name+"-Info.plist")).write_bytes(plistlib.dumps(info))
    file("Config/"+name+"-Info.plist")
    if name not in ["MorningResetTests", "MorningResetDemo"]:
        entitlements = {"com.apple.developer.family-controls":True, "com.apple.security.application-groups":["$(APP_GROUP_IDENTIFIER)"]}
        (ROOT / "Config" / (name+".entitlements")).write_bytes(plistlib.dumps(entitlements))
        file("Config/"+name+".entitlements")

for path in ["SPEC.md", "AGENTS.md", "README.md", "Docs/FEASIBILITY.md", "Docs/VALIDATION.md", "Docs/ARCHITECTURE.md", "Config/Local.xcconfig.example", "Scripts/generate_project.py", "Scripts/test_core.py", "Scripts/check_project.py", "Scripts/CoreTestSupport.swift", "Scripts/render_icon.swift"]: file(path)
groups = []
for label, prefix in [("Core", "Sources/"), ("App", "MorningReset/"), ("Extensions", "Extensions/"), ("Tests", "Tests/"), ("Config", "Config/"), ("Scripts", "Scripts/"), ("Docs", "Docs/")]:
    groups.append(obj("group:"+label, "PBXGroup", name=label, children=[ref for path, ref in refs.items() if path.startswith(prefix)], sourceTree="<group>"))
groups.append(obj("group:Frameworks", "PBXGroup", name="Frameworks", children=list(frameworks.values()), sourceTree="<group>"))
product_group = obj("group:Products", "PBXGroup", name="Products", children=products, sourceTree="<group>")
groups.append(product_group)
main = obj("group:main", "PBXGroup", children=groups+[refs[path] for path in refs if "/" not in path], sourceTree="<group>")
attributes = {"LastUpgradeCheck":"1600", "TargetAttributes": {uid("target:"+name): {"CreatedOnToolsVersion":"16.0", "SystemCapabilities": {} if name == "MorningResetDemo" else {"com.apple.ApplicationGroups.iOS":{"enabled":"1"}, "com.apple.FamilyControls":{"enabled":"1"}}} for name, *_ in targets if name != "MorningResetTests"}}
attributes["TargetAttributes"][uid("target:MorningResetTests")] = {"TestTargetID": uid("target:MorningReset"), "CreatedOnToolsVersion":"16.0"}
root_project = obj("project", "PBXProject", attributes=attributes, buildConfigurationList=project_config_list, compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings="0", knownRegions=["en", "Base"], mainGroup=main, productRefGroup=product_group, projectDirPath="", projectRoot="", targets=target_ids)
document = {"archiveVersion":"1", "classes":{}, "objectVersion":"56", "objects":objects, "rootObject":root_project}
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n"+render(document)+"\n")

def reference(name, suffix):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{escape(name)}.{suffix}" BlueprintName="{escape(name)}" ReferencedContainer="container:MorningReset.xcodeproj"/>'

scheme_dir = PROJECT / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference("MorningReset", "app")}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference("MorningResetTests", "xctest")}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference("MorningResetTests", "xctest")}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("MorningReset", "app")}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("MorningReset", "app")}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(scheme_dir / "MorningReset.xcscheme").write_text(scheme)
demo_scheme = scheme.replace(reference("MorningReset", "app"), reference("MorningResetDemo", "app"))
demo_scheme = demo_scheme.replace(f'    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference("MorningResetTests", "xctest")}</BuildActionEntry>', '')
demo_scheme = demo_scheme.replace(f'<TestableReference skipped="NO">{reference("MorningResetTests", "xctest")}</TestableReference>', '')
(scheme_dir / "MorningResetDemo.xcscheme").write_text(demo_scheme)
print(f"Generated {PROJECT.name}: {len(targets)} targets, {len(objects)} objects")

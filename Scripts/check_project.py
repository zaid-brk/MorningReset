#!/usr/bin/env python3
"""Validate project references, target membership, metadata, and Swift syntax without Xcode."""
from pathlib import Path
import json
import plistlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
project_path = root / "MorningReset.xcodeproj/project.pbxproj"
with tempfile.TemporaryDirectory(prefix="morning-reset-project-") as directory:
    converted = Path(directory) / "project.json"
    subprocess.run(["plutil", "-convert", "json", "-o", str(converted), str(project_path)], check=True)
    project = json.loads(converted.read_text())
objects = project["objects"]
assert project["rootObject"] in objects
reference_keys = {"buildConfigurationList", "productReference", "mainGroup", "productRefGroup", "fileRef", "target", "targetProxy", "containerPortal", "baseConfigurationReference"}
array_keys = {"children", "targets", "buildPhases", "dependencies", "buildConfigurations", "files"}
for identity, record in objects.items():
    for key, value in record.items():
        if key in reference_keys: assert value in objects, (identity, key, value)
        if key in array_keys:
            assert all(reference in objects for reference in value), (identity, key)
    if record["isa"] == "PBXFileReference" and record.get("sourceTree") == "<group>":
        assert (root / record["path"]).exists(), record["path"]
targets = [record for record in objects.values() if record["isa"] == "PBXNativeTarget"]
assert {target["name"] for target in targets} == {"MorningReset", "MorningResetDemo", "ActivityMonitor", "ShieldConfiguration", "MorningResetTests"}
for target in targets:
    sources = []
    for phase_id in target["buildPhases"]:
        phase = objects[phase_id]
        if phase["isa"] == "PBXSourcesBuildPhase":
            sources += [objects[objects[build_id]["fileRef"]]["path"] for build_id in phase["files"]]
    assert len(sources) == len(set(sources)), "Duplicate source membership"
    if target["name"] == "ActivityMonitor":
        assert not any("/Views/" in source or "HistoryArchive" in source or "AppModel" in source for source in sources)
        assert "Sources/MorningResetCore/RoutineEngine.swift" in sources
    if target["name"] == "MorningReset":
        assert set(str(path.relative_to(root)) for path in (root / "MorningReset").rglob("*.swift")).issubset(sources)
    if target["name"] == "MorningResetDemo":
        assert not target["dependencies"], "Free demo must not build Screen Time extensions"
        assert "MorningReset/Services/ScreenTimeBridge.swift" not in sources
        assert "MorningReset/Services/DemoScreenTimeBridge.swift" in sources
        for config_id in objects[target["buildConfigurationList"]]["buildConfigurations"]:
            settings = objects[config_id]["buildSettings"]
            assert "CODE_SIGN_ENTITLEMENTS" not in settings
            assert "MORNING_RESET_DEMO" in settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"]
        for phase_id in target["buildPhases"]:
            phase = objects[phase_id]
            assert phase["isa"] != "PBXCopyFilesBuildPhase"
            if phase["isa"] == "PBXFrameworksBuildPhase":
                linked = [objects[objects[entry]["fileRef"]]["name"] for entry in phase["files"]]
                assert not set(linked) & {"FamilyControls.framework", "ManagedSettings.framework", "DeviceActivity.framework"}
for path in (root / "Config").glob("*.plist"): plistlib.loads(path.read_bytes())
for path in (root / "Config").glob("*.entitlements"):
    entitlement = plistlib.loads(path.read_bytes())
    assert entitlement["com.apple.developer.family-controls"] is True
    assert entitlement["com.apple.security.application-groups"] == ["$(APP_GROUP_IDENTIFIER)"]
plistlib.loads((root / "MorningReset/PrivacyInfo.xcprivacy").read_bytes())
for path in (root / "MorningReset/Assets.xcassets").rglob("Contents.json"): json.loads(path.read_text())
for path in (root / "MorningReset.xcodeproj/xcshareddata/xcschemes").glob("*.xcscheme"):
    scheme = ET.parse(path)
    for reference in scheme.iter("BuildableReference"):
        assert reference.attrib["BlueprintIdentifier"] in objects
        if path.stem == "MorningResetDemo":
            assert reference.attrib["BlueprintName"] == "MorningResetDemo"
assert (root / "SPEC.md").read_bytes() == (root / "Morning-Reset-Codex-Prompt.md").read_bytes()
swift_sources = sorted((root / "Sources").rglob("*.swift")) + sorted((root / "MorningReset").rglob("*.swift")) + sorted((root / "Extensions").rglob("*.swift"))
subprocess.run(["swiftc", "-frontend", "-parse", *map(str, swift_sources)], check=True)
print(f"Project checks passed: {len(targets)} targets, {len(swift_sources)} Swift files, entitlements, plists, assets, shared scheme.")
print("Swift syntax parsed. iOS SDK type-checking/building still requires Xcode.")

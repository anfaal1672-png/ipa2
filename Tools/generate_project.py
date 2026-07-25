#!/usr/bin/env python3
"""Generates CodeForge.xcodeproj from the files on disk.

Keeping the project file generated (rather than hand-edited) means adding a
source file is just dropping it in CodeForge/Sources — re-run this script and
the project picks it up. The output is a plain, deterministic pbxproj that
`xcodebuild` accepts.
"""
import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT_NAME = "CodeForge"
BUNDLE_ID = "com.codeforge.editor"
DEPLOYMENT_TARGET = "16.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "1.0.0"
BUILD_VERSION = "1"

SOURCE_ROOT = ROOT / PROJECT_NAME / "Sources"
RESOURCE_FILES = [f"{PROJECT_NAME}/Resources/Assets.xcassets"]
INFO_PLIST = f"{PROJECT_NAME}/Resources/Info.plist"


def uid(key: str) -> str:
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def swift_sources():
    files = sorted(
        str(p.relative_to(ROOT)) for p in SOURCE_ROOT.rglob("*.swift")
    )
    if not files:
        raise SystemExit("no Swift sources found")
    return files


def group_children(paths):
    """Builds a nested group structure mirroring the directory layout."""
    tree = {}
    for path in paths:
        parts = Path(path).parts
        node = tree
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node.setdefault("__files__", []).append(path)
    return tree


def emit_groups(tree, name, path_component, lines, is_root=False):
    """Emits PBXGroup entries depth-first, returning this group's uid."""
    group_uid = uid(f"group:{name}:{path_component}")
    child_refs = []
    for key in sorted(k for k in tree if k != "__files__"):
        child_refs.append(emit_groups(tree[key], key, f"{path_component}/{key}", lines))
    for file_path in sorted(tree.get("__files__", [])):
        child_refs.append(uid(f"file:{file_path}"))

    children = "\n".join(f"\t\t\t\t{ref} /* child */," for ref in child_refs)
    lines.append(
        f"\t\t{group_uid} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{children}\n\t\t\t);\n"
        f"\t\t\tpath = \"{name}\";\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    return group_uid


def main():
    sources = swift_sources()
    all_files = sources + RESOURCE_FILES + [INFO_PLIST]

    target_uid = uid("target")
    project_uid = uid("project")
    product_uid = uid("product")
    main_group_uid = uid("maingroup")
    products_group_uid = uid("productsgroup")
    sources_phase_uid = uid("sourcesphase")
    frameworks_phase_uid = uid("frameworksphase")
    resources_phase_uid = uid("resourcesphase")
    project_config_list = uid("projectconfiglist")
    target_config_list = uid("targetconfiglist")

    out = []
    out.append("// !$*UTF8*$!")
    out.append("{")
    out.append("\tarchiveVersion = 1;")
    out.append("\tclasses = {\n\t};")
    out.append("\tobjectVersion = 56;")
    out.append("\tobjects = {")

    # ---- PBXBuildFile -------------------------------------------------
    out.append("\n/* Begin PBXBuildFile section */")
    for path in sources:
        out.append(
            f"\t\t{uid('build:' + path)} /* {Path(path).name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file:' + path)} /* {Path(path).name} */; }};"
        )
    for path in RESOURCE_FILES:
        out.append(
            f"\t\t{uid('build:' + path)} /* {Path(path).name} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file:' + path)} /* {Path(path).name} */; }};"
        )
    out.append("/* End PBXBuildFile section */")

    # ---- PBXFileReference ---------------------------------------------
    out.append("\n/* Begin PBXFileReference section */")
    for path in all_files:
        name = Path(path).name
        if name.endswith(".swift"):
            file_type = "sourcecode.swift"
        elif name.endswith(".xcassets"):
            file_type = "folder.assetcatalog"
        elif name.endswith(".plist"):
            file_type = "text.plist.xml"
        else:
            file_type = "text"
        out.append(
            f"\t\t{uid('file:' + path)} /* {name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {file_type}; path = \"{name}\"; sourceTree = \"<group>\"; }};"
        )
    out.append(
        f"\t\t{product_uid} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.application; includeInIndex = 0; "
        f"path = \"{PROJECT_NAME}.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    out.append("/* End PBXFileReference section */")

    # ---- PBXGroup ------------------------------------------------------
    out.append("\n/* Begin PBXGroup section */")
    group_lines = []
    tree = group_children(all_files)
    root_children = []
    for key in sorted(k for k in tree if k != "__files__"):
        root_children.append(emit_groups(tree[key], key, key, group_lines))

    out.extend(group_lines)

    children = "\n".join(f"\t\t\t\t{ref} /* child */," for ref in root_children)
    out.append(
        f"\t\t{main_group_uid} = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{children}\n"
        f"\t\t\t\t{products_group_uid} /* Products */,\n"
        f"\t\t\t);\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    out.append(
        f"\t\t{products_group_uid} /* Products */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n\t\t\t\t{product_uid} /* {PROJECT_NAME}.app */,\n\t\t\t);\n"
        f"\t\t\tname = Products;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    out.append("/* End PBXGroup section */")

    # ---- Native target --------------------------------------------------
    out.append("\n/* Begin PBXNativeTarget section */")
    out.append(
        f"\t\t{target_uid} /* {PROJECT_NAME} */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {target_config_list};\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{sources_phase_uid} /* Sources */,\n"
        f"\t\t\t\t{frameworks_phase_uid} /* Frameworks */,\n"
        f"\t\t\t\t{resources_phase_uid} /* Resources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n\t\t\t);\n"
        f"\t\t\tdependencies = (\n\t\t\t);\n"
        f"\t\t\tname = {PROJECT_NAME};\n"
        f"\t\t\tproductName = {PROJECT_NAME};\n"
        f"\t\t\tproductReference = {product_uid} /* {PROJECT_NAME}.app */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
        f"\t\t}};"
    )
    out.append("/* End PBXNativeTarget section */")

    # ---- Project --------------------------------------------------------
    out.append("\n/* Begin PBXProject section */")
    out.append(
        f"\t\t{project_uid} /* Project object */ = {{\n"
        f"\t\t\tisa = PBXProject;\n"
        f"\t\t\tattributes = {{\n"
        f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
        f"\t\t\t\tLastSwiftUpdateCheck = 1600;\n"
        f"\t\t\t\tLastUpgradeCheck = 1600;\n"
        f"\t\t\t\tTargetAttributes = {{\n"
        f"\t\t\t\t\t{target_uid} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n\t\t\t\t\t}};\n"
        f"\t\t\t\t}};\n"
        f"\t\t\t}};\n"
        f"\t\t\tbuildConfigurationList = {project_config_list};\n"
        f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
        f"\t\t\tdevelopmentRegion = en;\n"
        f"\t\t\thasScannedForEncodings = 0;\n"
        f"\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
        f"\t\t\tmainGroup = {main_group_uid};\n"
        f"\t\t\tproductRefGroup = {products_group_uid} /* Products */;\n"
        f"\t\t\tprojectDirPath = \"\";\n"
        f"\t\t\tprojectRoot = \"\";\n"
        f"\t\t\ttargets = (\n\t\t\t\t{target_uid} /* {PROJECT_NAME} */,\n\t\t\t);\n"
        f"\t\t}};"
    )
    out.append("/* End PBXProject section */")

    # ---- Build phases -----------------------------------------------------
    out.append("\n/* Begin PBXResourcesBuildPhase section */")
    resource_refs = "\n".join(
        f"\t\t\t\t{uid('build:' + path)} /* {Path(path).name} in Resources */,"
        for path in RESOURCE_FILES
    )
    out.append(
        f"\t\t{resources_phase_uid} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{resource_refs}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    out.append("/* End PBXResourcesBuildPhase section */")

    out.append("\n/* Begin PBXSourcesBuildPhase section */")
    source_refs = "\n".join(
        f"\t\t\t\t{uid('build:' + path)} /* {Path(path).name} in Sources */,"
        for path in sources
    )
    out.append(
        f"\t\t{sources_phase_uid} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{source_refs}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    out.append("/* End PBXSourcesBuildPhase section */")

    out.append("\n/* Begin PBXFrameworksBuildPhase section */")
    out.append(
        f"\t\t{frameworks_phase_uid} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    out.append("/* End PBXFrameworksBuildPhase section */")

    # ---- Build configurations ----------------------------------------------
    project_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": SWIFT_VERSION,
        "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    }
    project_debug = dict(project_common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": "\"DEBUG=1\" \"$(inherited)\"",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "\"DEBUG $(inherited)\"",
        "SWIFT_OPTIMIZATION_LEVEL": "\"-Onone\"",
    })
    project_release = dict(project_common, **{
        "DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "\"-O\"",
        "VALIDATE_PRODUCT": "YES",
    })

    target_common = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_IDENTITY": "\"\"",
        "CODE_SIGN_STYLE": "Manual",
        "CODE_SIGNING_ALLOWED": "NO",
        "CODE_SIGNING_REQUIRED": "NO",
        "CURRENT_PROJECT_VERSION": BUILD_VERSION,
        "DEVELOPMENT_TEAM": "\"\"",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f"{PROJECT_NAME}/Resources/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t)",
        "MARKETING_VERSION": MARKETING_VERSION,
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "PROVISIONING_PROFILE_SPECIFIER": "\"\"",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": "\"1,2\"",
    }

    def emit_config(config_uid, name, settings):
        body = "\n".join(f"\t\t\t\t{k} = {v};" for k, v in sorted(settings.items()))
        return (
            f"\t\t{config_uid} /* {name} */ = {{\n"
            f"\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{\n{body}\n\t\t\t}};\n"
            f"\t\t\tname = {name};\n"
            f"\t\t}};"
        )

    out.append("\n/* Begin XCBuildConfiguration section */")
    out.append(emit_config(uid("projectdebug"), "Debug", project_debug))
    out.append(emit_config(uid("projectrelease"), "Release", project_release))
    out.append(emit_config(uid("targetdebug"), "Debug", target_common))
    out.append(emit_config(uid("targetrelease"), "Release", target_common))
    out.append("/* End XCBuildConfiguration section */")

    out.append("\n/* Begin XCConfigurationList section */")
    out.append(
        f"\t\t{project_config_list} = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{uid('projectdebug')} /* Debug */,\n"
        f"\t\t\t\t{uid('projectrelease')} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};"
    )
    out.append(
        f"\t\t{target_config_list} = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{uid('targetdebug')} /* Debug */,\n"
        f"\t\t\t\t{uid('targetrelease')} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};"
    )
    out.append("/* End XCConfigurationList section */")

    out.append("\t};")
    out.append(f"\trootObject = {project_uid} /* Project object */;")
    out.append("}")

    project_dir = ROOT / f"{PROJECT_NAME}.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    (project_dir / "project.pbxproj").write_text("\n".join(out) + "\n")

    scheme_dir = project_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / f"{PROJECT_NAME}.xcscheme").write_text(scheme(target_uid))

    workspace_dir = project_dir / "project.xcworkspace"
    workspace_dir.mkdir(parents=True, exist_ok=True)
    (workspace_dir / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace version = "1.0">\n'
        '   <FileRef location = "self:">\n'
        '   </FileRef>\n'
        '</Workspace>\n'
    )

    print(f"generated {project_dir} with {len(sources)} Swift files")


def scheme(target_uid: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_uid}"
               BuildableName = "{PROJECT_NAME}.app"
               BlueprintName = "{PROJECT_NAME}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_uid}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_uid}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    main()

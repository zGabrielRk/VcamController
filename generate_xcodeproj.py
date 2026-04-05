#!/usr/bin/env python3
"""
Gera VcamController.xcodeproj sem precisar de XcodeGen ou Tuist.
"""

import os
import uuid

def make_id():
    return uuid.uuid4().hex[:24].upper()

PROJECT_ID     = make_id()
APP_TARGET_ID  = make_id()
SOURCES_ID     = make_id()
RESOURCES_ID   = make_id()
FRAMEWORKS_ID  = make_id()
CONFIG_LIST_ID = make_id()
DEBUG_ID       = make_id()
RELEASE_ID     = make_id()
TGT_CFG_ID     = make_id()
TGT_DBG_ID     = make_id()
TGT_REL_ID     = make_id()
PRODUCTS_ID    = make_id()
APP_PRODUCT_ID = make_id()
MAIN_GROUP_ID  = make_id()
SOURCES_GROUP  = make_id()

swift_files = [
    "VcamController/VcamControlApp.swift",
    "VcamController/RootView.swift",
    "VcamController/HomeView.swift",
    "VcamController/SettingsView.swift",
    "VcamController/VcamManager.swift",
    "VcamController/VideoPicker.swift",
    "VcamController/VideoTransferable.swift",
]

plist_file = "VcamController/Info.plist"

file_ids       = {f: make_id() for f in swift_files}
plist_id       = make_id()
build_file_ids = {f: make_id() for f in swift_files}

def pbx_file_ref(fid, path):
    name = os.path.basename(path)
    return f'\t\t{fid} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{name}"; path = "{path}"; sourceTree = "<group>"; }};'

def pbx_build_file(bfid, fid):
    return f'\t\t{bfid} = {{isa = PBXBuildFile; fileRef = {fid}; }};'

file_refs          = "\n".join(pbx_file_ref(file_ids[f], f) for f in swift_files)
build_files        = "\n".join(pbx_build_file(build_file_ids[f], file_ids[f]) for f in swift_files)
source_build_refs  = "\n".join(f"\t\t\t\t{build_file_ids[f]}," for f in swift_files)
file_ref_list      = "\n".join(f"\t\t\t\t{file_ids[f]}," for f in swift_files)

pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs}
\t\t{plist_id} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = "Info.plist"; path = "{plist_file}"; sourceTree = "<group>"; }};
\t\t{APP_PRODUCT_ID} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = VcamController.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXGroup section */
\t\t{MAIN_GROUP_ID} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{SOURCES_GROUP},
\t\t\t\t{PRODUCTS_ID},
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{SOURCES_GROUP} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{file_ref_list}
\t\t\t\t{plist_id},
\t\t\t);
\t\t\tname = VcamController;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{PRODUCTS_ID} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{APP_PRODUCT_ID},
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{APP_TARGET_ID} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {TGT_CFG_ID};
\t\t\tbuildPhases = (
\t\t\t\t{SOURCES_ID},
\t\t\t\t{RESOURCES_ID},
\t\t\t\t{FRAMEWORKS_ID},
\t\t\t);
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = VcamController;
\t\t\tproductName = VcamController;
\t\t\tproductReference = {APP_PRODUCT_ID};
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{PROJECT_ID} = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{APP_TARGET_ID} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 1500;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {CONFIG_LIST_ID};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base);
\t\t\tmainGroup = {MAIN_GROUP_ID};
\t\t\tproductRefGroup = {PRODUCTS_ID};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = ({APP_TARGET_ID});
\t\t}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
\t\t{SOURCES_ID} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{source_build_refs}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
\t\t{RESOURCES_ID} = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ();
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{FRAMEWORKS_ID} = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ();
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{DEBUG_ID} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{RELEASE_ID} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{TGT_DBG_ID} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "{plist_file}";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.vcam.controller";
\t\t\t\tPRODUCT_NAME = VcamController;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{TGT_REL_ID} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "{plist_file}";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.vcam.controller";
\t\t\t\tPRODUCT_NAME = VcamController;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{CONFIG_LIST_ID} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({DEBUG_ID}, {RELEASE_ID});
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{TGT_CFG_ID} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({TGT_DBG_ID}, {TGT_REL_ID});
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {PROJECT_ID};
}}
"""

os.makedirs("VcamController.xcodeproj", exist_ok=True)
with open("VcamController.xcodeproj/project.pbxproj", "w") as f:
    f.write(pbxproj)

scheme_dir = "VcamController.xcodeproj/xcshareddata/xcschemes"
os.makedirs(scheme_dir, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{APP_TARGET_ID}"
               BuildableName = "VcamController.app"
               BlueprintName = "VcamController"
               ReferencedContainer = "container:VcamController.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction buildConfiguration="Release" selectedDebuggerIdentifier="" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{APP_TARGET_ID}"
            BuildableName = "VcamController.app"
            BlueprintName = "VcamController"
            ReferencedContainer = "container:VcamController.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>
"""
with open(f"{scheme_dir}/VcamController.xcscheme", "w") as f:
    f.write(scheme)

print("✅ VcamController.xcodeproj gerado com sucesso!")

# Stage 1 extraction record

I recorded this inventory before moving the helpers. Each old entry point stays in place as a temporary forwarding function. Remove it only after the callers listed here move to the domain modules.

| Helper | Source | Remaining caller sites before extraction |
|---|---|---|
| `parentFolder` | `catalog.lua` | `acu_import.lua:39,67,72,142`; `bundles.lua:276,323,378`; `catalog.lua:28,148,186,193,203,304,307`; `folders.lua:31,33,95,112,139,185,248,264,300,371`; `native_bridge.lua:99,129,132,331`; `native_catalog.lua:112,123`; `presets.lua:414,638,661,800,900,913,1107,1141`; `trash.lua:524,559,657,752,933`; `view_cache.lua:97,103,161,167,208`; `ui/sections_folders.lua:13,66,96`; `ui/sections_load.lua:172,229` |
| `folderDepth` | `catalog.lua` | `native_bridge.lua:164,175`; `ui/sections_folders.lua:34`; `ui/sections_load.lua:200`; `ui/sections_save.lua:60` |
| `folderAncestorsExpanded` | `catalog.lua` | `native_bridge.lua:161`; `ui/sections_load.lua:130` |
| `folderPath` | `catalog.lua` | `catalog.lua:42`; `folders.lua:382,383`; `native_catalog.lua:162`; `trash.lua:943,944` |
| `presetPath` | `catalog.lua` | `backup.lua:186`; `bundles.lua:238,255`; `folders.lua:205`; `presets.lua:444,451,697,1108,1142,1179`; `trash.lua:402,430,783,814`; `ui/sections_manage.lua:20` |
| `baseName` | `view_cache.lua` | `acu_import.lua:40,47`; `backup.lua:380`; `bundles.lua:201,297,498`; `catalog.lua:140,149`; `folders.lua:37,198,302`; `native_bridge.lua:169,175,330`; `native_catalog.lua:116,127`; `presets.lua:415,639,662,799,988,995,1021,1043,1047,1052,1106,1140,1174`; `trash.lua:318,496,559,590`; `view_cache.lua:115`; `ui/sections_folders.lua:34`; `ui/sections_load.lua:140,211,228`; `ui/sections_save.lua:60` |
| `joinFolder` | `view_cache.lua` | `acu_import.lua:40,50`; `backup.lua:371,379`; `bundles.lua:488,494`; `catalog.lua:53,57,142,153`; `folders.lua:66,95,265,277,372`; `native_catalog.lua:165`; `presets.lua:642,665,683,900,913,988,1043`; `trash.lua:562`; `ui/sections_folders.lua:190,194`; `ui/sections_save.lua:31` |
| `isInFolderTree` | `view_cache.lua` | `bundles.lua:276,288`; `folders.lua:112,139,177,185,264,276,301,371`; `trash.lua:752,756,791,823,873,891` |
| `addFolderAncestors` | `view_cache.lua` | `acu_import.lua:142`; `backup.lua:370,371`; `bundles.lua:323,486,488`; `catalog.lua:28,31,127,187,199`; `trash.lua:524,647,652,657`; `ui/sections_load.lua:172` |
| `validRelativePath` | `view_cache.lua` | `acu_import.lua:30`; `backup.lua:176,182,311,316`; `bundles.lua:9`; `catalog.lua:66,68,134,136,144,357,359,361,376,377,383,388,441,459,461`; `native_catalog.lua:28`; `presets.lua:299,474`; `trash.lua:18,24,28,33,74,79,86,114,115,116,120,122,129,155,156,165,166,174` |
| `remapFolderTreePath` | `folders.lua` | `folders.lua:113,122,140,178,192` |
| `validBundlePath` | `bundles.lua` | `bundles.lua:170,190,219,233,378,384,394` |
| `validNativeRelativePath` | `native_catalog.lua` | `native_catalog.lua:71,83` |
| `isFolderBundleFilename` | `filesystem.lua` | `bundles.lua:92,169,184,423`; `trash.lua:271,342` |
| `validTrashFilename` | `trash.lua` | `trash.lua:17,74,121,155` |
| `sanitizeName` | `filesystem.lua` | `filesystem.lua:391`; `trash.lua:318`; `ui/sections_folders.lua:60`; `ui/sections_manage.lua:26`; `ui/sections_save.lua:31` |
| `sanitizeMetadata` | `filesystem.lua` | `history.lua:33`; `presets.lua:256,258,278,280,282,284,286,292,297,304,309,480,481,482,483,484,485,502,506,1099,1100` |
| `validatedPresetName` | `filesystem.lua` | `bundles.lua:11`; `catalog.lua:138`; `presets.lua:293,681,897`; `view_cache.lua:258`; `ui/sections_save.lua:12,15,37` |
| `validatedFolderName` | `view_cache.lua` | `folders.lua:64,93`; `ui/sections_folders.lua:49` |
| `findPresetCollision` | `view_cache.lua` | `backup.lua:338,358`; `bundles.lua:495`; `folders.lua:193`; `presets.lua:643,689,906,992,1045`; `trash.lua:490,555,563` |
| `uniqueStorageName` | `view_cache.lua` | `backup.lua:380`; `bundles.lua:498`; `folders.lua:198,302`; `presets.lua:785,1174`; `trash.lua:496,590` |
| `findExistingFolderName` | `presets.lua` | `folders.lua:67,102`; `presets.lua:657` |
| `folderNameExists` | `presets.lua` | `backup.lua:338,354`; `bundles.lua:480,614`; `native_bridge.lua:308,346`; `presets.lua:666` |
| `uniquePresetCopyName` | `presets.lua` | `presets.lua:1165`; `trash.lua:491` |
| `uniqueFolderCopyName` | `presets.lua` | `bundles.lua:480`; `folders.lua:164` |
| `isRuntimePointerText` | `options.lua` | `options.lua:37,47,50,58` |
| `stableChoiceIdentity` | `options.lua` | `options.lua:164,195`; `presets.lua:268,308` |
| `occurrenceKeyParts` | `options.lua` | `load_engine.lua:1010,1190,1197` |
| `optionIndexValidationError` | `options.lua` | `history.lua:17`; `options.lua:251`; `presets.lua:179,317,750,851` |
| `optionIndexIsValid` | `options.lua` | `comparison.lua:92`; `load_engine.lua:627,893,927,1032,1091,1118,1494`; `options.lua:254,255,256,257,258,259` |
| `catalogEncode` | `catalog.lua` | `backup.lua:176,195`; `bundles.lua:188,191,215,223,237`; `catalog.lua:378,379,384,389,478,481`; `trash.lua:19,20,25,26,29,30,34,35,117,118,123,124,125,130` |
| `catalogDecode` | `catalog.lua` | `backup.lua:112,120,310,314`; `bundles.lua:167,168,377,383,393,516`; `catalog.lua:355,356,438,454`; `presets.lua:250,252,254,256,258,262,266`; `trash.lua:71,72,73,78,85,154,163,164,173` |
| `encode` | `backup.lua` | `backup.lua:42,171` |
| `decode` | `backup.lua` | `backup.lua:107,308,315` |
| `hexEncode` | `bundles.lua` | `bundles.lua:46` |
| `hexDecode` | `bundles.lua` | `bundles.lua:518` |
| `decodeImportField` | `acu_import.lua` | `acu_import.lua:25` |
| `decodeNativeField` | `native_catalog.lua` | `native_catalog.lua:69,77` |
| `historyPath` | `history.lua` | `history.lua:63,84,96,103,104,109,113,151` |
| `supportedFile` | `native_catalog.lua` | `native_catalog.lua:83,170` |
| `cleanField` | `native_bridge.lua` | `native_bridge.lua:85,94,95,99,110,141,198,204,216,217,228` |

## What moved and why

| Domain module | Responsibility |
|---|---|
| `paths.lua` | Parent and leaf names, joins, tree checks, folder remapping, storage and history paths, and existing file suffix and path checks. |
| `names.lua` | Name cleanup, Windows device-name checks, case collisions, and copy and storage naming. |
| `identities.lua` | Pointer-text rejection, stable choice text, occurrence keys, and option-index checks. |
| `codecs.lua` | Percent encoding and decoding, shared hexadecimal byte conversion, and bridge field cleanup. |

I kept all 41 old functions as temporary forwards. The 29 shared functions still use their old names, and the 12 local functions keep their original scope. No caller needs to change in this stage.

The new modules return function tables and never access the shared runtime. Adapters pass library maps, the preset directory, the depth limit, and the name validator where needed. The existing storage-name adapter still lists files when no used-name map is supplied.

The domain functions keep the existing changes to caller-owned tables: `addFolderAncestors` fills its folder map, and `uniqueStorageName` reserves its chosen filename. Their return values remain unchanged. Neither function owns shared state.

I moved the option-index maximum and sharing and backup extensions into their domain modules. The old constants forward those same values. Existing name limits, copy limits, filename limits, suffixes, and codec numbers now have local names without changing their values.

Backup and folder-sharing codecs share byte conversion while keeping their different input rules. Backup decoding still accepts empty content, and sharing decoding still rejects it. Game-object conversion, protected calls, file access, the loader, UI rendering, redscript, native code, formats, and protocol versions stay as they were.

## Remaining callers after extraction

These sites use the temporary forwards after the move. Calls inside the domain modules use local functions instead, so they no longer keep a compatibility function alive. Line numbers below refer to this stage's source.

| Compatibility function | Source | Remaining callers |
|---|---|---|
| `parentFolder` | `catalog.lua` | `acu_import.lua:38,66,71,141`; `bundles.lua:268,315,370`; `catalog.lua:30,150,188,195,205`; `folders.lua:28,30,92,109,136,182,245,261,297,368`; `native_bridge.lua:100,130,133,332`; `native_catalog.lua:102,113`; `presets.lua:415,783,883,896,1090,1124`; `trash.lua:523,558,656,751,932`; `view_cache.lua:99,105,163,169`; `ui/sections_folders.lua:13,66,96`; `ui/sections_load.lua:172,229` |
| `folderDepth` | `catalog.lua` | `native_bridge.lua:165,176`; `ui/sections_folders.lua:34`; `ui/sections_load.lua:200`; `ui/sections_save.lua:60` |
| `folderAncestorsExpanded` | `catalog.lua` | `native_bridge.lua:162`; `ui/sections_load.lua:130` |
| `folderPath` | `catalog.lua` | `catalog.lua:44`; `folders.lua:379,380`; `native_catalog.lua:152`; `trash.lua:942,943` |
| `presetPath` | `catalog.lua` | `backup.lua:181`; `bundles.lua:230,247`; `folders.lua:202`; `presets.lua:445,452,680,1091,1125,1162`; `trash.lua:401,429,782,813`; `ui/sections_manage.lua:20` |
| `baseName` | `view_cache.lua` | `acu_import.lua:39,46`; `backup.lua:375`; `bundles.lua:193,289,490`; `catalog.lua:142,151`; `folders.lua:34,195,299`; `native_bridge.lua:170,176,331`; `native_catalog.lua:106,117`; `presets.lua:416,782,971,978,1004,1026,1030,1035,1089,1123,1157`; `trash.lua:317,495,558,589`; `view_cache.lua:117`; `ui/sections_folders.lua:34`; `ui/sections_load.lua:140,211,228`; `ui/sections_save.lua:60` |
| `joinFolder` | `view_cache.lua` | `acu_import.lua:39,49`; `backup.lua:366,374`; `bundles.lua:480,486`; `catalog.lua:55,59,144,155`; `folders.lua:63,92,262,274,369`; `native_catalog.lua:155`; `presets.lua:666,883,896,971,1026`; `trash.lua:561`; `ui/sections_folders.lua:190,194`; `ui/sections_save.lua:31` |
| `isInFolderTree` | `view_cache.lua` | `bundles.lua:268,280`; `folders.lua:109,136,174,182,261,273,298,368`; `trash.lua:751,755,790,822,872,890` |
| `addFolderAncestors` | `view_cache.lua` | `acu_import.lua:141`; `backup.lua:365,366`; `bundles.lua:315,478,480`; `catalog.lua:30,33,129,189,201`; `trash.lua:523,646,651,656`; `ui/sections_load.lua:172` |
| `validRelativePath` | `view_cache.lua` | `acu_import.lua:29`; `backup.lua:171,177,306,311`; `catalog.lua:68,70,136,138,146,346,348,350,365,366,372,377,430,448,450`; `presets.lua:300,475`; `trash.lua:17,23,27,32,73,78,85,113,114,115,119,121,128,154,155,164,165,173` |
| `remapFolderTreePath` | `folders.lua` | `folders.lua:110,119,137,175,189` |
| `validBundlePath` | `bundles.lua` | `bundles.lua:162,182,211,225,370,376,386` |
| `validNativeRelativePath` | `native_catalog.lua` | `native_catalog.lua:61,73` |
| `isFolderBundleFilename` | `filesystem.lua` | `bundles.lua:84,161,176,415`; `trash.lua:270,341` |
| `validTrashFilename` | `trash.lua` | `trash.lua:16,73,120,154` |
| `sanitizeName` | `filesystem.lua` | `trash.lua:317`; `ui/sections_folders.lua:60`; `ui/sections_manage.lua:26`; `ui/sections_save.lua:31` |
| `sanitizeMetadata` | `filesystem.lua` | `history.lua:34`; `presets.lua:257,259,279,281,283,285,287,293,298,305,310,481,482,483,484,485,486,503,507,1082,1083` |
| `validatedPresetName` | `filesystem.lua` | `catalog.lua:140`; `presets.lua:294,664,880`; `ui/sections_save.lua:12,15,37` |
| `validatedFolderName` | `view_cache.lua` | `folders.lua:61,90`; `ui/sections_folders.lua:49` |
| `findPresetCollision` | `view_cache.lua` | `backup.lua:333,353`; `bundles.lua:487`; `folders.lua:190`; `presets.lua:672,889,975,1028`; `trash.lua:489,554,562` |
| `uniqueStorageName` | `view_cache.lua` | `backup.lua:375`; `bundles.lua:490`; `folders.lua:195,299`; `presets.lua:768,1157`; `trash.lua:495,589` |
| `findExistingFolderName` | `presets.lua` | `folders.lua:64,99` |
| `folderNameExists` | `presets.lua` | `backup.lua:333,349`; `bundles.lua:472,606`; `native_bridge.lua:309,347` |
| `uniquePresetCopyName` | `presets.lua` | `presets.lua:1148`; `trash.lua:490` |
| `uniqueFolderCopyName` | `presets.lua` | `bundles.lua:472`; `folders.lua:161` |
| `isRuntimePointerText` | `options.lua` | `options.lua:34,44,47` |
| `stableChoiceIdentity` | `options.lua` | `options.lua:157,188`; `presets.lua:269,309` |
| `occurrenceKeyParts` | `options.lua` | `load_engine.lua:1010,1190,1197` |
| `optionIndexValidationError` | `options.lua` | `history.lua:18`; `presets.lua:180,318,733,834` |
| `optionIndexIsValid` | `options.lua` | `comparison.lua:92`; `load_engine.lua:627,893,927,1032,1091,1118,1494`; `options.lua:243,244,245,246,247,248` |
| `catalogEncode` | `catalog.lua` | `backup.lua:171,190`; `bundles.lua:180,183,207,215,229`; `catalog.lua:367,368,373,378,467,470`; `trash.lua:18,19,24,25,28,29,33,34,116,117,122,123,124,129` |
| `catalogDecode` | `catalog.lua` | `backup.lua:107,115,305,309`; `bundles.lua:159,160,369,375,385,508`; `catalog.lua:344,345,427,443`; `presets.lua:251,253,255,257,259,263,267`; `trash.lua:70,71,72,77,84,153,162,163,172` |
| `encode` | `backup.lua` | `backup.lua:37,166` |
| `decode` | `backup.lua` | `backup.lua:102,303,310` |
| `hexEncode` | `bundles.lua` | `bundles.lua:38` |
| `hexDecode` | `bundles.lua` | `bundles.lua:510` |
| `decodeImportField` | `acu_import.lua` | `acu_import.lua:24` |
| `decodeNativeField` | `native_catalog.lua` | `native_catalog.lua:59,67` |
| `historyPath` | `history.lua` | `history.lua:64,85,97,104,105,110,114,152` |
| `supportedFile` | `native_catalog.lua` | `native_catalog.lua:73,160` |
| `cleanField` | `native_bridge.lua` | `native_bridge.lua:86,95,96,100,111,142,199,205,217,218,229` |

## Validation

Before extraction, I ran the original helper bodies on the installed Lua 5.1 runtime and recorded 833 fixture results. The fixtures retain each returned value, its type, and the number of return values, including nil returns and error results. Error fixtures check that an error is raised; source filenames and line numbers change when code moves.

After extraction, those fixtures pass against the domain modules and again with the 29 public compatibility functions bound from the real legacy modules. The suite also checks all 256 byte values through each codec, exhausted copy and storage names, and domain loading without a runtime dependency. It does not call game APIs or write saved data.

From the repository root, run the test file with Lua 5.1:

```text
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage1_tests.lua"
```

The existing `native/verification/check_code.js` parses all 38 Lua files as Lua 5.1. I also ran the tests with the installed Lua 5.1 library through Python's standard-library interface. No dependency was added.

## Defects found

Name and metadata limits count bytes, so truncation can split a UTF-8 character. The baseline metadata fixture for `é猫` at three bytes retains this behavior. I left it unchanged for a separate fix.

The path validators also accept different sets of values. For example, the general relative-path check accepts `CON` and `a:b`, while bundle validation rejects them. Native relative-path validation accepts `CON` but rejects `a:b`. These differences may serve different callers, so I preserved them without treating them as confirmed defects.

## In-game checklist

Use a copy of an existing library and save for these checks. I have not performed them in the game.

1. **Save:** Save a preset at the library root and inside a nested folder. Include a Unicode name and notes or tags. Check the saved name, location, and format-8 text; try `CON` and a trailing period and compare the warnings with the baseline.
2. **Load:** Load both new presets, an older CPM preset, and a supported ACU preset. Check the selected choices and any warnings, then confirm the editor, save the game, and reload. Reading an older file must leave its bytes unchanged.
3. **Rename:** Rename a preset and a nested folder. Try a case collision and a name that differs only by case. Check the same collision rules, folder contents, and stored paths as before.
4. **Copy and move:** Duplicate a preset and folder twice, then move a preset into a nested folder. Check ` Copy` and ` Copy 2` naming, unchanged appearance data, and separate storage filenames.
5. **Import:** Preview and import an existing `.cpmfolder` file, then import it again. Check the same folder tree, collision names, and previous-import behavior. Import supported ACU files and check their names and locations.
6. **Backup:** Export and verify a `.cpmbackup` file with nested folders, notes, and Unicode text. Check the preset and folder counts and read the backup with the baseline version if available.
7. **Restore:** Restore that backup into a library with colliding names. Check the restore root, chosen names, notes, folder contents, and loaded appearance. Send a test preset to Trash and restore it as well.

## Before stage 2

**UNVERIFIED:** CET module loading and the in-game workflow checks above need runtime confirmation. No new game API was introduced, and this stage changes no hook or method replacement.

Check that installation copies all four new domain modules along with the changed legacy modules. Keep the byte-truncation defect separate from this extraction, and compare any unexpected result with the baseline before changing behavior.

I stopped at stage 1. Stage 2 requires confirmation after reviewing these results and the in-game checks.

local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

MOD_NAME = "Character Preset Manager (CET)"
PRESET_DIR = "Character Presets"
DATA_DIR = "Data"
CONFIG_DIR = DATA_DIR .. "/Config"
CATALOG_DIR = DATA_DIR .. "/Catalog"
RECOVERY_DIR = DATA_DIR .. "/Recovery"
TRASH_DIR = RECOVERY_DIR .. "/Trash"
LOG_DIR = DATA_DIR .. "/Logs"
LOG_ARCHIVE_DIR = LOG_DIR .. "/Archive"
TRASH_CATALOG_FILE = RECOVERY_DIR .. "/Trash Catalog.txt"
TRANSACTION_FILE = RECOVERY_DIR .. "/Recovery Journal.txt"
CATALOG_FILE = CATALOG_DIR .. "/Virtual Folders.txt"
INVENTORY_FILE = CATALOG_DIR .. "/Preset Inventory.txt"
IMPORTED_BUNDLES_FILE = CATALOG_DIR .. "/Imported Bundles.txt"
LOG_FILE = LOG_DIR .. "/Activity.log"
LOG_ARCHIVE_PREFIX = "Activity "
WINDOW_POSITION_STATUS_FILE = CONFIG_DIR .. "/Window Position Status.txt"
CONFIG_FILE = CONFIG_DIR .. "/Config.txt"
DISCOVERY_NOTICE_TITLE = "OPEN CHARACTER PRESET MANAGER"
DISCOVERY_NOTICE_MESSAGE = "Press the key you assigned to the CET Overlay."
DISCOVERY_NOTICE_SETTINGS_MESSAGE = "You can turn off this message in Settings."
LOG_ARCHIVE_LIMIT = 10
CURRENT_PRESET_FORMAT = 8
activitySequence = 0

AUTO_LOAD_TIMING = {
  interval = 0.10,
  pollInterval = 0.05,
  dependencyTimeout = 1.25,
  dependencyStableTime = 0.20,
}
PREFLIGHT_REFRESH_INTERVAL = 0.75
AUTO_LOAD_LIMITS = {
  minimumSeconds = 60,
  secondsPerOption = 2,
  maximumScannedPresets = 8192,
  maximumScannedEntries = 1048576,
}
STALL_CONFIRMATION_PASSES = 3
EDITOR_OPEN_TIMEOUT = 5.0
MAX_TREE_DEPTH = 12
MAX_PRESET_BYTES = 1048576
MAX_PRESET_ENTRIES = 4096
MAX_PRESET_LINES = MAX_PRESET_ENTRIES * 4 + 64
MAX_PRESET_KEY_BYTES = 256
MAX_OPTION_INDEX = 4294967295
FILE_COPY_CHUNK_SIZE = 65536
MAX_CATALOG_BYTES = 8388608
MAX_CATALOG_LINES = 32768
MAX_TRANSACTION_BYTES = 1048576
MAX_TRANSACTION_LINES = 8192
MAX_FOLDER_BUNDLE_BYTES = 33554432
MAX_FOLDER_BUNDLE_PRESETS = 512
FOLDER_BUNDLE_EXTENSION = ".cpmfolder"

return _ENV

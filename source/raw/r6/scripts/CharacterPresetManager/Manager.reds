module CPM
import Codeware.UI.*

public class PresetManager extends inkCustomController {
  private let bridge: wref<NativeBridge>;
  private let panel: wref<PresetPanel>;
  private let tabs: array<ref<PanelButton>>;
  private let buttons: array<ref<PanelButton>>;
  private let actions: array<String>;
  private let rows: array<ref<PanelButton>>;
  private let rowValues: array<String>;
  private let rowLabels: array<String>;
  private let rowKinds: array<String>;
  private let primary: ref<HubTextInput>;
  private let secondary: ref<HubTextInput>;
  private let search: ref<HubTextInput>;
  private let instruction: ref<inkText>;
  private let output: ref<inkText>;
  private let tab: Int32;
  private let offset: Int32;
  private let confirmation: String;
  private let syncing: Bool;

  private func Text(parent: ref<inkCompoundWidget>, text: String, x: Float, y: Float, width: Float, height: Float, size: Int32) -> ref<inkText> {
    let widget: ref<inkText> = new inkText();
    widget.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    widget.SetFontStyle(n"Medium");
    widget.SetFontSize(size);
    widget.SetText(text);
    widget.SetTintColor(HDRColor(0.85, 0.90, 0.92, 1.0));
    widget.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    widget.SetSize(width, height);
    widget.SetWrapping(true, width);
    widget.Reparent(parent);
    return widget;
  }
  private func Button(parent: ref<inkCompoundWidget>, label: String, x: Float, y: Float, width: Float, callback: CName) -> ref<PanelButton> {
    let button: ref<PanelButton> = PanelButton.Create(label);
    button.SetPosition(x, y);
    button.SetWidth(width);
    button.RegisterToCallback(n"OnBtnClick", this, callback);
    button.Reparent(parent, this.GetGameController());
    return button;
  }
  private func Input(parent: ref<inkCompoundWidget>, placeholder: String, x: Float, y: Float, callback: CName) -> ref<HubTextInput> {
    let input: ref<HubTextInput> = HubTextInput.Create();
    input.SetWidth(680.0);
    input.SetMaxLength(4096);
    input.SetDefaultText(placeholder);
    input.GetRootWidget().SetMargin(new inkMargin(x, y, 0.0, 0.0));
    input.RegisterToCallback(n"OnInput", this, callback);
    input.Reparent(parent, this.GetGameController());
    return input;
  }
  protected cb func OnCreate() -> Bool {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetSize(1500.0, 1230.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let background: ref<inkRectangle> = new inkRectangle();
    background.SetAnchor(inkEAnchor.Fill);
    background.SetTintColor(HDRColor(0.012, 0.018, 0.023, 1.0));
    background.SetOpacity(0.98);
    background.Reparent(root);
    this.Text(root, "MANAGE PRESETS", 24.0, 12.0, 1100.0, 60.0, 36);
    this.Button(root, "CANCEL LOAD", 820.0, 16.0, 310.0, n"OnCancelLoad");
    this.Button(root, "BACK TO EDITOR", 1160.0, 16.0, 310.0, n"OnClose");
    let labels: array<String> = ["PRESETS", "FOLDERS", "SHARING", "RECOVERY", "SETTINGS", "HELP", "BULK"];
    let i: Int32 = 0;
    while i < ArraySize(labels) {
      ArrayPush(this.tabs, this.Button(root, labels[i], 24.0 + Cast<Float>(i) * 207.0, 90.0, 197.0, n"OnTab"));
      i += 1;
    };
    this.search = this.Input(root, "Search presets", 24.0, 160.0, n"OnSearch");
    this.primary = this.Input(root, "Notes", 770.0, 270.0, n"OnEdit");
    this.secondary = this.Input(root, "Tags", 770.0, 365.0, n"OnEdit");
    this.instruction = this.Text(root, "", 770.0, 160.0, 680.0, 100.0, 26);
    this.output = this.Text(root, "Select a preset to see its details.", 24.0, 850.0, 1420.0, 340.0, 25);
    i = 0;
    while i < 9 {
      ArrayPush(this.rows, this.Button(root, "", 24.0, 265.0 + Cast<Float>(i) * 57.0, 700.0, n"OnRow"));
      i += 1;
    };
    this.Button(root, "SCROLL UP", 24.0, 785.0, 340.0, n"OnUp");
    this.Button(root, "SCROLL DOWN", 384.0, 785.0, 340.0, n"OnDown");
    i = 0;
    while i < 12 {
      ArrayPush(this.buttons, this.Button(root, "", 770.0 + Cast<Float>(i % 2) * 350.0, 470.0 + Cast<Float>(i / 2) * 57.0, 330.0, n"OnAction"));
      i += 1;
    };
    this.SetRootWidget(root);
    this.SetTab(0);
    return true;
  }
  public func IsEnteringText() -> Bool {
    return this.GetRootWidget().IsVisible() && (this.primary.IsFocused() || this.secondary.IsFocused() || this.search.IsFocused());
  }
  public func Open() -> Void {
    this.GetRootWidget().SetVisible(true);
    this.bridge.RegisterManager(this);
    this.SetTab(this.tab);
  }
  protected cb func OnInitialize() -> Bool {
    this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnBack");
    return true;
  }
  protected cb func OnUninitialize() -> Bool {
    this.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnBack");
    return true;
  }
  protected cb func OnBack(event: ref<inkPointerEvent>) -> Bool {
    if this.GetRootWidget().IsVisible() && event.IsAction(n"back") {
      this.GetRootWidget().SetVisible(false);
      this.panel.CloseManager();
      event.Handle();
      return true;
    };
    return false;
  }
  private func SetTab(value: Int32) -> Void {
    this.tab = value;
    this.confirmation = "";
    this.syncing = true;
    this.primary.SetText(""); this.secondary.SetText("");
    this.syncing = false;
    let labels: array<String>;
    ArrayClear(this.actions);
    if value == 0 {
      this.instruction.SetText("Select a preset to edit its notes and tags below. For Rename or Move, enter the full destination, such as My Folder/My Preset.");
      this.primary.SetDefaultText("Notes, or full destination name"); this.secondary.SetDefaultText("Tags");
      labels = ["LOAD", "SAVE NOTES / TAGS", "FAVORITE", "DUPLICATE", "RENAME", "MOVE", "MARK / UNMARK", "MOVE MARKED", "TRASH SELECTED", "TRASH MARKED", "COMPARE", "REFRESH"];
      this.actions = ["load", "metadata", "favorite", "duplicate", "rename", "move", "mark", "move_many", "delete", "trash_move", "compare", "refresh"];
      this.bridge.Request("current", "");
    };
    if value == 1 {
      this.instruction.SetText("Enter the folder name in the first field. To rename or copy it, enter the destination in the second field. Remove Folder keeps the presets in the parent folder.");
      this.primary.SetDefaultText("Folder name"); this.secondary.SetDefaultText("Destination folder");
      labels = ["CREATE FOLDER", "RENAME FOLDER", "COPY FOLDER", "REMOVE FOLDER", "SAVE LOCATION", "ROOT LOCATION", "TRASH FOLDER"];
      this.actions = ["create_folder", "rename_folder", "duplicate_folder", "remove_folder", "save_location", "root_location", "trash_folder"];
      this.bridge.Request("folder_list", "");
    };
    if value == 2 {
      this.instruction.SetText("Preview a shared file or backup before importing it. Your existing presets are kept. Export saves a file in red4ext/plugins/CharacterPresetManager/Character Presets.");
      this.primary.SetDefaultText("Shared file or backup name"); this.secondary.SetDefaultText("Folder to export, or leave empty for marked presets");
      labels = ["LIST FILES", "PREVIEW SHARED", "IMPORT SHARED", "EXPORT SHARED", "PREVIEW BACKUP", "RESTORE BACKUP", "CREATE BACKUP", "DELETE BACKUP", "TRASH SHARED"];
      this.actions = ["archive_list", "bundle_preview", "bundle_import", "bundle_export", "backup_preview", "backup_import", "backup_export", "backup_delete", "bundle_trash"];
      this.bridge.Request("archive_list", "");
    };
    if value == 3 {
      this.instruction.SetText("Select an item in Trash or appearance history, then choose Restore to bring it back. Empty Trash and Clear History delete saved files permanently. Select either action twice to confirm.");
      this.primary.SetDefaultText("Selected recovery item"); this.secondary.SetDefaultText("Unused");
      labels = ["SHOW TRASH", "RESTORE ITEM", "EMPTY TRASH", "SHOW HISTORY", "RESTORE HISTORY", "UNDO LAST LOAD", "CLEAR HISTORY", "ACTIVITY LOG", "RESTORE SHARED FILE", "RESTORE FOLDER"];
      this.actions = ["trash_query", "trash_restore", "trash_empty", "history", "restore_history", "restore_previous", "history_clear", "log", "bundle_restore", "restore_group"];
      this.bridge.Request("trash_query", "");
    };
    if value == 4 {
      this.instruction.SetText("Choose how to sort presets. To assign a key, select Bind Editor Key or Bind Panel Key and press the key you want. Press Backspace to clear that binding.");
      this.primary.SetDefaultText("Unused"); this.secondary.SetDefaultText("Unused");
      labels = ["SORT BY NAME", "SORT BY DATE", "BIND EDITOR KEY", "BIND PANEL KEY", "SHOW SETTINGS"];
      this.actions = ["sort_name", "sort_date", "bind_editor", "bind_panel", "config_read"];
      this.bridge.Request("config_read", "");
    };
    if value == 5 {
      this.instruction.SetText("You can save, load and manage presets without CET. Install CET if you also want force loading and technical information.");
      this.primary.SetDefaultText("Unused"); this.secondary.SetDefaultText("Unused");
      labels = ["HOW TO USE", "FILE LOCATIONS", "COMPATIBILITY", "ACTIVITY LOG"];
      this.actions = ["help", "paths", "compatibility", "log"];
      this.output.SetText("Choose a topic below. Select Back to Editor when you want to save or load presets.");
    };
    if value == 6 {
      this.instruction.SetText("Mark presets across pages and folders. Mark Page adds all presets on the current search page. To move them, enter a destination folder or leave it empty for All Presets. Export keeps each preset's folder path.");
      this.primary.SetDefaultText("Destination folder"); this.secondary.SetDefaultText("Unused");
      labels = ["MARK / UNMARK", "MARK PAGE", "CLEAR MARKS", "MOVE MARKED", "TRASH MARKED", "EXPORT MARKED"];
      this.actions = ["mark", "mark_page", "clear_marks", "move_many", "trash_move", "bundle_export"];
      this.bridge.Request("current", "");
    };
    let i: Int32 = 0;
    while i < ArraySize(this.buttons) {
      this.buttons[i].GetRootWidget().SetVisible(i < ArraySize(labels));
      if i < ArraySize(labels) { this.buttons[i].SetText(labels[i]); };
      i += 1;
    };
    i = 0;
    while i < ArraySize(this.tabs) { this.tabs[i].SetSelected(i == value); i += 1; };
  }
  protected cb func OnTab(widget: wref<inkWidget>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.tabs) { if this.tabs[i].GetRootWidget() == widget { this.SetTab(i); }; i += 1; };
    return true;
  }
  protected cb func OnClose(widget: wref<inkWidget>) -> Bool {
    this.GetRootWidget().SetVisible(false);
    this.panel.CloseManager();
    return true;
  }
  protected cb func OnEdit(widget: wref<inkWidget>) -> Bool { if !this.syncing { this.confirmation = ""; }; return true; }
  protected cb func OnSearch(widget: wref<inkWidget>) -> Bool { if !this.syncing && (this.tab == 0 || this.tab == 6) { this.bridge.Request("list", this.search.GetText()); }; return true; }
  protected cb func OnUp(widget: wref<inkWidget>) -> Bool { this.offset = Max(0, this.offset - 9); this.UpdateRows(); return true; }
  protected cb func OnDown(widget: wref<inkWidget>) -> Bool { this.offset = Min(Max(0, ArraySize(this.rowValues) - 9), this.offset + 9); this.UpdateRows(); return true; }
  protected cb func OnRow(widget: wref<inkWidget>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.rows) {
      if this.rows[i].GetRootWidget() == widget && this.offset + i < ArraySize(this.rowValues) {
        let row: Int32 = this.offset + i;
        this.confirmation = "";
        if Equals(this.rowKinds[row], "PRESET") { this.bridge.Request("select", this.rowValues[row]); }
        else {
          if Equals(this.rowKinds[row], "PAGE") { this.bridge.Request("page", this.rowValues[row]); }
          else { this.primary.SetText(this.rowValues[row]); };
        };
      };
      i += 1;
    };
    return true;
  }
  protected cb func OnAction(widget: wref<inkWidget>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.buttons) {
      if this.buttons[i].GetRootWidget() == widget && i < ArraySize(this.actions) { this.Execute(this.actions[i]); };
      i += 1;
    };
    return true;
  }
  private func Execute(action: String) -> Void {
    let text: String = this.primary.GetText();
    let extra: String = this.secondary.GetText();
    if Equals(action, "help") { this.output.SetText("Select a preset row and choose Load to apply it. To save your current appearance, enter a name and choose Save Preset. More Actions has recovery and compatibility tools. Open Manage Presets for folders, notes, sharing and backups. Hide Presets clears the panel so you can reach the game's controls. Cancel Load stops further changes, leaving applied choices visible."); return; };
    if Equals(action, "paths") { this.output.SetText("Presets: red4ext/plugins/CharacterPresetManager/Character Presets. Settings, recovery and logs: red4ext/plugins/CharacterPresetManager/Data. Back up both folders in full. When you first open the library after updating, the mod copies the old CET library and keeps the originals. Differing old files are saved under Data/Migration/Conflicts for review."); return; };
    if Equals(action, "compatibility") { this.output.SetText("Install the complete package, plus redscript, RED4ext and Codeware. CET is optional. Older CPM and compatible ACU presets stay readable; they update only when you overwrite them or save notes or tags. The mod cannot recreate missing custom choices. Loading keeps an existing character's gender and body type, and needs a supported appearance editor. Before you use the Full Appearance Editor, remove Character Customization Anywhere, then close and restart the game fully."); return; };
    if Equals(action, "bind_editor") || Equals(action, "bind_panel") { InputService.Get().BindKey(Equals(action, "bind_editor")); this.output.SetText("Press the key you want to use. To clear this binding, press Backspace."); return; };
    if Equals(action, "sort_name") { action = "config_save"; text = "name"; };
    if Equals(action, "sort_date") { action = "config_save"; text = "modified"; };
    if Equals(action, "root_location") { action = "save_location"; text = ""; };
    if Equals(action, "bundle_export") { text = extra; };
    let token: String = action + "|" + text + "|" + extra;
    let destructive: Bool = Equals(action, "trash_empty") || Equals(action, "history_clear") || Equals(action, "backup_delete") || Equals(action, "remove_folder") || Equals(action, "trash_move") || Equals(action, "bundle_trash") || Equals(action, "trash_folder");
    if destructive && NotEquals(this.confirmation, token) {
      this.confirmation = token;
      this.output.SetText("Select this action again to confirm it. Empty Trash, Clear History and Delete Backup delete the selected saved files permanently.");
      return;
    };
    this.bridge.RequestExtended(action, text, extra, destructive);
    this.confirmation = "";
  }
  protected cb func OnCancelLoad(widget: wref<inkWidget>) -> Bool { this.bridge.Request("cancel_load", ""); return true; }
  public func OnBusy(value: Bool, message: String) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.buttons) { this.buttons[i].SetDisabled(value); i += 1; };
    if this.GetRootWidget().IsVisible() && StrLen(message) > 0 { this.output.SetText(message); };
  }
  public func OnResponse(kind: String, payload: String, busy: Bool) -> Void {
    if !this.GetRootWidget().IsVisible() { return; };
    this.OnBusy(busy, "");
    if Equals(kind, "list") && this.tab != 0 && this.tab != 6 {
      this.output.SetText("Changes saved.");
      if this.tab == 1 { this.bridge.Request("folder_list", ""); };
      if this.tab == 2 { this.bridge.Request("archive_list", ""); };
      if this.tab == 3 { this.bridge.Request("trash_query", ""); };
      return;
    };
    if Equals(kind, "list") || Equals(kind, "manager_list") || Equals(kind, "history") {
      ArrayClear(this.rowValues); ArrayClear(this.rowLabels); ArrayClear(this.rowKinds);
      let lines: array<String> = StrSplit(payload, "\n", false);
      let i: Int32 = 0;
      while i < ArraySize(lines) {
        let fields: array<String> = StrSplit(lines[i], "\t", true);
        if ArraySize(fields) > 1 && Equals(fields[0], "SEARCH") && !this.search.IsFocused() {
          this.syncing = true; this.search.SetText(fields[1]); this.syncing = false;
        };
        if ArraySize(fields) > 3 && Equals(fields[0], "ROW") { ArrayPush(this.rowKinds, fields[1]); ArrayPush(this.rowValues, fields[2]); ArrayPush(this.rowLabels, fields[3]); };
        if ArraySize(fields) > 4 && Equals(fields[0], "HISTORY") { ArrayPush(this.rowKinds, "HISTORY"); ArrayPush(this.rowValues, fields[1]); ArrayPush(this.rowLabels, fields[2] + " | " + fields[3] + " choices"); };
        if ArraySize(fields) > 3 && Equals(fields[0], "SELECTED") {
          if this.tab == 0 { this.syncing = true; this.primary.SetText(fields[2]); this.secondary.SetText(fields[3]); this.syncing = false; };
          this.output.SetText("Selected: " + fields[1]);
        };
        if ArraySize(fields) > 2 && Equals(fields[0], "STATUS") && StrLen(fields[2]) > 0 { this.output.SetText(fields[2]); };
        i += 1;
      };
      this.offset = Min(this.offset, Max(0, ArraySize(this.rowValues) - 9));
      this.UpdateRows();
    } else { this.output.SetText(this.tab == 4 ? payload + "\n" + InputService.Get().BindingsText() : payload); };
  }
  private func UpdateRows() -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.rows) {
      let row: Int32 = this.offset + i;
      this.rows[i].GetRootWidget().SetVisible(row < ArraySize(this.rowValues));
      if row < ArraySize(this.rowValues) { this.rows[i].SetText(this.rowLabels[row]); };
      i += 1;
    };
  }
  public static func Create(bridge: ref<NativeBridge>, panel: ref<PresetPanel>) -> ref<PresetManager> {
    let manager: ref<PresetManager> = new PresetManager();
    manager.bridge = bridge; manager.panel = panel;
    manager.CreateInstance();
    return manager;
  }
}

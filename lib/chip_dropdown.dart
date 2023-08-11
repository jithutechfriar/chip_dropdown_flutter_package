// ignore_for_file: must_be_immutable

library chip_dropdown;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// README
/// - This widget has two `setSate()` properties
/// -- 1. To update widget => _setSate()
/// -- 2. To update Overlay Entry => overlaySetState()
///
/// - Overylay entry will get refreshed after every build unless it is disabled by [needOverlayRefresh] varibale
///
/// - Single selection widget can be accessed by the default [ChipDropdown] constructor.
/// -- [initialValue] => For single initial value. Accepts [ChipDropdownItem] value.
/// -- [onSelection] => For single onSelection callback. Returns single id of the selected item.
///
/// - Multi selection widget can be accessed by the [ChipDropdown.multiselection] constructor.
/// -- [initialValues] => For single initial value. Accepts list of [ChipDropdownItem] values.
/// -- [onChanged] => For single onSelection callback. Returns ids of selected items as a list.
///

/// Enums
enum ChipDropdownMode {
  // Follows main widget while scrolling.
  // Tap on [x] icon to close overlay
  normal,
  // Overlay in fixed position.
  // Dim background
  // Tap anywhere else to close
  focused
}

class ChipDropdown extends StatefulWidget {
  ChipDropdown({
    super.key,
    required this.items,
    this.onSelection,
    this.onSelectionAsItem,
    this.width,
    this.hint,
    this.initialValue,
    this.widgetDecoration,
    this.dropdownDecoration,
    this.chipMargin,
    this.chipPadding,
    this.chipFontSize,
    this.hintStyle,
    this.overlayHeight,
    this.textFieldWidth,
    this.errorText,
    this.mode = ChipDropdownMode.normal,
    this.textFieldPadding,
  });
  ChipDropdown.multiselection({
    super.key,
    required this.items,
    this.onChanged,
    this.onChangedAsItem,
    this.width,
    this.hint,
    this.initialValues,
    this.widgetDecoration,
    this.dropdownDecoration,
    this.chipMargin,
    this.chipPadding,
    this.chipFontSize,
    this.hintStyle,
    this.overlayHeight,
    this.textFieldWidth,
    this.errorText,
    this.mode = ChipDropdownMode.normal,
    this.textFieldPadding,
  }) {
    isMultiselectionMode = true;
  }

  /// Multi selection property.
  /// Returns ids as a list of [String].
  Function(List<String> selectedItems)? onChanged;

  /// Multi selection property.
  /// Returns ids as a list of [ChipDropdownItem].
  Function(List<ChipDropdownItem> selectedItems)? onChangedAsItem;

  /// Single selection property.
  /// Returns a single [id] as [String].
  Function(String selectedItemId)? onSelection;

  /// Single selection property.
  /// Returns a single [id] as [ChipDropdownItem].
  Function(ChipDropdownItem? selectedItemId)? onSelectionAsItem;

  /// List of items to load in ChipDropdown.
  final List<ChipDropdownItem> items;

  /// Width of widget.
  final double? width;

  /// Possible modes.
  /// 1. Single Selection => isMultiselectionMode == false;
  /// 2. Multi Selection => isMultiselectionMode == true;
  bool isMultiselectionMode = false;

  /// Hint text for input text field.
  final String? hint;

  /// Single selection property.
  /// Inital value to display.
  ChipDropdownItem? initialValue;

  /// Multi selection property.
  /// Initial values to display.
  List<ChipDropdownItem>? initialValues;

  /// Decoration property for main widget.
  final Decoration? widgetDecoration;

  /// Decoration property for dropdown overlay.
  final Decoration? dropdownDecoration;

  /// Padding of single chip in main widget.
  final double? chipPadding;

  /// Margin of single chip in main widget.
  final double? chipMargin;

  /// Font size of chip text.
  final double? chipFontSize;

  /// Height of dropdown overlay.
  final double? overlayHeight;

  /// Style properties for hint.
  final TextStyle? hintStyle;

  /// Width of text field
  final double? textFieldWidth;

  /// To display error message below the widget.
  final String? errorText;

  /// Change between modes
  final ChipDropdownMode mode;

  /// Padding for input text field.
  final EdgeInsetsGeometry? textFieldPadding;

  @override
  State<ChipDropdown> createState() => _ChipDropdownState();
}

class _ChipDropdownState extends State<ChipDropdown> {
  /// Customizable properties
  double popupMenuItemPadding = 8;
  // All side padding of main widget
  double mainWidgetPadding = 8;
  // All side margin of single chip
  double chipMargin = 2;
  // All side padding of single chip
  double chipPadding = 8;
  // Size of close icon in single chip
  double chipCloseIconSize = 24;
  // Gap between image and title in chip
  double chipImageAndTitleGap = 2;
  // Height of overlay
  double overlayHeight = 150;
  // Size of image
  double imageSize = 30;
  // Gap between image and title
  double paddingBetweenImageAndTitle = 5;

  // To link widget and overly to keep overlay always below the widget.
  final layerLink = LayerLink();

  // List of selected items.
  List<ChipDropdownItem> selectedItems = [];

  // List of filtered items to display in overlay menu.
  List<ChipDropdownItem> filteredItems = [];

  // SetSate for rebuilding overlay.
  late void Function(void Function()) overlaySetState;

  // controller for search input field.
  TextEditingController searchTextController = TextEditingController();

  // focusNode to detect `backSpace` key input from keyboard.
  FocusNode focusNode = FocusNode();

  // Current overlay entry object.
  OverlayEntry? overlayEntry;

  // Current overlay state oject.
  late OverlayState overlayState;

  // Size of overlay entry
  late Size overlaySize;

  // Width of main widget
  double? mainWidgetWidth;

  // Detect if [build()] called by updating this widget or entirely rebuilding this widget from its parent outside.
  bool isSetStateCalledInternally = false;

  @override
  void initState() {
    super.initState();

    // - Initial value must be present in the items list of dropdown.
    inputValidation();

    // Load correspoding initial values.
    widget.isMultiselectionMode ? loadMultiSelectionInitialValue() : loadSingleSelectionInitialValue();
  }

  @override
  void dispose() {
    removeOverlayEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isSetStateCalledInternally) {
        // Remove existing overylay and add new overylay with the latest data.
        refreshOverlayEntry();
        isSetStateCalledInternally = false;
      } else {
        updateNewValuesOnExternalSetState();
      }
    });
    return WillPopScope(
      onWillPop: () async {
        // If the page is being interrepted by other methods or system inputs, it would be benificial to remove overlay.
        removeOverlayEntry();
        return true;
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: widget.widgetDecoration ??
                      const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                  // `CompositedTransformTarget` used to track a widget's position while scrolling
                  child: CompositedTransformTarget(
                    link: layerLink,
                    child: mainWidget(),
                  ),
                ),
                if (widget.errorText != null) errorTextWidget()
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display error message
  Widget errorTextWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        widget.errorText!,
        style: const TextStyle(
          color: Colors.red,
        ),
      ),
    );
  }

  void showOverlay(BuildContext context) async {
    overlayState = Overlay.of(context);
    final renderbox = context.findRenderObject() as RenderBox;
    overlaySize = renderbox.size;

    overlayEntry = OverlayEntry(
      builder: (context) {
        if (widget.mode == ChipDropdownMode.focused) {
          return GestureDetector(
            onTap: () {
              removeOverlayEntry();
            },
            child: Container(color: const Color.fromARGB(43, 0, 0, 0), child: overlayParentWidget()),
          );
        } else {
          return overlayParentWidget();
        }
      },
    );
    overlayState.insert(overlayEntry!);
  }

  Widget overlayParentWidget() {
    return Stack(
      children: [
        Positioned(
          width: widget.width ?? (overlaySize.width),
          child: CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, overlaySize.height + 5),
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(
                builder: (context, setState) {
                  overlaySetState = setState;
                  return overlayWidget();
                },
                // child: overlayWidget(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget that contains the details of selected items and an input text field to search for new items.
  Widget mainWidget() {
    return InkWell(
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      onTap: () {
        // Prevent multiple overlays from showing at the same time.
        if (overlayEntry == null) {
          showOverlay(context);
        }
      },
      child: LayoutBuilder(
        builder: (ctx, constarints) {
          mainWidgetWidth = constarints.maxWidth;
          return Padding(
            padding: EdgeInsets.all(mainWidgetPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    children: [
                      for (int i = 0; i < selectedItems.length; i++)
                        Container(
                          margin: EdgeInsets.all(widget.chipMargin ?? chipMargin),
                          padding: EdgeInsets.all(widget.chipPadding ?? chipPadding),
                          decoration: const BoxDecoration(
                            color: Color(0xffeeeeee),
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              selectedItems[i].imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        selectedItems[i].imageUrl!,
                                        width: imageSize,
                                        height: imageSize,
                                        fit: BoxFit.fill,
                                      ),
                                    )
                                  : const SizedBox(),
                              SizedBox(
                                width: chipImageAndTitleGap,
                              ),
                              Container(
                                constraints: BoxConstraints(maxWidth: getMaximumAllowedSizeForChipTitle(imageUrl: selectedItems[i].imageUrl)),
                                child: Text(
                                  selectedItems[i].title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: widget.chipFontSize),
                                ),
                              ),
                              SizedBox(
                                width: chipCloseIconSize,
                                height: chipCloseIconSize,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    filteredItems.add(selectedItems[i]);
                                    selectedItems.remove(selectedItems[i]);

                                    // Clear input field and update popup items with unfiltered data
                                    searchTextController.clear();
                                    filterItems('');

                                    if (widget.mode == ChipDropdownMode.normal) {
                                      updateOverlayState();
                                    }
                                    widget.isMultiselectionMode ? onMultiSeletionChipRemove() : onSingleSelectionChipRemove();
                                    _setState();
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      SizedBox(
                        width: widget.textFieldWidth ?? 100,
                        child: RawKeyboardListener(
                          focusNode: focusNode,
                          onKey: (value) {
                            if (value.runtimeType.toString() == 'RawKeyUpEvent' && value.logicalKey == LogicalKeyboardKey.backspace) {
                              if (selectedItems.isEmpty) return;
                              filteredItems.add(selectedItems.last);
                              selectedItems.removeLast();
                              updateOverlayState();
                              _setState();
                              onChangedCallback();
                            }
                          },
                          child: Visibility(
                            // Hide input text field if the selection mode is single selection and one item is selected
                            visible: !(widget.isMultiselectionMode == false && selectedItems.length == 1),
                            child: Padding(
                              padding: widget.textFieldPadding != null && selectedItems.isEmpty ? widget.textFieldPadding! : const EdgeInsets.all(0),
                              child: TextField(
                                cursorColor: Colors.grey,
                                decoration: InputDecoration(
                                  hintText: setTextFieldHint(),
                                  border: InputBorder.none,
                                  hintStyle: widget.hintStyle ?? const TextStyle(fontSize: 12),
                                ),
                                controller: searchTextController,
                                onTap: () {
                                  // Prevent multiple overlays from showing at the same time.
                                  if (overlayEntry == null) {
                                    showOverlay(context);
                                  }
                                },
                                onChanged: (value) {
                                  filterItems(value);
                                  _setState();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: selectedItems.isEmpty,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Return user defined or default hint only when no items are seleted
  String? setTextFieldHint() {
    if (selectedItems.isEmpty) return widget.hint ?? 'Search';
    return null;
  }

  // Filter popup list items based on the user input.
  filterItems(String value) {
    filteredItems = widget.items.where((element) => element.title.toLowerCase().contains(value.toLowerCase())).toList();

    for (ChipDropdownItem item in selectedItems) {
      for (int i = 0; i < filteredItems.length; i++) {
        if (filteredItems[i].id == item.id) {
          filteredItems.removeAt(i);
          break;
        }
      }
    }
  }

  // Most parent of overlay widget
  Widget overlayWidget() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: Offset(2, 2),
            blurRadius: 12,
            color: Color.fromRGBO(0, 0, 0, 0.16),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add close button at the top
          if (widget.mode == ChipDropdownMode.normal) closeOverlayIcon(),
          Container(
            constraints: BoxConstraints(maxHeight: widget.overlayHeight ?? overlayHeight),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: generateOverlayWidgets(),
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Generate overlay widget including `close button` at the top and empty message if no items are present in [filteredItems] list
  List<Widget> generateOverlayWidgets() {
    List<Widget> items = [];
    items.addAll(filteredItems.isEmpty ? emptyItemsOverlayWidget() : overlayWidgets());
    return items;
  }

  // Button to close overlay
  Widget closeOverlayIcon() {
    return Row(
      children: [
        const Spacer(),
        IconButton(
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          onPressed: () {
            removeOverlayEntry();
          },
          icon: const Icon(
            Icons.close,
            color: Colors.grey,
          ),
        ),
        const SizedBox(
          width: 5,
        ),
      ],
    );
  }

  /// items of [filteredItems] list.
  List<Widget> overlayWidgets() {
    List<Widget> items = [];
    for (int i = 0; i < filteredItems.length; i++) {
      items.add(singleOverlayItem(item: filteredItems[i]));
    }
    return items;
  }

  /// Widget to display when there are no items in the [filteredItems] list.
  List<Widget> emptyItemsOverlayWidget() => [Padding(padding: EdgeInsets.all(popupMenuItemPadding), child: const Text('Nothing to show here'))];

  // Single element of overlay item.
  Widget singleOverlayItem({required ChipDropdownItem item}) {
    return InkWell(
      child: Padding(
        padding: EdgeInsets.all(popupMenuItemPadding),
        child: Row(
          children: [
            if (item.imageUrl != null)
              Padding(
                padding: EdgeInsets.only(right: paddingBetweenImageAndTitle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    item.imageUrl!,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            SizedBox(
              width: getMaximumAllowedSizeForOverlayTitle(imageUrl: item.imageUrl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (item.description != null)
                    Expanded(
                      child: Wrap(
                        children: [
                          Container(
                            margin: EdgeInsets.all(widget.chipMargin ?? chipMargin),
                            padding: EdgeInsets.all(widget.chipPadding ?? chipPadding),
                            decoration: const BoxDecoration(
                              color: Color(0xffeeeeee),
                              borderRadius: BorderRadius.all(Radius.circular(30)),
                            ),
                            child: Text(
                              item.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        widget.isMultiselectionMode ? multiSelectionOverlayItemTap(item) : singleSelectionOverlayItemTap(item);
      },
    );
  }

  // Handle onTap of overlay item for `SingleSelection` widget
  singleSelectionOverlayItemTap(ChipDropdownItem item) {
    filteredItems = List.from(widget.items);
    selectedItems.clear();
    selectedItems.add(item);
    filteredItems.remove(item);
    _setState();
    removeOverlayEntry();
    onSelectionCallback();
  }

  // Calculate maximum allowed size for title in overlay.
  // Used to set overflow for title.
  double getMaximumAllowedSizeForOverlayTitle({required String? imageUrl}) {
    // Overlay width is the maximum width.
    double maximumSize = overlaySize.width;
    // Reduce padding from both sides.
    maximumSize -= popupMenuItemPadding * 2;
    // Reduce image size and gap to title if current item consist of [imageUrl].
    maximumSize -= imageUrl != null ? (imageSize + paddingBetweenImageAndTitle) : 0;

    return maximumSize;
  }

  // Calculate maximum allowed size for title in main widget chip.
  double getMaximumAllowedSizeForChipTitle({required String? imageUrl}) {
    // [mainWidgetWidth] is the maximum width.
    double maximumSize = mainWidgetWidth ?? 0;
    // Reduce width of close icon.
    maximumSize -= chipCloseIconSize;
    // Reduce gap between image and title inside the chip.
    maximumSize -= chipImageAndTitleGap;
    // Reduce chip margin from both sides.
    maximumSize -= chipMargin * 2;
    // Reduce chip padding from both sides.
    maximumSize -= chipPadding * 2;
    // Reduce main widget padding from  both sides.
    maximumSize -= mainWidgetPadding * 2;

    return maximumSize;
  }

  // Handle onTap of overlay item for `MultiSelection` widget
  multiSelectionOverlayItemTap(ChipDropdownItem item) {
    selectedItems.add(item);
    filteredItems.remove(item);

    // Clear input field and update popup items with unfiltered data
    searchTextController.clear();
    filterItems('');
    _setState();
    updateOverlayState();
    onChangedCallback();
  }

  // Replace current popup and add new one.
  refreshOverlayEntry() {
    if (overlayEntry == null) return;
    removeOverlayEntry();
    showOverlay(context);
  }

  // Remove current popup
  removeOverlayEntry() {
    if (overlayEntry != null) {
      overlayEntry?.remove();
      overlayEntry = null;
    }
  }

  // Update state of popup
  updateOverlayState() {
    if (overlayEntry != null) {
      overlaySetState(
        () {},
      );
    }
  }

  // Load initial value for `SingleSelection` widget
  loadSingleSelectionInitialValue() {
    filteredItems = List.from(widget.items);
    if (widget.initialValue == null) return;
    selectedItems = List.from([widget.initialValue]);

    // Remove initial values from filtered items
    filteredItems.removeWhere((element) => element.id == selectedItems.first.id);
  }

  // Load initial value for `MultiSelection` widget
  loadMultiSelectionInitialValue() {
    filteredItems = List.from(widget.items);
    if (widget.initialValues == null) return;
    selectedItems = List.from(widget.initialValues!);

    // Remove initial values from filtered items
    for (ChipDropdownItem item in selectedItems) {
      filteredItems.removeWhere((element) => element.id == item.id);
    }
  }

  // onTap of remove button in chip for singleSelection
  onSingleSelectionChipRemove() {
    if (widget.onSelection != null) widget.onSelection!('');
    if (widget.onSelectionAsItem != null) widget.onSelectionAsItem!(null);
  }

  // onTap of remove button in chip for multiSelection
  onMultiSeletionChipRemove() {
    onChangedCallback();
    onSelectionCallback();
  }

  // Check if the widget has received the necessary data to work properly.
  inputValidation() {
    /// Check for items with same id
    for (ChipDropdownItem item in widget.items) {
      if (widget.items.where((element) => element.id == item.id).length > 1) {
        assert(false, 'Items must have unique id. Duplicate item found in list.');
      }
    }

    /// Single selection ///
    /// To check if the initial value of `Single selection chip dropdown` is present in items list.
    if (widget.initialValue != null) {
      bool isFound = false;
      for (var item in widget.items) {
        if (item.id == widget.initialValue!.id &&
            item.title == widget.initialValue!.title &&
            item.description == widget.initialValue!.description &&
            item.imageUrl == widget.initialValue!.imageUrl) {
          isFound = true;
        }
      }
      assert(isFound, 'Initial value must be present in the dropdown items list');
    }

    /// Multi selection ///
    /// To check if the initial values of `Multi selection chip dropdown` is present in items list.
    if (widget.initialValues != null) {
      bool isFound = false;
      for (ChipDropdownItem initialValue in widget.initialValues!) {
        for (ChipDropdownItem item in widget.items) {
          if (item.id == initialValue.id &&
              item.title == initialValue.title &&
              item.description == initialValue.description &&
              item.imageUrl == initialValue.imageUrl) {
            isFound = true;
          }
        }
        assert(isFound, 'Initial values must be present in the dropdown items list');
      }
    }
  }

  /// To return onChanged values
  onChangedCallback() {
    if (widget.onChanged != null) {
      widget.onChanged!(selectedItems.map((e) => e.id).toList());
    }
    if (widget.onChangedAsItem != null) {
      widget.onChangedAsItem!(selectedItems);
    }
  }

  /// To return onSelection values
  onSelectionCallback() {
    if (widget.onSelection != null) {
      widget.onSelection!(selectedItems.first.id);
    }
    if (widget.onSelectionAsItem != null) {
      widget.onSelectionAsItem!(selectedItems.first);
    }
  }

  /// Internal SetStateCall.
  _setState() {
    isSetStateCalledInternally = true;
    setState(() {});
  }

  /// Update new values on external set state call.
  void updateNewValuesOnExternalSetState() {
    /// Update initial values.
    if (widget.initialValues != null) selectedItems = widget.initialValues!;
    if (widget.initialValue != null) selectedItems = [widget.initialValue!];
    filterItems('');
    inputValidation();
    _setState();
  }
}

// Model class to accept input values.
class ChipDropdownItem {
  const ChipDropdownItem({required this.id, required this.title, this.description, this.imageUrl});
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
}

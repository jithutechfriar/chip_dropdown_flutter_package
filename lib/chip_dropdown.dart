// ignore_for_file: must_be_immutable

library chip_dropdown;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'globals.dart';

/// README
/// - This widget has two `setSate()` properties
/// -- 1. To update widget => setSate()
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
  }) {
    isMultiselectionMode = true;
  }

  Function(List<String> selectedItems)? onChanged;
  Function(List<ChipDropdownItem> selectedItems)? onChangedAsItem;
  Function(String selectedItemId)? onSelection;
  Function(ChipDropdownItem? selectedItemId)? onSelectionAsItem;
  final List<ChipDropdownItem> items;
  final double? width;
  bool isMultiselectionMode = false;
  final String? hint;
  ChipDropdownItem? initialValue;
  List<ChipDropdownItem>? initialValues;
  final Decoration? widgetDecoration;
  final Decoration? dropdownDecoration;
  final double? chipPadding;
  final double? chipMargin;
  final double? chipFontSize;
  final TextStyle? hintStyle;

  @override
  State<ChipDropdown> createState() => _ChipDropdownState();
}

class _ChipDropdownState extends State<ChipDropdown> {
  // Customizable properties
  double popupMenuItemPadding = 8;
  double popupMenuLeftPadding = 5;
  double mainWidgetPadding = 8;

  final layerLink = LayerLink();
  List<ChipDropdownItem> selectedItems = [];
  List<ChipDropdownItem> filteredItems = [];
  late void Function(void Function()) overlaySetState;
  TextEditingController textEditingController = TextEditingController();
  FocusNode focusNode = FocusNode();
  OverlayEntry? overlayEntry;
  late OverlayState overlayState;

  // Overlay refresh will take place after the build of last frame in `addPostFrameCallback()`
  // toggle this varible to set overlay refresh.
  bool needOverlayRefresh = true;

  // Size of overlay entry
  late Size overlaySize;

  @override
  void initState() {
    super.initState();
    filteredItems = List.from(widget.items);

    // - Initial value of `Single selection dropdwon` or initial values of `Multi selection dropdown` must be present in the items list of dropdown.
    handleInputErrors();

    // Load correspoding initial values.
    widget.isMultiselectionMode ? loadMultiSelectionInitialValue() : loadSingleSelectionInitialValue();
  }

  @override
  void dispose() {
    removeOverlayEntry();
    isWidgetCurrenltyActive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isWidgetCurrenltyActive && needOverlayRefresh) {
        // Remove existing overylay and add new overylay with the latest data.
        refreshOverlayEntry();
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
              child: Container(
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
            ),
          ],
        ));
  }

  void showOverlay(BuildContext context) async {
    overlayState = Overlay.of(context);
    final renderbox = context.findRenderObject() as RenderBox;
    overlaySize = renderbox.size;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          // TODO: Need improvement in setting width of overlay as same as that of widget.
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
        );
      },
    );
    overlayState.insert(overlayEntry!);
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
        isWidgetCurrenltyActive = true;
      },
      child: Padding(
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
                      margin: EdgeInsets.all(widget.chipMargin ?? 2),
                      padding: EdgeInsets.all(widget.chipPadding ?? 8),
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
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.fill,
                                  ),
                                )
                              : const SizedBox(),
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            selectedItems[i].title,
                            style: TextStyle(fontSize: widget.chipFontSize),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              filteredItems.add(selectedItems[i]);
                              selectedItems.remove(selectedItems[i]);

                              // Clear input field and update popup items with unfiltered data
                              textEditingController.clear();
                              if (widget.isMultiselectionMode == false) filterItems('');

                              updateOverlayState();
                              isWidgetCurrenltyActive = true;
                              setState(() {});
                              widget.isMultiselectionMode ? onMultiSeletionChipRemove() : onSingleSelectionChipRemove();
                            },
                            icon: const Icon(
                              Icons.close,
                            ),
                          )
                        ],
                      ),
                    ),
                  SizedBox(
                    width: 100,
                    child: RawKeyboardListener(
                      focusNode: focusNode,
                      onKey: (value) {
                        if (value.runtimeType.toString() == 'RawKeyUpEvent' && value.logicalKey == LogicalKeyboardKey.backspace) {
                          if (selectedItems.isEmpty) return;
                          filteredItems.add(selectedItems.last);
                          selectedItems.removeLast();
                          updateOverlayState();
                          setState(() {});
                          onChangedCallback();
                        }
                      },
                      child: Visibility(
                        // Hide input text field if the selection mode is single selection and one item is selected
                        visible: !(widget.isMultiselectionMode == false && selectedItems.length == 1),
                        child: TextField(
                          cursorColor: Colors.grey,
                          decoration: InputDecoration(
                            hintText: setTextFieldHint(),
                            border: InputBorder.none,
                            hintStyle: widget.hintStyle ?? const TextStyle(fontSize: 12),
                          ),
                          controller: textEditingController,
                          onTap: () {
                            // Prevent multiple overlays from showing at the same time.
                            if (overlayEntry == null) {
                              showOverlay(context);
                            }
                            isWidgetCurrenltyActive = true;
                          },
                          onChanged: (value) {
                            filterItems(value);
                          },
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

    // remove selected items
    for (var item in selectedItems) {
      if (filteredItems.contains(item)) {
        filteredItems.remove(item);
      }
    }

    setState(() {});
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
        children: generateOverlayWidgets(),
      ),
    );
  }

  /// Generate overlay widget including `close button` at the top and empty message if no items are present in [filteredItems] list
  List<Widget> generateOverlayWidgets() {
    List<Widget> items = [];
    // Add close button at the top
    items.add(closeOverlayIcon());
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
            isWidgetCurrenltyActive = false;
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
      items.add(singlesSeletedChip(item: filteredItems[i]));
    }
    return items;
  }

  /// Widget to display when there are no items in the [filteredItems] list.
  List<Widget> emptyItemsOverlayWidget() => [Padding(padding: EdgeInsets.all(popupMenuItemPadding), child: const Text('Nothing to show here'))];

  // Widget of a single selected chip, which includes an icon, title and close button
  Widget singlesSeletedChip({required ChipDropdownItem item}) {
    return InkWell(
      child: Padding(
        padding: EdgeInsets.all(popupMenuItemPadding),
        child: Row(
          children: [
            item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      item.imageUrl!,
                      width: 30,
                      height: 30,
                      fit: BoxFit.fill,
                    ),
                  )
                : const SizedBox(),
            const SizedBox(),
            SizedBox(
              // Reduce [popupMenuItemPadding] from both sides
              width: overlaySize.width - (popupMenuItemPadding * 2),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
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
    needOverlayRefresh = false;
    setState(() {});
    removeOverlayEntry();
    onSelectionCallback();
  }

  // Handle onTap of overlay item for `MultiSelection` widget
  multiSelectionOverlayItemTap(ChipDropdownItem item) {
    selectedItems.add(item);
    filteredItems.remove(item);

    // Clear input field and update popup items with unfiltered data
    textEditingController.clear();
    if (widget.isMultiselectionMode == false) filterItems('');

    setState(() {});
    updateOverlayState();
    onChangedCallback();
  }

  // Replace current popup and add new one.
  refreshOverlayEntry() {
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
    if (widget.initialValue != null) {
      selectedItems = List.from([widget.initialValue]);

      // Remove initial values from filtered items
      filteredItems.removeWhere((element) => element.id == widget.initialValue!.id);
    }
  }

  // Load initial value for `MultiSelection` widget
  loadMultiSelectionInitialValue() {
    if (widget.initialValues != null) {
      selectedItems = List.from(widget.initialValues!);

      // Remove initial values from filtered items
      for (var initialValue in widget.initialValues!) {
        filteredItems.removeWhere((element) => element.id == initialValue.id);
      }
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
  handleInputErrors() {
    /// To check if the initial value of `Single selection chip dropdown` is present in items list.
    if (widget.initialValue != null) {
      bool isFound = false;
      for (var item in widget.items) {
        if (item.id == widget.initialValue!.id && item.title == widget.initialValue!.title && item.imageUrl == widget.initialValue!.imageUrl) {
          isFound = true;
        }
      }
      assert(isFound, 'Initial value must be present in the dropdown items list');
    }

    /// To check if the initial values of `Multi selection chip dropdown` is present in items list.
    if (widget.initialValues != null) {
      bool isFound = false;
      for (ChipDropdownItem initialValue in widget.initialValues!) {
        for (ChipDropdownItem item in widget.items) {
          if (item.id == initialValue.id && item.title == initialValue.title && item.imageUrl == initialValue.imageUrl) {
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
}

// Model class to accept input values.
class ChipDropdownItem {
  const ChipDropdownItem({required this.id, required this.title, this.imageUrl});
  final String id;
  final String title;
  final String? imageUrl;
}

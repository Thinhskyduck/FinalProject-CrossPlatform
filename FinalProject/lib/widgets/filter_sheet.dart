import 'package:flutter/material.dart';

class FilterSheet extends StatefulWidget {
  final Function(double, double, List<String>, List<String>) onApplyFilter;
  final String initialCategory;

  FilterSheet({required this.onApplyFilter, required this.initialCategory});

  @override
  _FilterSheetState createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  double minPrice = 0;
  double maxPrice = 10000;
  RangeValues selectedRange = RangeValues(0, 10000);

  late String selectedCategory;
  List<String> selectedColors = [];
  List<String> selectedBrands = [];

  final List<String> colors = ["Silver", "White", "Grey", "Black", "Blue", "Pink", "Red"];
  final Map<String, List<String>> categoryBrands = {
    "Laptop": ["MacBook", "Asus", "MSI", "HP", "Dell", "Acer", "LG", "Lenovo"],
    "Monitor": ["LG UltraGear", "Dell UltraSharp", "Samsung Odyssey", "Alienware", "Asus Rog Swift"],
    "Hard Drivers": ["Seagate", "Western Digital", "Samsung SSD", "WD", "Toshiba"],
    "Keyboard": ["Logitech", "Razer", "Corsair", "Darue", "Fillco", "Newmen"],
    "Mouse": ["Logitech", "Razer", "SteelSeries", "Corsair", "Darue"]
  };

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    selectedBrands = [];
  }

  void updateBrandList(String category) {
    setState(() {
      selectedCategory = category;
      selectedBrands.clear();
    });
  }

  void toggleSelection(List<String> list, String item) {
    setState(() {
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Price (\$)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPriceField(selectedRange.start),
              _buildPriceField(selectedRange.end),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: Color(0xFFDB3022),
              thumbColor: Color(0xFFDB3022),
              rangeThumbShape: RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: selectedRange,
              min: minPrice,
              max: maxPrice,
              divisions: 100,
              labels: RangeLabels(
                "\$${selectedRange.start.toInt()}",
                "\$${selectedRange.end.toInt()}",
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  selectedRange = values;
                });
              },
            ),
          ),

          _buildCategorySection("Color", colors, selectedColors),
          SizedBox(height: 10),
          _buildCategorySection("Brand", categoryBrands[selectedCategory] ?? [], selectedBrands),
          SizedBox(height: 40,),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton("Clear filter ", Colors.white, Color(0xFFDB3022), () {
                setState(() {
                  selectedRange = RangeValues(minPrice, maxPrice);
                  selectedColors.clear();
                  selectedBrands.clear();
                });
              }),
              SizedBox(width: 10,),
              _buildActionButton("Apply", Color(0xFFDB3022), Colors.white, () {
                widget.onApplyFilter(selectedRange.start, selectedRange.end, selectedColors, selectedBrands);
                Navigator.pop(context);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField(double value) {
    return Container(
      width: 100,
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
      child: Text("\$${value.toInt()}", textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
    );
  }

  Widget _buildCategorySection(String title, List<String> options, List<String> selectedList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            bool isSelected = selectedList.contains(option);
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: Colors.red.shade100,
              backgroundColor: Colors.white,
              onSelected: (bool selected) {
                toggleSelection(selectedList, option);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, Color bgColor, Color textColor, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: bgColor, foregroundColor: textColor),
      onPressed: onPressed,
      child: Text(text, style: TextStyle(fontSize: 16)),
    );
  }
}

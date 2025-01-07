import 'package:flutter/material.dart';

class FilterWidget extends StatelessWidget {
  final String? selectedCategory;
  final Function(String?) onCategoryChanged;
  final List<String> categories;

  const FilterWidget({
    Key? key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    this.categories = const [
      'None',
      'Shirts',
      'Pants',
      'Jackets',
      'Skirt',
      'Dress',
      'Accessories'
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter by Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              TextButton(
                onPressed: () {
                  onCategoryChanged('All');
                  Navigator.pop(context);
                },
                child: Text(
                  'Reset',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final isSelected = selectedCategory == category;
              return FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  onCategoryChanged(selected ? category : 'All');
                  Navigator.pop(context);
                },
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade700,
                backgroundColor: Colors.grey.shade200,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.green.shade700 : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (selectedCategory != null && selectedCategory != 'All')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Selected: $selectedCategory',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

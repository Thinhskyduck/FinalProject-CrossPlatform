import 'package:cross_platform_mobile_app_development/utils/colors.dart';
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int pageIndex;
  final Function(int) onTap;

  const BottomNavBar({super.key, required this.pageIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 60,
      padding: EdgeInsets.all(0),
      elevation: 0.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Container(
          color: AppColor.primaryColor,
          child: Row(
            children: [
              navItem(
                Icons.computer,
                "Product",
                pageIndex == 0,
                onTap: () => onTap(0),
              ),
              navItem(
                Icons.person,
                "User",
                pageIndex == 1,
                onTap: () => onTap(1),
              ),
              const SizedBox(width: 64),
              navItem(
                Icons.shopping_bag_outlined,
                "Order",
                pageIndex == 2,
                onTap: () => onTap(2),
              ),
              navItem(
                Icons.tab_rounded,
                "Coupon",
                pageIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget navItem(
    IconData icon,
    String content,
    bool selected, {
    Function()? onTap,
  }) {
    return Expanded(
      child: Container(
        color: AppColor.primaryColor,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.white.withOpacity(0.4),
              ),
              Text(
                content,
                style: TextStyle(
                  color:
                      selected ? Colors.white : Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

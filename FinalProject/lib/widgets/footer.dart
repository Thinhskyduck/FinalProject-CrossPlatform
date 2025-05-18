import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color themeBluePrimary = Color(0xFF007BFF);
const Color cpsTextBlack = Color(0xFF222222);
const Color cpsTextGrey = Color(0xFF4A4A4A);
const Color cpsSubtleTextGrey = Color(0xFF757575);

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Container(
      color: Colors.grey[50],
      padding: EdgeInsets.symmetric(
        vertical: 40.0,
        horizontal: isWeb ? MediaQuery.of(context).size.width * 0.1 : 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoColumns(context, isWeb),
          const SizedBox(height: 40),
          _buildNewsletterSubscription(context, isWeb),
          const SizedBox(height: 40),
          const Divider(color: Colors.grey, thickness: 0.5),
          const SizedBox(height: 20),
          _buildBottomLinks(context, isWeb),
          const SizedBox(height: 20),
          _buildCopyrightInfo(context),
        ],
      ),
    );
  }

  Widget _buildInfoColumns(BuildContext context, bool isWeb) {
    if (isWeb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: _buildSupportColumn(context)),
          Expanded(flex: 2, child: _buildPoliciesColumn(context)),
          Expanded(flex: 2, child: _buildServicesColumn(context)),
          Expanded(flex: 2, child: _buildConnectColumn(context)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupportColumn(context, isMobile: true),
          const SizedBox(height: 30),
          _buildPoliciesColumn(context, isMobile: true),
          const SizedBox(height: 30),
          _buildServicesColumn(context, isMobile: true),
          const SizedBox(height: 30),
          _buildConnectColumn(context, isMobile: true),
        ],
      );
    }
  }

  Widget _buildFooterTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.roboto(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: cpsTextBlack,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFooterLink(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Text(
          text,
          style: GoogleFonts.roboto(
            fontSize: 13.5,
            color: cpsTextGrey,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSupportColumn(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterTitle("Tổng đài hỗ trợ miễn phí"),
        const SizedBox(height: 12),
        _buildFooterLink("Mua hàng - bảo hành: 1800.2097 (7h30 - 22h00)"),
        _buildFooterLink("Khiếu nại: 1800.2063 (8h00 - 21h30)"),
        const SizedBox(height: 20),
        _buildFooterTitle("Phương thức thanh toán"),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          children: [
            _paymentIconPlaceholder("Apple Pay"),
            _paymentIconPlaceholder("VN Pay"),
            _paymentIconPlaceholder("Momo"),
            _paymentIconPlaceholder("OnePay"),
            _paymentIconPlaceholder("Kredivo"),
            _paymentIconPlaceholder("ZaloPay"),
          ],
        ),
        if (isMobile) const SizedBox(height: 20),
      ],
    );
  }

  Widget _paymentIconPlaceholder(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        name,
        style: GoogleFonts.roboto(
          fontSize: 11,
          color: cpsTextBlack,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPoliciesColumn(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterTitle("Thông tin và chính sách"),
        const SizedBox(height: 12),
        _buildFooterLink("Mua hàng và thanh toán Online"),
        _buildFooterLink("Mua hàng trả góp Online"),
        _buildFooterLink("Mua hàng trả góp bằng thẻ tín dụng"),
        _buildFooterLink("Chính sách giao hàng"),
        _buildFooterLink("Chính sách đổi trả"),
        _buildFooterLink("Tra điểm Smember"),
        _buildFooterLink("Xem ưu đãi Smember"),
        _buildFooterLink("Tra thông tin bảo hành"),
      ],
    );
  }

  Widget _buildServicesColumn(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterTitle("Dịch vụ và thông tin khác"),
        const SizedBox(height: 12),
        _buildFooterLink("Khách hàng doanh nghiệp (B2B)"),
        _buildFooterLink("Ưu đãi thanh toán"),
        _buildFooterLink("Quy chế hoạt động"),
        _buildFooterLink("Chính sách bảo mật thông tin cá nhân"),
        _buildFooterLink("Chính sách Bảo hành"),
        _buildFooterLink("Liên hệ hợp tác kinh doanh"),
        _buildFooterLink("Tuyển dụng"),
      ],
    );
  }

  Widget _buildConnectColumn(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFooterTitle("Kết nối với BlueStore"),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _socialIcon(Icons.play_circle_fill, Colors.red, "YouTube"),
            _socialIcon(Icons.facebook, Colors.blue.shade800, "Facebook"),
            _socialIcon(Icons.camera_alt, Colors.pink, "Instagram"),
            _socialIcon(Icons.music_note, Colors.black, "TikTok"),
          ],
        ),
        const SizedBox(height: 20),
        _buildFooterTitle("Website thành viên"),
        const SizedBox(height: 12),
        _memberSitePlaceholder("dienthoaivui.com.vn"),
        _memberSitePlaceholder("careS (Apple Authorized)"),
        _memberSitePlaceholder("Schannel"),
        _memberSitePlaceholder("Sforum.vn"),
      ],
    );
  }

  Widget _socialIcon(IconData icon, Color color, String platform) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  Widget _memberSitePlaceholder(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          minimumSize: const Size(50, 20),
        ),
        onPressed: () {},
        child: Text(
          name,
          style: GoogleFonts.roboto(
            fontSize: 13.5,
            color: themeBluePrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _appStoreButtonPlaceholder(String storeName) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            storeName == "Google Play" ? Icons.shop_2_outlined : Icons.apple,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            storeName,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsletterSubscription(BuildContext context, bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Flex(
        direction: isWeb ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: isWeb ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: isWeb ? 2 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ĐĂNG KÝ NHẬN TIN KHUYẾN MÃI",
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeBluePrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Nhận ngay voucher 10%. Voucher sẽ được gửi sau 24h, chỉ áp dụng cho khách hàng mới.",
                  style: GoogleFonts.roboto(fontSize: 13, color: cpsSubtleTextGrey, height: 1.5),
                ),
                if (!isWeb) const SizedBox(height: 16),
              ],
            ),
          ),
          SizedBox(width: isWeb ? 24 : 0, height: isWeb ? 0 : 12),
          Expanded(
            flex: isWeb ? 3 : 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Nhập email của bạn",
                    hintStyle: GoogleFonts.roboto(fontSize: 14, color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: themeBluePrimary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: GoogleFonts.roboto(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Nhập số điện thoại",
                    hintStyle: GoogleFonts.roboto(fontSize: 14, color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: themeBluePrimary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: GoogleFonts.roboto(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (val) {},
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: themeBluePrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: Text(
                        "Tôi đồng ý với các điều khoản của BlueStore",
                        style: GoogleFonts.roboto(fontSize: 13, color: cpsTextGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeBluePrimary,
                    minimumSize: Size(isWeb ? 200 : double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    shadowColor: Colors.grey.withOpacity(0.3),
                  ),
                  child: Text(
                    "ĐĂNG KÝ NGAY",
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLinks(BuildContext context, bool isWeb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = constraints.maxWidth < 400 ? 11.0 : 12.0;
        final spacing = constraints.maxWidth < 400 ? 4.0 : (isWeb ? 10.0 : 6.0);
        List<String> links = [
          "Điện thoại iPhone 16 Pro",
          "Điện thoại iPhone 16 Pro Max",
          "Điện thoại iPhone 15",
          "Điện thoại iPhone 15 Pro Max",
          "Điện thoại Samsung",
          "Điện thoại OPPO",
          "Điện thoại Xiaomi",
          "Laptop",
          "Laptop Acer",
          "Laptop Dell",
          "Laptop HP",
          "Tivi",
          "Tivi Samsung",
          "Tivi Sony",
          "Tivi LG",
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: 8.0,
          alignment: WrapAlignment.start,
          children: links.map((link) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                    child: Text(
                      link,
                      style: GoogleFonts.roboto(
                        fontSize: fontSize,
                        color: cpsSubtleTextGrey,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                if (link != links.last)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      "|",
                      style: GoogleFonts.roboto(fontSize: fontSize, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCopyrightInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Công ty TNHH Thương Mại và Dịch Vụ Kỹ Thuật BLUE STORE - GPĐKKD: 0316172372 cấp tại Sở KH & ĐT TP. HCM. Địa chỉ văn phòng: 350-352 Võ Văn Kiệt, Phường Cô Giang, Quận 1, Thành phố Hồ Chí Minh, Việt Nam. Điện thoại: 028.7108.9666.",
          style: GoogleFonts.roboto(
            fontSize: 12,
            color: cpsSubtleTextGrey,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              height: 32,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                "Bộ Công Thương",
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 32,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                "DMCA",
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
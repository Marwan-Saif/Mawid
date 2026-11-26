package com.mawid.invoice;

import com.mawid.place.Place;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/**
 * The printable invoice: one self-contained HTML page in two sizes, A4 and an 80 mm receipt,
 * in Arabic (RTL) or English. The QR points back to this same page, so anyone can scan a
 * printed copy and check it's genuine and current (a voided invoice shows VOID).
 */
public final class InvoiceHtml {

    private InvoiceHtml() {
    }

    public enum Size { A4, RECEIPT }

    public static String render(Invoice inv, Place place, boolean arabic, Size size, boolean autoPrint,
                                String pageUrl) {
        T t = arabic ? T.AR : T.EN;
        String dir = arabic ? "rtl" : "ltr";
        String cur = currency(inv.getCurrency(), arabic);
        DateTimeFormatter when = DateTimeFormatter.ofPattern("yyyy-MM-dd  HH:mm", Locale.ENGLISH)
                .withZone(place.zone());
        boolean receipt = size == Size.RECEIPT;

        StringBuilder rows = new StringBuilder();
        for (InvoiceLine l : inv.getLines()) {
            rows.append("<tr><td>").append(esc(l.getDescription())).append("</td><td class=n>")
                    .append(l.getQty()).append("</td><td class=n>").append(money(l.getUnitPrice()))
                    .append("</td><td class=n>").append(money(l.amount())).append("</td></tr>");
        }

        String stamp = switch (inv.getStatus()) {
            case PAID -> "<div class='stamp paid'>" + t.paid + (inv.getPaymentMethod() == null ? ""
                    : " · " + t.method(inv.getPaymentMethod())) + "</div>";
            case VOID -> "<div class='stamp void'>" + t.voided + "</div>";
            case ISSUED -> "<div class='stamp due'>" + t.due + "</div>";
        };
        String placeName = arabic ? place.getNameAr() : place.getNameEn();
        String area = arabic ? place.getAreaAr() : place.getAreaEn();
        String qr = QrSvg.of(pageUrl, receipt ? 120 : 110);
        String otherLang = arabic ? "en" : "ar";
        String otherSize = receipt ? "a4" : "receipt";

        return "<!doctype html><html lang='" + (arabic ? "ar" : "en") + "' dir='" + dir + "'><head>"
                + "<meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
                + "<title>" + t.invoice + " #" + inv.getNumber() + " · " + esc(placeName) + "</title>"
                + "<style>" + css(receipt) + "</style></head><body>"
                + "<nav class='tools'>"
                + "<button onclick='window.print()'>" + t.print + "</button>"
                + "<a href='?size=" + otherSize + "&lang=" + (arabic ? "ar" : "en") + "'>"
                + (receipt ? t.a4 : t.receipt) + "</a>"
                + "<a href='?size=" + (receipt ? "receipt" : "a4") + "&lang=" + otherLang + "'>"
                + (arabic ? "English" : "العربية") + "</a></nav>"
                + "<main class='sheet'>"
                + "<header><div><h1>" + esc(placeName) + "</h1><p>" + esc(nz(area))
                + (place.getPhone() == null ? "" : " · <bdi>" + esc(place.getPhone()) + "</bdi>") + "</p></div>"
                + "<div class='no'><span>" + t.invoice + "</span><strong>#" + inv.getNumber() + "</strong></div></header>"
                + "<section class='meta'>"
                + item(t.date, "<bdi>" + when.format(inv.getCreatedAt()) + "</bdi>")
                + item(t.customer, esc(inv.getCustomerName()))
                + (inv.getStaffName() == null ? "" : item(t.doctor, esc(inv.getStaffName())))
                + (inv.getCustomerPhone() == null ? "" : item(t.phone, "<bdi>" + esc(inv.getCustomerPhone()) + "</bdi>"))
                + "</section>"
                + "<table><thead><tr><th>" + t.item + "</th><th class=n>" + t.qty + "</th><th class=n>"
                + t.price + "</th><th class=n>" + t.amount + "</th></tr></thead><tbody>" + rows + "</tbody></table>"
                + "<section class='totals'>"
                + line(t.subtotal, money(inv.getSubtotal()) + " " + cur, false)
                + (inv.getDiscount().signum() == 0 ? "" : line(t.discount, "−" + money(inv.getDiscount()) + " " + cur, false))
                + line(t.total, money(inv.getTotal()) + " " + cur, true)
                + "</section>"
                + stamp
                + (inv.getStatus() == InvoiceStatus.VOID && inv.getVoidReason() != null
                    ? "<p class='reason'>" + esc(inv.getVoidReason()) + "</p>" : "")
                + "<footer><div class='qr'>" + qr + "</div><div><p>" + t.scan + "</p>"
                + (inv.getUpdatedAt() == null ? "" : "<p class='muted'>" + t.edited + " <bdi>"
                    + when.format(inv.getUpdatedAt()) + "</bdi></p>")
                + "<p class='muted'>" + t.thanks + "</p></div></footer>"
                + "</main>"
                + (autoPrint ? "<script>addEventListener('load',()=>setTimeout(()=>print(),300))</script>" : "")
                + "</body></html>";
    }

    private static String css(boolean receipt) {
        String base = ":root{--ink:#0f172a;--muted:#475569;--line:#d6e6f0;--brand:#0369a1;--ok:#047857;--bad:#b91c1c;--warn:#b45309}"
                + "*{box-sizing:border-box}body{margin:0;background:#eef4f8;color:var(--ink);"
                + "font-family:'Segoe UI',Tahoma,'Noto Sans Arabic',Arial,sans-serif}"
                + ".tools{display:flex;gap:8px;justify-content:center;padding:12px;flex-wrap:wrap}"
                + ".tools button,.tools a{font:inherit;font-size:14px;padding:10px 16px;border-radius:999px;"
                + "border:1px solid var(--line);background:#fff;color:var(--ink);text-decoration:none;cursor:pointer}"
                + ".tools button{background:var(--brand);color:#fff;border-color:var(--brand)}"
                + ".sheet{background:#fff;margin:0 auto 24px;position:relative}"
                + "header{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;"
                + "border-bottom:2px solid var(--brand);padding-bottom:10px}"
                + "h1{margin:0;font-size:1.35em;color:var(--brand)}header p{margin:4px 0 0;color:var(--muted)}"
                + ".no{text-align:end}.no span{display:block;color:var(--muted);font-size:.85em}.no strong{font-size:1.4em}"
                + ".meta{display:grid;grid-template-columns:1fr 1fr;gap:6px 16px;margin:12px 0}"
                + ".meta div span{display:block;color:var(--muted);font-size:.8em}"
                + "table{width:100%;border-collapse:collapse;margin-top:6px}"
                + "th{text-align:start;color:var(--muted);font-weight:600;font-size:.8em;border-bottom:1px solid var(--line);padding:6px 4px}"
                + "td{padding:7px 4px;border-bottom:1px dashed var(--line)}.n{text-align:end;white-space:nowrap}"
                + ".totals{margin-top:10px;margin-inline-start:auto;max-width:280px}"
                + ".totals div{display:flex;justify-content:space-between;padding:4px 0}"
                + ".totals .grand{border-top:2px solid var(--ink);font-size:1.25em;font-weight:700;margin-top:4px;padding-top:8px}"
                + ".stamp{display:inline-block;margin-top:12px;padding:6px 14px;border:2px solid;border-radius:8px;font-weight:700}"
                + ".paid{color:var(--ok)}.void{color:var(--bad)}.due{color:var(--warn)}"
                + ".reason{color:var(--bad);margin:6px 0 0}"
                + "footer{display:flex;gap:14px;align-items:center;margin-top:16px;border-top:1px solid var(--line);padding-top:12px}"
                + "footer p{margin:2px 0}.muted{color:var(--muted);font-size:.85em}"
                + "@media print{body{background:#fff}.tools{display:none}.sheet{margin:0;box-shadow:none}}";
        if (receipt) {
            return base + ".sheet{width:80mm;padding:4mm;font-size:12px}.meta{grid-template-columns:1fr}"
                    + "header{flex-direction:column}.no{text-align:start}.totals{max-width:none}"
                    + "footer{flex-direction:column;text-align:center}"
                    + "@page{size:80mm auto;margin:0}";
        }
        return base + ".sheet{width:210mm;min-height:297mm;padding:18mm;font-size:15px;box-shadow:0 1px 8px #0002}"
                + "@page{size:A4;margin:0}"
                + "@media (max-width:820px){.sheet{width:auto;min-height:0;padding:20px;margin:0 12px 24px}}";
    }

    private static String item(String label, String value) {
        return "<div><span>" + label + "</span>" + value + "</div>";
    }

    private static String line(String label, String value, boolean grand) {
        return "<div" + (grand ? " class='grand'" : "") + "><span>" + label + "</span><bdi>" + value + "</bdi></div>";
    }

    static String money(BigDecimal v) {
        return v.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    static String currency(String code, boolean arabic) {
        if (!arabic) {
            return code;
        }
        return switch (code) {
            case "AED" -> "د.إ";
            case "EGP" -> "ج.م";
            case "JOD" -> "د.أ";
            case "SAR" -> "ر.س";
            case "KWD" -> "د.ك";
            default -> code;
        };
    }

    static String esc(String s) {
        if (s == null) {
            return "";
        }
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    /** UI words for the printout. */
    private enum T {
        AR("فاتورة", "التاريخ", "العميل", "الدكتور / المختص", "الموبايل", "البند", "الكمية", "السعر", "المبلغ",
                "المجموع الفرعي", "الخصم", "الإجمالي", "مدفوعة", "ملغاة", "غير مدفوعة", "طباعة", "مقاس A4",
                "إيصال ٨٠ مم", "امسح الكود للتأكد من الفاتورة", "اتعدّلت", "شكرًا لزيارتكم", "كاش", "كارت", "تحويل"),
        EN("Invoice", "Date", "Customer", "Doctor / specialist", "Phone", "Item", "Qty", "Price", "Amount",
                "Subtotal", "Discount", "Total", "Paid", "Void", "Not paid", "Print", "A4 size",
                "80 mm receipt", "Scan to verify this invoice", "Edited", "Thank you for your visit", "cash", "card",
                "transfer");

        final String invoice, date, customer, doctor, phone, item, qty, price, amount, subtotal, discount, total,
                paid, voided, due, print, a4, receipt, scan, edited, thanks, cash, card, transfer;

        T(String invoice, String date, String customer, String doctor, String phone, String item, String qty,
          String price, String amount, String subtotal, String discount, String total, String paid, String voided,
          String due, String print, String a4, String receipt, String scan, String edited, String thanks,
          String cash, String card, String transfer) {
            this.invoice = invoice;
            this.date = date;
            this.customer = customer;
            this.doctor = doctor;
            this.phone = phone;
            this.item = item;
            this.qty = qty;
            this.price = price;
            this.amount = amount;
            this.subtotal = subtotal;
            this.discount = discount;
            this.total = total;
            this.paid = paid;
            this.voided = voided;
            this.due = due;
            this.print = print;
            this.a4 = a4;
            this.receipt = receipt;
            this.scan = scan;
            this.edited = edited;
            this.thanks = thanks;
            this.cash = cash;
            this.card = card;
            this.transfer = transfer;
        }

        String method(PaymentMethod m) {
            return switch (m) {
                case CASH -> cash;
                case CARD -> card;
                case TRANSFER -> transfer;
            };
        }
    }
}

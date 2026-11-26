package com.mawid.invoice;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.math.BigDecimal;

/** "Blood pressure check × 1 @ 5.00". serviceId is set when the line came from the service list. */
@Embeddable
public class InvoiceLine {

    @Column(nullable = false, length = 120)
    private String description;

    @Column(nullable = false)
    private int qty;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal unitPrice;

    private Long serviceId;

    protected InvoiceLine() {
    }

    public InvoiceLine(String description, int qty, BigDecimal unitPrice, Long serviceId) {
        this.description = description;
        this.qty = qty;
        this.unitPrice = unitPrice;
        this.serviceId = serviceId;
    }

    public BigDecimal amount() {
        return unitPrice.multiply(BigDecimal.valueOf(qty));
    }

    public String getDescription() { return description; }
    public int getQty() { return qty; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public Long getServiceId() { return serviceId; }
}

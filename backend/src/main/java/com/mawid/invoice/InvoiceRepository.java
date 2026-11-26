package com.mawid.invoice;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface InvoiceRepository extends JpaRepository<Invoice, Long> {

    List<Invoice> findByPlaceIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByNumberDesc(
            Long placeId, Instant from, Instant to);

    List<Invoice> findByBookingIdInAndStatusNot(Collection<Long> bookingIds, InvoiceStatus status);

    Optional<Invoice> findByPlaceIdAndClientRef(Long placeId, String clientRef);

    Optional<Invoice> findByPublicToken(String publicToken);
}

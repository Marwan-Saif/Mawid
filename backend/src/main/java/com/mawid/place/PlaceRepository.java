package com.mawid.place;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PlaceRepository extends JpaRepository<Place, Long> {

    Optional<Place> findBySlug(String slug);

    List<Place> findAllByOrderByDistanceKmAsc();

    /**
     * SELECT ... FOR UPDATE on the place row. Serializes the two per-place counters (ticket numbers
     * and invoice numbers) so two reception devices can't hand out the same number.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Place p where p.id = :id")
    Optional<Place> lockById(@Param("id") Long id);
}

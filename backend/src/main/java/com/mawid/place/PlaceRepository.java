package com.mawid.place;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PlaceRepository extends JpaRepository<Place, Long> {

    Optional<Place> findBySlug(String slug);

    List<Place> findAllByOrderByDistanceKmAsc();
}

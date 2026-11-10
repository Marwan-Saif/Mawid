package com.mawid.place;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReviewRepository extends JpaRepository<Review, Long> {

    List<Review> findByPlaceIdOrderByCreatedAtDesc(Long placeId);
}

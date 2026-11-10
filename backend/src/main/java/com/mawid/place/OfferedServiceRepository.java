package com.mawid.place;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OfferedServiceRepository extends JpaRepository<OfferedService, Long> {

    List<OfferedService> findByPlaceIdOrderByIdAsc(Long placeId);

    List<OfferedService> findByPlaceIdAndActiveTrueOrderByIdAsc(Long placeId);
}

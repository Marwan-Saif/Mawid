package com.mawid;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MawidApplication {

    public static void main(String[] args) {
        SpringApplication.run(MawidApplication.class, args);
    }
}

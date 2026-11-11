package com.mawid.auth;

import java.time.Clock;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(AuthProperties.class)
public class AuthConfig {

    @Bean
    public TokenService tokenService(AuthProperties props, Clock clock) {
        return new TokenService(props.tokenSecret(), props.tokenTtl(), clock);
    }
}

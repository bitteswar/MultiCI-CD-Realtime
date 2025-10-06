package com.example.sampleapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Main entry point for the MultiCI-CD-Realtime Spring Boot application.
 * It will automatically scan all subpackages (e.g. controller, service, etc.)
 */
@SpringBootApplication
public class SampleAppApplication {

    public static void main(String[] args) {
        SpringApplication.run(SampleAppApplication.class, args);
    }
}

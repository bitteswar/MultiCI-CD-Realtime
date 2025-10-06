package com.example.sampleapp;

import com.example.sampleapp.controller.HelloController;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class HelloControllerTest {

    @Test
    void helloShouldReturnExpectedString() {
        HelloController c = new HelloController();
        assertEquals("Hello from sample-app v1", c.hello());
    }
}

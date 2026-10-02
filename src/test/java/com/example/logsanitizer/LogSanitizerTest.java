package com.example.logsanitizer;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class LogSanitizerTest {

    @Test
    void shouldMaskPassword() {
        String input = "password=secret123";

        assertEquals(
                "password=****",
                LogSanitizer.sanitize(input));
    }

    @Test
    void shouldMaskToken() {
        String input = "token=ABC123";

        assertEquals(
                "token=****",
                LogSanitizer.sanitize(input));
    }

    @Test
    void shouldMaskEmail() {
        String input = "User=john@example.com";

        assertEquals(
                "User=j***@example.com",
                LogSanitizer.sanitize(input));
    }

    @Test
    void shouldMaskMultipleValues() {
        String input =
                "User=john@example.com password=secret123 token=ABC123";

        assertEquals(
                "User=j***@example.com password=**** token=****",
                LogSanitizer.sanitize(input));
    }
}
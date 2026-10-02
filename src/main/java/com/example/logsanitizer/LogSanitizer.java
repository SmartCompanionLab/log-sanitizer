package com.example.logsanitizer;

import java.util.regex.Pattern;

public final class LogSanitizer {

    private static final Pattern EMAIL =
            Pattern.compile(
                    "([A-Za-z0-9._%+-])([A-Za-z0-9._%+-]*)(@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})");

    private static final Pattern PASSWORD =
            Pattern.compile(
                    "(?i)(password\\s*[=:]\\s*)[^\\s,;]+");

    private static final Pattern TOKEN =
            Pattern.compile(
                    "(?i)(token\\s*[=:]\\s*)[^\\s,;]+");

    private LogSanitizer() {
    }

    public static String sanitize(String input) {
        if (input == null) {
            return null;
        }

        String result = PASSWORD.matcher(input)
                .replaceAll("$1****");

        result = TOKEN.matcher(result)
                .replaceAll("$1****");

        result = EMAIL.matcher(result)
                .replaceAll("$1***$3");

        return result;
    }
}
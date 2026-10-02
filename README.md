# Log Sanitizer

A small Java utility for masking sensitive information in application logs.

## Example

```java
String input =
    "User=john@example.com password=secret123 token=ABC123";

String result = LogSanitizer.sanitize(input);
```

Result:

```
User=j***@example.com password=**** token=****
```

## Maven

```xml
<dependency>
    <groupId>io.github.YOUR_GITHUB_USERNAME</groupId>
    <artifactId>log-sanitizer</artifactId>
    <version>1.0.0</version>
</dependency>
```

## License

MIT
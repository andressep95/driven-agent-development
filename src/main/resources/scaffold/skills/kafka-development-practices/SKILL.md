---
name: kafka-development-practices
description: >
  Applies Kafka best practices for JVM backends written in Java.
  Framework-agnostic: works with plain kafka-clients, Quarkus SmallRye,
  Spring Kafka, or Micronaut Kafka without any changes to the core rules.
  Trigger: When producing, consuming, or processing Kafka events in Java.
metadata:
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "Implement Kafka producer in Java"
    - "Implement Kafka consumer in Java"
    - "Add Kafka Streams topology"
    - "Configure Kafka client"
    - "Handle Kafka message serialization"
    - "Dead letter queue Kafka"
    - "Kafka error handling Java"
    - "Test Kafka topology"
tags: [kafka, streaming, messaging, events, distributed, java, jvm]
allowed-tools: Read, Write, Edit, Bash
globs: "**/*.java"
---

# Kafka Development Practices — Java

## Iron Laws

1. **ALWAYS** set `acks=all` + `min.insync.replicas=2` for production producers.
   Default `acks=1` loses messages on leader failure before replication completes.

2. **NEVER** commit offsets before processing is complete.
   Commit after durable write; use transactions for exactly-once semantics.

3. **ALWAYS** implement idempotent consumers (deduplicate by key or sequence).
   Kafka guarantees at-least-once — duplicates on restart are normal, not bugs.

4. **NEVER** set `auto.offset.reset=earliest` on existing topics in production.
   Replays the entire topic history on first start; use `latest` for new groups.

5. **ALWAYS** set `max.poll.interval.ms` larger than worst-case processing time.
   Exceeding the interval evicts the consumer, triggering rebalance + duplicates.

6. **ALWAYS** close producers and consumers in a finally block or shutdown hook.
   Unclosed producers may lose buffered messages; consumers leak group membership.

## Producer — Canonical Pattern

```java
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,   StringSerializer.class.getName());
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
// Durability
props.put(ProducerConfig.ACKS_CONFIG,                "all");
props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG,  "true");   // deduplicates retries
props.put(ProducerConfig.RETRIES_CONFIG,             "3");
props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, "1");
// Performance
props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "snappy");
props.put(ProducerConfig.LINGER_MS_CONFIG,        "5");
props.put(ProducerConfig.BATCH_SIZE_CONFIG,       String.valueOf(16 * 1024));

try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
    ProducerRecord<String, String> record = new ProducerRecord<>("my-topic", key, value);
    producer.send(record, (metadata, ex) -> {
        if (ex != null) log.error("Send failed topic={} partition={}", metadata.topic(), metadata.partition(), ex);
    });
    producer.flush(); // ensure buffered messages are sent before close
}
```

## Consumer — Canonical Pattern

```java
Properties props = new Properties();
props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG,  "localhost:9092");
props.put(ConsumerConfig.GROUP_ID_CONFIG,            "my-group");
props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,   StringDeserializer.class.getName());
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG,        "latest");   // Iron Law #4
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG,       "false");    // Iron Law #2
props.put(ConsumerConfig.MAX_POLL_INTERVAL_MS_CONFIG,     "300000");   // tune per workload
props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG,         "500");

KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
Runtime.getRuntime().addShutdownHook(new Thread(consumer::wakeup)); // Iron Law #6

try {
    consumer.subscribe(List.of("my-topic"));
    while (true) {
        ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
        for (ConsumerRecord<String, String> record : records) {
            process(record);           // process first
        }
        consumer.commitSync();         // commit after Iron Law #2
    }
} catch (WakeupException ignored) {
    // shutdown requested
} finally {
    consumer.close();
}
```

## Serialization (framework-agnostic)

Prefer Avro + Schema Registry for schema evolution. Fall back to JSON (Jackson)
for internal/dev topics. Never use Java object serialization.

```java
// JSON — Jackson
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
String json = objectMapper.writeValueAsString(event);

// Avro — Confluent Schema Registry
props.put("schema.registry.url", "http://localhost:8081");
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
// value must be a GenericRecord or a SpecificRecord generated by avro-tools
```

## Dead Letter Queue (DLQ) Pattern

```java
for (ConsumerRecord<String, String> record : records) {
    try {
        process(record);
    } catch (NonRetriableException e) {
        dlqProducer.send(new ProducerRecord<>("my-topic.DLQ", record.key(), record.value()));
        log.error("Sent to DLQ key={} offset={}", record.key(), record.offset(), e);
    } catch (RetriableException e) {
        // back off and retry — do NOT commit this batch
        Thread.sleep(retryBackoffMs);
        break;
    }
}
```

## Kafka Streams — Topology Pattern

```java
StreamsBuilder builder = new StreamsBuilder();

KStream<String, Order> orders = builder.stream("orders",
    Consumed.with(Serdes.String(), orderSerde));

orders
    .filter((key, order) -> order.getAmount() > 0)
    .mapValues(order -> enrich(order))
    .to("orders.enriched", Produced.with(Serdes.String(), enrichedOrderSerde));

Properties streamsConfig = new Properties();
streamsConfig.put(StreamsConfig.APPLICATION_ID_CONFIG,    "order-enricher");
streamsConfig.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
streamsConfig.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG,   Serdes.String().getClass());
streamsConfig.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());
streamsConfig.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);

KafkaStreams streams = new KafkaStreams(builder.build(), streamsConfig);
Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
streams.start();
```

## Testing

```java
// Unit — TopologyTestDriver (no broker needed, same API as production)
@Test
void shouldEnrichOrder() {
    Properties config = new Properties();
    config.put(StreamsConfig.APPLICATION_ID_CONFIG,    "test");
    config.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "dummy:9092");

    try (TopologyTestDriver driver = new TopologyTestDriver(buildTopology(), config)) {
        TestInputTopic<String, Order> input = driver.createInputTopic(
            "orders", new StringSerializer(), orderSerializer);
        TestOutputTopic<String, EnrichedOrder> output = driver.createOutputTopic(
            "orders.enriched", new StringDeserializer(), enrichedDeserializer);

        input.pipeInput("k1", new Order("k1", 100));
        assertThat(output.readValue().getStatus()).isEqualTo("enriched");
    }
}

// Integration — TestContainers (real broker)
@Container
static KafkaContainer kafka = new KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.6"));
```

## Anti-Patterns

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| `acks=1` for critical data | Leader failure before replication = message loss | `acks=all` + `min.insync.replicas=2` + idempotent producer |
| Commit before processing | Crash after commit = silent message drop | Process → commit; use transactions for exactly-once |
| Non-idempotent consumer | Rebalance delivers duplicates; state corrupted | Deduplicate by key; upsert not insert in DB |
| `auto.offset.reset=earliest` on existing topics | Replays entire history on first boot | Use `latest` for new groups; `earliest` only for replay |
| Default `max.poll.interval.ms` with slow processing | Consumer evicted mid-batch → rebalance + duplicates | Tune interval > worst-case time; reduce batch size |
| `objectMapper.readValue` without try-catch in consumer | Poison pill crashes consumer loop | Deserialize in try-catch; route bad messages to DLQ |
| Hardcoded topic names | Topics vary per environment | Externalize via env vars or config file |
| `close()` only on happy path | Leaked connections on exception | Always close in finally or use try-with-resources |

## Configuration — Externalize Everything

```java
// Read from environment variables (works with Docker, K8s, Quarkus, Spring, plain Java)
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG,
    System.getenv().getOrDefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"));
String topic = System.getenv().getOrDefault("KAFKA_TOPIC_ORDERS", "orders");
```

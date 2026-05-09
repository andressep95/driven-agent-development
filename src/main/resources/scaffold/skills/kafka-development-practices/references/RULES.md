# Kafka Development Practices — Java Rules

## Scope

Framework-agnostic Java rules. Apply the same regardless of whether the project
uses plain `kafka-clients`, Quarkus SmallRye Reactive Messaging, Spring Kafka,
or Micronaut Kafka. The Kafka client API is identical underneath.

## Mandatory Configs

### Producer (non-negotiable in production)
- `acks=all` — waits for all in-sync replicas to acknowledge
- `enable.idempotence=true` — deduplicates retries at the broker level
- `max.in.flight.requests.per.connection=1` — required with idempotence + ordering
- `compression.type=snappy` — reduces network and storage cost, minimal CPU overhead

### Consumer (non-negotiable in production)
- `enable.auto.commit=false` — manual commit after processing
- `auto.offset.reset=latest` — for new groups on existing topics
- `max.poll.interval.ms` — must exceed worst-case processing time per batch

## Code Rules

1. Always close `KafkaProducer` and `KafkaConsumer` in `finally` or via shutdown hook.
2. Catch `WakeupException` in the consumer loop as the clean shutdown signal.
3. Deserialize inside try-catch; route unparseable messages to a `.DLQ` topic.
4. Deduplicate by message key before writing to state stores or databases.
5. Never use Java object serialization (`Serializable`) for Kafka values.
6. Externalize all topic names and broker addresses via environment variables.
7. Use `TopologyTestDriver` for unit tests; TestContainers for integration tests.
8. For Kafka Streams: set `processing.guarantee=exactly_once_v2` in production.

## See SKILL.md for complete documentation and code examples.

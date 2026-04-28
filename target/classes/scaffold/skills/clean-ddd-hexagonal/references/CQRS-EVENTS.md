# CQRS & Domain Events

> Sources:
> - [CQRS](https://martinfowler.com/bliki/CQRS.html) — Martin Fowler
> - [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) — Martin Fowler
> - [Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html) — microservices.io
> - [Domain Events – Salvation](https://udidahan.com/2009/06/14/domain-events-salvation/) — Udi Dahan

## CQRS Overview

**Command Query Responsibility Segregation** separates read and write operations into different models.

```
API Layer
├── Commands → Command Handler → Domain Model → Write DB
└── Queries  → Query Handler  → Read DB (optimized)

Write DB --[Domain Events]--> Event Handler --> Updates Read DB
```

---

## Commands vs Queries

### Commands (Write Side) — mutate data

```typescript
export interface PlaceOrderCommand {
  type: 'PlaceOrder';
  customerId: string;
  items: Array<{ productId: string; quantity: number }>;
}

export class PlaceOrderHandler {
  async handle(command: PlaceOrderCommand): Promise<OrderId> {
    const order = Order.create(CustomerId.from(command.customerId));
    for (const item of command.items) {
      const product = await this.productRepo.findById(item.productId);
      order.addItem(product.id, item.quantity, product.price);
    }
    await this.orderRepo.save(order);
    await this.eventPublisher.publishAll(order.domainEvents);
    return order.id;
  }
}
```

### Queries (Read Side) — never mutate state

```typescript
export class GetOrderHandler {
  constructor(private readonly readDb: IOrderReadModel) {}

  async handle(query: GetOrderQuery): Promise<OrderDTO | null> {
    return this.readDb.findById(query.orderId);
  }
}
```

---

## Domain Events

### Event Structure

```typescript
export abstract class DomainEvent {
  readonly eventId: string;
  readonly occurredAt: Date;
  readonly aggregateId: string;
  abstract readonly eventType: string;

  constructor(aggregateId: string) {
    this.eventId = crypto.randomUUID();
    this.occurredAt = new Date();
    this.aggregateId = aggregateId;
  }

  abstract toPayload(): Record<string, unknown>;
}

export class OrderConfirmed extends DomainEvent {
  readonly eventType = 'order.confirmed';

  constructor(
    readonly orderId: OrderId,
    readonly total: Money,
    readonly items: ReadonlyArray<{ productId: string; quantity: number }>,
  ) {
    super(orderId.value);
  }

  toPayload() {
    return {
      orderId: this.orderId.value,
      total: { amount: this.total.amount, currency: this.total.currency },
      items: this.items,
    };
  }
}
```

---

## Domain Events vs Integration Events

### Domain Events
- Stay within bounded context
- Fine-grained, named in domain language
- Trigger internal processes

### Integration Events
- Cross bounded context boundaries
- Coarser-grained, versioned schema
- Published to message broker

```typescript
interface OrderConfirmedIntegrationEvent {
  eventType: 'sales.order.confirmed';
  eventId: string;
  version: '1.0';
  occurredAt: string;
  payload: {
    orderId: string;
    customerId: string;
    total: { amount: number; currency: string };
  };
}
```

---

## Event Dispatcher Pattern

```typescript
export class EventDispatcher {
  private handlers: Map<string, IEventHandler<any>[]> = new Map();

  register<T extends DomainEvent>(eventType: string, handler: IEventHandler<T>): void {
    const existing = this.handlers.get(eventType) ?? [];
    existing.push(handler);
    this.handlers.set(eventType, existing);
  }

  async dispatch(event: DomainEvent): Promise<void> {
    const handlers = this.handlers.get(event.eventType) ?? [];
    await Promise.all(handlers.map(h => h.handle(event)));
  }
}
```

---

## Outbox Pattern

Ensures events are published reliably (exactly-once semantics).

```
class PlaceOrderHandler:
    handle(command) -> OrderId:
        order = Order.create(...)
        db.transaction((tx) => {
            orderRepo.save(order, tx)
            for event in order.domainEvents:
                outbox.save(event, tx)     # atomic with the write
        })
        return order.id

class OutboxProcessor:
    process():
        messages = outbox.getUnprocessed()
        for message in messages:
            messageBroker.publish(message.eventType, message.payload)
            outbox.markProcessed(message.id)
```

---

## Idempotent Consumer Pattern

**Required for reliable event processing.** Messages may be delivered more than once.

```
class OrderConfirmedHandler:
    processedIds: Set<string>

    handle(event: OrderConfirmed):
        if event.eventId in processedIds:
            return
        doWork(event)
        processedIds.add(event.eventId)
```

---

## When to Use CQRS

> **Warning:** "You should be very cautious about using CQRS... the majority of cases I've run into have not been so good." — Martin Fowler

### Use When:
- Read and write workloads have dramatically different scaling requirements
- Event sourcing is used (CQRS pairs naturally with ES)
- You've proven simpler approaches are insufficient

### Skip When:
- Simple CRUD application (most applications)
- Small team, simple domain
- Adding it "just in case"

**CQRS applies to specific bounded contexts, never entire systems.**

### Start Simple

```typescript
class OrderService {
  async placeOrder(cmd: PlaceOrderCommand): Promise<OrderId> {
    const order = Order.create(...);
    await this.orderRepo.save(order);
    return order.id;
  }

  async getOrder(id: string): Promise<OrderDTO | null> {
    return this.readModel.findById(id);
  }
}
```

Evolve to separate databases only when needed.

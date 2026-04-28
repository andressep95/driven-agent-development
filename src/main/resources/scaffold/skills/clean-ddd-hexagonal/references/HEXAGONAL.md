# Hexagonal Architecture (Ports & Adapters)

> Sources:
> - [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/) — Alistair Cockburn (2005)
> - [Hexagonal Architecture Pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/hexagonal-architecture.html) — AWS

## Core Concept

> "Allow an application to equally be driven by users, programs, automated tests, or batch scripts, and to be developed and tested in isolation from its eventual run-time devices and databases." — Alistair Cockburn

**The hexagon is conceptual.** Most applications have 2-4 ports. The shape emphasizes that all external interactions go through ports, regardless of direction.

---

## Ports

### Driver Ports (Primary / Inbound)

Define **how the world uses your application**. Entry points, represent use cases.

```typescript
export interface IPlaceOrderPort {
  execute(command: PlaceOrderCommand): Promise<OrderId>;
}

export interface IGetOrderPort {
  execute(query: GetOrderQuery): Promise<OrderDTO | null>;
}
```

### Driven Ports (Secondary / Outbound)

Define **how your application uses external systems**. Application defines, adapters implement.

```typescript
export interface IOrderRepositoryPort {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
  delete(order: Order): Promise<void>;
}

export interface IEventPublisherPort {
  publish(event: DomainEvent): Promise<void>;
  publishAll(events: DomainEvent[]): Promise<void>;
}

export interface IPaymentGatewayPort {
  charge(amount: Money, paymentMethod: PaymentMethod): Promise<PaymentResult>;
  refund(paymentId: PaymentId, amount: Money): Promise<RefundResult>;
}
```

---

## Adapters

### Driver Adapters (Primary / Inbound)

Convert external inputs to port calls.

```typescript
export class OrderController {
  constructor(
    private readonly placeOrder: IPlaceOrderPort,
    private readonly getOrder: IGetOrderPort,
  ) {}

  async create(req: Request, res: Response): Promise<void> {
    const orderId = await this.placeOrder.execute({
      customerId: req.user.id,
      items: req.body.items.map((item: any) => ({
        productId: item.product_id,
        quantity: item.quantity,
      })),
    });
    res.status(201).json({ id: orderId.value });
  }
}
```

### Driven Adapters (Secondary / Outbound)

```
class PostgresOrderRepository implements IOrderRepositoryPort:
    findById(id: OrderId) -> Order | null:
        row = db.orders.where(id: id.value).first()
        if not row: return null
        return OrderMapper.toDomain(row)

    save(order: Order):
        data = OrderMapper.toPersistence(order)
        db.orders.upsert(data)

class InMemoryOrderRepository implements IOrderRepositoryPort:
    orders: Map<string, Order> = {}
    findById(id: OrderId) -> Order | null:
        return orders.get(id.value) or null
    save(order: Order):
        orders.set(order.id.value, order)
```

---

## Naming Conventions

### Alistair Cockburn's Recommended Pattern

**Ports:** `For[Doing][Something]`
- Driver: `ForPlacingOrders`, `ForConfiguringSettings`
- Driven: `ForStoringUsers`, `ForNotifyingAlerts`

### Alternative Patterns

| Pattern | Port | Adapter |
|---------|------|---------|
| Interface/Impl | `IOrderRepository` | `PostgresOrderRepository` |
| Port suffix | `OrderRepositoryPort` | `PostgresOrderAdapter` |

---

## Key Asymmetry

- **Driver side:** Application defines what it OFFERS (use case interfaces)
- **Driven side:** Application defines what it NEEDS (infrastructure interfaces)

---

## Strong vs Weak Hexagonal

```typescript
// ❌ Weak: Leaks SQL concepts
interface IOrderRepository {
  findByQuery(sql: string, params: any[]): Promise<Order[]>;
}

// ✅ Strong: Pure domain concepts
interface IOrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  save(order: Order): Promise<void>;
}
```

---

## Configurability via Adapters

```typescript
function configureProduction(container: Container): void {
  container.bind<IOrderRepositoryPort>('IOrderRepositoryPort').to(PostgresOrderRepository);
  container.bind<IEventPublisherPort>('IEventPublisherPort').to(RabbitMQEventPublisher);
  container.bind<IPaymentGatewayPort>('IPaymentGatewayPort').to(StripePaymentGateway);
}

function configureTest(container: Container): void {
  container.bind<IOrderRepositoryPort>('IOrderRepositoryPort').to(InMemoryOrderRepository);
  container.bind<IEventPublisherPort>('IEventPublisherPort').to(SpyEventPublisher);
  container.bind<IPaymentGatewayPort>('IPaymentGatewayPort').to(MockPaymentGateway);
}
```

---

## Benefits

1. **Testability** - Swap real adapters for test doubles
2. **Flexibility** - Change technologies without changing core
3. **Independence** - Develop core without external systems
4. **Clear boundaries** - Explicit interfaces between layers
5. **Parallel development** - Teams work on different adapters

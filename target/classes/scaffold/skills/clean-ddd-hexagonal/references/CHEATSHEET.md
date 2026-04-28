# Quick Reference Cheatsheet

> See [SKILL.md](../SKILL.md#sources) for full source list.

## Layer Summary

```
INFRASTRUCTURE (Adapters)
  REST/gRPC controllers, CLI handlers, Database repositories,
  Message publishers, External service clients

APPLICATION (Use Cases)
  Command/Query handlers, DTOs, Transaction management,
  Port interfaces, Application services, Event dispatching

DOMAIN (Business Logic)
  Entities, Aggregates, Repository interfaces, Business rules,
  Value Objects, Domain Events, Domain Services, Specifications
```

*Dependencies point inward: Infrastructure → Application → Domain*

---

## Quick Decision Trees

### "Where does this code go?"

```
Is it a business rule or constraint?
├── YES → Domain layer
└── NO ↓

Is it orchestrating a use case?
├── YES → Application layer
└── NO ↓

Is it dealing with external systems (DB, API, UI)?
├── YES → Infrastructure layer
└── NO → Reconsider; probably domain
```

### "Entity or Value Object?"

```
Does it have a unique identity that persists?
├── YES → Entity
└── NO ↓

Is it defined entirely by its attributes?
├── YES → Value Object
└── NO → Probably an Entity
```

### "Aggregate boundary?"

```
Must these objects change together atomically?
├── YES → Same aggregate
└── NO ↓

Can one exist without the other?
├── YES → Different aggregates (reference by ID)
└── NO → Probably same aggregate
```

### "Domain Service or Entity method?"

```
Does it naturally belong to one entity?
├── YES → Entity method
└── NO ↓

Does it require multiple aggregates?
├── YES → Domain Service
└── NO ↓

Is it stateless business logic?
├── YES → Domain Service
└── NO → Reconsider placement
```

---

## Common Patterns Quick Reference

### Value Object Template

```typescript
export class Money {
  private constructor(
    private readonly _amount: number,
    private readonly _currency: string,
  ) {}

  static create(amount: number, currency: string): Money {
    if (amount < 0) throw new Error('Negative');
    return new Money(amount, currency);
  }

  add(other: Money): Money {
    return Money.create(this._amount + other._amount, this._currency);
  }

  equals(other: Money): boolean {
    return this._amount === other._amount && this._currency === other._currency;
  }
}
```

### Aggregate Root Template

```typescript
export class Order extends AggregateRoot<OrderId> {
  private _items: OrderItem[] = [];
  private _status: OrderStatus;

  private constructor(id: OrderId, customerId: CustomerId) {
    super(id);
    this._customerId = customerId;
    this._status = OrderStatus.Draft;
  }

  static create(customerId: CustomerId): Order {
    const order = new Order(OrderId.generate(), customerId);
    order.addDomainEvent(new OrderCreated(order.id, customerId));
    return order;
  }

  addItem(productId: ProductId, quantity: Quantity, price: Money): void {
    this.assertCanModify();
    this._items.push(OrderItem.create(productId, quantity, price));
  }

  confirm(): void {
    this.assertCanModify();
    if (this._items.length === 0) throw new EmptyOrderError();
    this._status = OrderStatus.Confirmed;
    this.addDomainEvent(new OrderConfirmed(this.id, this.total));
  }

  private assertCanModify(): void {
    if (this._status === OrderStatus.Cancelled) {
      throw new InvalidOrderStateError('Order is cancelled');
    }
  }
}
```

### Use Case Handler Template

```typescript
export class PlaceOrderHandler {
  constructor(
    private readonly orderRepo: IOrderRepository,
    private readonly productRepo: IProductRepository,
    private readonly eventPublisher: IEventPublisher,
  ) {}

  async execute(command: PlaceOrderCommand): Promise<OrderId> {
    const order = Order.create(CustomerId.from(command.customerId));
    for (const item of command.items) {
      const product = await this.productRepo.findById(item.productId);
      order.addItem(product.id, Quantity.create(item.quantity), product.price);
    }
    await this.orderRepo.save(order);
    await this.eventPublisher.publishAll(order.domainEvents);
    return order.id;
  }
}
```

---

## Port Naming Conventions

| Type | Pattern | Examples |
|------|---------|----------|
| Driver Port | `I{Action}UseCase` | `IPlaceOrderUseCase`, `IGetOrderUseCase` |
| Driven Port | `I{Resource}Repository` | `IOrderRepository`, `IProductRepository` |
| Driven Port | `I{Action}Service` | `IPaymentService`, `INotificationService` |
| Driven Port | `I{Resource}Gateway` | `IPaymentGateway`, `IShippingGateway` |

---

## Common Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Anemic Domain | Entities are just data bags | Put behavior in entities |
| Repository per table | One repo per DB table | One repo per aggregate |
| Fat Use Cases | Business logic in handlers | Move to domain |
| Leaky Abstraction | Domain depends on ORM | Keep domain pure |
| God Aggregate | One massive aggregate | Split into smaller ones |
| Cross-Aggregate TX | Modifying multiple in one TX | Use domain events |
| Direct Layer Skip | Controller → Repository | Go through application layer |
| Premature CQRS | Adding complexity early | Start simple, evolve |

---

## Dependency Rules Matrix

|  | Domain | Application | Infrastructure |
|--|--------|-------------|----------------|
| **Domain** | ✅ | ❌ | ❌ |
| **Application** | ✅ | ✅ | ❌ |
| **Infrastructure** | ✅ | ✅ | ✅ |

---

## Complexity Ladder (Start Simple)

```
Level 1: Simple layered (Controller → Service → Repository)
   ↓ When business rules grow complex
Level 2: Domain model (Entities with behavior)
   ↓ When need multiple entry points
Level 3: Hexagonal (Ports & Adapters)
   ↓ When read/write patterns diverge significantly
Level 4: CQRS (Separate read/write models)
   ↓ When need complete audit trail / temporal queries
Level 5: Event Sourcing (Store events, derive state)
```

**Don't skip levels.** Each level adds complexity. Move up only when you've proven the current level insufficient.

---

## Resources

### Books
- Clean Architecture (Robert C. Martin, 2017)
- Domain-Driven Design (Eric Evans, 2003)
- Implementing Domain-Driven Design (Vaughn Vernon, 2013)
- Hexagonal Architecture Explained (Alistair Cockburn, 2024)

### Reference Implementations
- Go: [bxcodec/go-clean-arch](https://github.com/bxcodec/go-clean-arch)
- TypeScript: [jbuget/nodejs-clean-architecture-app](https://github.com/jbuget/nodejs-clean-architecture-app)
- Java: [thombergs/buckpal](https://github.com/thombergs/buckpal)

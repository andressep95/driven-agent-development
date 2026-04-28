# Testing Patterns

> Sources:
> - [Unit Testing](https://martinfowler.com/bliki/UnitTest.html) — Martin Fowler
> - [Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html) — Martin Fowler

Testing strategies for Clean Architecture + DDD + Hexagonal systems.

## Testing Pyramid

```
E2E Tests            — Few, slow, expensive
Integration Tests    — Some, moderate speed
Unit Tests           — Many, fast, cheap (domain + application)
```

---

## Unit Tests

### Domain Layer Tests — no mocks needed

```typescript
describe('Order', () => {
  it('creates order with draft status', () => {
    const order = Order.create(CustomerId.from('cust-123'));
    expect(order.status).toBe(OrderStatus.Draft);
    expect(order.items).toHaveLength(0);
  });

  it('emits OrderCreated event', () => {
    const order = Order.create(CustomerId.from('cust-123'));
    expect(order.domainEvents[0]).toBeInstanceOf(OrderCreated);
  });

  it('throws when adding item to cancelled order', () => {
    const order = createCancelledOrder();
    expect(() => {
      order.addItem(ProductId.from('prod-123'), Quantity.create(1), Money.create(10, 'USD'));
    }).toThrow(InvalidOrderStateError);
  });

  it('calculates total from all items', () => {
    const order = createDraftOrder();
    order.addItem(ProductId.from('p1'), Quantity.create(2), Money.create(10, 'USD'));
    order.addItem(ProductId.from('p2'), Quantity.create(1), Money.create(25, 'USD'));
    expect(order.total.amount).toBe(45);
  });
});
```

### Application Layer Tests — mock at port boundaries

```typescript
describe('PlaceOrderHandler', () => {
  let handler: PlaceOrderHandler;
  let orderRepo: MockOrderRepository;
  let eventPublisher: MockEventPublisher;

  beforeEach(() => {
    orderRepo = new MockOrderRepository();
    eventPublisher = new MockEventPublisher();
    handler = new PlaceOrderHandler(orderRepo, eventPublisher);
  });

  it('creates order and saves', async () => {
    const command = { customerId: 'cust-123', items: [{ productId: 'p1', quantity: 2 }] };
    const orderId = await handler.handle(command);
    const saved = await orderRepo.findById(OrderId.from(orderId));
    expect(saved).not.toBeNull();
  });

  it('publishes domain events', async () => {
    await handler.handle({ customerId: 'cust-123', items: [{ productId: 'p1', quantity: 1 }] });
    expect(eventPublisher.publishedEvents[0]).toBeInstanceOf(OrderCreated);
  });
});

class MockOrderRepository implements IOrderRepository {
  savedOrders: Order[] = [];
  async findById(id: OrderId): Promise<Order | null> {
    return this.savedOrders.find(o => o.id.equals(id)) ?? null;
  }
  async save(order: Order): Promise<void> {
    this.savedOrders.push(order);
  }
  async delete(order: Order): Promise<void> {
    const index = this.savedOrders.findIndex(o => o.id.equals(order.id));
    if (index >= 0) this.savedOrders.splice(index, 1);
  }
}
```

---

## Integration Tests — use real infrastructure

```typescript
describe('PostgresOrderRepository', () => {
  let repository: PostgresOrderRepository;

  beforeEach(async () => {
    await pool.query('TRUNCATE orders, order_items CASCADE');
  });

  it('persists and retrieves order', async () => {
    const order = Order.create(CustomerId.from('cust-123'));
    order.addItem(ProductId.from('prod-1'), Quantity.create(2), Money.create(10, 'USD'));
    await repository.save(order);
    const retrieved = await repository.findById(order.id);
    expect(retrieved!.items).toHaveLength(1);
  });
});
```

---

## Architecture Tests — verify dependency rules

```typescript
describe('Architecture', () => {
  it('domain should not depend on infrastructure', async () => {
    const rule = filesOfProject()
      .inFolder('domain')
      .shouldNot()
      .dependOnFiles()
      .inFolder('infrastructure');
    await expect(rule).toPassAsync();
  });

  it('application should not depend on infrastructure', async () => {
    const rule = filesOfProject()
      .inFolder('application')
      .shouldNot()
      .dependOnFiles()
      .inFolder('infrastructure');
    await expect(rule).toPassAsync();
  });
});
```

---

## Test Organization

```
tests/
├── unit/
│   ├── domain/
│   └── application/
├── integration/
│   ├── persistence/
│   ├── messaging/
│   └── http/
├── e2e/
├── architecture/
├── fixtures/
└── helpers/
```

---

## Key Testing Principles

1. **Test behavior, not implementation** - Focus on what, not how
2. **Domain tests need no mocks** - Domain layer is pure
3. **Mock at port boundaries** - Application tests mock driven ports
4. **Integration tests use real infra** - Test actual database, message broker
5. **Test business rules in domain** - Not in application or infrastructure

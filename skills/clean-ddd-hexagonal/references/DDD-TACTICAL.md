# DDD Tactical Patterns

> Sources:
> - [Domain-Driven Design: The Blue Book](https://www.domainlanguage.com/ddd/blue-book/) — Eric Evans (2003)
> - [Implementing Domain-Driven Design](https://openlibrary.org/works/OL17392277W) — Vaughn Vernon (2013)
> - [Effective Aggregate Design](https://www.dddcommunity.org/library/vernon_2011/) — Vaughn Vernon

## Entity

An object with **identity** that persists through time.

```
abstract class Entity<ID>:
    id: ID
    equals(other: Entity<ID>) -> bool:
        return this.id == other.id

class OrderItem extends Entity<OrderItemId>:
    productId: ProductId
    quantity: Quantity
    unitPrice: Money

    static create(productId, quantity, unitPrice) -> OrderItem:
        return new OrderItem(id: OrderItemId.generate(), ...)

    increaseQuantity(amount: int):
        this.quantity = this.quantity.add(amount)

    subtotal() -> Money:
        return this.unitPrice.multiply(this.quantity.value)
```

---

## Value Object

An object defined by its **attributes**, not identity. Immutable, no setters, equality by value.

### Common Value Objects

| Value Object | Attributes | Validation |
|--------------|-----------|------------|
| Money | amount, currency | amount >= 0 |
| Email | address | valid email format |
| Address | street, city, zip, country | required fields |
| Quantity | value | value > 0 |

```
class Money extends ValueObject<{amount, currency}>:
    static create(amount, currency) -> Money:
        guard: amount >= 0
        return new Money({amount, currency})

    add(other: Money) -> Money:
        guard: this.currency == other.currency
        return Money.create(this.amount + other.amount, this.currency)

class Email extends ValueObject<{value}>:
    static create(email: string) -> Email:
        normalized = email.lowercase().trim()
        guard: isValidEmailFormat(normalized)
        return new Email({value: normalized})
```

---

## Aggregate

A cluster of entities and value objects with a **consistency boundary**.

### Rules

1. **One aggregate root** - Single entry point for all modifications
2. **Reference by ID only** - Aggregates reference others by identity only
3. **Transaction boundary** - One aggregate per transaction
4. **Small aggregates** - Prefer smaller over larger

### Aggregate Sizing Heuristics

| Metric | Healthy | Warning | Action |
|--------|---------|---------|--------|
| Entities per aggregate | 1-5 | 6-10 | >10: Split |
| Lines of code (root) | <500 | 500-1000 | >1000: Split |
| Transaction lock time | <100ms | 100-500ms | >500ms: Split |

```
class Order extends AggregateRoot<OrderId>:
    customerId: CustomerId
    items: List<OrderItem> = []
    status: OrderStatus

    static create(customerId: CustomerId) -> Order:
        order = new Order(id: OrderId.generate(), ...)
        order.addDomainEvent(OrderCreated{orderId, customerId})
        return order

    addItem(productId, quantity, unitPrice):
        guard: status != CANCELLED
        guard: quantity > 0
        existingItem = this.items.find(i => i.productId == productId)
        if existingItem:
            existingItem.increaseQuantity(quantity)
        else:
            this.items.append(OrderItem.create(productId, quantity, unitPrice))
        this.addDomainEvent(OrderItemAdded{orderId, productId, quantity})

    confirm():
        guard: status == DRAFT
        guard: items.length > 0
        this.status = CONFIRMED
        this.addDomainEvent(OrderConfirmed{orderId, total})

    cancel(reason: string):
        guard: status not in [SHIPPED, DELIVERED]
        this.status = CANCELLED
        this.addDomainEvent(OrderCancelled{orderId, reason})
```

---

## Repository

One repository per aggregate. Domain interface, infrastructure implementation.

```
interface OrderRepository:
    findById(id: OrderId) -> Order | null
    findByCustomerId(customerId: CustomerId) -> List<Order>
    save(order: Order)
    delete(order: Order)

# Wrong: repository per entity
interface OrderItemRepository:  # ❌
    findByOrderId(orderId) -> List<OrderItem>

# Wrong: query methods in repository
interface OrderRepository:  # ❌
    findByStatus(status) -> List<Order>
    countByCustomer(customerId)

# Correct: separate read model for queries
interface OrderReadModel:  # ✅
    findByStatus(status) -> List<OrderSummaryDTO>
    countByCustomer(customerId) -> int
```

---

## Domain Event

Records something significant that happened. Past tense naming, immutable.

```
abstract class DomainEvent:
    eventId: string = generateUUID()
    occurredAt: DateTime = now()
    abstract eventType: string

class OrderCreated extends DomainEvent:
    eventType = "order.created"
    orderId: OrderId
    customerId: CustomerId

class OrderConfirmed extends DomainEvent:
    eventType = "order.confirmed"
    orderId: OrderId
    total: Money
```

---

## Domain Service

Stateless operations that don't naturally fit within an entity.

**When to use:** operation involves multiple aggregates, or significant business logic that doesn't belong to one entity.

```
interface PricingService:
    calculateDiscount(order: Order, customer: Customer) -> Money

class PricingServiceImpl implements PricingService:
    calculateDiscount(order, customer) -> Money:
        discount = Money.zero()
        if order.itemCount() > 10:
            discount = discount.add(order.total().multiply(0.05))
        if customer.isVIP:
            discount = discount.add(order.total().multiply(0.10))
        maxDiscount = order.total().multiply(0.20)
        return min(discount, maxDiscount)
```

---

## Specification Pattern

Encapsulates business rules for querying or validation.

```
class OrderOverValueSpec implements Specification<Order>:
    minValue: Money
    isSatisfiedBy(order) -> bool:
        return order.total().amount >= minValue.amount

canShipFree = OrderOverValueSpec(Money.create(100, "USD"))
    .and(OrderHasItemsSpec())

if canShipFree.isSatisfiedBy(order):
    applyFreeShipping()
```

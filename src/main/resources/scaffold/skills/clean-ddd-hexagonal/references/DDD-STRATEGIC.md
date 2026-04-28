# DDD Strategic Patterns

> Sources:
> - [Domain-Driven Design: The Blue Book](https://www.domainlanguage.com/ddd/blue-book/) — Eric Evans (2003)
> - [Bounded Context](https://martinfowler.com/bliki/BoundedContext.html) — Martin Fowler
> - [Anti-Corruption Layer](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/acl.html) — AWS

## Overview

Strategic DDD patterns help decompose large systems into manageable parts with clear boundaries. They answer: **"How do we divide a complex domain?"**

**DDD is fundamentally collaborative.** The patterns below emerge from conversations, whiteboarding, and modeling sessions with domain experts.

---

## Domain Discovery Techniques

### Event Storming

```
Orange sticky: Domain Event (past tense: "OrderPlaced")
Blue sticky: Command (imperative: "Place Order")
Yellow sticky: Aggregate (noun: "Order")
Pink sticky: External System / Policy
Purple sticky: Problem / Question
```

**Workshop flow:**
1. **Chaotic exploration** — Everyone adds events they know about
2. **Timeline ordering** — Arrange events chronologically
3. **Identify aggregates** — Group related events
4. **Find boundaries** — Where language changes = bounded context boundary
5. **Surface problems** — Mark unclear areas for follow-up

---

## Ubiquitous Language

A shared vocabulary between developers and domain experts that appears in code, documentation, conversations, and UI labels.

### Principles

1. **One language per bounded context**
2. **Code reflects the language** - `Order.confirm()` not `Order.setStatus("confirmed")`
3. **Evolve together** - When language changes, code changes

```typescript
// ❌ Technical, not ubiquitous
class Order {
  setStatus(status: number): void { this.status = status; }
}

// ✅ Ubiquitous language
class Order {
  confirm(): void {
    if (this.status !== OrderStatus.Pending) {
      throw new OrderCannotBeConfirmedException(this.id);
    }
    this.status = OrderStatus.Confirmed;
    this.addDomainEvent(new OrderConfirmed(this.id));
  }
}
```

---

## Bounded Contexts

A **semantic boundary** where a particular domain model applies.

- Each bounded context has its **own ubiquitous language**
- Each bounded context has its **own model**
- The same real-world concept may have **different representations** in different contexts

### Example: "Customer" means different things

- **Sales**: Email, preferences, order history
- **Shipping**: Delivery address, phone number
- **Billing**: Payment methods, billing address

---

## Subdomains

| Type | Description | Investment | Example |
|------|-------------|------------|---------|
| **Core** | Competitive advantage | High | Product recommendation engine |
| **Supporting** | Necessary but not unique | Medium | Order management |
| **Generic** | Commodity, buy/outsource | Low | Email sending, payments |

---

## Context Mapping Patterns

### Anti-Corruption Layer (ACL)

Translation layer protecting your model from external models.

```
External Context → ACL (Translator + Adapter) → Your Context
```

**Use when:** integrating with legacy systems, third-party APIs, or messy external models.

```typescript
export class StripePaymentACL {
  translateStatus(stripeStatus: string): PaymentStatus {
    const mapping: Record<string, PaymentStatus> = {
      'requires_payment_method': PaymentStatus.Pending,
      'processing': PaymentStatus.Processing,
      'succeeded': PaymentStatus.Completed,
      'canceled': PaymentStatus.Cancelled,
    };
    return mapping[stripeStatus] ?? PaymentStatus.Unknown;
  }
}
```

### Other Patterns

| Pattern | When to Use |
|---------|-------------|
| **Partnership** | Two contexts succeed or fail together |
| **Shared Kernel** | Two contexts share a subset of the model (use sparingly) |
| **Customer-Supplier** | Upstream provides what downstream needs |
| **Conformist** | Downstream adopts upstream's model with no negotiation |
| **Open Host Service** | Expose a well-defined protocol for multiple consumers |

---

## Strategic Design Checklist

- [ ] Identify ubiquitous language terms with domain experts
- [ ] Map subdomains (core, supporting, generic)
- [ ] Define bounded context boundaries
- [ ] Document context map with relationships
- [ ] Design anti-corruption layers for external systems
- [ ] Define integration event schemas
- [ ] Ensure each context has its own data store

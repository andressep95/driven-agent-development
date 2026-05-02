---
name: jpa-query-optimizer
description: >
  Evaluates and implements SQL query optimizations in Spring Boot JPA/Hibernate projects.
  Trigger: When slow queries, N+1 problems, incorrect fetch strategies, inefficient projections,
  or pagination issues are detected in Spring Data JPA repositories.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Optimize JPA query or repository"
    - "N+1 problem in Hibernate"
    - "Slow SQL query in Spring Boot"
    - "Add fetch strategy or entity graph"
    - "Improve JPA performance"
    - "Add DTO projection to repository"
    - "Hibernate performance issue"
    - "LazyInitializationException"
    - "HHH000104 pagination warning"
    - "Enable Hibernate second level cache"
    - "JOIN FETCH with pagination"
    - "Database bottleneck"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

# JPA / Hibernate Query Optimizer

Guide for diagnosing and resolving SQL query bottlenecks in Spring Boot applications using Spring Data JPA and Hibernate.

## When to Use (and When NOT to)

| Use When | Skip When |
|----------|-----------|
| Slow queries detected in logs or APM | Index missing on the database side |
| `HHH000104` warning in logs | Simple CRUD with no relationships |
| `LazyInitializationException` at runtime | Performance is acceptable (<100ms) |
| N+1 queries visible via `show_sql` | First iteration / prototype |
| Loading full entities to read just 2 fields | Network or connection pool issue |

**Rule:** Enable `spring.jpa.show-sql=true` and `logging.level.org.hibernate.SQL=DEBUG` before optimizing. Measure first, optimize second.

## Quick Diagnosis

```
What is the symptom?
├─ Many similar queries in logs          → N+1 Problem (see N+1-PROBLEM.md)
├─ One query takes > 500ms               → Review JPQL / indexes / projections
├─ HHH000104 in logs                     → JOIN FETCH + Pageable (see PAGINATION.md)
├─ LazyInitializationException           → Wrong fetch strategy (see FETCH-STRATEGIES.md)
├─ Loading unnecessary columns           → Use projections (see PROJECTIONS.md)
└─ Repeated queries with same parameters → Second-level cache (see CACHING.md)
```

## CRITICAL: Optimization Decision Tree

```
Do you need related data?
├─ YES ─ Are they collections (OneToMany / ManyToMany)?
│         ├─ YES ─ Do you need to paginate?
│         │         ├─ YES → Separate queries (see PAGINATION.md)
│         │         └─ NO  → JOIN FETCH in JPQL
│         └─ NO (ManyToOne / OneToOne) → @EntityGraph or JOIN FETCH
└─ NO ─ Do you need only some fields?
          ├─ YES → Interface Projection or DTO Projection
          └─ NO  → Standard query is fine
```

## Critical Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| **FetchType.EAGER on collections** | Loads everything even when unused | Switch to `LAZY`, use `@EntityGraph` when needed |
| **JOIN FETCH + Pageable** | HHH000104 warning, in-memory pagination | Separate count query or use subquery |
| **Load full entity to read 2 fields** | Unnecessary SELECT * | Interface projection or DTO record |
| **Open session in view (presentation layer)** | Random LazyInitializationException | Close session at service layer, not controller |
| **Ignored N+1** | 1 + N queries when iterating collection | JOIN FETCH or batch fetch size |
| **findAll() with no limit** | Loads entire table into memory | Always paginate with `Pageable` |

## Optimization Patterns

### 1. Resolve N+1 with JOIN FETCH

```java
// BAD: generates N+1 queries when accessing books
List<Author> authors = authorRepository.findAll();
authors.forEach(a -> a.getBooks().size()); // N extra queries

// GOOD: single JOIN
@Query("SELECT a FROM Author a LEFT JOIN FETCH a.books WHERE a.genre = :genre")
List<Author> findByGenreWithBooks(@Param("genre") String genre);
```

### 2. Interface Projection — only the fields you need

```java
// Only selects name and age → SELECT a.name, a.age FROM author a
public interface AuthorNameAge {
    String getName();
    int getAge();
}

@Transactional(readOnly = true)
List<AuthorNameAge> findFirst2ByGenre(String genre);
```

### 3. DTO Projection with Record (JDK 14+)

```java
public record AuthorDto(String name, int age) {}

@Query("SELECT new com.example.dto.AuthorDto(a.name, a.age) FROM Author a WHERE a.active = true")
List<AuthorDto> fetchActiveAuthorsAsDto();
```

### 4. Entity Graph — control fetch at the repository level

```java
// Ad-hoc (no @NamedEntityGraph needed on the entity)
@EntityGraph(attributePaths = {"books", "books.reviews"})
Optional<Author> findWithBooksAndReviewsById(Long id);

// Named (defined on the entity)
@Entity
@NamedEntityGraph(name = "Author.detail",
    attributeNodes = @NamedAttributeNode("books"))
public class Author { ... }

@EntityGraph(value = "Author.detail", type = EntityGraphType.LOAD)
Author getByName(String name);
```

### 5. Correct pagination with collections

```java
// GOOD: separate countQuery avoids HHH000104
@Query(
    value = "SELECT a FROM Author a LEFT JOIN FETCH a.books WHERE a.genre = ?1",
    countQuery = "SELECT COUNT(a) FROM Author a WHERE a.genre = ?1"
)
Page<Author> findByGenreWithBooks(String genre, Pageable pageable);
```

### 6. Batch Size for LAZY collections

```java
// On the entity — groups N queries into ceil(N/batchSize) queries
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
@BatchSize(size = 25)
private Set<Book> books;

// Or globally in application.properties
// spring.jpa.properties.hibernate.default_batch_fetch_size=25
```

## Diagnostic Commands

```bash
# Enable SQL logging with parameters
# application.properties
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE

# View Hibernate statistics in tests
spring.jpa.properties.hibernate.generate_statistics=true
logging.level.org.hibernate.stat=DEBUG

# Check execution plan (PostgreSQL)
EXPLAIN ANALYZE <your SQL query>;

# Find entities with FetchType.EAGER in the project
grep -r "FetchType.EAGER" src/main/java --include="*.java"

# Find repositories returning List without Pageable
grep -rn "List<" src/main/java --include="*Repository*.java"
```

## Review Checklist

```
[ ] Any FetchType.EAGER on @OneToMany or @ManyToMany relationships?
[ ] Any findAll() without Pageable on large tables?
[ ] Any JOIN FETCH combined with Pageable without a separate countQuery?
[ ] Any full entities loaded when only 2-3 fields are used?
[ ] Any lazy collection accessed outside the transaction?
[ ] Is batch_fetch_size configured for lazy relationships?
[ ] Do read-only methods use @Transactional(readOnly = true)?
[ ] Do frequently repeated queries with same params have second-level cache?
```

## Internal Reference

| File | Content |
|------|---------|
| [references/N+1-PROBLEM.md](references/N+1-PROBLEM.md) | Full N+1 problem diagnosis |
| [references/FETCH-STRATEGIES.md](references/FETCH-STRATEGIES.md) | LAZY vs EAGER, JOIN FETCH, BatchSize |
| [references/PROJECTIONS.md](references/PROJECTIONS.md) | Interface, DTO record, JPQL constructor |
| [references/ENTITY-GRAPHS.md](references/ENTITY-GRAPHS.md) | Named and ad-hoc @EntityGraph |
| [references/PAGINATION.md](references/PAGINATION.md) | Efficient pagination, HHH000104 |
| [references/CACHING.md](references/CACHING.md) | Second-level cache, query cache |
| [references/CHEATSHEET.md](references/CHEATSHEET.md) | Quick decision guide |

## Sources

- [Spring Data JPA — Entity Graphs](https://docs.spring.io/spring-data/jpa/docs/current/reference/html/#jpa.entity-graph)
- [Hibernate Performance Best Practices](https://github.com/andreipall/spring-boot-jpa)
- [Vlad Mihalcea — High-Performance Java Persistence](https://vladmihalcea.com/books/high-performance-java-persistence/)
- [Baeldung — JPA/Hibernate N+1](https://www.baeldung.com/hibernate-common-performance-problems-in-logs)

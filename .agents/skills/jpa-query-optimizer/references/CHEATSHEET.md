# JPA Query Optimizer — Cheatsheet

## Main Decision Tree

```
What is the symptom?
│
├─ Many repeated queries in logs (N+1)
│   └─ Is there pagination?
│       ├─ YES → @BatchSize(size=25) or separate queries (IDs + fetch)
│       └─ NO  → JOIN FETCH + DISTINCT in JPQL
│
├─ HHH000104 warning in logs
│   └─ JOIN FETCH + Pageable → add separate countQuery or use @BatchSize
│
├─ LazyInitializationException
│   └─ Accessing lazy relationship outside @Transactional
│       → Move logic inside the transaction
│       → Or use @EntityGraph / JOIN FETCH on the repository method
│
├─ Query takes > 500ms
│   ├─ SELECT * with few fields used → Interface Projection or DTO record
│   ├─ No index on WHERE column      → EXPLAIN ANALYZE on database
│   └─ Same data loaded repeatedly  → Second-level cache
│
└─ findAll() with no limit on large table
    → Add Pageable to the repository method
```

## Quick Fixes by Problem Type

| Problem | Fix in 1 line |
|---------|--------------|
| N+1 without pagination | `@Query("SELECT DISTINCT a FROM Author a LEFT JOIN FETCH a.books")` |
| N+1 with pagination | `@BatchSize(size = 25)` on the collection |
| HHH000104 | Add `countQuery = "SELECT COUNT(a) FROM Author a"` to `@Query` |
| Unnecessary SELECT * | Change return type to interface projection |
| LazyInitializationException | Add `@Transactional` to the service method |
| Catalog entity reloaded | `@Cache(usage = CacheConcurrencyStrategy.READ_ONLY)` on entity |

## Minimum Diagnostic Configuration

```properties
# Add to application.properties to diagnose
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
spring.jpa.properties.hibernate.generate_statistics=true
```

## Reference Repository Patterns

```java
// 1. Full list with relationships
@Query("SELECT DISTINCT a FROM Author a LEFT JOIN FETCH a.books WHERE a.genre = :genre")
List<Author> findByGenreWithBooks(@Param("genre") String genre);

// 2. Paginated with relationships (no HHH000104)
@Query(value = "SELECT a FROM Author a LEFT JOIN FETCH a.books WHERE a.genre = ?1",
       countQuery = "SELECT COUNT(a) FROM Author a WHERE a.genre = ?1")
Page<Author> findByGenreWithBooksPaged(String genre, Pageable pageable);

// 3. Only required fields
@Transactional(readOnly = true)
List<AuthorNameAge> findFirst2ByGenre(String genre); // Interface projection

// 4. Immutable DTO
@Query("SELECT new com.example.dto.AuthorDto(a.name, a.age) FROM Author a WHERE a.active = true")
List<AuthorDto> fetchActiveAuthorsAsDto();

// 5. Ad-hoc entity graph
@EntityGraph(attributePaths = {"books", "publisher"})
Optional<Author> findWithDetailsById(Long id);
```

## Pre-Deploy Checklist

```
[ ] No FetchType.EAGER on @OneToMany / @ManyToMany
[ ] All findAll() on large tables use Pageable
[ ] JOIN FETCH + Pageable have a separate countQuery
[ ] Catalog entities have @Cache READ_ONLY
[ ] Read-only methods have @Transactional(readOnly = true)
[ ] Hibernate statistics reviewed in staging environment
[ ] EXPLAIN ANALYZE run on slow queries
```

## Expected Impact

| Optimization | Typical query reduction |
|-------------|------------------------|
| JOIN FETCH (resolve N+1) | From N+1 to 1 query |
| Interface Projection | 40-80% less data transferred |
| @BatchSize(25) | From N to ceil(N/25) queries |
| Second-level cache L2 | 0 queries for cached data |
| Pagination (replace findAll) | From full table load to N records |

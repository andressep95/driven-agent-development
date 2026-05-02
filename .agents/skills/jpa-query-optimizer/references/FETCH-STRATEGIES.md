# Fetch Strategies

## LAZY vs EAGER

| Strategy | Behavior | Use when |
|----------|----------|----------|
| `FetchType.LAZY` | Loads the relationship only when accessed | **Recommended default** for collections |
| `FetchType.EAGER` | Always loads the relationship with the parent entity | `@ManyToOne` / `@OneToOne` that is always needed |

### Rule
- `@OneToMany` / `@ManyToMany` → **always LAZY**
- `@ManyToOne` / `@OneToOne` → LAZY is also preferred; use EAGER only if always needed

```java
// GOOD
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
private Set<Book> books;

// BAD — loads all books on every Author query
@OneToMany(mappedBy = "author", fetch = FetchType.EAGER)
private Set<Book> books;
```

## JOIN FETCH

Forces loading of a LAZY relationship in a specific query without changing the global mapping.

```java
// Fetches authors and their books in a single SQL query with JOIN
@Query("SELECT DISTINCT a FROM Author a LEFT JOIN FETCH a.books WHERE a.genre = :genre")
List<Author> findByGenreWithBooks(@Param("genre") String genre);
```

**JOIN vs JOIN FETCH:**

| Type | Generated SQL | Loads the collection |
|------|--------------|---------------------|
| `JOIN` | `INNER JOIN` / `LEFT JOIN` | NO — filters only |
| `JOIN FETCH` | `LEFT JOIN` selecting all columns | YES — hydrates the relationship |

```java
// JOIN — filters by book.title but does NOT load books into Author
@Query("SELECT a FROM Author a JOIN a.books b WHERE b.title LIKE :title")
List<Author> findByBookTitle(@Param("title") String title); // books remain lazy

// JOIN FETCH — filters AND loads books into Author
@Query("SELECT DISTINCT a FROM Author a JOIN FETCH a.books b WHERE b.title LIKE :title")
List<Author> findByBookTitleWithBooks(@Param("title") String title);
```

## @BatchSize

Groups N+1 queries into batches using `WHERE id IN (...)`.

```java
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
@BatchSize(size = 25)
private Set<Book> books;
```

With 100 authors: instead of 100 separate queries, Hibernate executes 4 queries with `IN (25 ids)`.

**Global configuration (application.properties):**

```properties
spring.jpa.properties.hibernate.default_batch_fetch_size=25
```

## When to Use Each Strategy

```
How many records will be loaded?
├─ Few (< 100) and the relationship is always needed → JOIN FETCH
├─ Many or paginated → @BatchSize or separate queries
└─ Only sometimes needed → LAZY + @EntityGraph when required
```

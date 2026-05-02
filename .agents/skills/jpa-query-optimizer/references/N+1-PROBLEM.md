# N+1 Query Problem

## What Is It?

The N+1 problem occurs when an initial query loads N parent entities and then N additional queries are executed to load the associations of each one, resulting in `1 + N` total queries.

## How to Detect It

**Log with `show_sql=true`:**
```
Hibernate: select * from author
Hibernate: select * from book where author_id=1
Hibernate: select * from book where author_id=2
Hibernate: select * from book where author_id=3
... (N more times)
```

**With Hibernate statistics:**
```
logging.level.org.hibernate.stat=DEBUG
# Look for: "HHH90000004: firstResult/maxResults specified with collection fetch; applying in memory!"
```

**With Hypersistence Optimizer or p6spy:**
- Third-party tools that automatically detect N+1 problems in tests.

## Root Cause

```java
// Entity with LAZY fetch (correct by default)
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
private Set<Book> books;

// Problematic code:
List<Author> authors = authorRepository.findAll(); // 1 query
authors.forEach(a -> {
    System.out.println(a.getBooks().size()); // N queries — each access triggers a SELECT
});
```

## Solutions

### Option A: JOIN FETCH in JPQL (best for lists without pagination)

```java
@Query("SELECT DISTINCT a FROM Author a LEFT JOIN FETCH a.books")
List<Author> findAllWithBooks();
```

> Use `DISTINCT` to avoid duplicates when an author has multiple books.

### Option B: @EntityGraph (best for repository methods)

```java
@EntityGraph(attributePaths = {"books"})
List<Author> findAll();
```

### Option C: @BatchSize (best when JOIN FETCH is not viable)

```java
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
@BatchSize(size = 25)
private Set<Book> books;
```

Hibernate groups the N queries into `ceil(N/25)` queries using `WHERE id IN (...)`.

### Option D: Separate queries (best with pagination)

```java
// 1. Load paginated authors
Page<Author> authors = authorRepository.findAll(pageable);

// 2. Load books for those authors in a single query
List<Long> authorIds = authors.map(Author::getId).toList();
List<Book> books = bookRepository.findByAuthorIdIn(authorIds);

// 3. Map manually or let Hibernate resolve with @BatchSize
```

## When to Use Each Option

| Option | When to use |
|--------|------------|
| JOIN FETCH | No pagination, 1-2 relationship levels |
| @EntityGraph | Reuse fetch logic across multiple methods |
| @BatchSize | Deep relationships or active pagination |
| Separate queries | Pagination + collections (avoids HHH000104) |

## Golden Rule

> Never iterate over lazy-loaded entity collections outside the transactional context. All logic that accesses relationships must occur within `@Transactional`.

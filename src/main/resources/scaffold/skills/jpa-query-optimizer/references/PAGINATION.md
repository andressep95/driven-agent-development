# Efficient Pagination with JPA

## The Problem: HHH000104

When combining `JOIN FETCH` with `Pageable`, Hibernate emits this warning:

```
HHH90000104: firstResult/maxResults specified with collection fetch; applying in memory!
```

This means Hibernate loads **all records into memory** and then applies pagination in the JVM, not in the database. With large tables, this exhausts the heap.

## Cause

```java
// DANGEROUS — Hibernate discards LIMIT/OFFSET and paginates in memory
@Query("SELECT a FROM Author a LEFT JOIN FETCH a.books")
Page<Author> findAllWithBooks(Pageable pageable);
```

Generated SQL: **without** `LIMIT` or `OFFSET` — fetches the entire table.

## Solution 1: Separate countQuery (recommended)

```java
@Query(
    value = "SELECT a FROM Author a LEFT JOIN FETCH a.books WHERE a.genre = ?1",
    countQuery = "SELECT COUNT(a) FROM Author a WHERE a.genre = ?1"
)
Page<Author> findByGenreWithBooks(String genre, Pageable pageable);
```

Hibernate uses `countQuery` for the total count and `value` for the requested page. JOIN FETCH still works but only over the page, not the entire table.

## Solution 2: Two Separate Queries (most robust)

```java
// Step 1: get paginated IDs (no JOIN FETCH)
@Query("SELECT a.id FROM Author a WHERE a.genre = :genre")
Page<Long> findIdsByGenre(@Param("genre") String genre, Pageable pageable);

// Step 2: load full entities with JOIN FETCH for those IDs
@Query("SELECT a FROM Author a LEFT JOIN FETCH a.books WHERE a.id IN :ids")
List<Author> findWithBooksByIds(@Param("ids") List<Long> ids);
```

```java
// In the service:
Page<Long> ids = authorRepository.findIdsByGenre(genre, pageable);
List<Author> authors = authorRepository.findWithBooksByIds(ids.getContent());
```

## Solution 3: @BatchSize (no query changes needed)

```java
// On the entity — Hibernate groups SELECTs into batches
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
@BatchSize(size = 25)
private Set<Book> books;

// In the repository: simple pagination without JOIN FETCH
Page<Author> findByGenre(String genre, Pageable pageable);
```

Hibernate paginates in the database and then loads books in batches of 25. No HHH000104, no in-memory queries.

## Cursor-based Pagination (Keyset Pagination)

For very large tables (>1M rows), `OFFSET` is slow because the database must skip N rows.

```java
// BAD for large tables — OFFSET scans all previous rows
Pageable page = PageRequest.of(1000, 20); // skips 20,000 records

// GOOD — use WHERE id > lastSeenId for cursor
@Query("SELECT a FROM Author a WHERE a.id > :lastId AND a.genre = :genre ORDER BY a.id ASC")
List<Author> findNextPage(@Param("lastId") Long lastId, @Param("genre") String genre, Pageable pageable);
```

## Strategy Comparison

| Strategy | Complexity | Scale | When to use |
|----------|-----------|-------|-------------|
| JOIN FETCH + countQuery | Low | Medium | Small collections (<10K) |
| Two queries (IDs + fetch) | Medium | High | Large collections |
| @BatchSize | Low | High | Multiple lazy relationships |
| Cursor / Keyset | Medium | Very high | Tables >1M rows |

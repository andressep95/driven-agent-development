# Entity Graphs

Entity graphs allow controlling which relationships are loaded eagerly **per query**, without changing the global entity mapping. They are the clean alternative to hardcoding `FetchType.EAGER`.

## Types

| Type | Behavior |
|------|----------|
| `LOAD` | Graph attributes are loaded EAGER; others follow their FetchType |
| `FETCH` | Graph attributes are loaded EAGER; others are treated as LAZY |

## Ad-hoc Entity Graph (recommended)

No annotations needed on the entity. Defined directly on the repository method.

```java
// Loads author with books and reviews in one query
@EntityGraph(attributePaths = {"books", "books.reviews"})
Optional<Author> findWithBooksAndReviewsById(Long id);

// Combined with a custom @Query
@Query("SELECT a FROM Author a WHERE a.active = true")
@EntityGraph(attributePaths = {"books"})
List<Author> findActiveAuthorsWithBooks();

// Multiple depth levels
@EntityGraph(attributePaths = {"books", "publisher", "publisher.address"})
Author getDetailById(Long id);
```

## Named Entity Graph

Defined on the entity, referenced by name in the repository.

```java
// On the entity
@Entity
@NamedEntityGraph(
    name = "Author.withBooks",
    attributeNodes = @NamedAttributeNode("books")
)
@NamedEntityGraph(
    name = "Author.withBooksAndReviews",
    attributeNodes = @NamedAttributeNode(
        value = "books",
        subgraph = "books.reviews"
    ),
    subgraphs = @NamedSubgraph(
        name = "books.reviews",
        attributeNodes = @NamedAttributeNode("reviews")
    )
)
public class Author { ... }

// In the repository
@EntityGraph(value = "Author.withBooks", type = EntityGraphType.LOAD)
Author getByName(String name);

@EntityGraph(value = "Author.withBooksAndReviews")
Optional<Author> findDetailById(Long id);
```

## Entity Graph vs JOIN FETCH

| Aspect | Entity Graph | JOIN FETCH |
|--------|-------------|-----------|
| Syntax | Annotation on repository | Manual JPQL |
| Reusability | High (named graphs) | Low (duplicated query) |
| Pagination | Compatible with Pageable | HHH000104 problem |
| Multiple collections | May produce cartesian product | Also may duplicate |
| SQL control | Low | High |

## When to Use

```
Do you need to control the same relationship fetch across multiple methods?
├─ YES → Named Entity Graph on the entity
└─ NO  → Ad-hoc @EntityGraph on the repository method

Do you need to paginate and also load collections?
├─ YES → Entity Graph (avoids HHH000104 better than JOIN FETCH)
└─ NO  → JOIN FETCH or @BatchSize
```

## Warning: Cartesian Product

Loading multiple parallel collections with entity graphs or JOIN FETCH can return duplicate rows.

```java
// DANGEROUS — if author has 3 books and 2 tags: 3x2 = 6 rows
@EntityGraph(attributePaths = {"books", "tags"})
List<Author> findAll();

// SOLUTION A: Use Set instead of List for collections
private Set<Book> books;

// SOLUTION B: Split into two separate queries
```

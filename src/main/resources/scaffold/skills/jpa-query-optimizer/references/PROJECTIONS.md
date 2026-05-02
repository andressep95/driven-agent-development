# Projections — Only the Fields You Need

Projections avoid loading full entities when only 2-3 fields are needed. They reduce `SELECT *` to specific columns.

## Projection Types

### 1. Interface Projection (simplest)

```java
// Define the interface with getters for the desired fields
public interface AuthorNameAge {
    String getName();
    int getAge();
}

// Repository
@Transactional(readOnly = true)
List<AuthorNameAge> findFirst2ByGenre(String genre);

// Generated SQL: SELECT a.name, a.age FROM author a WHERE a.genre = ? LIMIT 2
```

**Nested projection** (fields from related entities):
```java
public interface AuthorWithGenre {
    String getName();

    interface GenreInfo {
        String getLabel();
    }
    GenreInfo getGenre();
}
```

### 2. DTO Projection with Record (JDK 14+)

```java
public record AuthorDto(String name, int age) {}

@Query("SELECT new com.example.dto.AuthorDto(a.name, a.age) FROM Author a WHERE a.active = true")
List<AuthorDto> fetchActiveAuthorsAsDto();
```

> The constructor expression `new com.example.dto.AuthorDto(...)` is standard JPQL. The fully qualified class name is required.

### 3. DTO with Native SQL (MySQL/PostgreSQL)

```java
// Interface projection with native query
public interface AuthorNameBookTitle {
    String getName();
    String getTitle();
}

@Query(
    value = "SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id WHERE a.genre = :genre",
    nativeQuery = true
)
List<AuthorNameBookTitle> findAuthorAndTitleByGenre(@Param("genre") String genre);
```

### 4. Dynamic Projection (same method, variable return type)

```java
// One method, multiple return types
<T> List<T> findByGenre(String genre, Class<T> type);

// Usage:
List<AuthorNameAge> slim = repo.findByGenre("Fiction", AuthorNameAge.class);
List<Author> full = repo.findByGenre("Fiction", Author.class);
```

## When to Use Each Type

| Type | When | Advantage |
|------|------|-----------|
| Interface Projection | Simple fields, no logic | Simplest, Spring generates it |
| DTO Record | Logic in the DTO, immutability | Type-safe, explicit constructor |
| Native SQL Projection | Complex queries, multiple tables | Maximum SQL control |
| Dynamic Projection | Same endpoint, different detail levels | Single repository method |

## Rule

> If a repository method returns a full entity and the caller only uses 2-3 fields → replace with Interface Projection or DTO record.

Signal in code:
```java
// Suspicious: loads full Author just to get the name
Author author = authorRepository.findById(id).orElseThrow();
return author.getName(); // only getName() is used

// Better:
AuthorNameOnly author = authorRepository.findNameById(id);
```

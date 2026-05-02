# Hibernate Caching

## Cache Levels

| Level | Scope | Enabled by default | When to use |
|-------|-------|--------------------|-------------|
| **L1 (First-level)** | Per session / transaction | Always active | Automatic — deduplicates queries within the same TX |
| **L2 (Second-level)** | Per SessionFactory (whole app) | No | Reference entities, rarely changing data |
| **Query Cache** | Per query with parameters | No | Frequent queries with the same parameters |

## Second-Level Cache (L2)

### Configuration with Ehcache (most common in Spring Boot)

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>
<dependency>
    <groupId>org.hibernate.orm</groupId>
    <artifactId>hibernate-jcache</artifactId>
</dependency>
<dependency>
    <groupId>org.ehcache</groupId>
    <artifactId>ehcache</artifactId>
</dependency>
```

```properties
# application.properties
spring.jpa.properties.hibernate.cache.use_second_level_cache=true
spring.jpa.properties.hibernate.cache.region.factory_class=org.hibernate.cache.jcache.JCacheCacheProvider
spring.jpa.properties.javax.cache.provider=org.ehcache.jsr107.EhcacheCachingProvider
```

### Annotating Entities for L2

```java
@Entity
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
public class Country {
    @Id
    private Long id;
    private String name;
    private String isoCode;
}

// For collections inside the entity
@OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
@Cache(usage = CacheConcurrencyStrategy.READ_ONLY)
private Set<Genre> genres;
```

### Concurrency Strategies

| Strategy | Access | When to use |
|----------|--------|-------------|
| `READ_ONLY` | Read-only, no updates | Catalog data (countries, currencies) |
| `NONSTRICT_READ_WRITE` | Read/write, eventual consistency | Rarely updated data |
| `READ_WRITE` | Read/write with locking | Moderately updated data |
| `TRANSACTIONAL` | Full TX (JTA required) | High consistency required |

## Query Cache

Caches the result of a JPQL/SQL query. **Requires L2 to be enabled.**

```properties
spring.jpa.properties.hibernate.cache.use_query_cache=true
```

```java
@Repository
public interface AuthorRepository extends JpaRepository<Author, Long> {

    @QueryHints(@QueryHint(name = "org.hibernate.cacheable", value = "true"))
    List<Author> findByGenre(String genre);
}
```

> The query cache stores IDs, not entities. Entities must also be in the L2 cache.

## When to Use L2 Cache

```
Does the data change rarely? (< once per hour)
├─ YES → Candidate for L2
└─ NO  → Do not cache (risk of stale data)

Is the same entity loaded many times by different users?
├─ YES → L2 has high ROI
└─ NO  → L1 (per-session) is enough

Is it a catalog table (countries, currencies, categories)?
└─ YES → READ_ONLY with L2 is ideal
```

## Monitoring

```properties
# View cache hit/miss statistics
spring.jpa.properties.hibernate.generate_statistics=true
logging.level.org.hibernate.stat=DEBUG
```

Statistics log includes:
- `SecondLevelCacheHitCount` — how many times served from cache
- `SecondLevelCacheMissCount` — how many times hit the database
- `SecondLevelCachePutCount` — how many entities stored in cache

## Eviction

```java
@Service
public class AuthorService {

    @Autowired
    private EntityManager entityManager;

    // Evict a specific entity from L2 cache
    public void evictAuthor(Long authorId) {
        entityManager.getEntityManagerFactory()
            .getCache()
            .evict(Author.class, authorId);
    }

    // Evict the entire region
    public void evictAllAuthors() {
        entityManager.getEntityManagerFactory()
            .getCache()
            .evict(Author.class);
    }
}
```

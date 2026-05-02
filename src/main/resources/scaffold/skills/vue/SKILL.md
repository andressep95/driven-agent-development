---
name: vue
description: >
  Vue 3 core patterns: Composition API, script setup, reactivity system, composables,
  lifecycle hooks, slots, Vue Router 4, and Pinia state management.
  Trigger: When writing Vue 3 components, composables, routing, or state management without a specific UI library.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Create a Vue 3 component"
    - "Write a Vue composable"
    - "Setup Vue Router with navigation guards"
    - "Define a Pinia store"
    - "Use ref reactive computed watch in Vue"
    - "Vue 3 lifecycle hooks"
    - "Vue 3 provide inject pattern"
    - "Vue slots scoped slots"
    - "Lazy load Vue route"
    - "Vue script setup TypeScript"
    - "storeToRefs Pinia"
    - "Vue 3 project structure"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

# Vue 3

Guía de patrones core para Vue 3: Composition API, reactividad, composables, Vue Router 4 y Pinia.

> Para componentes de UI con PrimeVue, carga también el skill `vue-primevue`.

## When to Use (and When NOT to)

| Use When | Skip When |
|----------|-----------|
| Creando o editando archivos `.vue` | Lógica de servidor / backend |
| Escribiendo composables compartidos | El componente es trivial (< 10 líneas) |
| Configurando Vue Router o Pinia | Ya está cubierto por `vue-primevue` |
| Necesitas reactividad, watchers, lifecycle | |

## Quick Diagnosis

```
¿Qué necesito?
├─ Estado local en un componente     → ref() / reactive()
├─ Estado derivado                   → computed()
├─ Reaccionar a cambios              → watch() / watchEffect()
├─ Lógica reutilizable               → composable useXxx()
├─ Pasar datos hacia abajo           → defineProps<T>()
├─ Pasar datos hacia arriba          → defineEmits<T>()
├─ Árbol profundo sin prop drilling  → provide() / inject()
├─ Estado global                     → Pinia defineStore()
├─ Navegación                        → Vue Router useRouter/useRoute
└─ DOM actualizado después de cambio → await nextTick()
```

## Critical Rules

| Regla | Por qué |
|-------|---------|
| **Siempre `<script setup>`** | Menos boilerplate, mejor inferencia TS |
| **Nunca mutar props** | Rompe el flujo unidireccional — emitir evento |
| **`storeToRefs()` para desestructurar store** | La desestructuración directa pierde reactividad |
| **`toRef(() => props.foo)` para pasar props a composables** | Mantiene el vínculo reactivo |
| **`await nextTick()` antes de leer DOM tras cambio de estado** | El DOM se actualiza de forma asíncrona |
| **Retornar todo el estado desde composables** | Permite testear y desestructurar |

## Patrones

### 1. Componente base con `<script setup>`

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

const props = defineProps<{
  title: string
  items?: string[]
}>()

const emit = defineEmits<{
  (e: 'select', value: string): void
}>()

const selected = ref('')
const count = computed(() => props.items?.length ?? 0)

onMounted(() => {
  console.log('mounted, items:', count.value)
})

function handleSelect(value: string) {
  selected.value = value
  emit('select', value)
}
</script>

<template>
  <div>
    <h2>{{ title }} ({{ count }})</h2>
    <ul>
      <li v-for="item in items" :key="item" @click="handleSelect(item)">
        {{ item }}
      </li>
    </ul>
  </div>
</template>
```

### 2. Reactividad — ref / reactive / computed / watch

```typescript
import { ref, reactive, computed, watch, watchEffect } from 'vue'

// ref: valor primitivo o reemplazable
const count = ref(0)
count.value++

// reactive: objeto con propiedades múltiples
const state = reactive({ name: '', age: 0 })
state.name = 'Ana'

// computed: valor derivado (cacheado)
const doubled = computed(() => count.value * 2)

// watch: reacción explícita con valor anterior
watch(count, (newVal, oldVal) => {
  console.log(newVal, oldVal)
})

// watchEffect: tracking automático de dependencias
watchEffect(() => {
  console.log('count is', count.value)
})
```

### 3. Composable — patrón estándar

```typescript
// composables/useUsers.ts
import { ref } from 'vue'

export function useUsers() {
  const users = ref<User[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchUsers() {
    loading.value = true
    error.value = null
    try {
      const res = await fetch('/api/users')
      users.value = await res.json()
    } catch (e) {
      error.value = 'Error al cargar usuarios'
    } finally {
      loading.value = false
    }
  }

  return { users, loading, error, fetchUsers }
}
```

```vue
<!-- Uso en componente -->
<script setup lang="ts">
import { onMounted } from 'vue'
import { useUsers } from '@/composables/useUsers'

const { users, loading, error, fetchUsers } = useUsers()
onMounted(fetchUsers)
</script>
```

### 4. provide / inject — árbol de componentes

```vue
<!-- Proveedor (ancestro) -->
<script setup>
import { provide, ref } from 'vue'

const theme = ref('light')
provide('theme', {
  theme,
  toggle: () => { theme.value = theme.value === 'light' ? 'dark' : 'light' }
})
</script>

<!-- Consumidor (cualquier descendiente) -->
<script setup>
import { inject } from 'vue'
const { theme, toggle } = inject('theme')
</script>
```

### 5. Slots — named y scoped

```vue
<!-- Componente que expone slots -->
<template>
  <div class="card">
    <header><slot name="header" /></header>
    <main><slot :items="items" /></main>  <!-- scoped slot -->
    <footer><slot name="footer" /></footer>
  </div>
</template>

<!-- Uso -->
<MyCard :items="list">
  <template #header>Título</template>
  <template #default="{ items }">
    <li v-for="item in items" :key="item.id">{{ item.name }}</li>
  </template>
  <template #footer>Footer</template>
</MyCard>
```

### 6. Componentes async y KeepAlive

```typescript
import { defineAsyncComponent } from 'vue'

// Carga diferida — genera chunk separado en el bundle
const HeavyChart = defineAsyncComponent(() => import('./HeavyChart.vue'))
```

```vue
<!-- Caché de instancias — preserva estado al cambiar tabs -->
<KeepAlive>
  <component :is="activeTab" />
</KeepAlive>
```

### 7. Utilidades de reactividad

```typescript
import { toRef, toRefs, shallowRef, nextTick } from 'vue'

// toRef: referencia reactiva a una prop (sin romper el vínculo)
useSomeFeature(toRef(() => props.foo))   // sintaxis getter (Vue 3.3+)

// toRefs: desestructurar reactive sin perder reactividad
const state = reactive({ x: 0, y: 0 })
const { x, y } = toRefs(state)   // x.value sigue reactivo

// shallowRef: solo el .value es reactivo (no sus propiedades internas)
const big = shallowRef({ data: [] })

// nextTick: esperar a que el DOM se actualice
count.value++
await nextTick()
console.log(el.value.textContent)  // DOM ya actualizado
```

---

## Vue Router 4

### 8. Configuración del router

```typescript
// router/index.ts
import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      component: () => import('@/views/HomeView.vue')  // lazy
    },
    {
      path: '/users/:id',
      component: () => import('@/views/UserView.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: 'profile', component: () => import('@/views/UserProfile.vue') },
        { path: 'posts',   component: () => import('@/views/UserPosts.vue') }
      ]
    }
  ]
})

// Guard global
router.beforeEach((to) => {
  if (to.meta.requiresAuth && !isAuthenticated()) return '/login'
})

export default router
```

### 9. useRouter / useRoute en componentes

```vue
<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router'

const router = useRouter()
const route = useRoute()

// Leer parámetros
const userId = route.params.id      // /users/42 → '42'
const q = route.query.search        // ?search=vue → 'vue'

// Navegar
function goToUser(id: number) {
  router.push({ name: 'UserProfile', params: { id } })
}

function goBack() {
  router.back()
}
</script>
```

---

## Pinia

### 10. Setup Store (recomendado)

```typescript
// stores/useCounterStore.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCounterStore = defineStore('counter', () => {
  // state
  const count = ref(0)
  const name = ref('default')

  // getters
  const doubled = computed(() => count.value * 2)

  // actions
  function increment() { count.value++ }
  async function fetchCount() {
    count.value = await api.getCount()
  }

  return { count, name, doubled, increment, fetchCount }
})
```

### 11. Usar el store en un componente

```vue
<script setup lang="ts">
import { storeToRefs } from 'pinia'
import { useCounterStore } from '@/stores/useCounterStore'

const store = useCounterStore()

// storeToRefs preserva reactividad al desestructurar state/getters
const { count, doubled } = storeToRefs(store)

// Las acciones se desestructuran directamente (no necesitan storeToRefs)
const { increment, fetchCount } = store
</script>

<template>
  <button @click="increment">{{ count }} (x2: {{ doubled }})</button>
</template>
```

### 12. Options Store (alternativa)

```typescript
export const useTodosStore = defineStore('todos', {
  state: () => ({
    todos: [] as Todo[],
    filter: 'all' as 'all' | 'done' | 'pending'
  }),
  getters: {
    done: (state) => state.todos.filter(t => t.done),
    pending: (state) => state.todos.filter(t => !t.done)
  },
  actions: {
    add(text: string) {
      this.todos.push({ id: Date.now(), text, done: false })
    },
    toggle(id: number) {
      const t = this.todos.find(t => t.id === id)
      if (t) t.done = !t.done
    }
  }
})
```

---

## Install Commands

```bash
# Scaffold de proyecto
npm create vue@latest my-app
# Seleccionar: TypeScript ✓ | Vue Router ✓ | Pinia ✓

# Instalar en proyecto existente
npm install vue@3 vue-router@4 pinia
```

## Review Checklist

```
[ ] Usando <script setup> con lang="ts"
[ ] Props con defineProps<T>() usando tipos genéricos
[ ] Emits con defineEmits<T>() tipados
[ ] No se mutan props directamente
[ ] Composables retornan { data, loading, error, action }
[ ] storeToRefs() usado para desestructurar state/getters del store
[ ] Rutas lazy-loaded con () => import(...)
[ ] Guards de navegación definidos en el router (no en componentes)
[ ] provide/inject usado en lugar de prop drilling > 2 niveles
[ ] nextTick() usado cuando se lee DOM tras cambio de estado
```

## Internal Reference

| File | Content |
|------|---------|
| [references/REACTIVITY.md](references/REACTIVITY.md) | API completa de reactividad |
| [references/ROUTER.md](references/ROUTER.md) | Vue Router: guards, rutas dinámicas, meta |
| [references/PINIA.md](references/PINIA.md) | Pinia: setup store, options store, $patch, $reset |
| [references/CHEATSHEET.md](references/CHEATSHEET.md) | Guía de decisiones rápidas |

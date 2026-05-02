# Pinia Reference

## Cuándo usar Setup Store vs Options Store

| Setup Store | Options Store |
|-------------|---------------|
| Preferido — mismo estilo que `<script setup>` | Familiaridad con Vuex |
| Mejor inferencia TypeScript | Stores simples sin lógica async compleja |
| Composables internos al store | `$reset()` disponible automáticamente |

## Setup Store — patrón completo

```typescript
// stores/useAuthStore.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  // state — refs
  const user = ref<User | null>(null)
  const token = ref<string | null>(localStorage.getItem('token'))

  // getters — computed
  const isLoggedIn = computed(() => !!token.value)
  const fullName   = computed(() => user.value ? `${user.value.name}` : '')

  // actions — functions
  async function login(credentials: Credentials) {
    const data = await authApi.login(credentials)
    token.value = data.token
    user.value  = data.user
    localStorage.setItem('token', data.token)
  }

  function logout() {
    user.value  = null
    token.value = null
    localStorage.removeItem('token')
  }

  return { user, token, isLoggedIn, fullName, login, logout }
})
```

## Usar el store correctamente

```typescript
import { storeToRefs } from 'pinia'
import { useAuthStore } from '@/stores/useAuthStore'

const store = useAuthStore()

// ✅ storeToRefs para state y getters — mantiene reactividad
const { user, isLoggedIn, fullName } = storeToRefs(store)

// ✅ acciones directamente del store
const { login, logout } = store

// ❌ INCORRECTO — desestructurar sin storeToRefs pierde reactividad
const { user } = store   // user ya no es reactivo
```

## Métodos de store built-in

```typescript
const store = useCounterStore()

// Mutar múltiples propiedades en una sola operación
store.$patch({ count: 10, name: 'updated' })
store.$patch((state) => { state.items.push(newItem) })

// Resetear al estado inicial (solo Options Store)
store.$reset()

// Suscribirse a cambios de estado
store.$subscribe((mutation, state) => {
  localStorage.setItem('counter', JSON.stringify(state))
})

// Suscribirse a acciones
store.$onAction(({ name, args, after, onError }) => {
  after((result) => { console.log(`${name} finished`, result) })
  onError((error) => { console.error(`${name} failed`, error) })
})
```

## Registrar Pinia en main.js

```typescript
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
app.use(createPinia())
app.mount('#app')
```

## Estructura de archivos recomendada

```
src/
└── stores/
    ├── useAuthStore.ts
    ├── useCartStore.ts
    └── useNotificationStore.ts
```

Convención: prefijo `use` + nombre en PascalCase + sufijo `Store`.

# Vue Router 4 Reference

## Setup completo

```typescript
// router/index.ts
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/HomeView.vue')
  },
  {
    path: '/users',
    component: () => import('@/views/UsersLayout.vue'),
    children: [
      { path: '',       name: 'UserList',    component: () => import('@/views/UserList.vue') },
      { path: ':id',    name: 'UserDetail',  component: () => import('@/views/UserDetail.vue') },
      { path: ':id/edit', name: 'UserEdit', component: () => import('@/views/UserEdit.vue'), meta: { requiresAuth: true } }
    ]
  },
  { path: '/:pathMatch(.*)*', name: 'NotFound', component: () => import('@/views/NotFound.vue') }
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

// Guard global — auth
router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { name: 'Login', query: { redirect: to.fullPath } }
  }
})

export default router
```

## Composables en componentes

```vue
<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router'

const router = useRouter()
const route  = useRoute()

// Leer params / query
const id     = route.params.id        // '/users/42' → '42'
const search = route.query.q          // '?q=vue' → 'vue'
const meta   = route.meta             // objeto tipado si se declara

// Navegar
router.push({ name: 'UserDetail', params: { id: 5 } })
router.push({ path: '/users', query: { page: 2 } })
router.replace('/login')
router.back()
router.go(-2)
</script>
```

## Tipos de guards

| Guard | Dónde se define | Cuándo aplica |
|-------|----------------|---------------|
| `router.beforeEach` | router/index.ts | Toda navegación |
| `router.afterEach` | router/index.ts | Post-navegación (analytics) |
| `beforeEnter` en ruta | routes array | Solo esa ruta |
| `onBeforeRouteLeave` | componente | Antes de salir de la ruta actual |
| `onBeforeRouteUpdate` | componente | Ruta cambia pero componente se reutiliza |

```vue
<!-- onBeforeRouteLeave — confirmar salida con cambios sin guardar -->
<script setup>
import { onBeforeRouteLeave } from 'vue-router'

onBeforeRouteLeave((to, from) => {
  if (hasUnsavedChanges.value) {
    return window.confirm('¿Salir sin guardar?')
  }
})
</script>
```

## Modos de history

| Modo | Función | URL | Requiere server config |
|------|---------|-----|----------------------|
| HTML5 | `createWebHistory()` | `/users/42` | Sí (fallback a index.html) |
| Hash | `createWebHashHistory()` | `/#/users/42` | No |
| Memory | `createMemoryHistory()` | ninguna | SSR / tests |

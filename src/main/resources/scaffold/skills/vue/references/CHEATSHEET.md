# Vue 3 — Quick Decision Guide

## ¿Qué API de reactividad uso?

```
¿Qué estoy guardando?
├─ Un valor simple (string, number, boolean)  → ref()
├─ Un booleano de UI (loading, visible)       → ref(false)
├─ Un objeto con múltiples campos             → reactive() o ref({})
├─ Un valor derivado de otros                 → computed()
└─ Un array de items                          → ref([])
```

## ¿Cuándo uso watch vs watchEffect?

| Necesito... | Usar |
|-------------|------|
| Valor anterior y nuevo | `watch(source, (new, old) => ...)` |
| Múltiples fuentes | `watch([a, b], ...)` |
| Correr inmediatamente | `watch(source, cb, { immediate: true })` |
| Tracking automático sin declarar fuente | `watchEffect(() => ...)` |
| Correr después del DOM update | `watchEffect(cb, { flush: 'post' })` |

## ¿Cómo paso datos entre componentes?

```
¿Cuántos niveles?
├─ 1 nivel hacia abajo         → defineProps
├─ 1 nivel hacia arriba        → defineEmits
├─ 2-3 niveles                 → provide/inject
├─ Global o múltiples ramas    → Pinia store
└─ Componente hermano          → Pinia store o emit al padre común
```

## ¿Dónde va la lógica?

| Tipo de lógica | Dónde va |
|----------------|---------|
| Local al componente | Dentro de `<script setup>` |
| Compartida entre componentes | `composables/useXxx.ts` |
| Estado global de app | Pinia `stores/useXxxStore.ts` |
| Config de rutas / guards | `router/index.ts` |

## Errores comunes

| Error | Fix |
|-------|-----|
| `const { count } = store` — no reactivo | `const { count } = storeToRefs(store)` |
| `props.items.push(...)` — mutación directa | Emitir evento al padre |
| `const { x } = reactive(obj)` — no reactivo | `const { x } = toRefs(reactive(obj))` |
| Leer DOM justo después de `state.value = X` | `await nextTick()` antes de leer |
| `ref` no disponible al llamar composable con prop | `toRef(() => props.foo)` |
| Componente pesado cargado en el bundle inicial | `defineAsyncComponent(() => import(...))` |

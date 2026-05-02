# Vue 3 — Reactivity API Reference

## Core Reactive APIs

| API | Uso | Notas |
|-----|-----|-------|
| `ref(val)` | Valor primitivo o reemplazable | Acceder con `.value` en JS, sin `.value` en template |
| `reactive(obj)` | Objeto con múltiples propiedades | No reemplazar el objeto completo — pierde reactividad |
| `computed(() => ...)` | Valor derivado cacheado | Solo recalcula cuando dependencias cambian |
| `watch(source, cb)` | Reacción explícita con valor anterior | Útil para side effects con control |
| `watchEffect(cb)` | Tracking automático de dependencias | Corre inmediatamente, no recibe valor anterior |
| `shallowRef(val)` | Solo `.value` reactivo, no propiedades internas | Performance con objetos grandes |
| `readonly(obj)` | Versión de solo lectura de un reactive/ref | Evita mutaciones accidentales |

## Reactive Utilities

| API | Cuándo usar |
|-----|-------------|
| `toRef(() => props.foo)` | Pasar prop a composable manteniendo reactividad (Vue 3.3+) |
| `toRefs(state)` | Desestructurar `reactive()` sin perder reactividad |
| `markRaw(obj)` | Excluir objeto del sistema reactivo (librerías de terceros) |
| `nextTick()` | Leer DOM después de cambio de estado |
| `isRef(val)` | Type guard para refs |
| `unref(val)` | Obtener valor sin importar si es ref o no |

## Lifecycle Hooks

| Hook | Cuándo corre |
|------|-------------|
| `onBeforeMount` | Antes de insertar en DOM |
| `onMounted` | DOM insertado — safe para acceder refs del DOM |
| `onBeforeUpdate` | Antes de re-render por cambio de estado |
| `onUpdated` | Después de re-render |
| `onBeforeUnmount` | Antes de destruir el componente |
| `onUnmounted` | Componente destruido — limpiar listeners, timers |
| `onErrorCaptured` | Capturar errores de componentes hijos |

```typescript
import { onMounted, onUnmounted } from 'vue'

onMounted(() => {
  window.addEventListener('resize', onResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', onResize)  // siempre limpiar
})
```

## watch vs watchEffect

```typescript
// watch: control total — fuente explícita, cb con old/new, lazy por default
watch(count, (newVal, oldVal) => { /* ... */ })
watch([a, b], ([newA, newB]) => { /* ... */ })
watch(count, cb, { immediate: true, deep: true })

// watchEffect: automático — corre inmediatamente, sin valor anterior
watchEffect(() => {
  console.log(count.value, name.value)  // ambos son dependencias
})

// flush: cuándo corre el callback
watch(count, cb, { flush: 'post' })   // después del DOM update
watch(count, cb, { flush: 'sync' })   // síncronamente al cambio
```

## defineExpose — exponer al padre vía template ref

```vue
<script setup>
import { ref } from 'vue'

const inputEl = ref<HTMLInputElement | null>(null)

defineExpose({ focus: () => inputEl.value?.focus() })
</script>
```

```vue
<!-- Padre -->
<script setup>
const childRef = ref()
childRef.value.focus()
</script>
<template>
  <MyInput ref="childRef" />
</template>
```

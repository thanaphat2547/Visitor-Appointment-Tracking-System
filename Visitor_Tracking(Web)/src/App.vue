<template>
  <a-config-provider :theme="{
      token: {
        fontFamily: 'Prompt',
      },
    }">
  <div id="app" class="app-background" >
    <router-view />
  </div>
  </a-config-provider>
</template>

<script setup>
</script>
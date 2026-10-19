<template>
  <section id="about" class="grid md:grid-cols-8 gap-8 mt-4">
    <Card center grid-column="1 / -1" grid-row="1 / span 20">
      <p class="mt-4 outfit text-4xl md:text-5xl lg:text-7xl">
        ben costolo <span class="outfit text-xl md:text-2xl lg:text-4xl">(he/him)</span>
      </p>
      <p class="mt-4 outfit text-xl md:text-2xl lg:text-4xl">
        new york-based software engineer building apps for the web and mobile since 2015
      </p>
      <p class="mt-4 outfit text-lg md:text-xl lg:text-2xl">
        <NuxtLink to="/cv">view my cv</NuxtLink>
      </p>
      <Ocean />
    </Card>
  </section>
</template>

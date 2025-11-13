
pnpm dlx @vendure/create my-shop --log-level verbose

# 1) crear el proyecto
pnpm dlx @vendure/create my-shop --log-level verbose

# 2) entrar al proyecto
cd my-shop

# 3) fijar SWC como devDependency
pnpm add -D @swc/core@1.13.5

# 4) en el package.json (en la RAÍZ del proyecto) agrega:
# "overrides": { "@swc/core": "1.13.5" }

# 5) reinstalar para aplicar el override
pnpm install

# 6) verificar
pnpm ls @swc/core

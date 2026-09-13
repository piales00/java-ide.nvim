# java-ide.nvim

Trabaja con Java en Neovim como en IntelliJ: crea proyectos Maven y Spring Boot, clases con
su paquete, y ejecuta, compila y prueba tu código (o tu API) sin salir del editor.

> Se complementa con [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls), que da
> autocompletado, errores e imports automáticos. Este plugin cubre lo que jdtls no hace:
> crear proyectos y clases, y correr tu código.

## Qué hace

- **Nuevo proyecto** Maven (Java y JUnit 5 ya configurados), **Spring Boot** (con
  [start.spring.io](https://start.spring.io): eliges versión, Maven o Gradle y dependencias) o
  Java plano (`src/` + `out/`).
- **Nueva clase / interfaz / enum / record / test**: escribe `com.app.model.User` y se crean
  la carpeta y el `package` automáticamente. Los tests van solos a `src/test/java`.
- **Ejecutar el `main` del archivo abierto** en milisegundos: usa `java` directamente, compila
  solo si hay cambios y los imports entre paquetes funcionan. Puedes escribir input
  (`Scanner`) en la terminal.
- **APIs:** levanta tu aplicación Spring Boot con perfiles (`dev`, `prod`…) y variables de un
  archivo `.env`; la deja corriendo en segundo plano y la reinicia o detiene con una tecla.
- **Compilar, testear (archivo o todo), empaquetar y limpiar** con Maven o Gradle.
- **Agregar dependencias** al `pom.xml` con `groupId:artifactId:version`.
- `:checkhealth java_ide` para ver si te falta instalar algo.

## Requisitos

- Neovim >= 0.10
- JDK 17 o superior (`java` y `javac`)
- Maven (`mvn`) para proyectos Maven
- `curl` y `tar` para crear proyectos Spring Boot (vienen instalados en casi todos los sistemas)
- Opcional: [mvnd](https://github.com/apache/maven-mvnd) para que Maven sea más rápido, y
  Gradle si usas proyectos Gradle sin `./gradlew`
- Probado en Linux. En macOS debería funcionar igual; en Windows funcionan Maven y Gradle,
  pero no los proyectos Java planos

Instalar el JDK y Maven:

| Sistema | Comando |
| --- | --- |
| Arch | `sudo pacman -S jdk21-openjdk maven` |
| Ubuntu / Debian | `sudo apt install openjdk-21-jdk maven` |
| Fedora | `sudo dnf install java-21-openjdk-devel maven` |
| macOS | `brew install openjdk@21 maven` |

Instalar mvnd (opcional):

| Sistema | Comando |
| --- | --- |
| Arch (AUR) | `yay -S mvnd` |
| macOS | `brew install mvndaemon/homebrew-mvnd/mvnd` |
| Cualquiera ([SDKMAN](https://sdkman.io)) | `sdk install mvnd` |

## Instalación

### lazy.nvim / LazyVim

```lua
-- ~/.config/nvim/lua/plugins/java-ide.lua
return {
  "piales00/java-ide.nvim",
  main = "java_ide",
  event = "VeryLazy",
  opts = {},
}
```

Para tener también autocompletado y debugger en **LazyVim**, activa los extras `lang.java` y
`dap.core` con `:LazyExtras`.

> **Aviso LazyVim:** el extra `lang.java` usa `<leader>tt` y `<leader>tr` para los tests.
> Si ya usas esas teclas para otra cosa, desactívalo y usa `<leader>jt` / `<leader>jT`:
>
> ```lua
> { "mfussenegger/nvim-jdtls", opts = { test = false } }
> ```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({ "https://github.com/piales00/java-ide.nvim" })
require("java_ide").setup()
```

### vim-plug

```vim
Plug 'piales00/java-ide.nvim'
" después de plug#end():
lua require("java_ide").setup()
```

Después de instalar, ejecuta `:checkhealth java_ide` para comprobar que no falte nada.

### Actualizar

- lazy.nvim: `:Lazy update java-ide.nvim`
- vim.pack: `:lua vim.pack.update()`
- vim-plug: `:PlugUpdate`

## Primeros pasos

1. `<leader>jn` → elige **Maven** → escribe el nombre del proyecto, la carpeta, el groupId y
   el paquete (puedes aceptar las sugerencias con Enter).
2. Se crea el proyecto, Neovim se mueve a esa carpeta y abre `Main.java`.
3. `<leader>jr` para ejecutarlo. La primera vez tarda unos segundos porque Maven descarga lo
   que necesita; las siguientes son casi instantáneas.
4. `<leader>jc` → **Class** → `com.example.miapp.model.User` para crear una clase en otro
   paquete. Úsala desde `Main` y vuelve a ejecutar.
5. `<leader>jt` en `MainTest.java` para correr los tests.

Estructura que genera un proyecto Maven:

```
miapp/
├── pom.xml
├── .gitignore
└── src/
    ├── main/
    │   ├── java/com/example/miapp/Main.java
    │   └── resources/
    └── test/
        └── java/com/example/miapp/MainTest.java
```

Un proyecto Java plano es solo `src/<paquete>/Main.java`; al ejecutar se compila a `out/`.

> Abre Neovim siempre en la **carpeta raíz del proyecto** (donde está el `pom.xml`), así jdtls
> reconoce el proyecto completo.

## Uso

| Tecla | Comando | Acción |
| --- | --- | --- |
| `<leader>jn` | `:JavaNewProject` | Nuevo proyecto |
| `<leader>jc` | `:JavaNewClass` | Nueva clase / interfaz / enum / record / test |
| `<leader>jr` | `:JavaRun [args]` | Ejecutar el `main` del archivo abierto |
| `<leader>jR` | `:JavaRunArgs` | Ejecutar pidiendo argumentos (recuerda los últimos) |
| `<leader>js` | `:JavaStop` | Detener lo que se está ejecutando |
| `<leader>jo` | `:JavaTerminal` | Mostrar u ocultar la terminal de ejecución |
| `<leader>jP` | `:JavaProfile` | Elegir el perfil de Spring |
| `<leader>jb` | `:JavaBuild` | Compilar |
| `<leader>jt` | `:JavaTestFile` | Tests del archivo abierto |
| `<leader>jT` | `:JavaTest` | Todos los tests |
| `<leader>jp` | `:JavaPackage` | Generar el jar |
| `<leader>jx` | `:JavaClean` | Clean (borra `target/` o `build/`) |
| `<leader>jd` | `:JavaAddDependency` | Agregar dependencia Maven |
| `<leader>ju` | `:JavaRefresh` | Recargar la configuración de jdtls |

Todo se ejecuta en una terminal abajo. Cada ejecución detiene y reemplaza a la anterior. Con `q`
(en modo normal) se cierra la ventana, pero **el proceso sigue corriendo** (útil para una API):
`<leader>jo` la vuelve a mostrar y `<leader>js` lo detiene.

`:JavaNewSpringProject` abre directamente el asistente de Spring Boot.

### ¿Qué clase se ejecuta?

1. La del archivo abierto, si tiene `main`.
2. Si no, la última que ejecutaste en ese proyecto (así puedes estar en un controller y
   reiniciar la API).
3. Si no, la configurada en el `pom.xml` (`exec.mainClass` o `start-class`).
4. Si no, la única clase con `main` del proyecto, o te pregunta cuál si hay varias.

### Nueva clase

Elige el tipo (Class, Interface, Enum, Record, Abstract class, Main class o JUnit test) y
escribe el nombre:

- Con paquete (`com.app.model.User`): se crea `com/app/model/User.java` con su `package`.
- Sin paquete (`User`): se crea en la raíz de fuentes, sin `package`.
- Se sugiere el paquete del archivo que tienes abierto.
- En Maven/Gradle, los tests se crean en `src/test/java` y lo demás en `src/main/java`.

### Agregar dependencias

`<leader>jd` y escribe las coordenadas, por ejemplo:

```
com.google.code.gson:gson:2.11.0
org.projectlombok:lombok:1.18.36:provided
```

Se agregan al `<dependencies>` del proyecto y se recarga jdtls. Las coordenadas se buscan en
[Maven Central](https://central.sonatype.com).

## Spring Boot y APIs

### Crear el proyecto

`<leader>jn` → **Spring Boot** y responde:

1. Build: Maven, Gradle (Groovy) o Gradle (Kotlin DSL).
2. Versión de Spring Boot (la recomendada aparece primero).
3. Nombre, carpeta, groupId y paquete.
4. Dependencias: se muestran solo las compatibles con esa versión. Con el picker de
   [Snacks](https://github.com/folke/snacks.nvim) (LazyVim) marcas varias con `Tab` y confirmas
   con `Enter`; si no marcas ninguna, se usa la que tiene el cursor. Sin Snacks, las agregas de
   a una y eliges **✔ Crear proyecto** al terminar.

El proyecto se descarga de start.spring.io, se abre la clase `*Application.java` y se agrega
`.env` al `.gitignore`. La versión de Java es la que tienes instalada (o la más cercana que
ofrezca start.spring.io).

### Ejecutar la API

`<leader>jr` levanta la aplicación con el modo rápido (con Maven) o con `bootRun` (con Gradle).
Puedes seguir editando: cuando quieras aplicar cambios, `<leader>jr` otra vez detiene la API,
espera a que libere el puerto y la vuelve a levantar.

**Variables de entorno (`.env`).** Si hay un archivo `.env` en la raíz del proyecto, sus
variables se pasan al ejecutar y a los tests:

```sh
# .env (no se sube a git)
DB_URL=jdbc:postgresql://localhost:5432/tienda
DB_USER=admin
DB_PASSWORD="mi clave"
```

```properties
# application.properties
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
```

**Perfiles.** `<leader>jP` muestra los perfiles que encuentra (`application-dev.yml` → `dev`),
o puedes escribir otros separados por coma. El perfil elegido se guarda por proyecto y se pasa
como `SPRING_PROFILES_ACTIVE` al ejecutar (no a los tests, que suelen usar `@ActiveProfiles`).

### Probar endpoints

Con [kulala.nvim](https://github.com/mistweaverco/kulala.nvim) pruebas tu API desde archivos
`.http`, como el cliente HTTP de IntelliJ. En LazyVim se activa con `:LazyExtras` → `util.rest`.

```http
### Listar productos
GET http://localhost:8080/api/productos

### Crear producto
POST http://localhost:8080/api/productos
Content-Type: application/json

{ "nombre": "Teclado", "precio": 25.5 }
```

Pon el cursor sobre una petición y usa `<leader>Rs` para enviarla (atajos del extra de LazyVim).

### Autocompletado de Spring (opcional)

[spring-boot.nvim](https://github.com/JavaHello/spring-boot.nvim) agrega lo que da la extensión de
Spring de VS Code: autocompletado en `application.properties`/`application.yml`, buscar beans y
endpoints (símbolos del workspace con `@/`, por ejemplo `@/hello -- GET`) y code actions.
Con LazyVim y el extra `lang.java`:

```lua
-- ~/.config/nvim/lua/plugins/spring-boot.lua
return {
  {
    "JavaHello/spring-boot.nvim",
    ft = { "java", "yaml", "jproperties" },
    dependencies = { "mfussenegger/nvim-jdtls" },
    opts = {},
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "vscode-spring-boot-tools" } },
  },
  {
    "mfussenegger/nvim-jdtls",
    opts = {
      -- Agrega las extensiones de Spring a jdtls sin quitar las del debugger.
      jdtls = function(config)
        local bundles = vim.deepcopy(config.init_options.bundles or {})
        vim.list_extend(bundles, require("spring_boot").java_extensions())
        config.init_options.bundles = bundles
        return config
      end,
    },
  },
}
```

La primera vez Mason descarga `vscode-spring-boot-tools` (~90 MB).

### ¿Cómo ejecuta?

`<leader>jr` no pasa por Maven: ejecuta tu clase con `java` directamente y solo compila si
algo cambió. Por eso es rápido:

| Situación | Tiempo aproximado |
| --- | --- |
| Sin cambios, o jdtls ya compiló al guardar | **~50 ms** |
| Con cambios (compila con `javac`) | ~0.6 s |
| Primera vez, o cambiaste el `pom.xml` (calcula el classpath con Maven) | ~3 s |
| Con `mvn compile exec:java` (versión 1.0) | ~3 s siempre |

| Proyecto | Qué hace |
| --- | --- |
| Maven | Guarda en caché las dependencias (`target/java-ide/`), compila `src/main/java` a `target/classes` si hace falta, copia `src/main/resources` y ejecuta `java -cp target/classes:<jars> <clase>`. Las dependencias `test` y `provided` no se incluyen al ejecutar, igual que con Maven |
| Gradle | `./gradlew bootRun` en Spring Boot; si no, `./gradlew run` (necesita el plugin `application`) |
| Sin build tool | Compila `src/` a `out/` si hace falta y ejecuta `java -cp out <clase>` |

Detalles:

- Lombok funciona con el modo rápido: si el procesador de anotaciones también es una dependencia
  (como en los proyectos de start.spring.io), `javac` lo usa directamente.
- Si el `pom.xml` usa cosas que `javac` solo no reproduce (módulos, procesadores que no son
  dependencias como MapStruct, código generado, filtrado de recursos, `@project.version@` en
  `application.properties`…), se compila con `mvn compile` y después se ejecuta con `java`.
- Los `main` dentro de `src/test/java` se ejecutan con `mvn exec:java`.
- Con `fast_run = false` se usa `mvn spring-boot:run` (Spring Boot) o `mvn compile exec:java`.
- Compilar, tests y jar usan Maven (o `mvnd` si está instalado).
- En Windows, `<leader>jr` usa `mvn spring-boot:run` o `mvn compile exec:java`.
- Proyectos multi-módulo: por ahora no están soportados. Solo funciona un módulo que no
  dependa de otros módulos del mismo proyecto.

## Configuración

Estos son los valores por defecto:

```lua
require("java_ide").setup({
  projects_dir = "~/Projects",   -- carpeta sugerida para proyectos nuevos
  java_version = nil,            -- nil = detectar la del `java` instalado
  group_id = "com.example",      -- groupId sugerido
  fast_run = true,               -- false = ejecutar siempre con `mvn compile exec:java`
  maven = nil,                   -- comando de Maven; nil = `mvnd` si está instalado, si no `mvn`
  env_file = ".env",             -- variables de entorno al ejecutar; false = no cargar
  spring = {
    initializr_url = "https://start.spring.io", -- o el Initializr de tu empresa
  },
  terminal = { position = "bottom", size = 0.4 }, -- o position = "right"
  keymaps = { prefix = "<leader>j" },             -- false = sin atajos
})
```

Con lazy.nvim, esas opciones van dentro de `opts = { ... }`.

## Problemas comunes

**Al ejecutar aparece `Unresolved compilation problem`.**
Guardaste con errores y jdtls generó las clases igual. Corrige el error (lo ves marcado en el
editor) y vuelve a ejecutar.

**Algo quedó raro después de cambiar muchas cosas.**
`<leader>jx` (clean) borra `target/` junto con la caché, y la próxima ejecución compila todo
de nuevo.

**No hay autocompletado ni errores en el editor.**
Eso lo da jdtls, no este plugin. Revisa que nvim-jdtls esté instalado (`:checkhealth java_ide`),
que abriste Neovim en la raíz del proyecto y espera unos segundos a que indexe la primera vez.
Después de agregar dependencias a mano en el `pom.xml`, usa `<leader>ju`.

**`mvn` o `javac` no encontrado.**
Instala el JDK completo y Maven (ver [Requisitos](#requisitos)). `:checkhealth java_ide` te
dice qué falta.

**La API no arranca: `Port 8080 was already in use`.**
Otra aplicación usa el puerto, por ejemplo una que levantaste fuera de Neovim. Detenla o cambia
`server.port` en `application.properties`. Las que levanta el plugin se detienen solas al
volver a ejecutar.

**No aparecen dependencias al crear un proyecto Spring Boot.**
Se necesita conexión a internet para consultar start.spring.io. Revisa también que `curl`
esté instalado (`:checkhealth java_ide`).

**La primera ejecución de un proyecto nuevo tarda.**
Es normal: Maven descarga sus plugins y las dependencias una sola vez.

## Licencia

MIT

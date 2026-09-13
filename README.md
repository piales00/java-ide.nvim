# java-ide.nvim

Trabajá con Java en Neovim como en IntelliJ: creá proyectos Maven, clases con su
paquete, y ejecutá, compilá y testeá sin salir del editor.

> Se complementa con [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls), que da
> autocompletado, errores e imports automáticos. Este plugin cubre lo que jdtls no hace:
> crear proyectos y clases, y correr tu código.

## Qué hace

- **Nuevo proyecto** Maven (Java y JUnit 5 ya configurados) o Java plano (`src/` + `out/`).
- **Nueva clase / interfaz / enum / record / test**: escribí `com.app.model.User` y crea
  la carpeta y el `package` por vos. Los tests van solos a `src/test/java`.
- **Ejecutar el `main` del archivo abierto** compilando *todo* el proyecto, así los
  imports entre paquetes funcionan. Podés escribir input (`Scanner`) en la terminal.
- **Compilar, testear (archivo o todo), empaquetar y limpiar** con Maven o Gradle.
- **Agregar dependencias** al `pom.xml` con `groupId:artifactId:version`.
- `:checkhealth java_ide` para ver si te falta instalar algo.

## Requisitos

- Neovim >= 0.10
- JDK 17 o superior (`java` y `javac`)
- Maven (`mvn`) para proyectos Maven; Gradle es opcional
- Linux o macOS (en Windows funcionan Maven/Gradle, pero no los proyectos Java planos)

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

Para tener también autocompletado y debugger en **LazyVim**, activá los extras `lang.java` y
`dap.core` con `:LazyExtras`.

> **Aviso LazyVim:** el extra `lang.java` usa `<leader>tt` y `<leader>tr` para los tests.
> Si esas teclas ya las usás para otra cosa, desactivalo y usá `<leader>jt` / `<leader>jT`:
>
> ```lua
> { "mfussenegger/nvim-jdtls", opts = { test = false } }
> ```

### Otros gestores

Instalá el repo y llamá a `require("java_ide").setup()`.

## Uso

| Tecla | Comando | Acción |
| --- | --- | --- |
| `<leader>jn` | `:JavaNewProject` | Nuevo proyecto |
| `<leader>jc` | `:JavaNewClass` | Nueva clase / interfaz / enum / record / test |
| `<leader>jr` | `:JavaRun` | Ejecutar el `main` del archivo abierto |
| `<leader>jb` | `:JavaBuild` | Compilar |
| `<leader>jt` | `:JavaTestFile` | Tests del archivo abierto |
| `<leader>jT` | `:JavaTest` | Todos los tests |
| `<leader>jp` | `:JavaPackage` | Generar el jar |
| `<leader>jx` | `:JavaClean` | Clean |
| `<leader>jd` | `:JavaAddDependency` | Agregar dependencia Maven |
| `<leader>ju` | `:JavaRefresh` | Recargar la configuración de jdtls |

En la terminal de ejecución, `q` (en modo normal) la cierra. Cada ejecución reemplaza a la anterior.

### ¿Cómo ejecuta?

| Proyecto | Comando |
| --- | --- |
| Maven (`pom.xml`) | `mvn -q compile exec:java -Dexec.mainClass=<clase actual>` |
| Gradle (`build.gradle`) | `./gradlew run` (necesita el plugin `application`) |
| Sin build tool | `javac -d out <todos los .java de src/>` y después `java -cp out <clase>` |

Si el archivo abierto no tiene `main`, Maven usa `exec.mainClass` del `pom.xml`.

## Configuración

Estos son los valores por defecto:

```lua
require("java_ide").setup({
  projects_dir = "~/Projects",   -- carpeta sugerida para proyectos nuevos
  java_version = nil,            -- nil = detectar la del `java` instalado
  group_id = "com.example",      -- groupId sugerido
  terminal = { position = "bottom", size = 0.4 }, -- o position = "right"
  keymaps = { prefix = "<leader>j" },             -- false = sin atajos
})
```

## Licencia

MIT

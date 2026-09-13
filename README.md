<h1 align="center">java-ide.nvim</h1>

<p align="center">
  <a href="https://neovim.io"><img alt="Neovim 0.10+" src="https://img.shields.io/badge/Neovim-0.10%2B-57A143?style=for-the-badge&logo=neovim&logoColor=white"></a>
  <a href="https://www.lua.org"><img alt="Lua" src="https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white"></a>
  <a href="https://openjdk.org"><img alt="Java 17+" src="https://img.shields.io/badge/Java-17%2B-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white"></a>
  <a href="https://spring.io/projects/spring-boot"><img alt="Spring Boot" src="https://img.shields.io/badge/Spring_Boot-6DB33F?style=for-the-badge&logo=springboot&logoColor=white"></a>
  <a href="https://maven.apache.org"><img alt="Maven" src="https://img.shields.io/badge/Maven-C71A36?style=for-the-badge&logo=apachemaven&logoColor=white"></a>
  <a href="https://gradle.org"><img alt="Gradle" src="https://img.shields.io/badge/Gradle-02303A?style=for-the-badge&logo=gradle&logoColor=white"></a>
</p>

<p align="center">
  <a href="https://github.com/piales00/java-ide.nvim/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/piales00/java-ide.nvim?style=for-the-badge&color=blue"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/piales00/java-ide.nvim?style=for-the-badge&color=yellow"></a>
  <a href="https://github.com/piales00/java-ide.nvim/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/piales00/java-ide.nvim?style=for-the-badge"></a>
</p>

<p align="center">
  Work with Java in Neovim like you would in IntelliJ: create Maven and Spring Boot projects,
  create classes with their package, and run, build and test your code (or your API) without
  leaving the editor.
</p>

> Designed to work alongside [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls), which
> provides completion, diagnostics and automatic imports. This plugin covers what jdtls doesn't:
> creating projects and classes, and running your code.

> [!NOTE]
> The plugin's prompts and messages are currently in Spanish.

## Features

- **New project**: Maven (Java and JUnit 5 preconfigured), **Spring Boot** (via
  [start.spring.io](https://start.spring.io): pick the version, Maven or Gradle, and dependencies)
  or plain Java (`src/` + `out/`).
- **New class / interface / enum / record / test**: type `com.app.model.User` and the folder and
  `package` declaration are created for you. Tests go to `src/test/java` automatically.
- **Run the `main` of the current file** in milliseconds: it calls `java` directly, only compiles
  when something changed, and imports across packages just work. You can type input
  (`Scanner`) in the terminal.
- **APIs:** start your Spring Boot app with profiles (`dev`, `prod`…) and variables from a `.env`
  file; it keeps running in the background and you can restart or stop it with one key.
- **Build, test (current file or all), package and clean** with Maven or Gradle.
- **Add dependencies** to `pom.xml` with `groupId:artifactId:version`.
- `:checkhealth java_ide` to see if anything is missing.

## Requirements

- Neovim >= 0.10
- JDK 17 or newer (`java` and `javac`)
- Maven (`mvn`) for Maven projects
- `curl` and `tar` to create Spring Boot projects (preinstalled on almost every system)
- Optional: [mvnd](https://github.com/apache/maven-mvnd) to make Maven faster, and Gradle if your
  Gradle projects don't include `./gradlew`
- Tested on Linux. It should work the same on macOS; on Windows, Maven and Gradle projects work,
  but plain Java projects don't

Installing the JDK and Maven:

| System | Command |
| --- | --- |
| Arch | `sudo pacman -S jdk21-openjdk maven` |
| Ubuntu / Debian | `sudo apt install openjdk-21-jdk maven` |
| Fedora | `sudo dnf install java-21-openjdk-devel maven` |
| macOS | `brew install openjdk@21 maven` |

Installing mvnd (optional):

| System | Command |
| --- | --- |
| Arch (AUR) | `yay -S mvnd` |
| macOS | `brew install mvndaemon/homebrew-mvnd/mvnd` |
| Any ([SDKMAN](https://sdkman.io)) | `sdk install mvnd` |

## Installation

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

To also get completion and a debugger in **LazyVim**, enable the `lang.java` and `dap.core`
extras with `:LazyExtras`.

> [!WARNING]
> The LazyVim `lang.java` extra uses `<leader>tt` and `<leader>tr` for tests. If you already use
> those keys for something else, disable it and use `<leader>jt` / `<leader>jT` instead:
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
" after plug#end():
lua require("java_ide").setup()
```

After installing, run `:checkhealth java_ide` to make sure nothing is missing.

### Updating

- lazy.nvim: `:Lazy update java-ide.nvim`
- vim.pack: `:lua vim.pack.update()`
- vim-plug: `:PlugUpdate`

## Getting started

1. `<leader>jn` → choose **Maven** → enter the project name, folder, groupId and package (press
   Enter to accept the suggestions).
2. The project is created, Neovim switches to that folder and opens `Main.java`.
3. `<leader>jr` to run it. The first run takes a few seconds while Maven downloads what it needs;
   after that it's almost instant.
4. `<leader>jc` → **Class** → `com.example.myapp.model.User` to create a class in another
   package. Use it from `Main` and run again.
5. `<leader>jt` in `MainTest.java` to run the tests.

Structure of a generated Maven project:

```
myapp/
├── pom.xml
├── .gitignore
└── src/
    ├── main/
    │   ├── java/com/example/myapp/Main.java
    │   └── resources/
    └── test/
        └── java/com/example/myapp/MainTest.java
```

A plain Java project is just `src/<package>/Main.java`; it's compiled to `out/` when you run it.

> [!TIP]
> Always open Neovim in the **project root** (where `pom.xml` is) so jdtls picks up the whole
> project.

## Usage

| Key | Command | Action |
| --- | --- | --- |
| `<leader>jn` | `:JavaNewProject` | New project |
| `<leader>jc` | `:JavaNewClass` | New class / interface / enum / record / test |
| `<leader>jr` | `:JavaRun [args]` | Run the `main` of the current file |
| `<leader>jR` | `:JavaRunArgs` | Run asking for arguments (remembers the last ones) |
| `<leader>js` | `:JavaStop` | Stop what is running |
| `<leader>jo` | `:JavaTerminal` | Show or hide the run terminal |
| `<leader>jP` | `:JavaProfile` | Choose the Spring profile |
| `<leader>jb` | `:JavaBuild` | Build |
| `<leader>jt` | `:JavaTestFile` | Run the tests of the current file |
| `<leader>jT` | `:JavaTest` | Run all tests |
| `<leader>jp` | `:JavaPackage` | Build the jar |
| `<leader>jx` | `:JavaClean` | Clean (deletes `target/` or `build/`) |
| `<leader>jd` | `:JavaAddDependency` | Add a Maven dependency |
| `<leader>ju` | `:JavaRefresh` | Reload the jdtls configuration |

Everything runs in a terminal at the bottom. Each run stops and replaces the previous one.
Pressing `q` (in normal mode) closes the window, but **the process keeps running** (handy for an
API): `<leader>jo` shows it again and `<leader>js` stops it.

`:JavaNewSpringProject` opens the Spring Boot wizard directly.

### Which class runs?

1. The one in the current file, if it has a `main`.
2. Otherwise, the last one you ran in that project (so you can restart the API from a
   controller).
3. Otherwise, the one configured in `pom.xml` (`exec.mainClass` or `start-class`).
4. Otherwise, the only class with a `main` in the project, or it asks you which one if there are
   several.

### New class

Choose the type (Class, Interface, Enum, Record, Abstract class, Main class or JUnit test) and
type the name:

- With a package (`com.app.model.User`): creates `com/app/model/User.java` with its `package`.
- Without a package (`User`): creates it in the source root, with no `package`.
- The package of the file you have open is suggested.
- In Maven/Gradle projects, tests are created in `src/test/java` and everything else in
  `src/main/java`.

### Adding dependencies

Press `<leader>jd` and type the coordinates, for example:

```
com.google.code.gson:gson:2.11.0
org.projectlombok:lombok:1.18.36:provided
```

They are added to the project's `<dependencies>` and jdtls is reloaded. You can look up
coordinates on [Maven Central](https://central.sonatype.com).

## Spring Boot and APIs

### Creating the project

`<leader>jn` → **Spring Boot** and answer:

1. Build: Maven, Gradle (Groovy) or Gradle (Kotlin DSL).
2. Spring Boot version (the recommended one is listed first).
3. Name, folder, groupId and package.
4. Dependencies: only the ones compatible with that version are shown. With the
   [Snacks](https://github.com/folke/snacks.nvim) picker (LazyVim) you mark several with `Tab`
   and confirm with `Enter`; if you don't mark any, the one under the cursor is used. Without
   Snacks, you add them one at a time and choose **✔ Crear proyecto** when you're done.

The project is downloaded from start.spring.io, the `*Application.java` class is opened and
`.env` is added to `.gitignore`. The Java version is the one you have installed (or the closest
one start.spring.io offers).

### Running the API

`<leader>jr` starts the application with fast run (Maven) or `bootRun` (Gradle). You can keep
editing: when you want to apply your changes, `<leader>jr` again stops the API, waits for it to
free the port and starts it again.

**Environment variables (`.env`).** If there's a `.env` file in the project root, its variables
are passed when running and to tests:

```sh
# .env (never committed to git)
DB_URL=jdbc:postgresql://localhost:5432/shop
DB_USER=admin
DB_PASSWORD="my password"
```

```properties
# application.properties
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
```

**Profiles.** `<leader>jP` lists the profiles it finds (`application-dev.yml` → `dev`), or you
can type others separated by commas. The chosen profile is saved per project and passed as
`SPRING_PROFILES_ACTIVE` when running (not to tests, which usually use `@ActiveProfiles`).

### Testing endpoints

With [kulala.nvim](https://github.com/mistweaverco/kulala.nvim) you can test your API from `.http`
files, like IntelliJ's HTTP client. In LazyVim, enable it with `:LazyExtras` → `util.rest`.

```http
### List products
GET http://localhost:8080/api/products

### Create a product
POST http://localhost:8080/api/products
Content-Type: application/json

{ "name": "Keyboard", "price": 25.5 }
```

Put the cursor on a request and press `<leader>Rs` to send it (keymaps from the LazyVim extra).

### Spring completion (optional)

[spring-boot.nvim](https://github.com/JavaHello/spring-boot.nvim) brings what the VS Code Spring
extension offers: completion in `application.properties`/`application.yml`, finding beans and
endpoints (workspace symbols with `@/`, e.g. `@/hello -- GET`) and code actions. With LazyVim and
the `lang.java` extra:

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
      -- Add the Spring extensions to jdtls without removing the debugger ones.
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

The first time, Mason downloads `vscode-spring-boot-tools` (~90 MB).

### How does running work?

`<leader>jr` doesn't go through Maven: it runs your class with `java` directly and only compiles
when something changed. That's why it's fast:

| Situation | Approximate time |
| --- | --- |
| No changes, or jdtls already compiled on save | **~50 ms** |
| With changes (compiles with `javac`) | ~0.6 s |
| First run, or `pom.xml` changed (resolves the classpath with Maven) | ~3 s |
| With `mvn compile exec:java` (version 1.0) | ~3 s every time |

| Project | What it does |
| --- | --- |
| Maven | Caches the dependencies (`target/java-ide/`), compiles `src/main/java` to `target/classes` when needed, copies `src/main/resources` and runs `java -cp target/classes:<jars> <class>`. `test` and `provided` dependencies are left out at runtime, just like Maven does |
| Gradle | `./gradlew bootRun` for Spring Boot; otherwise `./gradlew run` (requires the `application` plugin) |
| No build tool | Compiles `src/` to `out/` when needed and runs `java -cp out <class>` |

Details:

- Lombok works with fast run: if the annotation processor is also a dependency (as in
  start.spring.io projects), `javac` uses it directly.
- If `pom.xml` uses things `javac` alone can't reproduce (modules, processors that aren't
  dependencies such as MapStruct, generated code, resource filtering, `@project.version@` in
  `application.properties`…), it compiles with `mvn compile` and then runs with `java`.
- A `main` inside `src/test/java` runs with `mvn exec:java`.
- With `fast_run = false`, it uses `mvn spring-boot:run` (Spring Boot) or `mvn compile exec:java`.
- Build, tests and jar use Maven (or `mvnd` if installed).
- On Windows, `<leader>jr` uses `mvn spring-boot:run` or `mvn compile exec:java`.
- Multi-module projects aren't supported yet. Only a module that doesn't depend on other modules
  of the same project works.

## Configuration

These are the defaults:

```lua
require("java_ide").setup({
  projects_dir = "~/Projects",   -- suggested folder for new projects
  java_version = nil,            -- nil = detect the installed `java`
  group_id = "com.example",      -- suggested groupId
  fast_run = true,               -- false = always run with `mvn compile exec:java`
  maven = nil,                   -- Maven command; nil = `mvnd` if installed, otherwise `mvn`
  env_file = ".env",             -- environment variables when running; false = don't load
  spring = {
    initializr_url = "https://start.spring.io", -- or your company's Initializr
  },
  terminal = { position = "bottom", size = 0.4 }, -- or position = "right"
  keymaps = { prefix = "<leader>j" },             -- false = no keymaps
})
```

With lazy.nvim, these options go inside `opts = { ... }`.

## Troubleshooting

**Running shows `Unresolved compilation problem`.**
You saved with errors and jdtls generated the classes anyway. Fix the error (it's highlighted in
the editor) and run again.

**Something looks off after changing a lot of things.**
`<leader>jx` (clean) deletes `target/` along with the cache, and the next run compiles
everything again.

**No completion or diagnostics in the editor.**
That comes from jdtls, not from this plugin. Check that nvim-jdtls is installed
(`:checkhealth java_ide`), that you opened Neovim in the project root, and give it a few seconds
to index the first time. After editing dependencies by hand in `pom.xml`, use `<leader>ju`.

**`mvn` or `javac` not found.**
Install the full JDK and Maven (see [Requirements](#requirements)). `:checkhealth java_ide` tells
you what's missing.

**The API doesn't start: `Port 8080 was already in use`.**
Another application is using the port, for example one you started outside Neovim. Stop it or
change `server.port` in `application.properties`. Apps started by the plugin are stopped
automatically when you run again.

**No dependencies show up when creating a Spring Boot project.**
An internet connection is needed to reach start.spring.io. Also check that `curl` is installed
(`:checkhealth java_ide`).

**The first run of a new project is slow.**
That's expected: Maven downloads its plugins and your dependencies only once.

## License

[MIT](LICENSE)

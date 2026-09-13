local M = {}

function M.pom(opts)
  return string.format(
    [[
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>%s</groupId>
  <artifactId>%s</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.release>%s</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <exec.mainClass>%s</exec.mainClass>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>5.11.4</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.13.0</version>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.5.2</version>
      </plugin>
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>exec-maven-plugin</artifactId>
        <version>3.5.0</version>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-jar-plugin</artifactId>
        <version>3.4.2</version>
        <configuration>
          <archive>
            <manifest>
              <mainClass>${exec.mainClass}</mainClass>
            </manifest>
          </archive>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>]],
    opts.group_id,
    opts.artifact_id,
    opts.java_version,
    opts.main_class
  )
end

M.gitignore = {
  "target/",
  "build/",
  "out/",
  ".gradle/",
  "*.class",
  ".idea/",
  "*.iml",
  ".classpath",
  ".project",
  ".settings/",
  ".env",
}

-- Tipos de archivo para "nueva clase". `%s` es el nombre de la clase.
M.kinds = {
  { name = "Class", body = "public class %s {\n\n}" },
  { name = "Interface", body = "public interface %s {\n\n}" },
  { name = "Enum", body = "public enum %s {\n\n}" },
  { name = "Record", body = "public record %s() {\n\n}" },
  { name = "Abstract class", body = "public abstract class %s {\n\n}" },
  {
    name = "Main class",
    body = 'public class %s {\n    public static void main(String[] args) {\n        System.out.println("Hola, mundo!");\n    }\n}',
  },
  {
    name = "JUnit test",
    test = true,
    body = "import static org.junit.jupiter.api.Assertions.*;\n\nimport org.junit.jupiter.api.Test;\n\nclass %s {\n\n    @Test\n    void test() {\n        assertTrue(true);\n    }\n}",
  },
}

--- Contenido de un archivo Java con su declaración de paquete.
function M.java_file(kind, class, pkg)
  local header = (pkg and pkg ~= "") and ("package " .. pkg .. ";\n\n") or ""
  return header .. string.format(kind.body, class)
end

function M.find_kind(name)
  for _, kind in ipairs(M.kinds) do
    if kind.name == name then
      return kind
    end
  end
end

return M

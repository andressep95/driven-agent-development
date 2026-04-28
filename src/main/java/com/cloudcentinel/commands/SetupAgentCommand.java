package com.cloudcentinel.commands;

import picocli.CommandLine.Command;

import java.io.*;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.util.*;
import java.util.concurrent.Callable;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

@Command(
    name = "setup-agent",
    description = "Bootstraps the full agent scaffold: .agents/, skills, scripts, hooks, and symlinks.",
    mixinStandardHelpOptions = true
)
public class SetupAgentCommand implements Callable<Integer> {

    private static final String SCAFFOLD = "scaffold/";

    private final Path root = Path.of(System.getProperty("user.dir"));
    private final Path home = Path.of(System.getProperty("user.home"));

    @Override
    public Integer call() {
        System.out.println("[setup-agent] Bootstrapping agent scaffold...\n");
        try {
            extractFile("rules.md",                           ".agents/rules.md");
            extractFile(".claude/settings.json",              ".claude/settings.json");
            extractFile(".kiro/hooks/post-commit-clear.yaml", ".kiro/hooks/post-commit-clear.yaml");

            extractDir("skills/",  ".agents/skills/");
            extractDir("scripts/", ".agents/scripts/");
            makeAllExecutable(".agents/scripts/");

            mkdir(".agents/memory");

            symlink("CLAUDE.md",                       ".agents/rules.md");
            symlink("AGENTS.md",                       ".agents/rules.md");
            symlink(".claude/skills",                  "../.agents/skills");
            symlink(".kiro/skills",                    "../.agents/skills");
            symlink(".kiro/steering/project-rules.md", "../../.agents/rules.md");

            gitHook("scripts/post-commit", ".git/hooks/post-commit");

            globalHook("hooks/post-commit-clear.sh", ".claude/hooks/post-commit-clear.sh");
            globalHook("hooks/post-commit-clear.sh", ".kiro/hooks/post-commit-clear.sh");

            System.out.println("\n[setup-agent] Done.");
            System.out.println("  Next: fill in '## Stack' in .agents/rules.md, then run scan-memory.");
            return 0;

        } catch (Exception e) {
            System.err.println("\n[setup-agent] ERROR: " + e.getMessage());
            return 1;
        }
    }

    // ── extract ───────────────────────────────────────────────────────────────

    private void extractFile(String from, String to) throws IOException {
        Path target = root.resolve(to);
        Files.createDirectories(target.getParent());
        try (InputStream is = resource(SCAFFOLD + from)) {
            Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
        }
        log("extract", to);
    }

    private void extractDir(String from, String to) throws Exception {
        String prefix   = SCAFFOLD + from;
        Path   targetDir = root.resolve(to);
        File   jarFile   = jarSource();

        if (jarFile != null) {
            try (JarFile jar = new JarFile(jarFile)) {
                Enumeration<JarEntry> entries = jar.entries();
                while (entries.hasMoreElements()) {
                    JarEntry entry = entries.nextElement();
                    String name = entry.getName();
                    if (name.startsWith(prefix) && !entry.isDirectory()) {
                        Path out = targetDir.resolve(name.substring(prefix.length()));
                        Files.createDirectories(out.getParent());
                        try (InputStream is = jar.getInputStream(entry)) {
                            Files.copy(is, out, StandardCopyOption.REPLACE_EXISTING);
                        }
                    }
                }
            }
        } else {
            URL dirUrl = getClass().getClassLoader().getResource(prefix);
            if (dirUrl == null) throw new FileNotFoundException("Resource dir not found: " + prefix);
            Path srcDir = Path.of(dirUrl.toURI());
            Files.walk(srcDir)
                .filter(Files::isRegularFile)
                .forEach(src -> {
                    try {
                        Path out = targetDir.resolve(srcDir.relativize(src).toString());
                        Files.createDirectories(out.getParent());
                        Files.copy(src, out, StandardCopyOption.REPLACE_EXISTING);
                    } catch (IOException ex) {
                        throw new UncheckedIOException(ex);
                    }
                });
        }
        log("extract", to + " (dir)");
    }

    // ── dirs & links ──────────────────────────────────────────────────────────

    private void mkdir(String path) throws IOException {
        Files.createDirectories(root.resolve(path));
        log("mkdir  ", path);
    }

    private void symlink(String linkPath, String targetStr) throws IOException {
        Path link = root.resolve(linkPath);
        Files.createDirectories(link.getParent());
        if (Files.isSymbolicLink(link) || Files.exists(link)) Files.delete(link);
        Files.createSymbolicLink(link, Path.of(targetStr));
        log("symlink", linkPath + " → " + targetStr);
    }

    // ── hooks ─────────────────────────────────────────────────────────────────

    private void gitHook(String from, String to) throws IOException {
        Path target = root.resolve(to);
        Files.createDirectories(target.getParent());
        try (InputStream is = resource(SCAFFOLD + from)) {
            Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
        }
        makeExecutable(target);
        log("hook   ", to + " (+x)");
    }

    private void globalHook(String from, String homeRelPath) throws IOException {
        Path target = home.resolve(homeRelPath);
        Files.createDirectories(target.getParent());
        try (InputStream is = resource(SCAFFOLD + from)) {
            Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
        }
        makeExecutable(target);
        log("global ", "~/" + homeRelPath + " (+x)");
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private InputStream resource(String path) throws FileNotFoundException {
        InputStream is = getClass().getClassLoader().getResourceAsStream(path);
        if (is == null) throw new FileNotFoundException("Resource not found: " + path);
        return is;
    }

    private File jarSource() {
        try {
            File f = new File(getClass().getProtectionDomain().getCodeSource().getLocation().toURI());
            return f.isFile() ? f : null;
        } catch (URISyntaxException e) {
            return null;
        }
    }

    private void makeExecutable(Path file) throws IOException {
        try {
            Set<PosixFilePermission> perms = new HashSet<>(Files.getPosixFilePermissions(file));
            perms.add(PosixFilePermission.OWNER_EXECUTE);
            perms.add(PosixFilePermission.GROUP_EXECUTE);
            Files.setPosixFilePermissions(file, perms);
        } catch (UnsupportedOperationException ignored) {
            // Windows — skip
        }
    }

    private void makeAllExecutable(String dirPath) throws IOException {
        Path dir = root.resolve(dirPath);
        if (!Files.isDirectory(dir)) return;
        Files.walk(dir)
            .filter(Files::isRegularFile)
            .forEach(f -> {
                try { makeExecutable(f); } catch (IOException ignored) {}
            });
    }

    private void log(String action, String detail) {
        System.out.printf("  [%s] %s%n", action, detail);
    }
}

package com.cloudcentinel.commands;

import org.jline.terminal.Attributes;
import org.jline.terminal.Terminal;
import org.jline.terminal.TerminalBuilder;
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
    description = "Initializes git if needed, then bootstraps the full agent scaffold: .agents/, skills, scripts, hooks, and symlinks.",
    mixinStandardHelpOptions = true
)
public class SetupAgentCommand implements Callable<Integer> {

    private static final String SCAFFOLD = "scaffold/";

    private final Path root = Path.of(System.getProperty("user.dir"));
    private final Path home = Path.of(System.getProperty("user.home"));

    private boolean interactive() {
        return System.console() != null;
    }

    @Override
    public Integer call() {
        if (!isGitRepo()) {
            if (interactive()) {
                System.out.print("[setup-agent] No git repository found in this directory.\n"
                        + "Initialize one? [s/n]: ");
                String answer = new Scanner(System.in).nextLine().trim().toLowerCase();
                if (!answer.equals("s")) {
                    System.out.println("[setup-agent] Aborted.");
                    return 0;
                }
            } else {
                System.out.println("[setup-agent] No git repository found — initializing (non-interactive mode).");
            }
            int code = initRepo();
            if (code != 0) return code;
        }

        Set<String> tools;
        try {
            if (interactive()) {
                tools = selectTools();
            } else {
                tools = Set.of("claude", "kiro", "opencode");
                System.out.println("[setup-agent] Non-interactive mode — selecting all tools.");
            }
        } catch (Exception e) {
            System.err.println("[setup-agent] ERROR reading input: " + e.getMessage());
            return 1;
        }
        if (tools.isEmpty()) {
            System.out.println("[setup-agent] No tools selected. Aborted.");
            return 0;
        }

        System.out.println("\n[setup-agent] Bootstrapping agent scaffold...\n");
        try {
            // ── shared ────────────────────────────────────────────────────────
            extractFile("rules.md", ".agents/rules.md");
            extractDir("skills/",   ".agents/skills/");
            extractDir("scripts/",  ".agents/scripts/");
            makeAllExecutable(".agents/scripts/");
            mkdir(".agents/memory");
            gitHook("scripts/post-commit", ".git/hooks/post-commit");

            // ── Claude ────────────────────────────────────────────────────────
            if (tools.contains("claude")) {
                extractFile(".claude/settings.json", ".claude/settings.json");
                symlink("CLAUDE.md",      ".agents/rules.md");
                symlink(".claude/skills", "../.agents/skills");
                globalHook("hooks/post-commit-clear.sh", ".claude/hooks/post-commit-clear.sh");
            }

            // ── Kiro ──────────────────────────────────────────────────────────
            if (tools.contains("kiro")) {
                extractFile(".kiro/hooks/post-commit-clear.yaml", ".kiro/hooks/post-commit-clear.yaml");
                symlink(".kiro/skills",                    "../.agents/skills");
                symlink(".kiro/steering/project-rules.md", "../../.agents/rules.md");
                globalHook("hooks/post-commit-clear.sh", ".kiro/hooks/post-commit-clear.sh");
            }

            // ── OpenCode ──────────────────────────────────────────────────────
            if (tools.contains("opencode")) {
                symlink("AGENTS.md", ".agents/rules.md");
            }

            System.out.println("\n[setup-agent] Done.");
            System.out.println("\n[setup-agent] Initializing memory databases...");
            runBootstrap();
            return 0;

        } catch (Exception e) {
            System.err.println("\n[setup-agent] ERROR: " + e.getMessage());
            return 1;
        }
    }

    private Set<String> selectTools() throws Exception {
        String[] labels  = {"Claude Code", "Kiro", "OpenCode"};
        String[] keys    = {"claude",      "kiro", "opencode"};
        boolean[] marked = {true,          true,   true};
        int cursor = 0;

        try (Terminal terminal = TerminalBuilder.builder().system(true).build()) {
            Attributes saved = terminal.enterRawMode();
            PrintWriter out  = terminal.writer();
            try {
                renderChecklist(out, labels, marked, cursor);
                while (true) {
                    int ch = terminal.reader().read();
                    if (ch == 27) {
                        int b = terminal.reader().read();
                        if (b == '[') {
                            int dir = terminal.reader().read();
                            if (dir == 'A' && cursor > 0) cursor--;
                            else if (dir == 'B' && cursor < labels.length - 1) cursor++;
                        }
                    } else if (ch == ' ') {
                        marked[cursor] = !marked[cursor];
                    } else if (ch == '\r' || ch == '\n') {
                        break;
                    }
                    clearLines(out, labels.length + 3);
                    renderChecklist(out, labels, marked, cursor);
                }
            } finally {
                terminal.setAttributes(saved);
                out.println();
                out.flush();
            }
        }

        Set<String> result = new LinkedHashSet<>();
        for (int i = 0; i < keys.length; i++) {
            if (marked[i]) result.add(keys[i]);
        }
        return result;
    }

    private void renderChecklist(PrintWriter out, String[] labels, boolean[] marked, int cursor) {
        out.println("[setup-agent] Select AI tools to configure:");
        out.println("  ↑↓ navigate  ·  Space toggle  ·  Enter confirm\n");
        for (int i = 0; i < labels.length; i++) {
            String pointer = i == cursor ? "> " : "  ";
            String check   = marked[i]   ? "x" : " ";
            out.printf("  %s[%s] %s%n", pointer, check, labels[i]);
        }
        out.flush();
    }

    private void clearLines(PrintWriter out, int n) {
        for (int i = 0; i < n; i++) out.print("\033[1A\033[2K");
        out.flush();
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

    // ── git ───────────────────────────────────────────────────────────────────

    private boolean isGitRepo() {
        try {
            ProcessBuilder pb = new ProcessBuilder("git", "rev-parse", "--git-dir");
            pb.redirectErrorStream(true);
            Process proc = pb.start();
            String out = new String(proc.getInputStream().readAllBytes()).trim();
            proc.waitFor();
            return !out.startsWith("fatal:");
        } catch (Exception e) {
            return false;
        }
    }

    private void runBootstrap() {
        Path bootstrap = root.resolve(".agents/scripts/bootstrap.sh");
        if (!Files.exists(bootstrap)) {
            System.out.println("  [bootstrap] bootstrap.sh not found — skipping.");
            return;
        }
        try {
            ProcessBuilder pb = new ProcessBuilder("bash", bootstrap.toString());
            pb.directory(root.toFile());
            pb.inheritIO();
            int code = pb.start().waitFor();
            if (code != 0) System.err.println("  [bootstrap] Exited with code " + code + ".");
        } catch (Exception e) {
            System.err.println("  [bootstrap] ERROR: " + e.getMessage());
        }
    }

    private int initRepo() {
        try {
            ProcessBuilder pb = new ProcessBuilder("git", "init");
            pb.inheritIO();
            int code = pb.start().waitFor();
            if (code == 0) System.out.println("[setup-agent] Git repository initialized.\n");
            else System.err.println("[setup-agent] Failed to initialize git (exit " + code + ").");
            return code;
        } catch (Exception e) {
            System.err.println("[setup-agent] ERROR: " + e.getMessage());
            return 1;
        }
    }
}

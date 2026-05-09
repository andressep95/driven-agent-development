package com.cloudcentinel.setup;

import java.io.*;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.util.*;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.stream.Stream;

public final class ScaffoldInstaller {

    private static final String SCAFFOLD = "scaffold/";

    private final Path root;
    private final Path home;
    private final ClassLoader loader;
    private final File jarFile;

    public ScaffoldInstaller(Path root, Path home, Class<?> source) {
        this.root    = root;
        this.home    = home;
        this.loader  = source.getClassLoader();
        this.jarFile = resolveJar(source);
    }

    public void extractFile(String from, String to) throws IOException {
        Path target = root.resolve(to);
        Files.createDirectories(target.getParent());
        try (InputStream is = resource(SCAFFOLD + from)) {
            Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
        }
        log("extract", to);
    }

    public void extractDir(String from, String to) throws Exception {
        String prefix    = SCAFFOLD + from;
        Path   targetDir = root.resolve(to);

        if (jarFile != null) {
            try (JarFile jar = new JarFile(jarFile)) {
                Enumeration<JarEntry> entries = jar.entries();
                while (entries.hasMoreElements()) {
                    JarEntry entry = entries.nextElement();
                    String name = entry.getName();
                    if (name.startsWith(prefix) && !entry.isDirectory()) {
                        Path dest = targetDir.resolve(name.substring(prefix.length()));
                        Files.createDirectories(dest.getParent());
                        try (InputStream is = jar.getInputStream(entry)) {
                            Files.copy(is, dest, StandardCopyOption.REPLACE_EXISTING);
                        }
                    }
                }
            }
        } else {
            URL dirUrl = loader.getResource(prefix);
            if (dirUrl == null) throw new FileNotFoundException("Resource dir not found: " + prefix);
            Path srcDir = Path.of(dirUrl.toURI());
            try (Stream<Path> stream = Files.walk(srcDir)) {
                stream.filter(Files::isRegularFile).forEach(src -> {
                    try {
                        Path dest = targetDir.resolve(srcDir.relativize(src).toString());
                        Files.createDirectories(dest.getParent());
                        Files.copy(src, dest, StandardCopyOption.REPLACE_EXISTING);
                    } catch (IOException ex) {
                        throw new UncheckedIOException(ex);
                    }
                });
            }
        }
        log("extract", to + " (dir)");
    }

    public void cleanSkillsDir() throws IOException {
        Path skillsDir = root.resolve(".agents/skills");
        if (!Files.exists(skillsDir)) return;
        try (Stream<Path> stream = Files.walk(skillsDir)) {
            stream.sorted(Comparator.reverseOrder())
                  .forEach(p -> { try { Files.delete(p); } catch (IOException ignored) {} });
        }
        log("clean  ", ".agents/skills/ (reset)");
    }

    public void extractSelectedSkills(Set<String> skills) throws Exception {
        if (skills.isEmpty()) { log("extract", ".agents/skills/ (none selected)"); return; }
        for (String skill : skills) {
            extractDir("skills/" + skill + "/", ".agents/skills/" + skill + "/");
        }
        log("extract", ".agents/skills/ (" + skills.size() + " skills)");
    }

    public void mkdir(String path) throws IOException {
        Files.createDirectories(root.resolve(path));
        log("mkdir  ", path);
    }

    public void symlink(String linkPath, String targetStr) throws IOException {
        Path link = root.resolve(linkPath);
        Files.createDirectories(link.getParent());
        if (Files.isSymbolicLink(link) || Files.exists(link)) Files.delete(link);
        Files.createSymbolicLink(link, Path.of(targetStr));
        log("symlink", linkPath + " → " + targetStr);
    }

    public void gitHook(String from, String to) throws IOException {
        Path target = root.resolve(to);
        Files.createDirectories(target.getParent());
        try (InputStream is = resource(SCAFFOLD + from)) {
            Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
        }
        makeExecutable(target);
        log("hook   ", to + " (+x)");
    }

    public void globalHook(String from, String homeRelPath) throws IOException {
        Path target = home.resolve(homeRelPath);
        Files.createDirectories(target.getParent());
        try (InputStream is = resource(SCAFFOLD + from)) {
            Files.copy(is, target, StandardCopyOption.REPLACE_EXISTING);
        }
        makeExecutable(target);
        log("global ", "~/" + homeRelPath + " (+x)");
    }

    public void makeAllExecutable(String dirPath) throws IOException {
        Path dir = root.resolve(dirPath);
        if (!Files.isDirectory(dir)) return;
        try (Stream<Path> stream = Files.walk(dir)) {
            stream.filter(Files::isRegularFile)
                  .forEach(f -> { try { makeExecutable(f); } catch (IOException ignored) {} });
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

    private InputStream resource(String path) throws FileNotFoundException {
        InputStream is = loader.getResourceAsStream(path);
        if (is == null) throw new FileNotFoundException("Resource not found: " + path);
        return is;
    }

    private static File resolveJar(Class<?> source) {
        try {
            File f = new File(source.getProtectionDomain().getCodeSource().getLocation().toURI());
            return f.isFile() ? f : null;
        } catch (URISyntaxException e) {
            return null;
        }
    }

    private void log(String action, String detail) {
        System.out.printf("  [%s] %s%n", action, detail);
    }
}

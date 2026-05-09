package com.cloudcentinel.setup;

import java.io.*;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.*;
import java.util.*;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.stream.Stream;

public final class SkillRegistry {

    private static final String PREFIX = "scaffold/skills/";

    private final ClassLoader loader;
    private final File jarFile;

    public SkillRegistry(Class<?> source) {
        this.loader = source.getClassLoader();
        this.jarFile = resolveJar(source);
    }

    public List<String> listSkills() throws Exception {
        Set<String> skills = new LinkedHashSet<>();
        if (jarFile != null) {
            try (JarFile jar = new JarFile(jarFile)) {
                Enumeration<JarEntry> entries = jar.entries();
                while (entries.hasMoreElements()) {
                    String name = entries.nextElement().getName();
                    if (name.startsWith(PREFIX) && name.length() > PREFIX.length()) {
                        String rest = name.substring(PREFIX.length());
                        int slash = rest.indexOf('/');
                        if (slash > 0) skills.add(rest.substring(0, slash));
                    }
                }
            }
        } else {
            URL dirUrl = loader.getResource(PREFIX);
            if (dirUrl != null) {
                Path srcDir = Path.of(dirUrl.toURI());
                try (Stream<Path> stream = Files.list(srcDir)) {
                    stream.filter(Files::isDirectory)
                          .map(p -> p.getFileName().toString())
                          .sorted()
                          .forEach(skills::add);
                }
            }
        }
        return new ArrayList<>(skills);
    }

    public List<SkillMeta> parseMetas(Set<String> skillNames) {
        List<SkillMeta> metas = new ArrayList<>();
        for (String s : skillNames) metas.add(parse(s));
        metas.sort(Comparator.comparing(SkillMeta::name));
        return metas;
    }

    private SkillMeta parse(String skillName) {
        InputStream is = loader.getResourceAsStream(PREFIX + skillName + "/SKILL.md");
        if (is == null) return new SkillMeta(skillName, "", List.of());

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(is))) {
            String name = skillName;
            StringBuilder desc = new StringBuilder();
            List<String> autoInvoke = new ArrayList<>();
            boolean inFrontmatter = false;
            boolean inAutoInvoke  = false;
            boolean inDescription = false;
            String line;

            while ((line = reader.readLine()) != null) {
                String t = line.trim();
                if (t.equals("---")) {
                    if (!inFrontmatter) { inFrontmatter = true; continue; }
                    else break;
                }
                if (!inFrontmatter) continue;

                if (t.startsWith("name:")) {
                    name = t.substring(5).trim().replaceAll("^\"|\"$", "");
                    inAutoInvoke = false; inDescription = false;
                } else if (t.equals("description: >") || t.equals("description: |")) {
                    inDescription = true; inAutoInvoke = false;
                } else if (t.startsWith("description:") && !t.endsWith(">") && !t.endsWith("|")) {
                    desc.append(t.substring(12).trim().replaceAll("^\"|\"$", ""));
                    inDescription = false; inAutoInvoke = false;
                } else if (inDescription && (line.startsWith("  ") || line.startsWith("\t"))) {
                    desc.append(t).append(" ");
                } else if (t.equals("auto_invoke:")) {
                    inAutoInvoke = true; inDescription = false;
                } else if (inAutoInvoke && t.startsWith("- ")) {
                    autoInvoke.add(t.substring(2).replaceAll("^\"|\"$", "").trim());
                } else if (!t.startsWith("-") && t.contains(":") && !line.startsWith(" ") && !line.startsWith("\t")) {
                    inAutoInvoke = false; inDescription = false;
                }
            }
            return new SkillMeta(name, desc.toString().trim(), List.copyOf(autoInvoke));
        } catch (IOException e) {
            return new SkillMeta(skillName, "", List.of());
        }
    }

    private static File resolveJar(Class<?> source) {
        try {
            File f = new File(source.getProtectionDomain().getCodeSource().getLocation().toURI());
            return f.isFile() ? f : null;
        } catch (URISyntaxException e) {
            return null;
        }
    }
}

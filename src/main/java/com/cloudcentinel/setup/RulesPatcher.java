package com.cloudcentinel.setup;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public final class RulesPatcher {

    private RulesPatcher() {}

    /**
     * Replaces the Available Skills and Auto-Invoke Skills tables in rules.md
     * with rows generated from the given skill metadata. All other content is preserved.
     */
    public static void patch(Path rulesPath, List<SkillMeta> metas) throws IOException {
        List<String> lines = Files.readAllLines(rulesPath, StandardCharsets.UTF_8);
        List<String> out   = new ArrayList<>(lines.size() + metas.size() * 4);
        int state = 0; // 0=copy  1=skip-available  2=skip-auto-invoke

        for (String line : lines) {
            switch (state) {
                case 0 -> {
                    out.add(line);
                    if (line.equals("## Available Skills")) {
                        out.add("");
                        writeAvailable(out, metas);
                        state = 1;
                    } else if (line.equals("## Auto-Invoke Skills")) {
                        out.add("");
                        writeAutoInvoke(out, metas);
                        state = 2;
                    }
                }
                case 1 -> {
                    // skip old available-skills content until the next section
                    if (line.equals("## Auto-Invoke Skills")) {
                        out.add("");
                        out.add(line);
                        out.add("");
                        writeAutoInvoke(out, metas);
                        state = 2;
                    }
                }
                case 2 -> {
                    // skip old auto-invoke content until the next section
                    if (line.startsWith("## ")) {
                        out.add("");
                        out.add(line);
                        state = 0;
                    }
                }
            }
        }

        Files.write(rulesPath, out, StandardCharsets.UTF_8);
        System.out.printf("  [patch  ] .agents/rules.md (%d skills)%n", metas.size());
    }

    private static void writeAvailable(List<String> out, List<SkillMeta> metas) {
        out.add("| Skill | Trigger |");
        out.add("|-------|---------|");
        for (SkillMeta m : metas) {
            out.add("| `" + m.name() + "` | " + m.trigger() + " |");
        }
    }

    private static void writeAutoInvoke(List<String> out, List<SkillMeta> metas) {
        out.add("| Action | Skill |");
        out.add("|--------|-------|");
        for (SkillMeta m : metas) {
            if (!m.autoInvoke().isEmpty()) {
                out.add("| " + m.trigger() + " | `" + m.name() + "` |");
            }
        }
    }
}

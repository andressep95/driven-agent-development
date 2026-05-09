package com.cloudcentinel.commands;

import com.cloudcentinel.setup.*;
import picocli.CommandLine.Command;

import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.Callable;

@Command(
    name = "setup-agent",
    description = "Initializes git if needed, then bootstraps the full agent scaffold: .agents/, skills, scripts, hooks, and symlinks.",
    mixinStandardHelpOptions = true
)
public class SetupAgentCommand implements Callable<Integer> {

    private final Path root = Path.of(System.getProperty("user.dir"));
    private final Path home = Path.of(System.getProperty("user.home"));

    @Override
    public Integer call() {
        if (!isGitRepo()) {
            if (interactive()) {
                System.out.print("[setup-agent] No git repository found.\nInitialize one? [s/n]: ");
                String answer = new Scanner(System.in).nextLine().trim().toLowerCase();
                if (!answer.equals("s")) { System.out.println("[setup-agent] Aborted."); return 0; }
            } else {
                System.out.println("[setup-agent] No git repository found — initializing (non-interactive mode).");
            }
            int code = initRepo();
            if (code != 0) return code;
        }

        ScaffoldInstaller installer = new ScaffoldInstaller(root, home, getClass());
        SkillRegistry     registry  = new SkillRegistry(getClass());

        // ── Step 1: AI tools ──────────────────────────────────────────────────
        Set<String> tools;
        try {
            tools = interactive() ? pickTools() : allTools();
        } catch (Exception e) {
            System.err.println("[setup-agent] ERROR: " + e.getMessage()); return 1;
        }
        if (tools.isEmpty()) { System.out.println("[setup-agent] No tools selected. Aborted."); return 0; }

        // ── Step 2: skills ────────────────────────────────────────────────────
        Set<String> skills;
        try {
            List<String> available = registry.listSkills();
            skills = interactive() ? pickSkills(available) : new LinkedHashSet<>(available);
            if (!interactive()) System.out.println("[setup-agent] Non-interactive — selecting all skills.");
        } catch (Exception e) {
            System.err.println("[setup-agent] ERROR: " + e.getMessage()); return 1;
        }

        // ── Install ───────────────────────────────────────────────────────────
        System.out.println("\n[setup-agent] Bootstrapping agent scaffold...\n");
        try {
            installer.extractFile("rules.md", ".agents/rules.md");
            installer.cleanSkillsDir();
            installer.extractSelectedSkills(skills);
            RulesPatcher.patch(root.resolve(".agents/rules.md"), registry.parseMetas(skills));
            installer.extractDir("scripts/", ".agents/scripts/");
            installer.makeAllExecutable(".agents/scripts/");
            installer.mkdir(".agents/memory");
            installer.gitHook("scripts/post-commit", ".git/hooks/post-commit");

            if (tools.contains("claude")) {
                installer.extractFile(".claude/settings.json", ".claude/settings.json");
                installer.symlink("CLAUDE.md",      ".agents/rules.md");
                installer.symlink(".claude/skills", "../.agents/skills");
                installer.globalHook("hooks/post-commit-clear.sh", ".claude/hooks/post-commit-clear.sh");
            }
            if (tools.contains("kiro")) {
                installer.extractFile(".kiro/hooks/post-commit-clear.yaml",   ".kiro/hooks/post-commit-clear.yaml");
                installer.extractFile(".kiro/hooks/user-prompt-submit.yaml",  ".kiro/hooks/user-prompt-submit.yaml");
                installer.extractFile(".kiro/hooks/session-start.yaml",       ".kiro/hooks/session-start.yaml");
                installer.extractFile(".kiro/hooks/validate-commit.yaml",     ".kiro/hooks/validate-commit.yaml");
                installer.symlink(".kiro/skills",                    "../.agents/skills");
                installer.symlink(".kiro/steering/project-rules.md", "../../.agents/rules.md");
                installer.globalHook("hooks/post-commit-clear.sh", ".kiro/hooks/post-commit-clear.sh");
            }
            if (tools.contains("opencode")) {
                installer.symlink("AGENTS.md", ".agents/rules.md");
            }

            System.out.println("\n[setup-agent] Done.");
            System.out.println("\n[setup-agent] To initialize memory databases, run:");
            System.out.println("    bash .agents/scripts/init.sh");
            return 0;

        } catch (Exception e) {
            System.err.println("\n[setup-agent] ERROR: " + e.getMessage());
            return 1;
        }
    }

    // ── selection helpers ─────────────────────────────────────────────────────

    private static Set<String> pickTools() throws Exception {
        return Checklist.select(
            "[setup-agent] Select AI tools to configure:",
            new String[]{"Claude Code", "Kiro", "OpenCode"},
            new String[]{"claude",      "kiro", "opencode"},
            new boolean[]{true,          true,   true}
        );
    }

    private static Set<String> allTools() {
        System.out.println("[setup-agent] Non-interactive — selecting all tools.");
        return new LinkedHashSet<>(List.of("claude", "kiro", "opencode"));
    }

    private static Set<String> pickSkills(List<String> available) throws Exception {
        String[]  labels = available.toArray(new String[0]);
        boolean[] dflt   = new boolean[available.size()];
        Arrays.fill(dflt, true);
        return Checklist.select("[setup-agent] Select skills to install:", labels, labels, dflt);
    }

    // ── git ───────────────────────────────────────────────────────────────────

    private boolean interactive() { return System.console() != null; }

    private boolean isGitRepo() {
        try {
            ProcessBuilder pb = new ProcessBuilder("git", "rev-parse", "--git-dir");
            pb.redirectErrorStream(true);
            Process p = pb.start();
            String out = new String(p.getInputStream().readAllBytes()).trim();
            p.waitFor();
            return !out.startsWith("fatal:");
        } catch (Exception e) { return false; }
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

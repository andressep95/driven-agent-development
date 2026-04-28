package com.cloudcentinel.commands;

import picocli.CommandLine.Command;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;

@Command(
    name = "scan-git",
    description = "Scans the current git repository: config, remotes, branches, hooks, and recent history.",
    mixinStandardHelpOptions = true
)
public class ScanGitConfigCommand implements Callable<Integer> {

    @Override
    public Integer call() {
        if (!isGitRepo()) {
            System.err.println("ERROR: Not inside a git repository.");
            return 1;
        }

        printSection("IDENTITY", git("config", "user.name"), git("config", "user.email"));
        printBlock("REMOTES",   git("remote", "-v"));
        printBlock("BRANCHES",  git("branch", "-a"));
        printBlock("HOOKS",     listHooks());
        printBlock("CONFIG",    git("config", "--list"));
        printBlock("STATUS",    git("status", "--short"));
        printBlock("RECENT COMMITS", git("log", "--oneline", "-10"));

        return 0;
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private boolean isGitRepo() {
        List<String> out = git("rev-parse", "--git-dir");
        return !out.isEmpty() && !out.get(0).startsWith("fatal:");
    }

    private List<String> git(String... args) {
        List<String> cmd = new ArrayList<>();
        cmd.add("git");
        for (String a : args) cmd.add(a);
        return run(cmd);
    }

    private List<String> listHooks() {
        List<String> result = new ArrayList<>();
        List<String> gitDirLines = git("rev-parse", "--git-dir");
        if (gitDirLines.isEmpty()) return result;

        File hooksDir = new File(gitDirLines.get(0).trim(), "hooks");
        if (!hooksDir.isDirectory()) {
            result.add("(hooks directory not found)");
            return result;
        }

        File[] files = hooksDir.listFiles(f -> !f.getName().endsWith(".sample") && f.isFile());
        if (files == null || files.length == 0) {
            result.add("(no active hooks)");
            return result;
        }

        for (File f : files) {
            String executable = f.canExecute() ? "[executable]" : "[not executable]";
            result.add(f.getName() + "  " + executable);
        }
        return result;
    }

    private List<String> run(List<String> cmd) {
        List<String> output = new ArrayList<>();
        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.redirectErrorStream(true);
            Process proc = pb.start();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) output.add(line);
            }
            proc.waitFor();
        } catch (Exception e) {
            output.add("ERROR: " + e.getMessage());
        }
        return output;
    }

    private void printSection(String title, List<String>... values) {
        System.out.println("\n══ " + title + " ══");
        for (List<String> lines : values) {
            for (String l : lines) System.out.println("  " + l);
        }
    }

    private void printBlock(String title, List<String> lines) {
        System.out.println("\n══ " + title + " ══");
        if (lines.isEmpty()) {
            System.out.println("  (empty)");
        } else {
            for (String l : lines) System.out.println("  " + l);
        }
    }
}

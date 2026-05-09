package com.cloudcentinel.setup;

import java.util.List;

public record SkillMeta(String name, String description, List<String> autoInvoke) {

    public String trigger() {
        if (!autoInvoke.isEmpty()) return autoInvoke.get(0);
        if (description != null && !description.isBlank()) {
            int idx = description.indexOf("Trigger:");
            if (idx >= 0) return truncate(extractSentence(description, idx + 8));
            idx = description.indexOf("should be used when ");
            if (idx >= 0) return truncate(extractSentence(description, idx + 20));
        }
        return "See SKILL.md";
    }

    private static String extractSentence(String text, int from) {
        String after = text.substring(from).trim();
        int dot = after.indexOf('.');
        return dot >= 0 ? after.substring(0, dot) : after;
    }

    private static String truncate(String s) {
        return s.length() <= 80 ? s : s.substring(0, 77) + "...";
    }
}
